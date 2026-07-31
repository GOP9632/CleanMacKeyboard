import Foundation

/// 清潔流程的三個階段。
///
/// 這是狀態機的全部狀態，不多也不少。畫面上看到的顏色與文字是它的投影
/// （見 `RingPhase`），不是另一份狀態。
enum CleaningStage: String, CaseIterable, Equatable {
    /// 待命：app 已啟動但未攔截任何輸入。
    case standby

    /// 準備清潔：按下開始之後、攔截尚未生效的緩衝倒數。
    ///
    /// 這個階段**不攔截**。它存在的目的是讓使用者把手離開鍵盤、拿起抹布。
    case preparing

    /// 清潔中：輸入裝置被攔截，使用者可以安全擦拭機身。
    case cleaning
}

/// 離開清潔中的路徑。
///
/// 這個型別是那條不變條件的所在：**任何**離開清潔中的路徑都必須要求攔截器
/// 解除。控制器只有一個函式能離開清潔中，而那個函式吃的就是這個值，
/// 所以「有沒有漏掉一條路」變成「這個列舉有沒有漏掉一個 case」，
/// 而後者有測試逐項守著。
///
/// 現在有解鎖手勢與逾時兩條。闔蓋與喚醒（#7）、安全輸入模式（#8）之後會各加
/// 一個 case，加的時候不需要再想一次要不要解除攔截。
enum CleaningExit: String, CaseIterable, Equatable {
    /// 解鎖手勢完成。使用者自己按滿了設定的秒數。
    case unlockGesture

    /// 逾時解鎖。時間到自動回到待命。
    case timedOut

    /// 離開時要播的那一聲。`nil` 代表這條路徑不出聲。
    ///
    /// 逾時解除的聲音必須與解鎖成功不同，使用者才知道是保險跳掉了，
    /// 而不是自己解開的。
    var sound: WipeSound? {
        switch self {
        case .unlockGesture: .unlocked
        case .timedOut: .timedOut
        }
    }
}
