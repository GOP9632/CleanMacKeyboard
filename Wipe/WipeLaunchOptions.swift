import Foundation

/// 啟動時才決定、之後不會再改的選項。
///
/// 它跟 `WipeSettings` 不一樣：設定是使用者調的、會被記住、隨時改得動；
/// 這裡的東西是開發用的開關，只在組裝那一刻讀一次。所以它擺在 `WipeApp`
/// 旁邊而不是 Flow 底下：讀它的只有組裝那一行，流程本身不認得它。
enum WipeLaunchOptions {
    /// 乾跑模式的鍵。在 Xcode 的 scheme 裡加一個 `-WipeDryRun YES` 就會落在這裡。
    static let dryRunKey = "WipeDryRun"

    /// 這一次啟動要不要用乾跑模式。
    ///
    /// 乾跑是真的讀鍵盤、真的跑完整個流程，但不真的鎖住鍵盤。判定邏輯出問題時
    /// 需要它，否則每改一行程式都要冒著把自己鎖在外面的風險
    /// （見 `docs/seams.md`）。
    ///
    /// 預設是**真的攔截**：開發期大部分時間要驗的就是攔截本身，預設乾跑的話
    /// 很容易忘記自己現在在驗什麼。
    ///
    /// 正式建置永遠回傳 `false`，連問都不問。正式建置若跑成乾跑，畫面會寫著
    /// 清潔中而鍵盤還活著，那正是這個 app 最不能發生的事
    /// （見 `CONTEXT.md` 的不變條件）。
    static func dryRunIsEnabled(in defaults: UserDefaults = .standard) -> Bool {
        #if DEBUG
        defaults.bool(forKey: dryRunKey)
        #else
        false
        #endif
    }
}
