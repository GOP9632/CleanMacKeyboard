import Foundation
import Testing

@testable import Wipe

/// 授權閘門決定主視窗裡放的是圓環還是授權引導畫面。
///
/// 這件事值得被自動化測試守著，因為它錯了的樣子都很難用眼睛看出來：
/// 使用者去系統設定打完勾回來，畫面卻還停在引導畫面，他會以為自己打錯了地方，
/// 而這正是非工程背景使用者最容易放棄的一步（見 #9）。
@Suite("授權閘門")
@MainActor
struct AuthorizationGateTests {
    @Test("已經有授權時一開啟就放行")
    func alreadyAuthorizedOpensImmediately() {
        // 授權過的老使用者不該先看到一瞬間的引導畫面才被放行。
        let gate = AuthorizationGate(authorization: FakeAccessibilityAuthorization(isTrusted: true), clock: TestClock())

        #expect(gate.isAuthorized)
    }

    @Test("沒有授權時擋著，並且開始等")
    func unauthorizedStartsWatching() {
        let clock = TestClock()
        let gate = AuthorizationGate(authorization: FakeAccessibilityAuthorization(), clock: clock)

        #expect(gate.isAuthorized == false)
        #expect(clock.isTicking)
    }

    @Test("使用者打完勾之後自動偵測到，不需要重開 app")
    func detectsAuthorizationWithoutARestart() {
        let clock = TestClock()
        let authorization = FakeAccessibilityAuthorization()
        let gate = AuthorizationGate(authorization: authorization, clock: clock)

        authorization.grant()
        clock.advance(by: AuthorizationGate.pollInterval)

        #expect(gate.isAuthorized)
    }

    @Test("還沒打勾之前一直擋著")
    func staysClosedUntilTheBoxIsTicked() {
        let clock = TestClock()
        let gate = AuthorizationGate(authorization: FakeAccessibilityAuthorization(), clock: clock)

        clock.advance(by: 60)

        #expect(gate.isAuthorized == false)
        #expect(clock.isTicking)
    }

    @Test("授權被收回時閘門又關上")
    func authorizationCanBeTakenBack() {
        // 授權被拿掉的人就是一個未授權的使用者，他不該看到一顆可以按但
        // 按了沒用的開始按鈕（見 #1 的 user story 50）。清潔模式進行中
        // 不換畫面那一條是視圖層的事，見 `MainWindowView`。
        let clock = TestClock()
        let authorization = FakeAccessibilityAuthorization()
        let gate = AuthorizationGate(authorization: authorization, clock: clock)
        authorization.grant()
        clock.advance(by: AuthorizationGate.pollInterval)
        #expect(gate.isAuthorized)

        authorization.revoke()
        clock.advance(by: AuthorizationGate.pollInterval)

        #expect(gate.isAuthorized == false)
    }

    @Test("按下按鈕就把使用者帶去系統設定")
    func openSettingsGoesThroughToTheRealThing() {
        let authorization = FakeAccessibilityAuthorization()
        let gate = AuthorizationGate(authorization: authorization, clock: TestClock())

        gate.openSettings()

        #expect(authorization.openSettingsCount == 1)
    }
}
