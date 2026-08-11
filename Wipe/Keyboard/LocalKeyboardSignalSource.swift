import AppKit
import Observation

/// 用 AppKit 的**本機**事件監看器實作的鍵盤訊號來源。
///
/// 選本機監看器有兩個理由：
///
/// 一是它不需要任何系統授權。全域監看器與 CGEventTap 都要「輔助使用」授權，
/// 而授權是綁在簽章上的，開發期簽章會一直變（見 `Config/Common.xcconfig`）。
/// 要回答「左右 Command 分不分得開」不必先把授權那條路走完。
///
/// 二是它不可能攔截到東西。監看器把事件原封不動還回去就等於沒有插手，
/// 這件事有測試守著。
///
/// 代價是它只收得到送進 Wipe 自己的事件，也就是 Wipe 在前景的時候。
/// 對診斷來說夠了；清潔模式期間真正的訊號來自輸入攔截器那一條路。
@MainActor
@Observable
final class LocalKeyboardSignalSource: KeyboardSignalSource {
    private(set) var signal: KeyboardSignal = .idle

    @ObservationIgnored
    var onSignal: ((KeyboardSignal) -> Void)?

    @ObservationIgnored
    var onReading: ((KeyboardEventReading) -> Void)?

    @ObservationIgnored
    private var monitor: Any?

    /// 按鍵狀態的累加規則。跟攔截那一條路共用同一份
    /// （見 `KeyboardSignalReader`）。
    ///
    /// 這一份是累加出來的，所以它跟修飾鍵不一樣：按著某顆鍵的時候切到別的 app，
    /// 那顆鍵的放開事件就收不到，會留下一個不存在的按鍵。診斷用不著在意，
    /// 清潔流程走的是攔截那一條路，事件不會漏掉。
    @ObservationIgnored
    private var reader = KeyboardSignalReader()

    var isMonitoring: Bool { monitor != nil }

    private static let monitoredEvents: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .keyUp]

    func start() {
        // 重複呼叫不可以裝上第二個監看器，否則每一次按鍵都會被記兩遍。
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: Self.monitoredEvents) { [weak self] event in
            // AppKit 保證這個區塊在主執行緒上被呼叫，只是它的型別上沒有寫出來。
            // 刻意不把事件當成回傳值帶出這個區塊：`NSEvent` 不是 Sendable，
            // 那樣寫在 Swift 6 會是錯誤。
            MainActor.assumeIsolated { _ = self?.handle(event) }
            // 收到哪一個就還哪一個。回傳 nil 才是攔截，而這個來源不攔截，
            // 這裡也沒有第二條路可以走。
            return event
        }
    }

    func stop() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
        signal = .idle
        reader.forgetEverything()
    }

    /// 讀一個事件，然後把它原封不動地還回去。
    ///
    /// 回傳型別刻意是 `NSEvent` 而不是 `NSEvent?`：本機監看器回傳 `nil` 就是
    /// 攔截，而這個來源不攔截也不修改任何事件。型別上沒有那個選項，
    /// 日後就不會有人不小心加上去。
    @discardableResult
    func handle(_ event: NSEvent) -> NSEvent {
        guard let reading = KeyboardEventReading(event) else { return event }

        signal = reader.read(reading)

        // 每一次事件都交出去一次，即使狀態跟上一次一模一樣。解鎖手勢要靠
        // 「這一次事件帶著第三顆鍵」來歸零，只在狀態變了才通知會漏掉按鍵重複。
        onSignal?(signal)
        onReading?(reading)
        return event
    }

    deinit {
        // 這裡不能碰 signal 與 pressedKeyCodes（deinit 不在 main actor 上），
        // 但監看器一定要拆掉，否則 AppKit 會抱著一個死掉的物件。
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
}
