import Foundation

/// 清潔流程控制器的時間來源。
///
/// 控制器不准直接讀系統時間（見 `docs/seams.md`）。逾時解鎖、準備清潔的緩衝
/// 倒數、解鎖手勢按住的秒數全部走這裡，測試才能用虛擬時間推進，
/// 不需要真的等 15 分鐘。
@MainActor
protocol WipeClock: AnyObject {
    /// 單調遞增的秒數。
    ///
    /// 它只用來相減算「過了多久」，絕對值沒有意義。刻意不是牆上時鐘：
    /// 使用者調整系統時間或夏令時間切換都不該讓倒數跳一大格。
    var now: TimeInterval { get }

    /// 開始以固定間隔回呼，直到 `stopTicking()`。
    ///
    /// 重複呼叫是換掉前一個，不是再裝一個。控制器在階段轉換時會直接再呼叫
    /// 一次，若這裡累積成兩個計時器，每一格就會被走兩遍。
    func startTicking(every interval: TimeInterval, onTick: @MainActor @escaping () -> Void)

    func stopTicking()
}

extension TimeInterval {
    /// 時間比對的容差。
    ///
    /// 不管是真的計時器還是虛擬時間，時間都是一格一格加上去的，而浮點數
    /// 加久了會有誤差。所以「有沒有走滿三秒」這種比較要留一點餘裕，
    /// 否則最後一格會差那麼一點點而不成立。
    ///
    /// 它放在時鐘接縫旁邊，因為接縫兩頭用的必須是同一個值。這個量級遠小於
    /// 任何有意義的時間差。
    static let clockTolerance: TimeInterval = 1e-6
}
