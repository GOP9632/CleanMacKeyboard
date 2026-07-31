import AppKit
import Foundation
import Testing

@testable import Wipe

/// 解鎖手勢：清潔模式期間同時按住左右 Command 滿設定秒數就回到待命。
///
/// 這些測試全部走清潔流程控制器這個唯一的接縫（見 `docs/seams.md`），
/// 只看外部觀察得到的東西：目前階段、按住進度、被要求解除攔截、被播放的音效。
/// 時間一律由虛擬時鐘推進，沒有任何一個測試真的等待。
///
/// 手勢是這個 app 最要緊的一段判定：清潔模式期間鍵盤是失效的，「解不開」
/// 是最嚴重的失效模式，而「被抹布誤解鎖」則讓整個 app 失去意義。
/// 每一條規則在這裡都有一個測試。
@Suite("解鎖手勢")
@MainActor
struct UnlockGestureTests {
    /// 手勢的測試不關心逾時，但逾時關不掉，所以一律給一個遠大於手勢秒數的值，
    /// 免得保險先跳掉而看起來像手勢成功了。
    private static let farAwayTimeout: TimeInterval = 60

    private func cleaningHarness(holdSeconds: TimeInterval = 3) -> CleaningFlowHarness {
        .cleaning(
            settings: WipeSettings(
                timeoutSeconds: Self.farAwayTimeout,
                unlockHoldSeconds: holdSeconds
            )
        )
    }

    // MARK: - 開始計時的條件

    @Test("兩顆 Command 都按住滿設定秒數就回到待命")
    func holdingBothCommandsUnlocks() {
        let harness = cleaningHarness()
        harness.keyboard.holdBothCommands()

        harness.clock.advance(by: 3)

        #expect(harness.controller.stage == .standby)
        #expect(harness.interceptor.activeScope == nil)
        #expect(harness.interceptor.stopCount == 1)
        #expect(harness.sound.played.last == .unlocked)
    }

    @Test("不要求同一瞬間按下，先按左邊再按右邊也算")
    func commandsMayBePressedOneAfterTheOther() {
        // 人類做不到真正同時按下兩顆鍵。要求同時等於要求一件做不到的事。
        let harness = cleaningHarness()

        harness.keyboard.send(leftCommand: true)
        harness.clock.advance(by: 2)
        #expect(harness.controller.stage == .cleaning)

        harness.keyboard.holdBothCommands()
        // 計時是從兩顆都按住的那一刻起算，不是從第一顆按下起算。
        harness.clock.advance(by: 2.9)
        #expect(harness.controller.stage == .cleaning)

        harness.clock.advance(by: 0.2)
        #expect(harness.controller.stage == .standby)
    }

    @Test("只按一顆不計時")
    func oneCommandAloneDoesNotCount() {
        let harness = cleaningHarness()

        harness.keyboard.send(leftCommand: true)
        harness.clock.advance(by: 10)

        #expect(harness.controller.stage == .cleaning)
        #expect(harness.controller.unlockHoldProgress == 0)
        #expect(harness.sound.count(of: .unlockGestureDetected) == 0)
    }

    @Test("夾帶其他修飾鍵時不計時")
    func otherModifiersDisqualifyTheGesture() {
        // 兩顆 Command 加上 Shift 是使用者在打字，不是要解鎖。
        let harness = cleaningHarness()

        harness.keyboard.send(leftCommand: true, rightCommand: true, otherModifiers: true)
        harness.clock.advance(by: 10)

        #expect(harness.controller.stage == .cleaning)
        #expect(harness.sound.count(of: .unlockGestureDetected) == 0)
    }

    @Test("計時到一半才夾上其他修飾鍵，一樣歸零")
    func otherModifiersAppearingMidwayResetTheTimer() {
        // 抹布壓到 Shift 跟壓到別的鍵一樣要歸零，不能因為兩顆 Command 還按著
        // 就讓進度繼續累積。
        let harness = cleaningHarness()
        harness.keyboard.holdBothCommands()
        harness.clock.advance(by: 2)

        harness.keyboard.send(leftCommand: true, rightCommand: true, otherModifiers: true)
        #expect(harness.controller.unlockHoldProgress == 0)
        #expect(harness.sound.count(of: .unlockGestureReset) == 1)

        harness.clock.advance(by: 2)
        #expect(harness.controller.stage == .cleaning)
    }

    @Test("Caps Lock 開著不影響手勢")
    func capsLockDoesNotBlockTheGesture() throws {
        // 這一條刻意接真的鍵盤訊號來源，用合成的事件走完整條路：
        // 旗標判讀（Caps Lock 不算夾帶其他修飾鍵）與手勢判定要一起成立才有意義。
        // Caps Lock 是切換式的，開著的時候旗標一直在，若計入就會讓使用者永遠解不開
        // （見 #1 的 user story 33）。
        let clock = TestClock()
        let keyboard = LocalKeyboardSignalSource()
        let interceptor = RecordingInputInterceptor()
        let sound = RecordingSoundOutput()
        let controller = CleaningFlowController(
            settings: WipeSettings(
                bufferIsEnabled: false,
                timeoutSeconds: Self.farAwayTimeout,
                unlockHoldSeconds: 3
            ),
            clock: clock,
            keyboard: keyboard,
            interceptor: interceptor,
            sound: sound
        )
        controller.start()

        let bothCommandsWithCapsLock = KeyboardFlags.bothCommands | KeyboardFlags.capsLockBit
        keyboard.handle(
            try #require(
                NSEvent.fake(
                    .flagsChanged,
                    keyCode: KeyboardEventReading.rightCommandKeyCode,
                    rawFlags: bothCommandsWithCapsLock
                )
            )
        )
        clock.advance(by: 3)

        #expect(controller.stage == .standby)
        #expect(interceptor.activeScope == nil)
        #expect(sound.played.last == .unlocked)
    }

    // MARK: - 歸零

    @Test("任一顆 Command 放開，計時歸零")
    func releasingEitherCommandResetsTheTimer() {
        let harness = cleaningHarness()
        harness.keyboard.holdBothCommands()
        harness.clock.advance(by: 2)

        harness.keyboard.send(leftCommand: true)
        #expect(harness.controller.unlockHoldProgress == 0)

        // 歸零之後重新按住，從零開始，不是接著剛才那兩秒。
        harness.keyboard.holdBothCommands()
        harness.clock.advance(by: 2.9)
        #expect(harness.controller.stage == .cleaning)

        harness.clock.advance(by: 0.2)
        #expect(harness.controller.stage == .standby)
    }

    @Test("計時期間出現第三顆按鍵，計時歸零")
    func aThirdKeyResetsTheTimer() {
        // 這一條就是抹布解不開的理由：抹布壓下去必然會壓到空白鍵或旁邊一整片按鍵。
        let harness = cleaningHarness()
        harness.keyboard.holdBothCommands()
        harness.clock.advance(by: 2)

        harness.keyboard.pressThirdKey()
        harness.clock.advance(by: 2.9)
        #expect(harness.controller.stage == .cleaning)

        harness.clock.advance(by: 0.2)
        #expect(harness.controller.stage == .standby)
    }

    @Test("第三顆鍵的歸零以按下為觸發，不追蹤放開")
    func theThirdKeyResetIsTriggeredByThePressAlone() {
        // 若靠追蹤放開，系統漏掉一次放開事件就會讓使用者永遠解不開，
        // 那比誤觸更嚴重。所以第三顆鍵只在按下的那一刻歸零一次，
        // 之後就算它的放開事件從來沒有來過，手勢照樣走得完。
        let harness = cleaningHarness()
        harness.keyboard.holdBothCommands()
        harness.keyboard.pressThirdKey()

        harness.clock.advance(by: 3)

        #expect(harness.controller.stage == .standby)
        #expect(harness.sound.played.last == .unlocked)
    }

    @Test("歸零之後全部放開，重新按住從零開始計時")
    func timerRestartsFromZeroAfterAReset() {
        let harness = cleaningHarness()
        harness.keyboard.holdBothCommands()
        harness.clock.advance(by: 2.5)

        harness.keyboard.releaseEverything()
        harness.clock.advance(by: 5)
        #expect(harness.controller.stage == .cleaning)

        harness.keyboard.holdBothCommands()
        #expect(harness.controller.unlockHoldProgress == 0)
        harness.clock.advance(by: 3)
        #expect(harness.controller.stage == .standby)
    }

    // MARK: - 門檻

    @Test("按住不足設定秒數不解除")
    func holdingTooBrieflyDoesNotUnlock() {
        let harness = cleaningHarness()
        harness.keyboard.holdBothCommands()

        harness.clock.advance(by: 2.9)

        #expect(harness.controller.stage == .cleaning)
        #expect(harness.interceptor.activeScope == .keyboard)
    }

    @Test("設定不同秒數時門檻跟著改變")
    func theThresholdFollowsTheSetting() {
        let harness = cleaningHarness(holdSeconds: 5)
        harness.keyboard.holdBothCommands()

        harness.clock.advance(by: 3)
        #expect(harness.controller.stage == .cleaning)

        harness.clock.advance(by: 2)
        #expect(harness.controller.stage == .standby)
    }

    @Test("準備清潔期間按住兩顆 Command 不算數")
    func theGestureOnlyCountsWhileCleaning() {
        // 手勢是「離開清潔模式」的動作。還沒進去的時候按住它不該累積任何進度，
        // 否則一進去就立刻解開。
        let harness = CleaningFlowHarness(
            settings: WipeSettings(
                bufferSeconds: 3,
                timeoutSeconds: Self.farAwayTimeout,
                unlockHoldSeconds: 3
            )
        )
        harness.controller.start()
        harness.keyboard.holdBothCommands()

        harness.clock.advance(by: 3)
        #expect(harness.controller.stage == .cleaning)

        harness.clock.advance(by: 3)
        #expect(harness.controller.stage == .cleaning)
        #expect(harness.controller.unlockHoldProgress == 0)
    }

    // MARK: - 圓環

    @Test("清潔中的圓環表達手勢按住進度")
    func theRingShowsTheHoldProgress() {
        let harness = cleaningHarness()
        #expect(harness.controller.unlockHoldProgress == 0)

        harness.keyboard.holdBothCommands()
        harness.clock.advance(by: 1.5)
        #expect(abs(harness.controller.unlockHoldProgress - 0.5) < 0.05)

        // 逾時不佔用圓環，走了一大段時間也不會把環推上去。
        #expect(harness.controller.timeoutSecondsRemaining != nil)
    }

    @Test("回到待命之後按住進度歸零")
    func theHoldProgressIsZeroInStandby() {
        let harness = cleaningHarness()
        harness.keyboard.holdBothCommands()
        harness.clock.advance(by: 3)

        #expect(harness.controller.stage == .standby)
        #expect(harness.controller.unlockHoldProgress == 0)
    }

    // MARK: - 音效

    @Test("偵測到手勢時只播放一次，不是每次判定都播放")
    func theDetectedSoundPlaysOnce() {
        // 使用者看不到螢幕時，這一聲代表「認到了，繼續按住」。每一格都響一次
        // 會變成三秒的噪音。
        let harness = cleaningHarness()

        harness.keyboard.holdBothCommands()
        harness.clock.advance(by: 1)
        // 修飾鍵沒變也可能再送一次事件（例如另一顆鍵放開），不可以因此再響一次。
        harness.keyboard.holdBothCommands()
        harness.clock.advance(by: 1)

        #expect(harness.sound.count(of: .unlockGestureDetected) == 1)
    }

    @Test("計時歸零時播放音效")
    func theResetSoundPlays() {
        // 沒有這一聲，使用者會白按三秒才發現剛才被歸零了。
        let harness = cleaningHarness()
        harness.keyboard.holdBothCommands()
        harness.clock.advance(by: 1)

        harness.keyboard.releaseEverything()

        #expect(harness.sound.count(of: .unlockGestureReset) == 1)
        #expect(harness.sound.played.last == .unlockGestureReset)
    }

    @Test("根本沒開始計時就不會有歸零的聲音")
    func noResetSoundWithoutATimerToReset() {
        let harness = cleaningHarness()

        harness.keyboard.send(leftCommand: true)
        harness.keyboard.releaseEverything()
        harness.keyboard.send(rightCommand: true)
        harness.clock.advance(by: 5)

        #expect(harness.sound.count(of: .unlockGestureReset) == 0)
    }

    @Test("解鎖成功時播放的音效與逾時不同")
    func theUnlockSoundDiffersFromTheTimeoutSound() {
        // 使用者看不到螢幕時，這一聲是他分辨「我自己解開了」與「保險跳掉了」
        // 的唯一線索。
        #expect(CleaningExit.unlockGesture.sound == .unlocked)
        #expect(WipeSound.unlocked != WipeSound.timedOut)

        let harness = cleaningHarness()
        harness.keyboard.holdBothCommands()
        harness.clock.advance(by: 3)

        #expect(harness.sound.count(of: .unlocked) == 1)
        #expect(harness.sound.count(of: .timedOut) == 0)
    }

    @Test("整段手勢的聲音照順序只有三聲")
    func theWholeGestureSoundsLikeThis() {
        let harness = cleaningHarness()
        harness.keyboard.holdBothCommands()
        harness.clock.advance(by: 1)
        harness.keyboard.pressThirdKey()
        harness.clock.advance(by: 3)

        // 鎖上、認到手勢、被抹布歸零、然後才解開。中間不多不少。
        #expect(harness.sound.played == [.locked, .unlockGestureDetected, .unlockGestureReset, .unlocked])
    }

    // MARK: - 鍵盤訊號來源的生命週期

    @Test("只在清潔中監看鍵盤")
    func theKeyboardIsOnlyWatchedWhileCleaning() {
        let harness = CleaningFlowHarness(
            settings: WipeSettings(bufferSeconds: 3, timeoutSeconds: Self.farAwayTimeout)
        )
        #expect(harness.keyboard.isMonitoring == false)

        harness.controller.start()
        #expect(harness.keyboard.isMonitoring == false)

        harness.clock.advance(by: 3)
        #expect(harness.controller.stage == .cleaning)
        #expect(harness.keyboard.isMonitoring)

        harness.controller.exitCleaning(.timedOut)
        #expect(harness.keyboard.isMonitoring == false)
    }

    // MARK: - 逾時與手勢並存

    @Test("逾時期間手勢仍然可用")
    func theGestureStillWorksWhileTheTimeoutIsRunning() {
        let harness = cleaningHarness()
        harness.clock.advance(by: 30)
        #expect(harness.controller.stage == .cleaning)

        harness.keyboard.holdBothCommands()
        harness.clock.advance(by: 3)

        #expect(harness.controller.stage == .standby)
        #expect(harness.sound.played.last == .unlocked)
    }
}
