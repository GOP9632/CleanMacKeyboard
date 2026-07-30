import Foundation
import Observation

/// 清潔流程控制器：持有狀態機的那個東西。
///
/// 它是這個專案**唯一**的自動化測試接縫（見 `docs/seams.md`）。所有規格描述的
/// 行為都必須經過它，而它不准直接讀系統時間、不准直接註冊系統事件、不准直接
/// 呼叫攔截 API。這些能力全部從外面注入進來，測試才有辦法把真實世界那一頭
/// 拔掉換成替身。
///
/// 這一版只做階段流程本身：待命、準備清潔、清潔中，以及逾時解鎖。
/// 解鎖手勢是 #5，闔蓋與喚醒是 #7，安全輸入模式是 #8，真正的攔截是 #11。
/// 那幾張票加的都是「離開清潔中的一條路」或「一個注入進來的訊號」，
/// 不會改動這裡的骨架。
@MainActor
@Observable
final class CleaningFlowController {
    /// 目前階段。只有這個類別改得動它。
    private(set) var stage: CleaningStage = .standby

    /// 設定值。改了之後從下一次進入清潔模式起生效。
    var settings: WipeSettings

    @ObservationIgnored private let clock: WipeClock
    @ObservationIgnored private let interceptor: InputInterceptor
    @ObservationIgnored private let sound: SoundOutput

    /// 目前這個階段是什麼時候開始的。只跟 `clock.now` 相減，絕對值沒有意義。
    @ObservationIgnored private var stageStartedAt: TimeInterval = 0

    /// 目前這個階段已經過了多久。
    ///
    /// 這是唯一一個會隨時間變動的儲存屬性，畫面上所有會動的數字都由它算出來。
    /// 刻意不讓那些數字直接去問時鐘：那樣算出來的值不會通知畫面重畫。
    private var elapsed: TimeInterval = 0

    /// 準備清潔期間已經播到第幾聲。
    @ObservationIgnored private var preparingTicksPlayed = 0

    init(
        settings: WipeSettings,
        clock: WipeClock,
        interceptor: InputInterceptor,
        sound: SoundOutput
    ) {
        self.settings = settings
        self.clock = clock
        self.interceptor = interceptor
        self.sound = sound
    }

    /// 乾跑用的組裝：真的跑完整個流程，但輸入攔截器什麼都不做。
    ///
    /// 乾跑不是第二個接縫，只是在同一個接縫換一組替身（見 `docs/seams.md`）。
    static func dryRun(settings: WipeSettings = WipeSettings()) -> CleaningFlowController {
        CleaningFlowController(
            settings: settings,
            clock: SystemClock(),
            interceptor: DryRunInputInterceptor(),
            sound: SystemSoundOutput()
        )
    }

    // MARK: - 對外可觀察
    //
    // 這裡只放 `docs/seams.md` 列的那幾個值。圓環要畫成什麼樣子不在這裡：
    // 那是視圖層拿這幾個值去映射的事，控制器不認識 SwiftUI。

    /// 準備清潔還剩幾秒。不在準備清潔時是 `nil`。
    var preparingSecondsRemaining: Int? {
        guard stage == .preparing else { return nil }
        return Self.secondsRemaining(from: TimeInterval(settings.bufferSeconds) - elapsed)
    }

    /// 準備清潔的倒數走完了多少，0 到 1。
    ///
    /// 緩衝秒數至少是 1（見 `WipeSettings.bufferSecondsRange`），所以這裡
    /// 不必擔心除以零。
    var preparingProgress: Double {
        guard stage == .preparing else { return 0 }
        return min(elapsed / TimeInterval(settings.bufferSeconds), 1)
    }

    /// 距離逾時自動解除還剩幾秒。不在清潔中時是 `nil`。
    ///
    /// 這個值以文字呈現，不佔用圓環：解鎖進度是使用者唯一需要盯著看的東西，
    /// 逾時只會被偶爾瞄一眼，兩者時間尺度差兩個數量級。
    var timeoutSecondsRemaining: Int? {
        guard stage == .cleaning else { return nil }
        return Self.secondsRemaining(from: settings.timeoutSeconds - elapsed)
    }

    // MARK: - 使用者動作

    /// 使用者點了圓環。
    func activateRing() {
        switch stage {
        case .standby: start()
        case .preparing: cancel()
        // 清潔中的圓環不可點擊：抹布掃過觸控板剛好點到不可以有任何作用。
        // 畫面那一層也擋著（見 `RingPhase.allowsActivation`），這裡是第二道。
        case .cleaning: break
        }
    }

    /// 使用者按下開始。
    func start() {
        guard stage == .standby else { return }
        if settings.bufferIsEnabled {
            enterPreparing()
        } else {
            enterCleaning()
        }
    }

    /// 使用者在準備清潔期間反悔（按 Esc 或再點一次圓環）。
    ///
    /// 只有準備清潔取消得掉。清潔中要離開得走 `exitCleaning(_:)`，
    /// 因為那條路一定要解除攔截。
    func cancel() {
        guard stage == .preparing else { return }
        enterStandby()
    }

    /// 離開清潔中。**這是唯一的出口。**
    ///
    /// 不變條件：任何離開清潔中的路徑都必須要求攔截器解除。所以離開的動作
    /// 只有這一個函式做得到，別在其他地方把 `stage` 改回待命。
    /// 有測試逐項走過 `CleaningExit` 的每一個 case 守著這一條。
    func exitCleaning(_ exit: CleaningExit) {
        guard stage == .cleaning else { return }
        interceptor.stopIntercepting()
        enterStandby()
        if let sound = exit.sound { self.sound.play(sound) }
    }

    // MARK: - 階段轉換

    private func enterStandby() {
        stage = .standby
        clock.stopTicking()
        stageStartedAt = clock.now
        elapsed = 0
        preparingTicksPlayed = 0
    }

    private func enterPreparing() {
        stage = .preparing
        preparingTicksPlayed = 0
        beginTiming()
        // 第一聲在按下開始的當下就響，使用者不必等滿一秒才聽到回應。
        advancePreparing()
    }

    private func enterCleaning() {
        stage = .cleaning
        beginTiming()
        // 先真的開始攔截，再出聲。那一聲是「可以開始擦了」的許可，
        // 它響的時候鍵盤必須已經是鎖著的。
        interceptor.startIntercepting(scope: settings.interceptionScope)
        sound.play(.locked)
    }

    /// 開始為新的階段計時。
    ///
    /// 從準備清潔轉進清潔中時，這裡會把起點重設成「現在」，也就是最多差
    /// 一格 tick 的那個時間點。逾時是分鐘等級的東西，這點誤差不影響任何事。
    private func beginTiming() {
        stageStartedAt = clock.now
        elapsed = 0
        clock.startTicking(every: Self.tickInterval) { [weak self] in
            self?.tick()
        }
    }

    // MARK: - 時間推進

    private func tick() {
        elapsed = clock.now - stageStartedAt
        switch stage {
        case .preparing: advancePreparing()
        case .cleaning: advanceCleaning()
        case .standby: break
        }
    }

    private func advancePreparing() {
        let buffer = TimeInterval(settings.bufferSeconds)
        guard elapsed + .clockTolerance < buffer else {
            enterCleaning()
            return
        }
        // 走過第幾個整秒就該響過幾聲。用「已經播了幾聲」跟「該播幾聲」相比，
        // 而不是判斷「這一格是不是剛好踩在整秒上」：後者只要有一格被跳過
        // 就會漏掉一聲。
        let due = min(Int(elapsed + .clockTolerance) + 1, settings.bufferSeconds)
        while preparingTicksPlayed < due {
            preparingTicksPlayed += 1
            sound.play(.preparingTick)
        }
    }

    private func advanceCleaning() {
        guard elapsed + .clockTolerance >= settings.timeoutSeconds else { return }
        exitCleaning(.timedOut)
    }

    /// 每一格的長度。
    ///
    /// 三十分之一秒是為了圓環：解鎖手勢的按住進度會直接畫在環上，格子太粗
    /// 會看得出來在跳。逾時那一邊完全不需要這麼細，但多算幾次的成本是零。
    static let tickInterval: TimeInterval = 1.0 / 30.0

    /// 把「還剩多少時間」換成畫面上要顯示的秒數。
    ///
    /// 無條件進位：剩 0.2 秒時顯示的是 1，歸零那一刻才顯示 0。這樣數字看起來
    /// 才跟使用者感覺到的一致。
    private static func secondsRemaining(from remaining: TimeInterval) -> Int {
        max(0, Int((remaining - .clockTolerance).rounded(.up)))
    }
}
