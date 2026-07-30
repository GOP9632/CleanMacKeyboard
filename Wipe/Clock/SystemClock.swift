import Foundation

/// 真的系統時鐘。app 跑起來時插在時鐘接縫上的就是這一個。
@MainActor
final class SystemClock: WipeClock {
    /// 開機到現在的秒數。
    ///
    /// 用它而不是 `Date()`：它單調遞增，不受使用者調整系統時間影響。
    /// 它在系統睡眠期間不前進，這剛好是想要的行為，因為睡醒之後清潔模式
    /// 本來就會被喚醒解鎖收掉（見 #7），不需要靠倒數補刀。
    var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    private var timer: Timer?

    func startTicking(every interval: TimeInterval, onTick: @MainActor @escaping () -> Void) {
        stopTicking()
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            // Timer 掛在主 run loop 上，所以這個區塊一定在主執行緒，
            // 只是它的型別上沒有寫出來。
            MainActor.assumeIsolated { onTick() }
        }
        // 用 .common 而不是預設模式：使用者拖著視窗或按著選單時，
        // 預設模式的計時器會停住，而倒數與逾時在那幾秒裡不可以凍結。
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopTicking() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        // deinit 不在 main actor 上，但計時器一定要拆掉，
        // 否則 run loop 會抱著一個已經沒人要的物件繼續跑。
        timer?.invalidate()
    }
}
