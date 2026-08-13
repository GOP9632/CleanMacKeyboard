import Foundation

/// 清潔模式期間阻止螢幕因為閒置而變暗或關閉。
///
/// 使用者擦機器的那幾分鐘裡不會碰鍵盤也不會碰觸控板，那正是系統判斷「閒置」
/// 的依據。沒有這份宣告，螢幕會在擦到一半自己暗掉，而畫面上那個圓環是使用者
/// 判斷「到底鎖了沒」的唯一來源（見 #1 的 user story 17）。
///
/// **這份宣告只擋閒置睡眠，不擋闔蓋睡眠。**闔上蓋子時系統走的是另一條路，
/// 跟閒置多久無關，所以闔蓋解鎖那道保險不受影響（見 `MachineSignalSource`）。
/// 這件事只有真機驗得到，是手動驗收清單的第 6 項。
///
/// 用的是 `ProcessInfo` 的活動宣告而不是自己去建 IOKit 的電源宣告：前者是
/// 同一件事的官方包裝，而且 app 被強制結束時系統自己會把它收掉。那一條
/// 對得上本 app 的不變條件：process 一旦結束，留下的東西必定消失。
@MainActor
final class DisplaySleepBlock {
    /// 現在有沒有宣告著。
    var isEngaged: Bool { activity != nil }

    /// 系統手上那份宣告的憑據。`nil` 代表現在沒有宣告。
    private var activity: NSObjectProtocol?

    /// 開或關。**這是唯一的入口**，兩個方向都走這裡。
    ///
    /// 已經是那個狀態就什麼都不做。上游會用同一個答案叫很多次
    /// （見 `MainWindowVisibility`），而每一次都真的去宣告一份的話，系統手上
    /// 就會累積好幾份，收回只收得回最後那一份。剩下的會留到 app 結束，
    /// 使用者的螢幕從此不會自己變暗。
    func setEngaged(_ engaged: Bool) {
        guard engaged != isEngaged else { return }
        if engaged {
            // 只宣告「螢幕不要閒置變暗」這一項。系統睡眠不必另外擋：螢幕亮著的
            // 時候系統本來就不會因為閒置而睡。多宣告一項的代價是多一條不需要的
            // 副作用，而這個 app 的副作用要越少越好。
            //
            // 這句理由會出現在 `pmset -g assertions` 裡，是給人看的診斷字串，
            // 不是介面文字，所以不進字串目錄。
            activity = ProcessInfo.processInfo.beginActivity(
                options: .idleDisplaySleepDisabled,
                reason: "Wipe cleaning mode keeps the screen visible"
            )
        } else {
            // 走到這裡代表 `isEngaged` 是 true，所以憑據一定在。收回之後欄位
            // 一定要清乾淨：留著一個已經收回的憑據會讓 `isEngaged` 說謊。
            if let activity {
                ProcessInfo.processInfo.endActivity(activity)
            }
            activity = nil
        }
    }
}
