import Foundation
import Observation

/// 清潔流程控制器：持有狀態機的那個東西。
///
/// 它是這個專案**唯一**的自動化測試接縫（見 `docs/seams.md`）。所有規格描述的
/// 行為都必須經過它，而它不准直接讀系統時間、不准直接註冊系統事件、不准直接
/// 呼叫攔截 API。這些能力全部從外面注入進來，測試才有辦法把真實世界那一頭
/// 拔掉換成替身。
///
/// 這一版做的是階段流程本身（待命、準備清潔、清潔中）、逾時解鎖，以及解鎖手勢。
/// 闔蓋與喚醒是 #7，安全輸入模式是 #8，真正的攔截是 #11。那幾張票加的都是
/// 「離開清潔中的一條路」或「一個注入進來的訊號」，不會改動這裡的骨架。
@MainActor
@Observable
final class CleaningFlowController {
    /// 目前階段。只有這個類別改得動它。
    private(set) var stage: CleaningStage = .standby

    /// 目前的設定值。
    ///
    /// 控制器只讀不寫：設定是使用者從設定視窗改的，改動走
    /// `WipeSettingsStore`，控制器每次要用的時候問一次最新的值。
    var settings: WipeSettings { settingsStore.settings }

    @ObservationIgnored private let settingsStore: WipeSettingsStore
    @ObservationIgnored private let clock: WipeClock
    @ObservationIgnored private let keyboard: KeyboardSignalSource
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

    /// 解鎖手勢目前按到哪裡。
    ///
    /// 它是 `@ObservationIgnored` 的：畫面上會動的是按住進度，而那個值算出來
    /// 要靠 `elapsed`，清潔中每一格都在變，環自然會跟著重畫。
    @ObservationIgnored private var gesture = UnlockGesture()

    init(
        settings store: WipeSettingsStore,
        clock: WipeClock,
        keyboard: KeyboardSignalSource,
        interceptor: InputInterceptor,
        sound: SoundOutput
    ) {
        self.settingsStore = store
        self.clock = clock
        self.keyboard = keyboard
        self.interceptor = interceptor
        self.sound = sound
        // 鍵盤是推進來的，不是定期去讀的。理由見 `KeyboardSignalSource.onSignal`。
        self.keyboard.onSignal = { [weak self] signal in
            self?.keyboardSignalArrived(signal)
        }
    }

    /// 給一組值就好的組裝。測試與預覽用：設定只活在記憶體裡，不碰硬碟。
    convenience init(
        settings: WipeSettings,
        clock: WipeClock,
        keyboard: KeyboardSignalSource,
        interceptor: InputInterceptor,
        sound: SoundOutput
    ) {
        self.init(
            settings: WipeSettingsStore(settings),
            clock: clock,
            keyboard: keyboard,
            interceptor: interceptor,
            sound: sound
        )
    }

    /// 乾跑用的組裝：真的跑完整個流程，但輸入攔截器什麼都不做。
    ///
    /// 乾跑不是第二個接縫，只是在同一個接縫換一組替身（見 `docs/seams.md`）。
    ///
    /// 不給設定就用一組只活在記憶體裡的預設值，預覽用。這裡用 optional 而不是
    /// 直接把 `WipeSettingsStore(WipeSettings())` 寫成預設值，是因為預設值的
    /// 算式跑在 nonisolated 的位置，叫不動 `@MainActor` 的初始化。
    static func dryRun(settings: WipeSettingsStore? = nil) -> CleaningFlowController {
        CleaningFlowController(
            settings: settings ?? WipeSettingsStore(WipeSettings()),
            clock: SystemClock(),
            keyboard: LocalKeyboardSignalSource(),
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

    /// 解鎖手勢按住了多少，0 到 1。清潔中的圓環畫的就是這個值。
    ///
    /// 環在清潔中**只**表達這一件事，不表達逾時：解鎖進度是使用者唯一需要
    /// 盯著看的東西，兩者共用同一個環會讓人分不清哪一個在動。
    var unlockHoldProgress: Double {
        guard stage == .cleaning else { return 0 }
        return gesture.progress(at: clockTimeAtLastTick, holdSeconds: settings.unlockHoldSeconds)
    }

    /// 上一格走完的時候是幾點。
    ///
    /// 刻意繞過 `clock.now` 而從 `elapsed` 推回去：`elapsed` 是會通知畫面重畫的
    /// 那個值，直接問時鐘算出來的進度不會讓環動起來。
    private var clockTimeAtLastTick: TimeInterval { stageStartedAt + elapsed }

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
        if let sound = exit.sound { play(sound) }
    }

    // MARK: - 出聲

    /// 播放某一個時刻的音效，除非設定說這一聲要靜音。
    ///
    /// 控制器裡每一個會出聲的地方都走這一個函式，沒有例外。哪幾聲要靜音是
    /// 設定的事，不是控制器的事（見 `docs/seams.md`），所以判斷只出現在
    /// 這一行，其他地方照樣直說「現在該響哪一聲」。
    private func play(_ sound: WipeSound) {
        guard settings.sounds.plays(sound) else { return }
        self.sound.play(sound)
    }

    // MARK: - 解鎖手勢

    /// 鍵盤送來一次事件。
    ///
    /// 只有清潔中的事件算數：手勢是「離開清潔模式」的動作，還沒進去的時候
    /// 按住它不該累積任何進度，否則一進去就立刻解開。
    private func keyboardSignalArrived(_ signal: KeyboardSignal) {
        guard stage == .cleaning else { return }
        switch gesture.observe(signal, at: clock.now) {
        case .nothing:
            break
        case .detected:
            // 使用者看不到螢幕時，這一聲代表「認到了，繼續按住」。
            play(.unlockGestureDetected)
        case .reset:
            // 沒有這一聲，使用者會白按滿三秒才發現剛才被歸零了。
            play(.unlockGestureReset)
        }
    }

    // MARK: - 階段轉換

    private func enterStandby() {
        stage = .standby
        clock.stopTicking()
        // 待命不需要鍵盤。手勢只在清潔中有意義，其他時候放手，
        // 順便把按著的鍵忘乾淨。
        keyboard.stop()
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
        // 每一次進入清潔中，手勢都從零開始。這一行是防呆：上一次的進度若被留著，
        // 一進來就會立刻解開，那是這個 app 最不能發生的事。
        gesture = UnlockGesture()
        beginTiming()
        // 從這一刻起才聽鍵盤。進來之前按著什麼都不算，所以剛好按著兩顆 Command
        // 進到清潔中也不會立刻解開。
        keyboard.start()
        // 先真的開始攔截，再出聲。那一聲是「可以開始擦了」的許可，
        // 它響的時候鍵盤必須已經是鎖著的。
        interceptor.startIntercepting(scope: settings.interceptionScope)
        play(.locked)
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
            play(.preparingTick)
        }
    }

    private func advanceCleaning() {
        // 手勢先問。兩件事撞在同一格時，使用者自己按滿的那條路優先，
        // 出的聲音才對得上他剛剛做的事。
        if gesture.isComplete(at: clock.now, holdSeconds: settings.unlockHoldSeconds) {
            exitCleaning(.unlockGesture)
            return
        }
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
