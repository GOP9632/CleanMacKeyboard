import AppKit
import Testing

@testable import Wipe

/// 遮蔽層真的跟著清潔流程走。
///
/// 這一組守的是中間那一段接線：控制器的階段變了、設定被改了，有沒有真的傳到
/// 開視窗的那一頭。這一段斷掉的話，`OverlayVisibilityTests` 與
/// `OverlayWindowsTests` 都還是綠的，而真機上什麼都不會發生。
///
/// 這條路刻意不經過主視窗重畫（理由見 `OverlayPresenter`），所以這裡也一個
/// 視圖都不建，只有控制器與遮蔽層。
@Suite("遮蔽層跟著清潔流程走")
@MainActor
struct OverlayPresenterTests {
    /// 讓觀察那一頭排的工作跑完。
    ///
    /// 值變動的通知會排到下一輪才讀新的值（見 `OverlayPresenter`），所以這裡
    /// 讓出幾次執行機會。它不是等待：沒有任何一項在等時間過去。
    private static func settle() async {
        for _ in 0..<10 {
            await Task.yield()
        }
    }

    @Test("待命時沒有遮蔽層")
    func standbyHasNoOverlay() {
        let harness = CleaningFlowHarness(
            settings: WipeSettings(screenPresentation: .overlay)
        )
        let presenter = OverlayPresenter(controller: harness.controller)
        presenter.start()

        #expect(presenter.openWindows.isEmpty)
    }

    @Test("設定選遮蔽層，進到清潔中就鋪出去")
    func cleaningCoversTheScreens() async {
        let harness = CleaningFlowHarness(
            settings: WipeSettings(bufferIsEnabled: false, screenPresentation: .overlay)
        )
        let presenter = OverlayPresenter(controller: harness.controller)
        presenter.start()

        harness.controller.start()
        await Self.settle()

        #expect(presenter.openWindows.count == NSScreen.screens.count)

        harness.controller.exitCleaning(.unlockGesture)
        await Self.settle()
    }

    @Test("離開清潔模式就收回來")
    func leavingCleaningRemovesTheOverlay() async {
        // 這一項是整個遮蔽層最重要的一條。鋪出去看得出來，收不回來看不出來，
        // 而收不回來就是一片蓋住整台電腦的黑。
        let harness = CleaningFlowHarness(
            settings: WipeSettings(bufferIsEnabled: false, screenPresentation: .overlay)
        )
        let presenter = OverlayPresenter(controller: harness.controller)
        presenter.start()
        harness.controller.start()
        await Self.settle()
        #expect(presenter.openWindows.isEmpty == false)

        harness.controller.exitCleaning(.unlockGesture)
        await Self.settle()

        #expect(presenter.openWindows.isEmpty)
    }

    @Test("逾時解除也收得回來")
    func timeoutRemovesTheOverlay() async {
        // 逾時這條路特別值得單獨守：使用者沒有做任何動作，畫面上也沒有任何
        // 東西被點過。清潔中主視窗被遮蔽層整個蓋住，如果收回的指令要靠那個
        // 視窗重畫才送得出來，這一條就是它會斷掉的地方。
        let harness = CleaningFlowHarness(
            settings: WipeSettings(
                bufferIsEnabled: false,
                timeoutSeconds: 60,
                screenPresentation: .overlay
            )
        )
        let presenter = OverlayPresenter(controller: harness.controller)
        presenter.start()
        harness.controller.start()
        await Self.settle()
        #expect(presenter.openWindows.isEmpty == false)

        harness.clock.advance(by: 60)
        await Self.settle()

        #expect(harness.controller.stage == .standby)
        #expect(presenter.openWindows.isEmpty)
    }

    @Test("設定選主視窗時，清潔中也不鋪")
    func mainWindowPresentationNeverCovers() async {
        let harness = CleaningFlowHarness(
            settings: WipeSettings(bufferIsEnabled: false, screenPresentation: .mainWindow)
        )
        let presenter = OverlayPresenter(controller: harness.controller)
        presenter.start()

        harness.controller.start()
        await Self.settle()

        #expect(presenter.openWindows.isEmpty)

        harness.controller.exitCleaning(.unlockGesture)
    }

    @Test("清潔中改設定，遮蔽層跟著鋪出去")
    func changingTheSettingWhileCleaningCovers() async {
        // 鍵盤鎖底下觸控板還活著，使用者真的有辦法在清潔中打開設定改這一項。
        let store = WipeSettingsStore(
            WipeSettings(bufferIsEnabled: false, screenPresentation: .mainWindow)
        )
        let harness = CleaningFlowHarness(store: store)
        let presenter = OverlayPresenter(controller: harness.controller)
        presenter.start()
        harness.controller.start()
        await Self.settle()
        #expect(presenter.openWindows.isEmpty)

        store.settings.screenPresentation = .overlay
        await Self.settle()

        #expect(presenter.openWindows.isEmpty == false)

        harness.controller.exitCleaning(.unlockGesture)
        await Self.settle()
    }
}
