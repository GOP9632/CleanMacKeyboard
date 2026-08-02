import Foundation
import Testing

@testable import Wipe

/// 安全輸入模式是 Wipe 最危險的失效角落：它啟動期間所有第三方鍵盤攔截都會
/// 被系統繞過，畫面卻還顯示清潔中。使用者正是因為相信那個顯示才敢閉著眼睛擦，
/// 所以這裡的規則是拒絕進入、進行中偵測到就立刻退出
/// （見 `CONTEXT.md` 的不變條件與 ADR-0002）。
///
/// 這兩條路徑都測得到，是因為安全輸入探測是注入進來的（見 `docs/seams.md`）：
/// 測試直接說「現在正在安全輸入模式」，不需要真的把某個密碼欄位叫出來。
@Suite("安全輸入模式")
@MainActor
struct SecureInputRefusalTests {
    // MARK: - 拒絕進入

    @Test("安全輸入模式啟動中按下開始，階段維持待命")
    func refusesToStart() {
        let harness = CleaningFlowHarness()
        harness.secureInput.turnOn()

        harness.controller.start()

        #expect(harness.controller.stage == .standby)
        // 不是「先進準備清潔再說」：緩衝倒數預設是開著的，若這裡沒擋住，
        // 使用者會看到倒數開始跑，以為一切正常。
        #expect(harness.clock.isTicking == false)
    }

    @Test("被拒絕時從未要求攔截器開始攔截")
    func refusalNeverAsksForInterception() {
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: false))
        harness.secureInput.turnOn()

        harness.controller.start()

        #expect(harness.interceptor.wasEverAskedToIntercept == false)
    }

    @Test("被拒絕時播放拒絕音效")
    func refusalPlaysTheRefusedSound() {
        let harness = CleaningFlowHarness()
        harness.secureInput.turnOn()

        harness.controller.start()

        #expect(harness.sound.played == [.refused])
    }

    @Test("被拒絕時指出是哪個 app 造成的")
    func refusalNamesTheResponsibleApp() {
        let harness = CleaningFlowHarness()
        harness.secureInput.turnOn(blaming: "1Password")

        harness.controller.start()

        #expect(harness.controller.refusal == .secureInput(appName: "1Password"))
    }

    @Test("查不出是哪個 app 時照樣回報理由")
    func refusalWithoutANameStillReportsTheReason() {
        // 真實世界裡查不到名字是會發生的：造成安全輸入模式的可能是一個
        // 沒有 app 身分的程序。查不到不可以變成「沒事」。
        let harness = CleaningFlowHarness()
        harness.secureInput.turnOn(blaming: nil)

        harness.controller.start()

        #expect(harness.controller.refusal == .secureInput(appName: nil))
    }

    @Test("一切正常時沒有拒絕理由")
    func noRefusalWhenSecureInputIsOff() {
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: false))

        harness.controller.start()

        #expect(harness.controller.refusal == nil)
        #expect(harness.controller.stage == .cleaning)
    }

    @Test("安全輸入模式解除之後再按一次就進得去，理由被清掉")
    func refusalClearsOnceSecureInputGoesAway() {
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: false))
        harness.secureInput.turnOn(blaming: "1Password")
        harness.controller.start()
        #expect(harness.controller.refusal != nil)

        harness.secureInput.turnOff()
        harness.controller.start()

        #expect(harness.controller.stage == .cleaning)
        #expect(harness.controller.refusal == nil)
        #expect(harness.interceptor.activeScope == .keyboard)
    }

    @Test("拒絕音效關掉時不出聲，但照樣拒絕")
    func mutingTheRefusedSoundDoesNotWeakenTheRefusal() {
        // 設定只調整體驗，不拆保險（見 ADR-0002）。
        var settings = WipeSettings(bufferIsEnabled: false)
        settings.sounds[.refused] = false
        let harness = CleaningFlowHarness(settings: settings)
        harness.secureInput.turnOn()

        harness.controller.start()

        #expect(harness.sound.played.isEmpty)
        #expect(harness.controller.stage == .standby)
        #expect(harness.interceptor.wasEverAskedToIntercept == false)
        #expect(harness.controller.refusal == .secureInput(appName: nil))
    }

    // MARK: - 準備清潔期間才啟動

    @Test("準備清潔期間安全輸入模式才啟動，倒數歸零也不進清潔中")
    func secureInputDuringPreparingBlocksTheHandover() {
        // 進入清潔中的那一刻才是攔截真正生效的時候，所以檢查要在那一刻
        // 再做一次，不能只在按下開始的時候做。
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferSeconds: 3))
        harness.controller.start()
        #expect(harness.controller.stage == .preparing)

        harness.secureInput.turnOn(blaming: "Terminal")
        harness.clock.advance(by: 3)

        #expect(harness.controller.stage == .standby)
        #expect(harness.interceptor.wasEverAskedToIntercept == false)
        #expect(harness.controller.refusal == .secureInput(appName: "Terminal"))
        #expect(harness.sound.played.last == .refused)
        #expect(harness.clock.isTicking == false)
    }

    // MARK: - 中途退出

    @Test("清潔中偵測到安全輸入模式，立刻回到待命並解除攔截")
    func secureInputDuringCleaningExitsImmediately() {
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: false, timeoutSeconds: 60))
        harness.controller.start()
        #expect(harness.controller.stage == .cleaning)

        harness.secureInput.turnOn(blaming: "1Password")
        harness.clock.advance(by: 1)

        #expect(harness.controller.stage == .standby)
        #expect(harness.interceptor.activeScope == nil)
        #expect(harness.interceptor.stopCount == 1)
    }

    @Test("中途退出也播放拒絕音效並說明理由")
    func exitingMidCleaningExplainsItself() {
        // 使用者這時正閉著眼睛擦。畫面剛剛從清潔中變回待命，
        // 若不出聲也不說原因，他會以為自己還在保護之下。
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: false, timeoutSeconds: 60))
        harness.controller.start()

        harness.secureInput.turnOn(blaming: "Terminal")
        harness.clock.advance(by: 1)

        #expect(harness.sound.played.last == .refused)
        #expect(harness.controller.refusal == .secureInput(appName: "Terminal"))
    }

    @Test("中途退出走的是離開清潔中那唯一的出口")
    func exitingMidCleaningUsesTheOneDoor() {
        // 這個列舉是那條不變條件的所在：任何離開清潔中的路徑都必須要求解除
        // 攔截。安全輸入模式多出來的這一條也不例外，
        // `CleaningFlowControllerTests` 那個逐項走過 `CleaningExit` 的測試
        // 會自動涵蓋它。
        #expect(CleaningExit.secureInput.sound == .refused)
    }

    @Test("清潔中的安全輸入模式優先於逾時")
    func secureInputBeatsTheTimeoutOnTheSameTick() {
        // 兩件事撞在同一格時，出的聲音必須是拒絕而不是逾時：使用者需要知道
        // 剛才那一段可能根本沒鎖住，而不是以為保險正常跳掉了。
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: false, timeoutSeconds: 60))
        harness.controller.start()
        harness.clock.advance(by: 59)

        harness.secureInput.turnOn()
        harness.clock.advance(by: 1)

        #expect(harness.controller.stage == .standby)
        #expect(harness.sound.played.last == .refused)
        #expect(harness.sound.count(of: .timedOut) == 0)
    }

    @Test("清潔中的安全輸入模式優先於解鎖手勢")
    func secureInputBeatsTheUnlockGestureOnTheSameTick() {
        // 順序是刻意的：使用者按滿了手勢，同一格又發現攔截其實沒生效，
        // 這時該讓他知道的是「剛才那一段可能沒鎖住」，而不是一句「你解開了」。
        let harness = CleaningFlowHarness(
            settings: WipeSettings(bufferIsEnabled: false, timeoutSeconds: 600, unlockHoldSeconds: 3)
        )
        harness.controller.start()
        harness.keyboard.holdBothCommands()
        harness.clock.advance(by: 2)

        harness.secureInput.turnOn()
        harness.clock.advance(by: 1)

        #expect(harness.controller.stage == .standby)
        #expect(harness.sound.played.last == .refused)
        #expect(harness.sound.count(of: .unlocked) == 0)
    }

    @Test("清潔中一直沒有安全輸入模式就什麼都不會發生")
    func quietCleaningIsUnaffected() {
        // 這一條是上面那些測試的對照組：探測被問了那麼多次，
        // 回答「沒有」的時候不可以有任何副作用。
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: false, timeoutSeconds: 60))
        harness.controller.start()

        harness.clock.advance(by: 30)

        #expect(harness.controller.stage == .cleaning)
        #expect(harness.controller.refusal == nil)
        #expect(harness.sound.count(of: .refused) == 0)
    }
}
