import CoreGraphics
import Foundation

/// 真的攔截：用 CGEventTap 把事件丟掉。
///
/// 這是插在輸入攔截器那個接縫上的真實世界那一頭（見 `docs/seams.md`）。
/// 控制器一行都不用改，換掉的只是插在同一個插座上的東西：
/// 開發期插 `DryRunInputInterceptor`，正式跑插這個。
///
/// **測試裡絕對不能用它。**真的裝上去，跑測試的那台電腦就當場沒有鍵盤。
/// 所以這個類別本身沒有自動化測試，只有它裡面兩塊「錯了會安靜地失效」的
/// 判斷被抽成純值測著（`InterceptionScope.eventMask` 與 `EventTapResponse`），
/// 其餘靠真機驗收（見 #1 的手動驗收清單第 1、8、10 項）。
///
/// ## 為什麼 process 一死攔截就消失
///
/// CGEventTap 是掛在這個 process 上的。process 沒了，系統就把它拆掉，
/// 鍵盤立刻恢復。這不是這裡多寫了什麼程式碼換來的，而是刻意不寫任何
/// 東西換來的：不裝 daemon、不註冊登入項目、不自動重啟
/// （見 `CONTEXT.md` 的不變條件）。
@MainActor
final class EventTapInputInterceptor: InputInterceptor {
    private(set) var activeScope: InterceptionScope?

    /// 每一個被丟掉的鍵盤事件，在丟掉之前先把判讀交出來。
    ///
    /// 這是解鎖手勢在真的攔截底下唯一的訊號來源。少了它，使用者一進清潔模式
    /// 就再也解不開（見 `InterceptedKeyboardSignalSource`）。
    var onKeyboardReading: ((KeyboardEventReading) -> Void)?

    /// 攔截被系統停掉之後又接回來了。
    ///
    /// 停用的那段空窗裡，事件照常送到其他 app，Wipe 一個也沒看到。使用者
    /// 在那段時間放開的鍵會永遠留在鍵盤狀態裡，變成一顆壓著不放的幽靈按鍵，
    /// 而解鎖手勢碰到第三顆按鍵就歸零，也就是使用者再也解不開。
    /// 接回來的那一刻要把按鍵狀態忘乾淨，這條路就是通知那件事的。
    var onInterceptionResumed: (() -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func startIntercepting(scope: InterceptionScope) -> Bool {
        // 先解一次。重複呼叫是安全的，而留下一個舊的攔截等於漏解一次。
        stopIntercepting()

        // 沒有「輔助使用」授權時這一行就會回傳 nil，也就是控制器要的那個
        // 「裝不上去」。系統說有授權而這裡照樣失敗的情況真的存在，最常見的
        // 原因是簽章換過（見 `InputInterceptor.startIntercepting(scope:)`）。
        guard let tap = CGEvent.tapCreate(
            // 事件進到登入 session 的地方。放在這裡就攔得下送往所有 app 的事件。
            //
            // 另一個選擇是 `.cghidEventTap`，位置更前面，但那一層連系統自己的
            // 東西都一起接管，代價是萬一 Wipe 出問題影響更大。真機驗收若發現
            // 有哪個系統捷徑漏過去，改的就是這一行，理由記在這裡。
            tap: .cgSessionEventTap,
            // 插在佇列最前面，其他 app 裝的攔截拿到之前就先丟掉。
            place: .headInsertEventTap,
            // 要能真的丟掉事件就不可以是 `.listenOnly`。
            options: .defaultTap,
            eventsOfInterest: scope.eventMask,
            callback: { _, type, event, context in
                // 這個回呼是一個 C 函式指標，捕捉不到任何東西，所以攔截器本人
                // 是從 `userInfo` 那個指標找回來的。
                guard let context else { return nil }
                let interceptor = Unmanaged<EventTapInputInterceptor>
                    .fromOpaque(context)
                    .takeUnretainedValue()
                // 回呼跑在攔截註冊的那個 run loop 上，也就是主執行緒。
                // 型別上沒有寫出來，所以這裡自己說明白。
                MainActor.assumeIsolated { interceptor.handle(event, of: type) }
                // 一律回傳 nil，也就是「這個事件到此為止」。會走到這裡的
                // 事件全部是我們自己指定要攔的那些（見 `InterceptionScope`），
                // 清潔模式期間它們就是不該送到任何地方。
                return nil
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        // 用 common modes 而不是 default mode：選單拉開、視窗在拖曳的時候
        // run loop 會換模式，只註冊 default mode 的話那幾秒鐘鍵盤會活過來。
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        // 建得起來不等於啟用得起來。這一步不確認的話，畫面會顯示清潔中而
        // 鍵盤還活著，正是 Wipe 最不能發生的事。
        guard CGEvent.tapIsEnabled(tap: tap) else {
            Self.teardown(tap: tap, source: source)
            return false
        }

        self.tap = tap
        runLoopSource = source
        activeScope = scope
        return true
    }

    /// 攔截還活著嗎，不活的話先修一次再回答。
    ///
    /// 修一次是為了不要為了一個瞬間就把使用者踢出清潔模式：系統剛把攔截停掉、
    /// 通知還沒送到回呼的那一小段時間，這裡問到的就是「停著」。真的修不回來
    /// 才是失效，那一刻誠實回報比繼續顯示清潔中重要得多。
    func confirmIntercepting() -> Bool {
        guard let tap else { return false }
        if CGEvent.tapIsEnabled(tap: tap) { return true }
        CGEvent.tapEnable(tap: tap, enable: true)
        guard CGEvent.tapIsEnabled(tap: tap) else { return false }
        // 停用的那段空窗裡，使用者放開的鍵 Wipe 收不到，留在狀態裡就成了一顆
        // 永遠壓著的幽靈按鍵，而那顆鍵會讓解鎖手勢每一次事件都歸零，
        // 也就是使用者再也解不開（見 `onInterceptionResumed`）。
        onInterceptionResumed?()
        return true
    }

    func stopIntercepting() {
        Self.teardown(tap: tap, source: runLoopSource)
        tap = nil
        runLoopSource = nil
        activeScope = nil
    }

    /// 一個事件送進回呼了。
    ///
    /// 事件本身在回呼那一頭已經被丟掉了，這裡只做兩件事：把系統擅自停掉的
    /// 攔截重新啟用，以及把鍵盤判讀交給解鎖手勢那條路。
    private func handle(_ event: CGEvent, of type: CGEventType) {
        switch EventTapResponse(eventType: type) {
        case .reenable:
            // macOS 會在回呼處理得太慢的時候自己把攔截停掉，而且不會有任何
            // 錯誤，只有鍵盤悄悄復活。這一行就是驗收條件裡的「攔截被系統
            // 因逾時而停用時，app 重新啟用它」。
            //
            // 修不回來的話這裡不做第二件事：控制器每一格都會問一次
            // `confirmIntercepting()`，那條路會把使用者帶出清潔模式。
            _ = confirmIntercepting()
        case .discard:
            // 全輸入鎖底下滑鼠事件也會進來，那些沒有判讀，丟掉就算了。
            guard let reading = KeyboardEventReading(event, type: type) else { return }
            onKeyboardReading?(reading)
        }
    }

    /// 把攔截從系統上拆下來。
    ///
    /// 靜態而且 nonisolated，因為 `deinit` 也要用，而 `deinit` 不在 main actor 上。
    /// 裡面兩個 CoreFoundation 呼叫本來就可以在任何執行緒上做。
    nonisolated private static func teardown(tap: CFMachPort?, source: CFRunLoopSource?) {
        if let source {
            CFRunLoopSourceInvalidate(source)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
    }

    deinit {
        // 物件沒了，攔截也必須跟著沒。留著的話系統會抱著一個沒有人收事件的
        // 攔截，鍵盤就真的回不來了。
        Self.teardown(tap: tap, source: runLoopSource)
    }
}
