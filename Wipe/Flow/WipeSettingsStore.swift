import Foundation
import Observation

/// 設定接縫的真實那一頭：使用者存在硬碟上的偏好。
///
/// 它把「一組值」變成「一組會被記住的值」。改了就存，下次啟動讀回來，
/// 中間沒有存檔按鈕，也沒有套用按鈕，這是 Mac 設定視窗一貫的樣子。
///
/// 測試那一頭是 `init(_:)`：一份只活在記憶體裡的設定，不碰 `UserDefaults`，
/// 所以測試不必為了給一組值而汙染跑測試那台機器的偏好。
@MainActor
@Observable
final class WipeSettingsStore {
    /// 目前的設定。改了就存。
    var settings: WipeSettings {
        didSet {
            guard settings != oldValue else { return }
            guard let defaults else { return }
            Self.write(settings, to: defaults)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults?

    /// 存在硬碟上的那一份。啟動時就地把值讀回來。
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.settings = Self.read(from: defaults)
    }

    /// 只活在記憶體裡的一份，測試與預覽用。
    init(_ settings: WipeSettings) {
        self.defaults = nil
        self.settings = settings
    }

    // MARK: - 硬碟上的樣子

    /// 偏好裡的鍵。
    ///
    /// 一個欄位一個鍵，不整包塞成一筆 JSON。理由是欄位會增減：整包存的話，
    /// 舊版本存下的那一包少一個欄位就整包解不開，使用者的設定會一次全部消失；
    /// 一個一個存，少掉的那個自己退回預設值，其他的照樣活著。
    enum Key {
        static let bufferIsEnabled = "settings.bufferIsEnabled"
        static let bufferSeconds = "settings.bufferSeconds"
        static let timeoutSeconds = "settings.timeoutSeconds"
        static let unlockHoldSeconds = "settings.unlockHoldSeconds"
        static let interceptionScope = "settings.interceptionScope"
        static let screenPresentation = "settings.screenPresentation"
        static let soundIsEnabled = "settings.sound.isEnabled"
        static let mutedSounds = "settings.sound.muted"
    }

    /// 從偏好讀出一組設定。
    ///
    /// 每一個欄位都是「讀得到就用，讀不到就用預設值」。範圍的把關不在這裡，
    /// 而是在 `WipeSettings.init`：舊版本存下的值若落在現在的範圍之外，
    /// 會在那裡被拉回來（見 ADR-0002，逾時的上限尤其不能被硬碟上的舊值繞過）。
    ///
    /// 逾時多一道：除了夾進範圍，還要靠到設定畫面真的提供得出來的那幾個選項
    /// 之一。少了這一步，硬碟上的 30 秒在 Release 建置裡會合法但選不到，
    /// 畫面顯示一分鐘、實際三十秒就跳（見 `SettingsOptions.nearestTimeout(to:)`）。
    private static func read(from defaults: UserDefaults) -> WipeSettings {
        let fallback = WipeSettings()
        return WipeSettings(
            bufferIsEnabled: defaults.object(forKey: Key.bufferIsEnabled) as? Bool
                ?? fallback.bufferIsEnabled,
            bufferSeconds: defaults.object(forKey: Key.bufferSeconds) as? Int
                ?? fallback.bufferSeconds,
            timeoutSeconds: SettingsOptions.nearestTimeout(
                to: defaults.object(forKey: Key.timeoutSeconds) as? TimeInterval
                    ?? fallback.timeoutSeconds
            ),
            unlockHoldSeconds: defaults.object(forKey: Key.unlockHoldSeconds) as? TimeInterval
                ?? fallback.unlockHoldSeconds,
            // 認不得的字串一律退回預設值。硬碟上的東西可能來自更新的版本，
            // 也可能被人手改過，不能假設它一定對得上現在的列舉。
            interceptionScope: (defaults.string(forKey: Key.interceptionScope)
                .flatMap(InterceptionScope.init(rawValue:))) ?? fallback.interceptionScope,
            screenPresentation: (defaults.string(forKey: Key.screenPresentation)
                .flatMap(ScreenPresentation.init(rawValue:))) ?? fallback.screenPresentation,
            sounds: SoundSettings(
                isEnabled: defaults.object(forKey: Key.soundIsEnabled) as? Bool
                    ?? fallback.sounds.isEnabled,
                mutedSounds: Set(
                    (defaults.stringArray(forKey: Key.mutedSounds) ?? [])
                        .compactMap(WipeSound.init(rawValue:))
                )
            )
        )
    }

    /// 把一組設定寫回偏好。
    private static func write(_ settings: WipeSettings, to defaults: UserDefaults) {
        defaults.set(settings.bufferIsEnabled, forKey: Key.bufferIsEnabled)
        defaults.set(settings.bufferSeconds, forKey: Key.bufferSeconds)
        defaults.set(settings.timeoutSeconds, forKey: Key.timeoutSeconds)
        defaults.set(settings.unlockHoldSeconds, forKey: Key.unlockHoldSeconds)
        defaults.set(settings.interceptionScope.rawValue, forKey: Key.interceptionScope)
        defaults.set(settings.screenPresentation.rawValue, forKey: Key.screenPresentation)
        defaults.set(settings.sounds.isEnabled, forKey: Key.soundIsEnabled)
        // 排過序才寫，硬碟上那一行才不會每次存都長得不一樣。
        defaults.set(settings.sounds.mutedSounds.map(\.rawValue).sorted(), forKey: Key.mutedSounds)
    }
}
