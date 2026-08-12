import AppKit
import CoreGraphics

/// 攔截範圍換成「事件攔截器要監看哪些事件」。
///
/// 這張表是鍵盤鎖與全輸入鎖之間唯一的差別。它擺在這裡而不是 `InputInterceptor`
/// 裡面，是因為範圍本身是流程的詞彙（設定裡選得到、控制器讀得到），
/// 而 `CGEventType` 是實作那一頭的事，只有真的事件攔截器需要它。
extension InterceptionScope {
    /// 這個範圍要監看的事件遮罩，也就是 `CGEvent.tapCreate` 收的那個形式。
    ///
    /// 只有這個遮罩點到的事件會進到攔截器的回呼，也只有它們會被丟掉。
    ///
    /// 兩個範圍是包含關係，不是兩組不同的東西：全輸入鎖就是鍵盤鎖再加上
    /// 觸控板與滑鼠。有測試守著這個關係。
    var eventMask: CGEventMask {
        switch self {
        case .keyboard: Self.keyboardMask
        case .allInput: Self.keyboardMask | Self.pointerMask
        }
    }

    /// 鍵盤上的每一顆鍵，包括上排那些媒體鍵。
    ///
    /// 修飾鍵變化（`.flagsChanged`）也要在裡面：少了它，按著 Command 擦鍵盤
    /// 就會讓別的 app 收到一連串組合鍵。
    private static let keyboardMask =
        mask(of: [CGEventType.keyDown, .keyUp, .flagsChanged]) | mediaKeyMask

    /// 觸控板與滑鼠，包括多指手勢。
    ///
    /// 游標移動（`.mouseMoved`）與三種拖曳都要在裡面，否則其他 app 會繼續收到
    /// 「滑鼠移到這裡了」，選單與按鈕會跟著亮起來。
    ///
    /// **游標本身還是會動。**#12 在真機上驗過：這一層攔得下事件，沒有 app 收得到
    /// 它們，點擊與手勢完全沒有反應，但螢幕上那個箭頭照樣跟著手指跑。游標的位置
    /// 是視窗伺服器直接從 HID 那一層畫的，不經過這個攔截點。要真的把箭頭定住得
    /// 用別的機制，那是另一張票的事；畫面上的說明也因此不承諾游標會停
    /// （見 `InterceptionScope.statusText`）。
    private static let pointerMask = mask(of: [
        CGEventType.leftMouseDown, .leftMouseUp,
        .rightMouseDown, .rightMouseUp,
        .otherMouseDown, .otherMouseUp,
        .mouseMoved,
        .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
        .scrollWheel,
    ]) | gestureMask

    /// 上排媒體鍵（音量、亮度、播放）走的那一種事件，`NX_SYSDEFINED`。
    ///
    /// 少了它，抹布掃過上排照樣會調音量與亮度，那就不是使用者要的
    /// 「鍵盤完全沒有反應」（見 #1 的 user story 10）。
    ///
    /// `CGEventType` 沒有這個成員：它本來是 IOKit 的常數
    /// （`IOLLEvent.h` 的 `NX_SYSDEFINED`）。AppKit 那一頭有同一個值，
    /// 所以編號從那裡拿，不必自己抄數字。
    ///
    /// 這一種事件裡混著媒體鍵以外的系統訊息，這裡是整批丟掉，沒有分類：
    /// 從 `CGEvent` 分辨子種類要先轉成 `NSEvent`，而分錯的代價是安靜地
    /// 漏掉幾顆鍵。清潔模式期間這些訊息全部不送出去，時間上限就是逾時那幾
    /// 分鐘，然後一切照舊。擦上排真的沒反應、其餘功能沒受影響，這兩件事
    /// 只有真機驗得到。
    private static let mediaKeyMask = mask(of: [NSEvent.EventType.systemDefined])

    /// 觸控板的多指手勢：旋轉、縮放、滑動、用力按、直接觸碰。
    ///
    /// 這些跟點擊是同一件事的兩半。少了它們，全輸入鎖底下點擊沒有反應，
    /// 抹布掃過觸控板照樣會縮放頁面、切換桌面，而使用者以為自己已經把觸控板
    /// 關掉了。那就是製造假象（見 `CONTEXT.md` 的不變條件）。
    ///
    /// #12 在真機上驗過這一整組真的有效：點擊與手勢完全沒有反應。
    ///
    /// 跟媒體鍵同一個處境：`CGEventType` 一個成員都沒有，編號從
    /// `NSEvent.EventType` 拿。
    ///
    /// 這張清單刻意寬鬆，把每一種沾得上手勢的事件都放進來，包括只是標記
    /// 起點與終點的 `.beginGesture` 與 `.endGesture`，以及觸控表面本身的
    /// `.directTouch`。多攔幾種在清潔模式期間沒有代價，那幾分鐘裡這些事件
    /// 本來就一律丟掉；漏掉的代價卻是安靜地漏掉一種手勢。
    ///
    private static let gestureMask = mask(of: [
        NSEvent.EventType.gesture,
        .magnify,
        .rotate,
        .swipe,
        .smartMagnify,
        .pressure,
        .beginGesture,
        .endGesture,
        .directTouch,
    ])

    /// 一串事件種類換成它們在遮罩裡的那幾個位元。
    ///
    /// 吃兩種列舉，因為有幾種事件只有 `NSEvent.EventType` 有成員
    /// （見 `mediaKeyMask` 與 `gestureMask`）。兩套常數的編號是同一組值，
    /// 所以換算的算式只有這一份。
    private static func mask<Event: RawRepresentable>(of types: [Event]) -> CGEventMask
    where Event.RawValue: BinaryInteger {
        types.reduce(0) { $0 | (1 << CGEventMask($1.rawValue)) }
    }
}
