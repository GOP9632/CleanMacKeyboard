import Testing

@testable import Wipe

/// 圓環的顯示狀態。圓環是主視窗與遮蔽層共用的元件，這些是它對外的約定。
@Suite("圓環的顯示狀態")
struct RingPhaseTests {
    @Test("待命時中央是開始清潔、顏色是中性灰、環靜止")
    func standby() {
        let standby = RingPhase.standby
        #expect(standby.title == .ringStandbyTitle)
        #expect(standby.tint == .standby)
        #expect(standby.progress == nil)
        #expect(standby.secondsRemaining == nil)
    }

    @Test("準備清潔是琥珀色，中央帶剩餘秒數")
    func preparing() {
        let preparing = RingPhase.preparing(secondsRemaining: 2, progress: 0.25)
        #expect(preparing.title == .ringPreparingTitle)
        #expect(preparing.tint == .preparing)
        #expect(preparing.progress == 0.25)
        #expect(preparing.secondsRemaining == 2)
    }

    @Test("清潔中是青色，環表達的是按住進度")
    func cleaning() {
        let cleaning = RingPhase.cleaning(holdProgress: 0.6)
        #expect(cleaning.title == .ringCleaningTitle)
        #expect(cleaning.tint == .cleaning)
        #expect(cleaning.progress == 0.6)
        // 逾時剩餘時間不畫在環上，也不佔用中央的第二行。
        #expect(cleaning.secondsRemaining == nil)
    }

    @Test("待命與準備清潔可以點，清潔中不可以")
    func activation() {
        #expect(RingPhase.standby.allowsActivation)
        #expect(RingPhase.preparing(secondsRemaining: 1, progress: 0.5).allowsActivation)
        // 抹布掃過觸控板剛好點到圓環不可以解鎖。
        #expect(RingPhase.cleaning(holdProgress: 0.9).allowsActivation == false)
    }

    @Test("超出範圍的進度值會被夾回 0 到 1", arguments: [
        (-1.0, 0.0),
        (0.0, 0.0),
        (0.5, 0.5),
        (1.0, 1.0),
        (2.5, 1.0),
    ])
    func progressIsClamped(_ input: Double, _ expected: Double) {
        #expect(RingPhase.cleaning(holdProgress: input).progress == expected)
        #expect(RingPhase.preparing(secondsRemaining: 0, progress: input).progress == expected)
    }
}
