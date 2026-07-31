import Foundation

/// 解鎖手勢的判定：同時按住左右 Command 滿設定秒數。
///
/// 它是一個純值，只認得「鍵盤現在長什麼樣」與「現在幾點」，不知道階段、
/// 不知道攔截、也不出聲。判定結果交回給清潔流程控制器，由控制器決定要播哪一聲、
/// 要不要離開清潔中。這樣這幾條規則可以擺在一起讀，而規則本身是這個 app
/// 最要緊的一段：解不開與被抹布誤解鎖，兩邊都不能發生。
///
/// 四條規則（見 #1 的實作決策）：
///
/// 1. 左右 Command 都按住、且沒有夾帶其他修飾鍵時開始計時。不要求同一瞬間按下。
/// 2. 任一顆放開，計時歸零。
/// 3. 計時期間出現任何第三顆按鍵，計時歸零。
/// 4. 連續按住滿設定的秒數才算完成。
struct UnlockGesture {
    /// 一次觀察造成的結果。控制器拿它去對應要播哪一聲。
    enum Reaction: Equatable {
        /// 什麼都沒發生：可能還沒開始計時，也可能只是繼續按著。
        case nothing

        /// 剛認到手勢，開始計時。這一聲是「認到了，繼續按住」。
        case detected

        /// 計時歸零。停下來也好、從零重新開始也好，對使用者都是同一件事：
        /// 剛才那幾秒不算了。
        case reset
    }

    /// 這一輪計時是什麼時候開始的。`nil` 代表現在沒有在計時。
    private(set) var startedAt: TimeInterval?

    /// 看一次鍵盤事件。
    ///
    /// 傳進來的是**一次事件**，不是定期的取樣。第三顆按鍵之所以只在這裡歸零
    /// 一次，就是因為這件事：一顆被壓著不動的鍵不會一直產生事件，也就不會
    /// 一直歸零。反過來若靠「現在有沒有第三顆鍵按著」來判斷，系統漏掉一次
    /// 放開事件就會讓使用者永遠解不開，那是比誤觸更嚴重的失效。
    ///
    /// 已知的殘留風險：使用者若關閉了系統的按鍵重複，一顆被壓著不動的鍵
    /// 只會觸發一次歸零。這個取捨是刻意的。
    mutating func observe(_ signal: KeyboardSignal, at now: TimeInterval) -> Reaction {
        guard signal.isHoldingBothCommands else {
            guard startedAt != nil else { return .nothing }
            startedAt = nil
            return .reset
        }
        guard startedAt != nil else {
            // 這裡刻意不管第三顆鍵按著沒有。它只在計時期間歸零，不阻止開始，
            // 否則一顆漏掉放開事件的鍵會讓手勢永遠開不了頭。
            startedAt = now
            return .detected
        }
        guard signal.otherKeyIsDown else { return .nothing }
        // 從零重新開始，而不是停下來等下一次事件。停下來的話，使用者按住兩顆
        // Command 不動、而那顆鍵的放開事件又沒來，就再也沒有東西叫得醒計時。
        startedAt = now
        return .reset
    }

    /// 按住的秒數夠了沒。
    func isComplete(at now: TimeInterval, holdSeconds: TimeInterval) -> Bool {
        guard let startedAt else { return false }
        return now - startedAt + .clockTolerance >= holdSeconds
    }

    /// 按住走完了多少，0 到 1。圓環畫的就是這個值。
    func progress(at now: TimeInterval, holdSeconds: TimeInterval) -> Double {
        guard let startedAt, holdSeconds > 0 else { return 0 }
        return min(max((now - startedAt) / holdSeconds, 0), 1)
    }
}
