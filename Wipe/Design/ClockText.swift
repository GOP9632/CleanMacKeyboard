import Foundation

/// 把秒數排成畫面上要看的樣子。
///
/// 它不屬於任何一個畫面，也不需要知道自己排的是哪一種時間，所以獨立成一個
/// 型別：畫面元件本身用眼睛驗比較划算，但「4:05 不可以排成 4:5」這種事
/// 用眼睛不一定看得到，值得有測試。
enum ClockText {
    /// 把剩餘秒數排成「分:秒」。
    ///
    /// 逾時最長 15 分鐘，所以不需要處理小時。
    static func minutesAndSeconds(_ seconds: Int) -> String {
        let seconds = max(0, seconds)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// 把一段長度排成「3 秒」「5 分鐘」這種帶單位的樣子，給設定畫面用。
    ///
    /// 交給 Foundation 排而不是自己拼字串：單複數（`1 minute` 對 `2 minutes`）
    /// 與單位的翻譯它本來就會，自己拼的話字串目錄裡要為每一個單位各準備
    /// 一組複數變化，而那組東西沒有人會記得維護。
    ///
    /// 零的那一段會被藏起來，所以 300 秒排出來是「5 分鐘」，不是「5 分鐘 0 秒」。
    static func duration(_ seconds: TimeInterval, in locale: Locale) -> String {
        Duration.seconds(max(0, seconds)).formatted(
            .units(allowed: [.minutes, .seconds], width: .wide).locale(locale)
        )
    }
}
