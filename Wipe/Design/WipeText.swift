import SwiftUI

/// 介面上所有文字的鍵。
///
/// 集中在一個型別裡的理由有兩個：一是「有沒有漏翻」可以被測試逐項檢查，
/// 二是圓環中央文字的排版要以英文長度為基準，測試需要拿得到那幾個鍵。
enum WipeText: String, CaseIterable {
    case appName = "app.name"

    case ringStandbyTitle = "ring.standby.title"
    case ringPreparingTitle = "ring.preparing.title"
    case ringPreparingSeconds = "ring.preparing.seconds"
    case ringCleaningTitle = "ring.cleaning.title"

    case settingsPlaceholderTitle = "settings.placeholder.title"
    case settingsPlaceholderDetail = "settings.placeholder.detail"

    // 診斷畫面的文字。這一整組會跟著診斷視窗一起被拆掉（見 #3）。
    case diagnosticsWindowTitle = "diagnostics.window.title"
    case diagnosticsHeadline = "diagnostics.headline"
    case diagnosticsInstructions = "diagnostics.instructions"
    case diagnosticsLeftCommand = "diagnostics.left.command"
    case diagnosticsRightCommand = "diagnostics.right.command"
    case diagnosticsStateDown = "diagnostics.state.down"
    case diagnosticsStateUp = "diagnostics.state.up"
    case diagnosticsLogEmpty = "diagnostics.log.empty"
    case diagnosticsLogCopy = "diagnostics.log.copy"
    case diagnosticsLogClear = "diagnostics.log.clear"
    case diagnosticsLogCount = "diagnostics.log.count"
    case diagnosticsPassThroughNote = "diagnostics.passthrough.note"

    var key: String { rawValue }

    var localizedKey: LocalizedStringKey { LocalizedStringKey(rawValue) }

    /// 目前系統語言下的字串。
    var localized: String {
        Bundle.wipe.localizedString(forKey: key, value: nil, table: nil)
    }

    /// 指定語言下的字串。
    ///
    /// 有些文字沒辦法交給 `Text` 去查，例如帶參數的格式字串與輔助使用標籤。
    /// 這個方法讓那些地方跟著同一個 locale 走，不會出現介面一半中文一半英文。
    /// 查不到對應語言時退回 app 目前的語言。
    func localized(in locale: Locale) -> String {
        guard
            let language = Bundle.preferredLocalizations(
                from: Bundle.wipe.localizations,
                forPreferences: [locale.identifier(.bcp47)]
            ).first,
            let path = Bundle.wipe.path(forResource: language, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else { return localized }
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
