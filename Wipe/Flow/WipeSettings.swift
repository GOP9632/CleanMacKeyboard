import Foundation

/// 控制器需要的設定值。
///
/// 它是七個接縫裡最單純的一個：純粹的值，不需要假的實作，測試直接給一組
/// 就好。設定畫面與持久化是 #6，這裡只負責「有哪些值、值的範圍在哪」。
///
/// 安全網不在這裡：逾時可以調長短但不能關，闔蓋解鎖與「第三顆鍵歸零」
/// 根本沒有對應的欄位。設定只調整體驗，不拆保險
/// （見 `docs/adr/0002-safety-nets-are-not-configurable.md`）。
struct WipeSettings: Equatable {
    /// 緩衝秒數的可調範圍。
    static let bufferSecondsRange: ClosedRange<Int> = 1...10

    /// 逾時的可調範圍。
    ///
    /// 上限 15 分鐘寫死，而且沒有「關閉」或「永不」這個選項可以選：
    /// 型別上就是一個一定有值的秒數。這是 ADR-0002 在程式裡的樣子。
    ///
    /// 下限刻意低到 30 秒，因為開發版預設就是 30 秒。設定畫面提供給使用者
    /// 的選項會是這個範圍的子集合（見 #6）。
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

    /// 攔截範圍。切換是設定項，不是每次進入時詢問。
    var interceptionScope: InterceptionScope

    init(
        bufferIsEnabled: Bool = true,
        bufferSeconds: Int = 3,
        timeoutSeconds: TimeInterval = defaultTimeoutSeconds,
        interceptionScope: InterceptionScope = .keyboard
    ) {
        self.bufferIsEnabled = bufferIsEnabled
        // init 裡的指派不會觸發 didSet，所以這兩個要自己夾一次。
        // 舊版本存下的值若落在現在的範圍之外，就是在這裡被拉回來的（見 #6）。
        self.bufferSeconds = Self.bufferSecondsRange.clamping(bufferSeconds)
        self.timeoutSeconds = Self.timeoutSecondsRange.clamping(timeoutSeconds)
        self.interceptionScope = interceptionScope
    }
}

private extension ClosedRange {
    func clamping(_ value: Bound) -> Bound {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}
