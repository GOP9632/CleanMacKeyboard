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
}
