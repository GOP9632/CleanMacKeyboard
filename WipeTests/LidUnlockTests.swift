import Foundation
import Testing

@testable import Wipe

/// 闔蓋解鎖是兩道不可關閉的保險之一（另一道是逾時解鎖）。
///
/// 它在全輸入鎖模式下特別重要：那個模式連滑鼠都失效，闔上蓋子是使用者
/// 手指一定按得到的動作。
///
/// 主要訊號是蓋子闔上，次要訊號是系統從睡眠喚醒。只監聽睡眠不夠：接上
/// 外接螢幕與電源時闔蓋不會睡眠，那正是保險最需要生效的場合。
@Suite("闔蓋解鎖")
@MainActor
struct LidUnlockTests {
    /// 久到不會在測試中途跳掉的逾時，免得保險先跳掉而看起來像闔蓋生效了。
    static let farAwayTimeout: TimeInterval = 15 * 60

    static func cleaningHarness() -> CleaningFlowHarness {
        CleaningFlowHarness.cleaning(
            settings: WipeSettings(timeoutSeconds: farAwayTimeout)
        )
    }

    // MARK: - 兩條路徑

    @Test("清潔中蓋子闔上，回到待命並解除攔截")
    func closingTheLidReturnsToStandby() {
        let harness = Self.cleaningHarness()
        #expect(harness.controller.stage == .cleaning)

        harness.machine.closeLid()

        #expect(harness.controller.stage == .standby)
        #expect(harness.interceptor.activeScope == nil)
        #expect(harness.interceptor.stopCount == 1)
    }

    @Test("清潔中系統從睡眠喚醒，回到待命並解除攔截")
    func wakingFromSleepReturnsToStandby() {
        let harness = Self.cleaningHarness()

        harness.machine.wake()

        #expect(harness.controller.stage == .standby)
        #expect(harness.interceptor.activeScope == nil)
        #expect(harness.interceptor.stopCount == 1)
    }

    @Test("兩條路徑都不出聲")
    func neitherPathMakesASound() {
        // 七個出聲的時刻是規格寫死的，這兩條不在裡面（見 #1）。闔上蓋子的
        // 使用者看不到也多半聽不到螢幕那一邊發生什麼事，而喚醒之後畫面上
        // 就是待命，不需要一聲來解釋。
        #expect(CleaningExit.lidClosed.sound == nil)
        #expect(CleaningExit.systemWoke.sound == nil)

        let harness = Self.cleaningHarness()
        let heardBefore = harness.sound.played
        harness.machine.closeLid()

        #expect(harness.sound.played == heardBefore)
    }

    // MARK: - 只有清潔中算數

    @Test("待命期間的機器訊號不做任何事", arguments: MachineSignal.allCases)
    func machineSignalsDoNothingInStandby(_ signal: MachineSignal) {
        let harness = CleaningFlowHarness()

        harness.machine.send(signal)

        #expect(harness.controller.stage == .standby)
        #expect(harness.interceptor.stopCount == 0)
    }

    @Test("準備清潔期間的機器訊號不做任何事", arguments: MachineSignal.allCases)
    func machineSignalsDoNothingWhilePreparing(_ signal: MachineSignal) {
        // 準備清潔還沒攔截任何東西，使用者的手也還在鍵盤上，沒有被鎖住的
        // 風險。這個階段要離開，取消就好。
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: true, bufferSeconds: 3))
        harness.controller.start()

        harness.machine.send(signal)

        #expect(harness.controller.stage == .preparing)
    }

    @Test("機器訊號來源只在清潔中被監看")
    func theSourceIsOnlyWatchedWhileCleaning() {
        let harness = CleaningFlowHarness(
            settings: WipeSettings(bufferSeconds: 3, timeoutSeconds: Self.farAwayTimeout)
        )
        #expect(harness.machine.isMonitoring == false)

        harness.controller.start()
        #expect(harness.machine.isMonitoring == false)

        harness.clock.advance(by: 3)
        #expect(harness.controller.stage == .cleaning)
        #expect(harness.machine.isMonitoring)

        harness.machine.closeLid()
        #expect(harness.machine.isMonitoring == false)
    }

    // MARK: - 拆不掉

    @Test("沒有任何設定拆得掉闔蓋解鎖", arguments: MachineSignal.allCases)
    func noSettingCanTurnItOff(_ signal: MachineSignal) {
        // 型別上就沒有對應的欄位，這一條由 `WipeSettingsTests` 守著。這裡守的是
        // 行為那一面：把設定裡每一個拆得動的東西都拆到底，保險照樣跳
        // （見 ADR-0002）。
        var settings = WipeSettings(
            bufferIsEnabled: false,
            timeoutSeconds: WipeSettings.timeoutSecondsRange.upperBound,
            unlockHoldSeconds: WipeSettings.unlockHoldSecondsRange.upperBound,
            interceptionScope: .allInput,
            screenPresentation: .overlay
        )
        settings.sounds.isEnabled = false
        let harness = CleaningFlowHarness.cleaning(settings: settings)

        harness.machine.send(signal)

        #expect(harness.controller.stage == .standby)
        #expect(harness.interceptor.activeScope == nil)
    }
}

/// 蓋子那一條真正去問 IOKit 的部分沒辦法寫測試，但「一連串狀態怎麼變成一次
/// 剛剛闔上」可以，而那正是錯了會很嚴重的那一段。
@Suite("蓋子闔上的邊緣偵測")
struct LidCloseDetectorTests {
    /// 依序讀進一串蓋子狀態（`true` 是闔著），回傳每一次的答案。
    static func answers(startingClosed: Bool, reading states: [Bool]) -> [Bool] {
        var lid = LidCloseDetector(lidIsClosed: startingClosed)
        return states.map { lid.observe(lidIsClosed: $0) }
    }

    @Test("從開著變成闔上算一次")
    func openThenClosedCounts() {
        #expect(Self.answers(startingClosed: false, reading: [false, true]) == [false, true])
    }

    @Test("一直闔著只算第一次那一下")
    func stayingClosedOnlyCountsOnce() {
        #expect(Self.answers(startingClosed: false, reading: [true, true, true]) == [true, false, false])
    }

    @Test("起點就闔著的話不算")
    func startingClosedDoesNotCount() {
        // 接著外接螢幕闔蓋使用的使用者，蓋子本來就一直闔著。這裡若回 true，
        // 他一進清潔模式就會被踢回待命，永遠擦不了那顆外接鍵盤。
        #expect(Self.answers(startingClosed: true, reading: [true, true]) == [false, false])
    }

    @Test("起點就闔著，打開再闔上就算")
    func reopeningRearmsIt() {
        // 上一條的另一面：clamshell 模式下這條路仍然走得通，只是使用者要先
        // 把蓋子掀開。
        #expect(Self.answers(startingClosed: true, reading: [false, true]) == [false, true])
    }
}
