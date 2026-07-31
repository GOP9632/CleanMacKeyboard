import Foundation
import Testing

@testable import Wipe

/// 清潔流程控制器是這個專案唯一的自動化測試接縫（見 `docs/seams.md`）。
///
/// 這些測試只看外部觀察得到的東西：目前階段、剩餘秒數、被要求的攔截範圍、
/// 被要求解除攔截、被播放的音效。控制器內部怎麼算時間、用什麼資料結構記狀態
/// 都不在這裡。
///
/// 時間一律由虛擬時鐘推進，沒有任何一個測試真的等待。
@Suite("清潔流程控制器")
@MainActor
struct CleaningFlowControllerTests {
    // MARK: - 待命

    @Test("起步是待命，沒有攔截也沒有聲音")
    func startsInStandby() {
        let harness = CleaningFlowHarness()
        #expect(harness.controller.stage == .standby)
        #expect(harness.interceptor.wasEverAskedToIntercept == false)
        #expect(harness.sound.played.isEmpty)
        #expect(harness.controller.timeoutSecondsRemaining == nil)
    }

    // MARK: - 準備清潔

    @Test("緩衝開啟時按下開始進入準備清潔，而不是直接攔截")
    func bufferEnabledEntersPreparing() {
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: true, bufferSeconds: 3))
        harness.controller.start()

        #expect(harness.controller.stage == .preparing)
        // 準備清潔期間不攔截，這正是它存在的理由。
        #expect(harness.interceptor.wasEverAskedToIntercept == false)
    }

    @Test("緩衝關閉時按下開始直接進入清潔中")
    func bufferDisabledEntersCleaningImmediately() {
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: false))
        harness.controller.start()

        #expect(harness.controller.stage == .cleaning)
        #expect(harness.interceptor.activeScope == .keyboard)
        #expect(harness.sound.played == [.locked])
    }

    @Test("準備清潔期間圓環顯示剩餘秒數")
    func preparingShowsSecondsRemaining() {
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferSeconds: 3))
        harness.controller.start()
        #expect(harness.controller.preparingSecondsRemaining == 3)

        harness.clock.advance(by: 1)
        #expect(harness.controller.preparingSecondsRemaining == 2)

        harness.clock.advance(by: 1)
        #expect(harness.controller.preparingSecondsRemaining == 1)

        // 還沒走完最後一秒，畫面上仍然是 1，不是 0。
        harness.clock.advance(by: 0.5)
        #expect(harness.controller.preparingSecondsRemaining == 1)
        #expect(harness.controller.stage == .preparing)
    }

    @Test("準備清潔期間每秒播放一次音效")
    func preparingPlaysOneTickPerSecond() {
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferSeconds: 3))
        harness.controller.start()
        // 第一聲在按下開始的當下，使用者不用等一秒才聽到回應。
        #expect(harness.sound.count(of: .preparingTick) == 1)

        harness.clock.advance(by: 1)
        #expect(harness.sound.count(of: .preparingTick) == 2)

        harness.clock.advance(by: 1)
        #expect(harness.sound.count(of: .preparingTick) == 3)

        // 三秒的倒數就是三聲，最後一格不會多補一聲。
        harness.clock.advance(by: 1)
        #expect(harness.sound.count(of: .preparingTick) == 3)
        #expect(harness.sound.played == [.preparingTick, .preparingTick, .preparingTick, .locked])
    }

    @Test("倒數歸零進入清潔中，播放鎖上並要求攔截")
    func preparingFinishesIntoCleaning() {
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferSeconds: 3))
        harness.controller.start()
        harness.clock.advance(by: 3)

        #expect(harness.controller.stage == .cleaning)
        #expect(harness.sound.played.last == .locked)
        #expect(harness.interceptor.requestedScopes == [.keyboard])
        #expect(harness.controller.preparingSecondsRemaining == nil)
    }

    @Test("準備清潔期間按 Esc 回到待命，過程中從未要求攔截")
    func cancellingPreparingNeverIntercepts() {
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferSeconds: 3))
        harness.controller.start()
        harness.clock.advance(by: 2)

        harness.controller.cancel()

        #expect(harness.controller.stage == .standby)
        #expect(harness.interceptor.wasEverAskedToIntercept == false)
        // 取消之後時間再怎麼走都不可以自己跑進清潔中。
        harness.clock.advance(by: 10)
        #expect(harness.controller.stage == .standby)
        #expect(harness.interceptor.wasEverAskedToIntercept == false)
    }

    @Test("準備清潔期間再點一次圓環也是取消")
    func activatingRingDuringPreparingCancels() {
        let harness = CleaningFlowHarness()
        harness.controller.activateRing()
        #expect(harness.controller.stage == .preparing)

        harness.controller.activateRing()
        #expect(harness.controller.stage == .standby)
        #expect(harness.interceptor.wasEverAskedToIntercept == false)
    }

    @Test("回到待命之後不再佔著時鐘")
    func standbyStopsTheClock() {
        let harness = CleaningFlowHarness()
        harness.controller.start()
        #expect(harness.clock.isTicking)

        harness.controller.cancel()
        #expect(harness.clock.isTicking == false)
    }

    // MARK: - 清潔中

    @Test("清潔中的圓環不可點擊")
    func cleaningRingIsNotClickable() {
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: false))
        harness.controller.start()

        // 畫面那一層由 `RingPhase.allowsActivation` 擋著（見 RingPhaseTests），
        // 這裡守的是第二道：抹布掃過觸控板剛好點到，也不可以有任何事發生。
        harness.controller.activateRing()
        #expect(harness.controller.stage == .cleaning)
        #expect(harness.interceptor.activeScope == .keyboard)
    }

    @Test("逾時剩餘時間以文字呈現，不佔用圓環")
    func timeoutRemainingDoesNotUseTheRing() {
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: false, timeoutSeconds: 60))
        harness.controller.start()

        #expect(harness.controller.timeoutSecondsRemaining == 60)
        harness.clock.advance(by: 20)
        #expect(harness.controller.timeoutSecondsRemaining == 40)

        // 剩餘秒數是一個獨立的值，跟圓環那一組值分開。環在清潔中只表達
        // 解鎖手勢的按住進度，中央也不擺秒數，那一條由 RingPhaseTests 守著。
        #expect(harness.controller.preparingSecondsRemaining == nil)
    }

    @Test("逾時後自動回到待命，解除攔截，並播放逾時音效")
    func timeoutReturnsToStandby() {
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: false, timeoutSeconds: 60))
        harness.controller.start()

        harness.clock.advance(by: 59)
        #expect(harness.controller.stage == .cleaning)
        #expect(harness.interceptor.activeScope == .keyboard)

        harness.clock.advance(by: 1)
        #expect(harness.controller.stage == .standby)
        #expect(harness.interceptor.activeScope == nil)
        #expect(harness.interceptor.stopCount == 1)
        #expect(harness.sound.played.last == .timedOut)
        #expect(harness.controller.timeoutSecondsRemaining == nil)
    }

    @Test("逾時解除的聲音與手勢解鎖不同")
    func timeoutSoundDiffersFromUnlock() {
        // 使用者看不到螢幕時，這一聲是他分辨「保險跳掉了」與「我自己解開了」
        // 的唯一線索。
        #expect(CleaningExit.timedOut.sound == .timedOut)
        #expect(WipeSound.timedOut != WipeSound.unlocked)
    }

    @Test("逾時上限 15 分鐘也不需要真的等")
    func fifteenMinuteTimeoutNeedsNoWaiting() {
        let limit = WipeSettings.timeoutSecondsRange.upperBound
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: false, timeoutSeconds: limit))
        harness.controller.start()

        harness.clock.advance(by: limit - 1)
        #expect(harness.controller.stage == .cleaning)

        harness.clock.advance(by: 1)
        #expect(harness.controller.stage == .standby)
        #expect(harness.interceptor.activeScope == nil)
    }

    @Test("攔截範圍照設定走", arguments: InterceptionScope.allCases)
    func interceptionScopeFollowsSettings(_ scope: InterceptionScope) {
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: false, interceptionScope: scope))
        harness.controller.start()

        #expect(harness.interceptor.requestedScopes == [scope])
    }

    // MARK: - 不變條件

    @Test("任何離開清潔中的路徑都要求攔截器解除", arguments: CleaningExit.allCases)
    func everyExitReleasesTheInterceptor(_ exit: CleaningExit) {
        // 這一條刻意逐項走過 CleaningExit 的每一個 case，而不是只測逾時那一條。
        // 日後多一條離開的路徑就多一個 case，這個測試會自動涵蓋它，
        // 不需要有人記得回來補。
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: false))
        harness.controller.start()
        #expect(harness.interceptor.activeScope != nil)

        harness.controller.exitCleaning(exit)

        #expect(harness.controller.stage == .standby)
        #expect(harness.interceptor.activeScope == nil)
        #expect(harness.interceptor.stopCount == 1)
    }

    @Test("重複要求離開清潔中不會重複解除")
    func exitingTwiceIsHarmless() {
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: false))
        harness.controller.start()

        harness.controller.exitCleaning(.timedOut)
        harness.controller.exitCleaning(.timedOut)

        #expect(harness.controller.stage == .standby)
        #expect(harness.interceptor.stopCount == 1)
        #expect(harness.sound.count(of: .timedOut) == 1)
    }
}
