import Foundation

@testable import Wipe

/// 測試用的鍵盤訊號來源：測試自己說「現在按著什麼」，不需要真鍵盤。
///
/// 每呼叫一次 `send`，就等於真的鍵盤送出一次事件。這個區別很重要：
/// 解鎖手勢的「第三顆按鍵歸零」以**按下**為觸發，不追蹤放開，所以測試必須
/// 能表達「這一次事件帶著第三顆鍵」，而不只是「現在有第三顆鍵按著」。
@MainActor
final class FakeKeyboardSignalSource: KeyboardSignalSource {
    private(set) var signal: KeyboardSignal = .idle

    var onSignal: ((KeyboardSignal) -> Void)?
    var onReading: ((KeyboardEventReading) -> Void)?

    /// 現在有沒有在監看。控制器只在清潔中需要鍵盤，其他時候應該放手。
    private(set) var isMonitoring = false

    func start() { isMonitoring = true }

    func stop() {
        isMonitoring = false
        signal = .idle
    }

    /// 送一次鍵盤事件進去。
    func send(
        leftCommand: Bool = false,
        rightCommand: Bool = false,
        otherModifiers: Bool = false,
        otherKey: Bool = false
    ) {
        signal = KeyboardSignal(
            leftCommandIsDown: leftCommand,
            rightCommandIsDown: rightCommand,
            otherModifiersAreDown: otherModifiers,
            otherKeyIsDown: otherKey
        )
        onSignal?(signal)
    }

    /// 兩顆 Command 都按住。
    func holdBothCommands() {
        send(leftCommand: true, rightCommand: true)
    }

    /// 按住兩顆 Command 的期間壓到第三顆鍵。
    func pressThirdKey() {
        send(leftCommand: true, rightCommand: true, otherKey: true)
    }

    /// 全部放開。
    func releaseEverything() {
        send()
    }
}
