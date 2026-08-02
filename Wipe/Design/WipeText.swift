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

    case mainTimeoutRemaining = "main.timeout.remaining"

    case mainRefusalSecureInput = "main.refusal.secureInput"
    case mainRefusalSecureInputApp = "main.refusal.secureInput.app"

    case settingsTabGeneral = "settings.tab.general"
    case settingsTabSound = "settings.tab.sound"

    case settingsScopeTitle = "settings.scope.title"
    case settingsScopeKeyboard = "settings.scope.keyboard"
    case settingsScopeAllInput = "settings.scope.allInput"
    case settingsScopeFootnote = "settings.scope.footnote"

    case settingsBufferToggle = "settings.buffer.toggle"
    case settingsBufferLength = "settings.buffer.length"
    case settingsBufferFootnote = "settings.buffer.footnote"

    case settingsPresentationTitle = "settings.presentation.title"
    case settingsPresentationMainWindow = "settings.presentation.mainWindow"
    case settingsPresentationOverlay = "settings.presentation.overlay"
    case settingsPresentationFootnote = "settings.presentation.footnote"

    case settingsUnlockHold = "settings.unlock.hold"
    case settingsUnlockFootnote = "settings.unlock.footnote"

    case settingsTimeoutTitle = "settings.timeout.title"
    case settingsTimeoutFootnote = "settings.timeout.footnote"

    case settingsSoundMaster = "settings.sound.master"
    case settingsSoundIndividual = "settings.sound.individual"
    case settingsSoundFootnote = "settings.sound.footnote"
    case settingsSoundPreparingTick = "settings.sound.preparingTick"
    case settingsSoundLocked = "settings.sound.locked"
    case settingsSoundUnlockGestureDetected = "settings.sound.unlockGestureDetected"
    case settingsSoundUnlockGestureReset = "settings.sound.unlockGestureReset"
    case settingsSoundUnlocked = "settings.sound.unlocked"
    case settingsSoundTimedOut = "settings.sound.timedOut"
    case settingsSoundRefused = "settings.sound.refused"

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
