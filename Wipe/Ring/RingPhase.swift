import Foundation
import SwiftUI

/// 圓環要顯示的狀態。
///
/// 這是圓環元件的唯一輸入。圓環本身不持有時鐘、不持有狀態機，也不知道
/// 攔截這件事，它只負責把這個值畫出來。清潔流程控制器產生的階段會在視圖層
/// 被映射成這個型別。
enum RingPhase: Equatable {
    /// 待命：環靜止，中央是「開始清潔」。
    case standby

    /// 準備清潔：環表達緩衝倒數，中央是「準備清潔」加上剩餘秒數。
    /// - Parameters:
    ///   - secondsRemaining: 中央要顯示的剩餘秒數。
    ///   - progress: 倒數已經走完的比例，0 到 1。
    case preparing(secondsRemaining: Int, progress: Double)

    /// 清潔中：環**只**表達解鎖手勢的按住進度。
    ///
    /// 逾時剩餘時間不畫在環上，以文字呈現。理由見 `CONTEXT.md` 的圓環定義：
    /// 兩者時間尺度差兩個數量級，共用同一個環會讓人分不清哪一個在動。
    case cleaning(holdProgress: Double)

    /// 中央的標題文字。
    var title: WipeText {
        switch self {
        case .standby: .ringStandbyTitle
        case .preparing: .ringPreparingTitle
        case .cleaning: .ringCleaningTitle
        }
    }

    /// 這個階段的顏色。
    var tint: WipeColor {
        switch self {
        case .standby: .standby
        case .preparing: .preparing
        case .cleaning: .cleaning
        }
    }

    /// 環要表達的進度。`nil` 代表環靜止、畫滿一整圈。
    var progress: Double? {
        switch self {
        case .standby: nil
        case .preparing(_, let progress): progress.clampedToUnitInterval
        case .cleaning(let holdProgress): holdProgress.clampedToUnitInterval
        }
    }

    /// 中央標題底下要顯示的秒數。只有準備清潔會用到。
    ///
    /// 這裡回傳數字而不是排版好的字串，localization 是視圖層的事。
    var secondsRemaining: Int? {
        switch self {
        case .preparing(let secondsRemaining, _): secondsRemaining
        case .standby, .cleaning: nil
        }
    }

    /// 這個階段的圓環是否接受點擊。
    ///
    /// 清潔模式期間永遠是 `false`：抹布掃過觸控板剛好點到圓環不可以解鎖。
    var allowsActivation: Bool {
        switch self {
        case .standby, .preparing: true
        case .cleaning: false
        }
    }
}

private extension Double {
    var clampedToUnitInterval: Double { min(max(self, 0), 1) }
}
