import Foundation
import Testing

@testable import Wipe

/// 設定要被記住，重開 app 後仍在。這裡走的是真的 `UserDefaults`，只是換到
/// 一個測試自己的網域裡，跑完就清掉，不會汙染跑測試那台機器的偏好。
@Suite("設定的持久化")
@MainActor
struct WipeSettingsStoreTests {
    /// 一個用完就丟的偏好網域。
    ///
    /// 每個測試各拿一個新的，測試之間才不會互相汙染，也才能並行跑。
    static func makeDefaults() -> UserDefaults {
        let name = "WipeSettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("第一次啟動拿到的是預設值")
    func emptyDefaultsGivesDefaults() {
        let store = WipeSettingsStore(defaults: Self.makeDefaults())
        #expect(store.settings == WipeSettings())
    }

    @Test("改了設定，換一個 store 讀回來還在")
    func settingsSurviveARestart() {
        let defaults = Self.makeDefaults()

        let first = WipeSettingsStore(defaults: defaults)
        first.settings.bufferIsEnabled = false
        first.settings.bufferSeconds = 7
        first.settings.timeoutSeconds = 10 * 60
        first.settings.unlockHoldSeconds = 5
        first.settings.interceptionScope = .allInput
        first.settings.screenPresentation = .overlay

        // 換一個 store 就等於重開一次 app：什麼都不記在記憶體裡，全部重讀。
        let second = WipeSettingsStore(defaults: defaults)
        #expect(second.settings == first.settings)
    }

    @Test("音效的總開關與個別開關都被記住")
    func soundSettingsSurviveARestart() {
        let defaults = Self.makeDefaults()

        let first = WipeSettingsStore(defaults: defaults)
        first.settings.sounds.isEnabled = false
        first.settings.sounds[.preparingTick] = false
        first.settings.sounds[.refused] = false

        let second = WipeSettingsStore(defaults: defaults)
        #expect(!second.settings.sounds.isEnabled)
        #expect(second.settings.sounds.mutedSounds == [.preparingTick, .refused])
        #expect(second.settings.sounds[.locked])
    }

    @Test("舊版本存下的逾時若超過現在的上限，開啟時被拉回來")
    func legacyTimeoutIsClampedOnLoad() {
        let defaults = Self.makeDefaults()
        // 假裝上一版把上限放到一小時，而使用者當時選了一小時。
        defaults.set(60 * 60, forKey: WipeSettingsStore.Key.timeoutSeconds)

        let store = WipeSettingsStore(defaults: defaults)

        // 不是「照舊放行」也不是「整組退回預設值」，而是拉回範圍內的最大值。
        // 硬碟上的舊值不可以繞過 ADR-0002 的 15 分鐘上限。
        #expect(store.settings.timeoutSeconds == WipeSettings.timeoutSecondsRange.upperBound)
    }

    @Test("讀回來的逾時一定是設定畫面選得到的值")
    func loadedTimeoutIsOneOfTheOfferedOptions() {
        let defaults = Self.makeDefaults()
        // 4 分鐘落在合法範圍內，所以夾不掉它，但選單裡沒有這一項。
        defaults.set(4 * 60, forKey: WipeSettingsStore.Key.timeoutSeconds)

        let store = WipeSettingsStore(defaults: defaults)

        // 靠攏在讀檔就做完，畫面顯示的數字才會等於真正生效的數字。
        // 只在畫面上遮的話，會變成「寫著三分鐘、實際四分鐘才跳」。
        #expect(SettingsOptions.timeoutSeconds.contains(store.settings.timeoutSeconds))
        #expect(store.settings.timeoutSeconds == SettingsOptions.nearestTimeout(to: 4 * 60))
    }

    @Test("舊版本存下的其他值也一樣被拉回範圍內")
    func otherLegacyValuesAreClampedOnLoad() {
        let defaults = Self.makeDefaults()
        defaults.set(0, forKey: WipeSettingsStore.Key.timeoutSeconds)
        defaults.set(99, forKey: WipeSettingsStore.Key.bufferSeconds)
        defaults.set(0.0, forKey: WipeSettingsStore.Key.unlockHoldSeconds)

        let store = WipeSettingsStore(defaults: defaults)

        // 逾時是「夾進範圍」再「靠到選單」，所以零會落在最短的那一項，
        // 而不是範圍的下限（Release 建置的選單裡沒有 30 秒）。
        #expect(store.settings.timeoutSeconds == SettingsOptions.timeoutSeconds.first)
        #expect(store.settings.bufferSeconds == WipeSettings.bufferSecondsRange.upperBound)
        #expect(store.settings.unlockHoldSeconds == WipeSettings.unlockHoldSecondsRange.lowerBound)
    }

    @Test("認不得的字串退回預設值，不是當掉")
    func unknownRawValuesFallBack() {
        let defaults = Self.makeDefaults()
        // 硬碟上的東西可能來自更新的版本，也可能被人手改過。
        defaults.set("laser", forKey: WipeSettingsStore.Key.interceptionScope)
        defaults.set("hologram", forKey: WipeSettingsStore.Key.screenPresentation)
        defaults.set(["kazoo"], forKey: WipeSettingsStore.Key.mutedSounds)

        let store = WipeSettingsStore(defaults: defaults)

        #expect(store.settings.interceptionScope == .keyboard)
        #expect(store.settings.screenPresentation == .mainWindow)
        #expect(store.settings.sounds.mutedSounds.isEmpty)
    }

    @Test("少掉一個欄位的舊偏好，其他欄位照樣活著")
    func aMissingFieldDoesNotWipeTheRest() {
        let defaults = Self.makeDefaults()
        // 假裝這是「還沒有畫面呈現這個欄位」的那一版存下來的。
        defaults.set(9, forKey: WipeSettingsStore.Key.bufferSeconds)
        defaults.set(InterceptionScope.allInput.rawValue, forKey: WipeSettingsStore.Key.interceptionScope)

        let store = WipeSettingsStore(defaults: defaults)

        #expect(store.settings.bufferSeconds == 9)
        #expect(store.settings.interceptionScope == .allInput)
        #expect(store.settings.screenPresentation == .mainWindow)
    }

    @Test("記憶體版的 store 不碰硬碟")
    func inMemoryStoreWritesNothing() {
        // 測試跑在 Wipe.app 自己的 process 裡，所以這裡的 standard 就是
        // 開發機上那一份真的偏好。「直接給一組值」那一頭不可以留下痕跡，
        // 否則跑一次測試就會把開發者自己的設定改掉。
        let key = WipeSettingsStore.Key.bufferSeconds
        let before = UserDefaults.standard.object(forKey: key) as? Int

        let store = WipeSettingsStore(WipeSettings())
        store.settings.bufferSeconds = 8

        #expect(store.settings.bufferSeconds == 8)
        #expect(UserDefaults.standard.object(forKey: key) as? Int == before)
    }

    @Test("控制器讀得到 store 上最新的值")
    func controllerReadsThroughToTheStore() {
        let store = WipeSettingsStore(WipeSettings())
        let controller = CleaningFlowController(
            settings: store,
            clock: TestClock(),
            keyboard: FakeKeyboardSignalSource(),
            machine: FakeMachineSignalSource(),
            interceptor: RecordingInputInterceptor(),
            sound: RecordingSoundOutput()
        )

        // 設定視窗改的是 store，控制器沒有自己的副本，所以不必重開 app。
        store.settings.unlockHoldSeconds = 6
        #expect(controller.settings.unlockHoldSeconds == 6)
    }
}
