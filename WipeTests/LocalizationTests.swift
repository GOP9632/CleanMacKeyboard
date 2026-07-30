import Foundation
import Testing

@testable import Wipe

/// 雙語是這一票的地基之一：介面必須跟隨系統語言，英文為開發語言。
/// 這些測試檢查真正被打包進 Wipe.app 的字串，不是原始檔裡的字串。
@Suite("雙語字串")
struct LocalizationTests {
    static let languages = ["en", "zh-Hant"]

    @Test("兩種語言都被打包進 app", arguments: languages)
    func languageIsBundled(_ language: String) {
        #expect(Bundle.wipe.localizations.contains(language), "Wipe.app 裡沒有 \(language)")
    }

    @Test("每一個介面文字在兩種語言都有翻譯", arguments: WipeText.allCases, languages)
    func everyKeyIsTranslated(_ text: WipeText, _ language: String) {
        let value = text.localized(in: Locale(identifier: language))
        // 查不到翻譯時會原封不動把鍵回傳，所以「等於鍵」就是漏翻。
        #expect(value != text.key, "\(language) 少了 \(text.key)")
        #expect(!value.isEmpty, "\(language) 的 \(text.key) 是空字串")
    }

    @Test("中文不是照抄英文", arguments: WipeText.allCases.filter { $0 != .appName })
    func chineseDiffersFromEnglish(_ text: WipeText) {
        let english = text.localized(in: Locale(identifier: "en"))
        let chinese = text.localized(in: Locale(identifier: "zh-Hant"))
        #expect(english != chinese, "\(text.key) 的中文跟英文一樣，可能忘記翻譯")
    }

    @Test("帶地區的語言也對得上，不會退回英文")
    func regionalIdentifierStillResolvesChinese() {
        // 使用者的語言通常是「繁體中文（台灣）」這種帶地區的形式。
        let taiwan = WipeText.ringStandbyTitle.localized(in: Locale(identifier: "zh-Hant-TW"))
        let chinese = WipeText.ringStandbyTitle.localized(in: Locale(identifier: "zh-Hant"))
        #expect(taiwan == chinese)
    }

    @Test("英文是開發語言")
    func developmentLanguageIsEnglish() {
        let region = Bundle.wipe.infoDictionary?["CFBundleDevelopmentRegion"] as? String
        #expect(region == "en")
    }
}
