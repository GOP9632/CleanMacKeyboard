import Foundation
import Testing

@testable import Wipe

/// 設定是最單純的那個接縫：純粹的值。這裡守的是「值的範圍拆不掉保險」。
@Suite("設定值")
struct WipeSettingsTests {
    @Test("預設是緩衝三秒、鍵盤鎖")
    func defaults() {
        let settings = WipeSettings()
        #expect(settings.bufferIsEnabled)
        #expect(settings.bufferSeconds == 3)
        // 預設保留觸控板，萬一解鎖手勢失靈還有一條非鍵盤的求救路徑。
        #expect(settings.interceptionScope == .keyboard)
    }

    @Test("逾時上限是 15 分鐘，超過會被拉回來")
    func timeoutIsCappedAtFifteenMinutes() {
        #expect(WipeSettings.timeoutSecondsRange.upperBound == 15 * 60)

        var settings = WipeSettings(timeoutSeconds: 60 * 60)
        #expect(settings.timeoutSeconds == 15 * 60)

        // 事後改也一樣拉得回來，不只是 init 那一次。
        settings.timeoutSeconds = 60 * 60
        #expect(settings.timeoutSeconds == 15 * 60)
    }

    @Test("逾時關不掉，也沒有「永不」")
    func timeoutCannotBeDisabled() {
        // 型別上就是一個一定有值的秒數，沒有 nil、沒有 0、沒有無限大可以填。
        // 這是 ADR-0002 在程式裡的樣子。
        var settings = WipeSettings()
        settings.timeoutSeconds = 0
        #expect(settings.timeoutSeconds == WipeSettings.timeoutSecondsRange.lowerBound)
        #expect(settings.timeoutSeconds > 0)

        settings.timeoutSeconds = .infinity
        #expect(settings.timeoutSeconds == WipeSettings.timeoutSecondsRange.upperBound)
    }

    @Test("開發版的逾時預設值比正式版短")
    func developmentDefaultIsShorter() {
        // 判定邏輯出錯時不必等太久。
        #if DEBUG
        #expect(WipeSettings.defaultTimeoutSeconds == 30)
        #else
        #expect(WipeSettings.defaultTimeoutSeconds == 5 * 60)
        #endif
        #expect(WipeSettings.timeoutSecondsRange.contains(WipeSettings.defaultTimeoutSeconds))
    }

    @Test("解鎖手勢預設按住三秒，而且被夾在範圍內")
    func unlockHoldSecondsIsClamped() {
        #expect(WipeSettings().unlockHoldSeconds == 3)
        #expect(WipeSettings(unlockHoldSeconds: 0).unlockHoldSeconds == WipeSettings.unlockHoldSecondsRange.lowerBound)
        #expect(WipeSettings(unlockHoldSeconds: 999).unlockHoldSeconds == WipeSettings.unlockHoldSecondsRange.upperBound)

        // 零秒的按住等於一按就開，抹布掃過兩顆 Command 就解鎖了。
        #expect(WipeSettings.unlockHoldSecondsRange.lowerBound >= 1)

        var settings = WipeSettings()
        settings.unlockHoldSeconds = 999
        #expect(settings.unlockHoldSeconds == WipeSettings.unlockHoldSecondsRange.upperBound)
    }

    @Test("緩衝秒數也被夾在範圍內")
    func bufferSecondsIsClamped() {
        #expect(WipeSettings(bufferSeconds: 0).bufferSeconds == WipeSettings.bufferSecondsRange.lowerBound)
        #expect(WipeSettings(bufferSeconds: 999).bufferSeconds == WipeSettings.bufferSecondsRange.upperBound)
        // 緩衝至少一秒：零秒的緩衝等於沒開，那是 bufferIsEnabled 的事。
        #expect(WipeSettings.bufferSecondsRange.lowerBound >= 1)
    }
}
