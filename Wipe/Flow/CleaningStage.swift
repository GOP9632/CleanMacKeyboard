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
/// 現在有六條：解鎖手勢、逾時、闔蓋解鎖的兩個訊號，以及兩種「攔不住了」
/// （偵測到安全輸入模式、攔截跑到一半死掉）。
enum CleaningExit: String, CaseIterable, Equatable {
    /// 解鎖手勢完成。使用者自己按滿了設定的秒數。
    case unlockGesture

    /// 逾時解鎖。時間到自動回到待命。
    case timedOut

    /// 闔蓋解鎖的主要訊號：螢幕蓋子闔上。
    case lidClosed

    /// 闔蓋解鎖的次要訊號：系統從睡眠喚醒。
    ///
    /// 為什麼兩個訊號都要，見 `MachineSignal`。
    case systemWoke

    /// 偵測到安全輸入模式。
    ///
    /// 這條不是使用者要求的，也不是保險跳掉，而是 Wipe 承認自己攔不住了。
    /// 清潔模式絕不在無法可靠攔截時維持（見 `CONTEXT.md` 的不變條件）。
    case secureInput

    /// 裝上去的攔截跑到一半死掉。
    ///
    /// 系統把它停掉而且修不回來，或授權在清潔中被收回。事件從那一刻起重新
    /// 流向其他 app，鍵盤已經活了，畫面卻還寫著清潔中。跟安全輸入模式一樣，
    /// 這條不是使用者要求的，是 Wipe 承認自己攔不住了。
    case interceptionLost

    /// 離開時要播的那一聲。`nil` 代表這條路徑不出聲。
    ///
    /// 逾時解除的聲音必須與解鎖成功不同，使用者才知道是保險跳掉了，
    /// 而不是自己解開的。
    ///
    /// 安全輸入模式與攔截死掉那兩條借用「拒絕進入」的那一聲。它們跟拒絕是
    /// 同一件事的不同時機：Wipe 攔不住，所以不做。這一聲非響不可，
    /// 使用者這時正閉著眼睛擦，畫面已經不是他以為的那個了。
    ///
    /// 闔蓋與喚醒兩條不出聲。出聲的時刻是規格寫死的七個（見 #1），這兩條
    /// 不在裡面：蓋子闔上的人看不到也多半聽不到螢幕那一邊發生什麼事，而
    /// 喚醒之後畫面上就是待命，不需要一聲來解釋。
    var sound: WipeSound? {
        switch self {
        case .unlockGesture: .unlocked
        case .timedOut: .timedOut
        case .secureInput, .interceptionLost: .refused
        case .lidClosed, .systemWoke: nil
        }
    }
}
