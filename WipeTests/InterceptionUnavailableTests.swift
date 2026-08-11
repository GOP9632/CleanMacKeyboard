import Foundation
import Testing

@testable import Wipe

/// 授權給了，攔截卻還是建立不起來。
///
/// 這是授權引導畫面收不掉的那一個角落（見 #9）：畫面已經放行了，代表系統
/// 說有授權，但事件攔截器就是裝不上去。macOS 上這件事真的會發生，最常見的
/// 原因是 app 的簽章換過，系統那份授權清單記著的是舊的身分。
///
/// 這時唯一有效的動作是重開 Wipe，所以這條路徑必須跟安全輸入模式一樣誠實：
/// 拒絕進入、出聲、把理由說出來，而不是安靜地什麼都沒發生
/// （見 `CONTEXT.md` 的不變條件與 ADR-0002）。
@Suite("攔截建立不起來")
@MainActor
struct InterceptionUnavailableTests {
    @Test("攔截建立不起來時階段維持待命")
    func refusesToEnterCleaning() {
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: false))
        harness.interceptor.breakInterception()

        harness.controller.start()

        #expect(harness.controller.stage == .standby)
        #expect(harness.clock.isTicking == false)
    }

    @Test("攔截建立不起來時說得出理由")
    func reportsTheReason() {
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: false))
        harness.interceptor.breakInterception()

        harness.controller.start()

        #expect(harness.controller.refusal == .interceptionUnavailable)
    }

    @Test("攔截建立不起來時播放拒絕音效，而不是鎖上那一聲")
    func playsTheRefusedSoundAndNeverTheLockedOne() {
        // 「鎖上」那一聲是「可以開始擦了」的許可。它響的時候鍵盤必須真的
        // 已經鎖著，所以攔截沒裝上去的時候它絕對不可以響。
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: false))
        harness.interceptor.breakInterception()

        harness.controller.start()

        #expect(harness.sound.played == [.refused])
    }

    @Test("攔截建立不起來時照樣要求解除，不留半開的攔截")
    func asksForATeardownAnyway() {
        // 攔截器可能是裝到一半才失敗的（例如鍵盤那一條裝上了、滑鼠那一條沒有）。
        // 解除可以重複呼叫，寧可多解一次也不要漏解一次（見 `InputInterceptor`）。
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: false))
        harness.interceptor.breakInterception()

        harness.controller.start()

        #expect(harness.interceptor.stopCount == 1)
        #expect(harness.interceptor.activeScope == nil)
    }

    @Test("緩衝倒數走完那一刻才失敗，也擋得下來")
    func failureAtTheHandoverIsCaught() {
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferSeconds: 3))
        harness.controller.start()
        #expect(harness.controller.stage == .preparing)

        harness.interceptor.breakInterception()
        harness.clock.advance(by: 3)

        #expect(harness.controller.stage == .standby)
        #expect(harness.controller.refusal == .interceptionUnavailable)
        #expect(harness.sound.played.last == .refused)
        #expect(harness.clock.isTicking == false)
    }

    @Test("攔截修好之後再按一次就進得去，理由被清掉")
    func refusalClearsOnceInterceptionWorksAgain() {
        let harness = CleaningFlowHarness(settings: WipeSettings(bufferIsEnabled: false))
        harness.interceptor.breakInterception()
        harness.controller.start()
        #expect(harness.controller.refusal != nil)

        harness.interceptor.fixInterception()
        harness.controller.start()

        #expect(harness.controller.stage == .cleaning)
        #expect(harness.controller.refusal == nil)
        #expect(harness.interceptor.activeScope == .keyboard)
    }
}
