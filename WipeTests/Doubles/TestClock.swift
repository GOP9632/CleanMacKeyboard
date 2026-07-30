import Foundation

@testable import Wipe

/// 測試用的虛擬時鐘。時間只在測試自己喊 `advance(by:)` 的時候前進。
///
/// 有了它，「五分鐘後自動解除」這種測試不需要真的等五分鐘，甚至 15 分鐘的
/// 逾時上限也是一瞬間跑完的。任何測試都不應該真的等待。
@MainActor
final class TestClock: WipeClock {
    private(set) var now: TimeInterval = 0

    private var interval: TimeInterval?
    private var onTick: (@MainActor () -> Void)?

    /// 現在有沒有人掛著計時。控制器回到待命時應該停掉。
    var isTicking: Bool { interval != nil }

    func startTicking(every interval: TimeInterval, onTick: @MainActor @escaping () -> Void) {
        self.interval = interval
        self.onTick = onTick
    }

    func stopTicking() {
        interval = nil
        onTick = nil
    }

    /// 推進虛擬時間。
    ///
    /// 刻意一格一格走完，中間每一格都回呼，這樣控制器看到的過程跟真實時鐘
    /// 底下一模一樣，而不是一步跳到終點。「倒數期間每秒一聲」這種行為，
    /// 只有走完每一格才驗得到。
    ///
    /// 回呼期間控制器可能會換掉或停掉計時（階段轉換就會），所以每一圈都
    /// 重新讀一次目前的間隔。
    func advance(by seconds: TimeInterval) {
        let target = now + seconds
        while let interval, interval > 0, now + interval <= target + .clockTolerance {
            now = Swift.min(now + interval, target)
            onTick?()
        }
        if now < target { now = target }
    }
}
