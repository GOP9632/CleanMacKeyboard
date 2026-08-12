import Foundation

@testable import Wipe

/// 把控制器與它的六個替身綁在一起，省得每個測試都抄一次。
///
/// 控制器是這個專案唯一的自動化測試接縫（見 `docs/seams.md`），所以每一份
/// 測試都是從這裡開始的：真實世界那一頭全部換成替身，跑的還是同一份程式碼。
@MainActor
struct CleaningFlowHarness {
    let clock: TestClock
    let keyboard: FakeKeyboardSignalSource
    let machine: FakeMachineSignalSource
    let secureInput: FakeSecureInputProbe
    let interceptor: RecordingInputInterceptor
    let sound: RecordingSoundOutput
    let controller: CleaningFlowController

    init(settings: WipeSettings = WipeSettings()) {
        self.init(store: WipeSettingsStore(settings))
    }

    /// 從一個設定 store 開始，而不是一組值。
    ///
    /// 要在清潔中改設定的測試需要它：控制器每次用到設定都問同一個 store 拿
    /// 最新的值，所以測試手上得握著那個 store 才改得動。
    init(store: WipeSettingsStore) {
        let clock = TestClock()
        let keyboard = FakeKeyboardSignalSource()
        let machine = FakeMachineSignalSource()
        let secureInput = FakeSecureInputProbe()
        let interceptor = RecordingInputInterceptor()
        let sound = RecordingSoundOutput()
        self.clock = clock
        self.keyboard = keyboard
        self.machine = machine
        self.secureInput = secureInput
        self.interceptor = interceptor
        self.sound = sound
        self.controller = CleaningFlowController(
            settings: store,
            clock: clock,
            keyboard: keyboard,
            machine: machine,
            secureInput: secureInput,
            interceptor: interceptor,
            sound: sound
        )
    }

    /// 直接進到清潔中，跳過緩衝倒數。手勢的測試關心的是清潔中發生的事，
    /// 前面那一段每次都重跑只會讓測試變吵。
    static func cleaning(settings: WipeSettings) -> CleaningFlowHarness {
        var settings = settings
        settings.bufferIsEnabled = false
        let harness = CleaningFlowHarness(settings: settings)
        harness.controller.start()
        return harness
    }
}
