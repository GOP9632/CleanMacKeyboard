import Foundation
import Testing

@testable import Wipe

/// 全輸入鎖：鍵盤、觸控板與滑鼠一起被攔截，游標定住。
///
/// 「有沒有攔到」是另一份測試的事（見 `InterceptionScopeEventsTests`）。
/// 這一份守的是這個範圍獨有的兩個風險：
///
/// 一是**出不來**。全輸入鎖底下沒有滑鼠可以求救，逾時解鎖與闔蓋解鎖從
/// 「保險」變成使用者唯一的出路，所以這兩條在這個範圍底下要各自被測到，
/// 不能只靠鍵盤鎖那一組測試涵蓋。
///
/// 二是**看不出自己在哪一種範圍裡**。兩種範圍留下的求救路徑不一樣，
/// 使用者得知道現在觸控板還能不能動。
@Suite("全輸入鎖")
@MainActor
struct AllInputLockTests {
    /// 久到不會在測試中途跳掉的逾時，免得保險先跳掉而看起來像別的路徑生效了。
    /// 要測逾時的那一條自己給短的值。
    ///
    /// `nonisolated` 是因為它被當成下面那個函式的預設引數，而預設引數的算式
    /// 跑在 main actor 外面。
    nonisolated static let farAwayTimeout: TimeInterval = 15 * 60

    static func cleaningHarness(
        scope: InterceptionScope = .allInput,
        timeoutSeconds: TimeInterval = farAwayTimeout
    ) -> CleaningFlowHarness {
        .cleaning(settings: WipeSettings(timeoutSeconds: timeoutSeconds, interceptionScope: scope))
    }

    // MARK: - 出得來

    @Test("全輸入鎖底下逾時解鎖仍然有效")
    func theTimeoutStillWorks() {
        // 這個範圍底下逾時不只是保險：滑鼠也沒了，它是使用者手上剩下的兩條
        // 出路之一（見 ADR-0002）。
        let harness = Self.cleaningHarness(timeoutSeconds: 60)
        #expect(harness.interceptor.activeScope == .allInput)

        harness.clock.advance(by: 60)

        #expect(harness.controller.stage == .standby)
        #expect(harness.interceptor.activeScope == nil)
        #expect(harness.controller.activeInterceptionScope == nil)
        #expect(harness.sound.played.last == .timedOut)
    }

    @Test("全輸入鎖底下闔蓋解鎖仍然有效", arguments: MachineSignal.allCases)
    func lidUnlockStillWorks(_ signal: MachineSignal) {
        // 另一條出路。闔上蓋子是手指一定按得到的動作，不需要游標。
        let harness = Self.cleaningHarness()

        harness.machine.send(signal)

        #expect(harness.controller.stage == .standby)
        #expect(harness.interceptor.activeScope == nil)
        #expect(harness.controller.activeInterceptionScope == nil)
    }

    @Test("全輸入鎖底下解鎖手勢仍然有效")
    func theUnlockGestureStillWorks() {
        // 手勢不是保險，是正常的出口。全輸入鎖多攔的是觸控板與滑鼠，鍵盤事件
        // 照樣先經過攔截器才被丟掉，手勢的訊號就是從那裡來的
        // （見 `InterceptedKeyboardSignalSource`）。
        let harness = Self.cleaningHarness()
        harness.keyboard.holdBothCommands()

        harness.clock.advance(by: harness.controller.settings.unlockHoldSeconds)

        #expect(harness.controller.stage == .standby)
        #expect(harness.interceptor.activeScope == nil)
        #expect(harness.sound.played.last == .unlocked)
    }

    // MARK: - 看得出目前的範圍

    @Test("清潔中看得出目前是哪一種攔截範圍", arguments: InterceptionScope.allCases)
    func theScopeInForceIsVisibleWhileCleaning(_ scope: InterceptionScope) {
        let harness = Self.cleaningHarness(scope: scope)

        #expect(harness.controller.stage == .cleaning)
        #expect(harness.controller.activeInterceptionScope == scope)
    }

    @Test("待命時沒有範圍可以顯示")
    func standbyHasNoScopeToShow() {
        let harness = CleaningFlowHarness(settings: WipeSettings(interceptionScope: .allInput))

        #expect(harness.controller.activeInterceptionScope == nil)
    }

    @Test("準備清潔還沒攔截任何東西，也沒有範圍可以顯示")
    func preparingHasNoScopeToShow() {
        // 這個階段的觸控板與鍵盤都還活著。說它已經鎖住等於製造假象
        // （見 `CONTEXT.md` 的不變條件）。
        let harness = CleaningFlowHarness(
            settings: WipeSettings(
                bufferIsEnabled: true,
                bufferSeconds: 3,
                interceptionScope: .allInput
            )
        )

        harness.controller.start()

        #expect(harness.controller.stage == .preparing)
        #expect(harness.controller.activeInterceptionScope == nil)
    }

    @Test("每一條離開清潔中的路徑都把範圍收回去", arguments: CleaningExit.allCases)
    func everyExitClearsTheScope(_ exit: CleaningExit) {
        // 跟「每一條路徑都解除攔截」是同一件事的兩面。逐項走過每一個 case，
        // 日後多一條路就自動被涵蓋。
        let harness = Self.cleaningHarness()
        #expect(harness.controller.activeInterceptionScope == .allInput)

        harness.controller.exitCleaning(exit)

        #expect(harness.controller.activeInterceptionScope == nil)
    }

    @Test("攔截裝不上去的時候不顯示任何範圍")
    func aRefusedInterceptionShowsNoScope() {
        let harness = CleaningFlowHarness(
            settings: WipeSettings(bufferIsEnabled: false, interceptionScope: .allInput)
        )
        harness.interceptor.breakInterception()

        harness.controller.start()

        #expect(harness.controller.stage == .standby)
        #expect(harness.controller.activeInterceptionScope == nil)
    }

    @Test("清潔中改設定，顯示的仍然是真的裝上去的那一個範圍")
    func changingTheSettingMidCleaningDoesNotChangeWhatIsShown() {
        // 鍵盤鎖底下觸控板還活著，使用者真的有辦法在清潔中打開設定改這一項。
        // 已經裝上去的攔截不會跟著變，所以顯示設定裡那一個就是說一句不成立的話：
        // 畫面寫著游標已經定住，而使用者手上的游標正在動。
        let store = WipeSettingsStore(
            WipeSettings(bufferIsEnabled: false, interceptionScope: .keyboard)
        )
        let harness = CleaningFlowHarness(store: store)
        harness.controller.start()
        #expect(harness.controller.activeInterceptionScope == .keyboard)

        store.settings.interceptionScope = .allInput

        #expect(harness.controller.activeInterceptionScope == .keyboard)
        #expect(harness.interceptor.activeScope == .keyboard)
    }

    // MARK: - 畫面上說的是哪一句話

    @Test("兩種範圍各自對到自己的那一句話")
    func eachScopeMapsToItsOwnSentence() {
        // 對調了不會有編譯錯誤，只會在畫面上說反：使用者以為觸控板還能動，
        // 而它其實已經停了，或者反過來。
        #expect(InterceptionScope.keyboard.statusText == .mainScopeKeyboard)
        #expect(InterceptionScope.allInput.statusText == .mainScopeAllInput)
    }

    @Test("沒有兩種範圍共用同一句話")
    func noTwoScopesShareASentence() {
        // 日後多一種範圍時，這一條會在有人忘記補文字的時候失敗。
        let sentences = Set(InterceptionScope.allCases.map(\.statusText))
        #expect(sentences.count == InterceptionScope.allCases.count)
    }
}
