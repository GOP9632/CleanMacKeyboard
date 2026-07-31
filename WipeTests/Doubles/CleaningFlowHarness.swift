import Foundation

@testable import Wipe

/// 把控制器與它的五個替身綁在一起，省得每個測試都抄一次。
///
/// 控制器是這個專案唯一的自動化測試接縫（見 `docs/seams.md`），所以每一份
/// 測試都是從這裡開始的：真實世界那一頭全部換成替身，跑的還是同一份程式碼。
@MainActor
struct CleaningFlowHarness {
    let clock: TestClock
    let keyboard: FakeKeyboardSignalSource
    let machine: FakeMachineSignalSource
    let interceptor: RecordingInputInterceptor
    let sound: RecordingSoundOutput
    let controller: CleaningFlowController

    init(settings: WipeSettings = WipeSettings()) {
        let clock = TestClock()
        let keyboard = FakeKeyboardSignalSource()
        let machine = FakeMachineSignalSource()
        let interceptor = RecordingInputInterceptor()
        let sound = RecordingSoundOutput()
        self.clock = clock
        self.keyboard = keyboard
        self.machine = machine
        self.interceptor = interceptor
        self.sound = sound
        self.controller = CleaningFlowController(
            settings: settings,
            clock: clock,
            keyboard: keyboard,
            machine: machine,
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
