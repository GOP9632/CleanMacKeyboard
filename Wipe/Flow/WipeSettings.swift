import Foundation

/// 控制器需要的設定值。
///
/// 它是七個接縫裡最單純的一個：純粹的值，不需要假的實作，測試直接給一組
/// 就好。這裡只負責「有哪些值、值的範圍在哪」；存到硬碟上是
/// `WipeSettingsStore` 的事，畫成畫面是 `SettingsView` 的事。
///
/// 安全網不在這裡：逾時可以調長短但不能關，闔蓋解鎖與「第三顆鍵歸零」
/// 根本沒有對應的欄位。設定只調整體驗，不拆保險
/// （見 `docs/adr/0002-safety-nets-are-not-configurable.md`）。
struct WipeSettings: Equatable {
    /// 緩衝秒數的可調範圍。
    static let bufferSecondsRange: ClosedRange<Int> = 1...10

    /// 解鎖手勢要按住幾秒的可調範圍。
    ///
    /// 下限一秒：零秒的按住等於一按就開，抹布掃過兩顆 Command 就解鎖了，
    /// 而手勢存在的理由正是抹布做不到。上限十秒，再長就不是手勢而是懲罰。
    static let unlockHoldSecondsRange: ClosedRange<TimeInterval> = 1...10

    /// 逾時的可調範圍。
    ///
    /// 上限 15 分鐘寫死，而且沒有「關閉」或「永不」這個選項可以選：
    /// 型別上就是一個一定有值的秒數。這是 ADR-0002 在程式裡的樣子。
    ///
    /// 下限刻意低到 30 秒，因為開發版預設就是 30 秒。設定畫面提供給使用者
    /// 的選項是這個範圍的子集合，見 `SettingsOptions.timeoutSeconds`。
    static let timeoutSecondsRange: ClosedRange<TimeInterval> = 30...(15 * 60)

    #if DEBUG
    /// 開發版預設 30 秒。判定邏輯出錯時不必等太久。
    static let defaultTimeoutSeconds: TimeInterval = 30
    #else
    /// 正式版預設 5 分鐘。
    static let defaultTimeoutSeconds: TimeInterval = 5 * 60
    #endif

    /// 按下開始之後要不要先給一段緩衝倒數。
    var bufferIsEnabled: Bool

    /// 緩衝倒數幾秒。超出範圍的值會被拉回範圍內。
    var bufferSeconds: Int {
        didSet { bufferSeconds = Self.bufferSecondsRange.clamping(bufferSeconds) }
    }

    /// 進入清潔模式後幾秒自動解除。超出範圍的值會被拉回範圍內。
    var timeoutSeconds: TimeInterval {
        didSet { timeoutSeconds = Self.timeoutSecondsRange.clamping(timeoutSeconds) }
    }

    /// 解鎖手勢要按住幾秒。超出範圍的值會被拉回範圍內。
    ///
    /// 這是使用者自己在安全與方便之間的取捨：按久一點，抹布誤解鎖的機會更低；
    /// 按短一點，自己解鎖更輕鬆。它調的是體驗，不是保險，所以可調
    /// （「第三顆按鍵就重新計時」那一條才是保險，見 ADR-0002）。
    var unlockHoldSeconds: TimeInterval {
        didSet { unlockHoldSeconds = Self.unlockHoldSecondsRange.clamping(unlockHoldSeconds) }
    }

    /// 攔截範圍。切換是設定項，不是每次進入時詢問。
    var interceptionScope: InterceptionScope

    /// 清潔模式期間畫面怎麼呈現。
    var screenPresentation: ScreenPresentation

    /// 七個時刻的音效開關。
    var sounds: SoundSettings

    init(
        bufferIsEnabled: Bool = true,
        bufferSeconds: Int = 3,
        timeoutSeconds: TimeInterval = defaultTimeoutSeconds,
        unlockHoldSeconds: TimeInterval = 3,
        interceptionScope: InterceptionScope = .keyboard,
        screenPresentation: ScreenPresentation = .mainWindow,
        sounds: SoundSettings = SoundSettings()
    ) {
        self.bufferIsEnabled = bufferIsEnabled
        // init 裡的指派不會觸發 didSet，所以這三個要自己夾一次。
        // 舊版本存下的值若落在現在的範圍之外，就是在這裡被拉回來的：
        // `WipeSettingsStore` 讀完硬碟上的值之後一律走這個 init。
        self.bufferSeconds = Self.bufferSecondsRange.clamping(bufferSeconds)
        self.timeoutSeconds = Self.timeoutSecondsRange.clamping(timeoutSeconds)
        self.unlockHoldSeconds = Self.unlockHoldSecondsRange.clamping(unlockHoldSeconds)
        self.interceptionScope = interceptionScope
        self.screenPresentation = screenPresentation
        self.sounds = sounds
    }
}

private extension ClosedRange {
    func clamping(_ value: Bound) -> Bound {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}
