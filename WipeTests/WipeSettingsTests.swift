import Foundation
import Testing

@testable import Wipe

/// 設定是最單純的那個接縫：純粹的值。這裡守的是「值的範圍拆不掉保險」。
@Suite("設定值")
struct WipeSettingsTests {
    @Test("預設是緩衝三秒、鍵盤鎖、主視窗")
    func defaults() {
        let settings = WipeSettings()
        #expect(settings.bufferIsEnabled)
        #expect(settings.bufferSeconds == 3)
        // 預設保留觸控板，萬一解鎖手勢失靈還有一條非鍵盤的求救路徑。
        #expect(settings.interceptionScope == .keyboard)
        // 預設不鋪遮蔽層：主視窗最不打擾人，遮蔽層是想要的人自己去開。
        #expect(settings.screenPresentation == .mainWindow)
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

    @Test("設定就是這幾個欄位，不多不少")
    func fieldsAreExactlyThese() {
        // 闔蓋解鎖與「解鎖手勢期間出現第三顆按鍵就重新計時」在型別上就沒有
        // 對應的欄位，所以設定畫面想做一個開關也做不出來。這是 ADR-0002
        // 在程式裡的樣子。
        //
        // 這個清單刻意寫死。日後多一個欄位這裡就會紅，逼人先回去讀一次
        // ADR-0002 再決定那個欄位該不該存在，而不是等到有人在設定畫面上
        // 看到一個不該出現的開關。
        let fields = Set(Mirror(reflecting: WipeSettings()).children.compactMap(\.label))
        #expect(fields == [
            "bufferIsEnabled",
            "bufferSeconds",
            "timeoutSeconds",
            "unlockHoldSeconds",
            "interceptionScope",
            "screenPresentation",
            "sounds",
        ])
    }
}

/// 音效設定分成總開關與個別開關兩層。這裡守的是那兩層怎麼互動。
@Suite("音效設定")
struct SoundSettingsTests {
    @Test("預設七個時刻全部開著", arguments: WipeSound.allCases)
    func everySoundStartsEnabled(_ sound: WipeSound) {
        let sounds = SoundSettings()
        #expect(sounds.isEnabled)
        #expect(sounds[sound])
        #expect(sounds.plays(sound))
    }

    @Test("總開關關掉，七個時刻一聲都不響", arguments: WipeSound.allCases)
    func masterSwitchSilencesEverything(_ sound: WipeSound) {
        var sounds = SoundSettings()
        sounds.isEnabled = false
        #expect(!sounds.plays(sound))
    }

    @Test("個別關掉只影響那一個")
    func mutingOneLeavesTheRest() {
        var sounds = SoundSettings()
        sounds[.preparingTick] = false

        #expect(!sounds.plays(.preparingTick))
        for other in WipeSound.allCases where other != .preparingTick {
            #expect(sounds.plays(other), "\(other) 不該被 preparingTick 的開關影響")
        }
    }

    @Test("總開關關掉再打開，個別的取捨原封不動")
    func masterSwitchDoesNotEraseIndividualChoices() {
        var sounds = SoundSettings()
        sounds[.preparingTick] = false

        sounds.isEnabled = false
        sounds.isEnabled = true

        #expect(!sounds[.preparingTick])
        #expect(sounds[.locked])
    }

    @Test("記的是被關掉的那幾個，不是開著的那幾個")
    func remembersWhatIsMuted() {
        // 預設是空集合，所以日後多一個時刻時，舊版本存下的偏好裡沒有它，
        // 它會自動是開著的，而不是靜悄悄地不出聲。
        #expect(SoundSettings().mutedSounds.isEmpty)

        var sounds = SoundSettings()
        sounds[.locked] = false
        #expect(sounds.mutedSounds == [.locked])

        sounds[.locked] = true
        #expect(sounds.mutedSounds.isEmpty)
    }
}
