import AppKit
import Testing

@testable import Wipe

/// 攔截範圍那一行**必須剛好一行**。
///
/// 它不是排版癖：那一行在待命時留著版位，清潔模式期間才填字（見
/// `MainWindowView.scopeLabel`）。字如果折成兩行，主視窗會在每一次進出清潔
/// 模式時長高再縮回來，而 #1 的 user story 16 說主視窗維持原來的樣子和位置。
/// 這裡直接用畫面上那個字型量，超出寬度就會被截斷成「…」。
@Suite("圓環底下說明文字的排版")
struct SecondaryLineLayoutTests {
    static let languages = ["en", "zh-Hant"]

    /// 這幾行可用的寬度。主視窗的內容寬度就是圓環的直徑
    /// （見 `MainWindowView.ring` 的 `minWidth` 與 padding）。
    static let availableWidth = RingMetrics.diameter

    private static func width(_ string: String) -> CGFloat {
        (string as NSString)
            .size(withAttributes: [.font: RingMetrics.secondaryLineNSFont])
            .width
    }

    @Test(
        "兩種範圍的說明在兩種語言下都塞得進一行",
        arguments: InterceptionScope.allCases, languages
    )
    func theScopeLineFitsOnOneLine(_ scope: InterceptionScope, _ language: String) {
        let sentence = scope.statusText.localized(in: Locale(identifier: language))
        let measured = Self.width(sentence)
        #expect(
            measured <= Self.availableWidth,
            "「\(sentence)」量到 \(measured) 點，超過可用的 \(Self.availableWidth) 點，會被截斷"
        )
    }
}
