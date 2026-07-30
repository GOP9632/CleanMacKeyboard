import AppKit
import SwiftUI

/// 圓環的尺寸與字型。
///
/// 獨立成一個型別是因為「中央文字在英文介面下不截斷也不擠爆」這件事需要被
/// 測試量到，而測試必須拿到跟畫面上完全一樣的字型與寬度，不能各寫一份。
enum RingMetrics {
    /// 圓環直徑。主視窗與遮蔽層共用同一個尺寸。
    static let diameter: CGFloat = 220
    static let strokeWidth: CGFloat = 14

    /// 底環的不透明度。底環用當前階段的顏色淡化而來，這樣在淺色、深色，
    /// 以及固定深色的遮蔽層上都看得見。
    static let trackOpacity: Double = 0.18

    /// 中央文字可用的寬度佔直徑的比例。
    ///
    /// 上限來自圓內接矩形：文字區塊要留在環內，寬度不能超過直徑的 0.7 左右。
    static let centerTextWidthRatio: CGFloat = 0.66

    /// 中央文字可用的寬度。
    static var centerTextWidth: CGFloat { (diameter * centerTextWidthRatio).rounded(.down) }

    static let centerTitleFontSize: CGFloat = 20
    /// 標題最多兩行。英文的「Start cleaning」會斷成兩行，這是預期的排版。
    static let centerTitleLineLimit = 2
    /// 縮字只是保險。正常情況下英文標題應該不需要縮字就塞得下，有測試守著。
    static let centerTitleMinimumScale: CGFloat = 0.8
    static let centerSecondsFontSize: CGFloat = 15
    static let centerLineSpacing: CGFloat = 4

    /// 中央標題的字型。刻意由 AppKit 的字型轉過來，而不是各寫一份：
    /// 測試要量的必須就是畫面上畫的那一個字型。
    static var centerTitleFont: Font { Font(centerTitleNSFont) }

    static var centerSecondsFont: Font {
        .system(size: centerSecondsFontSize, weight: .medium, design: .rounded)
    }

    /// 中央標題字型的 AppKit 形式。這是唯一的來源，量測與繪製都走這裡。
    static var centerTitleNSFont: NSFont {
        let base = NSFont.systemFont(ofSize: centerTitleFontSize, weight: .semibold)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded),
              let rounded = NSFont(descriptor: descriptor, size: centerTitleFontSize)
        else { return base }
        return rounded
    }
}
