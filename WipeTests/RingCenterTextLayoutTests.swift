import AppKit
import Testing

@testable import Wipe

/// 圓環中央文字的排版以英文長度為基準（`Cleaning` 對 `清潔中`、
/// `Start cleaning` 對 `開始清潔`）。這裡直接用畫面上那個字型量，
/// 確認英文既不會被截斷、也不會擠爆圓環。
@Suite("圓環中央文字排版")
struct RingCenterTextLayoutTests {
    static let centerTitles: [WipeText] = [
        .ringStandbyTitle,
        .ringPreparingTitle,
        .ringCleaningTitle,
    ]

    private struct Measurement {
        let width: CGFloat
        let lines: Int
    }

    private static func string(_ text: WipeText, in language: String) -> String {
        text.localized(in: Locale(identifier: language))
    }

    private static func measure(_ string: String) -> Measurement {
        let attributes: [NSAttributedString.Key: Any] = [.font: RingMetrics.centerTitleNSFont]
        let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]

        let unbounded = CGFloat.greatestFiniteMagnitude

        let wrapped = (string as NSString).boundingRect(
            with: CGSize(width: RingMetrics.centerTextWidth, height: unbounded),
            options: options,
            attributes: attributes
        )
        // 用同一段文字單行的高度當基準，這樣中日韓字型的行高差異不會被誤算成多一行。
        let singleLine = (string as NSString).boundingRect(
            with: CGSize(width: unbounded, height: unbounded),
            options: options,
            attributes: attributes
        )
        let lines = max(1, Int((wrapped.height / singleLine.height).rounded()))
        return Measurement(width: wrapped.width, lines: lines)
    }

    @Test("英文標題塞得進圓環的文字寬度，不需要縮字", arguments: centerTitles)
    func englishTitleFits(_ text: WipeText) {
        let english = Self.string(text, in: "en")
        let measured = Self.measure(english)
        #expect(
            measured.width <= RingMetrics.centerTextWidth,
            "「\(english)」量到 \(measured.width) 點，超過圓環的 \(RingMetrics.centerTextWidth) 點"
        )
        #expect(
            measured.lines <= RingMetrics.centerTitleLineLimit,
            "「\(english)」需要 \(measured.lines) 行，超過上限會被截斷"
        )
    }

    @Test("中文標題也塞得下", arguments: centerTitles)
    func chineseTitleFits(_ text: WipeText) {
        let chinese = Self.string(text, in: "zh-Hant")
        let measured = Self.measure(chinese)
        #expect(measured.width <= RingMetrics.centerTextWidth)
        #expect(measured.lines <= RingMetrics.centerTitleLineLimit)
    }

    @Test("中央文字的寬度留在圓環內")
    func centerTextStaysInsideTheRing() {
        // 圓內接正方形的邊長是直徑除以根號二。文字區塊比它窄，才不會壓到環上。
        let inscribed = RingMetrics.diameter / 2.0.squareRoot()
        #expect(RingMetrics.centerTextWidth < inscribed)
    }
}
