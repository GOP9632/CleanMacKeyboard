import AppKit
import Testing

@testable import Wipe

/// 清潔模式期間主視窗要一直看得見。
///
/// 這一組守的是那張對照表本身：哪一個階段要置頂、置到多高、置頂期間視窗的
/// 集合行為要換成什麼。這三個值錯了都不會有編譯錯誤，只會安靜地失效成
/// 「使用者閉著眼睛擦，抬頭卻找不到那個圓環」。
///
/// 真的蓋得過全螢幕 app、真的不會變暗，只有真機驗得到，那是手動驗收清單的
/// 第 3 與第 6 項。
@Suite("清潔模式期間畫面一直看得見")
struct CleaningVisibilityTests {
    @Test("待命不置頂")
    func standbyStaysOrdinary() {
        // 待命是使用者看最久的畫面，而且什麼都沒鎖。一個永遠蓋在別人上面的
        // 普通視窗只是討人厭。
        #expect(CleaningVisibility.isEngaged(during: .standby) == false)
    }

    @Test("準備清潔也不置頂")
    func preparingStaysOrdinary() {
        // 這個階段一個事件都還沒攔（見 `CleaningStage.preparing`），使用者的
        // 鍵盤與滑鼠都活著，隨時可以按 Esc 反悔。置頂要解決的是「鍵盤已經鎖了
        // 卻看不到狀態」，那件事到清潔中才發生。
        #expect(CleaningVisibility.isEngaged(during: .preparing) == false)
    }

    @Test("清潔中置頂")
    func cleaningIsRaised() {
        #expect(CleaningVisibility.isEngaged(during: .cleaning))
    }

    @Test("置頂的層級高過一般 app 用得到的每一個層級")
    func raisedLevelIsAboveEveryOrdinaryLevel() {
        // 全螢幕 app 的視窗本身是普通層級，選單列與 Dock 則落在下面這幾個。
        // 只要比它們全部高，背景 app 跳到前景就蓋不掉主視窗。
        let ordinary: [NSWindow.Level] = [
            .normal, .floating, .submenu, .tornOffMenu, .modalPanel,
            .mainMenu, .statusBar, .popUpMenu,
        ]
        for level in ordinary {
            #expect(
                CleaningVisibility.raisedWindowLevel.rawValue > level.rawValue,
                "置頂層級沒有高過 \(level.rawValue)"
            )
        }
    }

    @Test("置頂時跟著每一個 Space 走，也跟得進全螢幕 app")
    func raisedBehaviorFollowsEverySpace() {
        // 只把層級調高是不夠的：全螢幕 app 各自佔一個 Space，沒有這兩個旗標
        // 的視窗留在原本那個 Space，使用者切過去就什麼都看不到。
        let raised = CleaningVisibility.raisedCollectionBehavior(from: [])
        #expect(raised.contains(.canJoinAllSpaces))
        #expect(raised.contains(.fullScreenAuxiliary))
    }

    @Test("置頂時拿掉跟置頂互斥的那兩個旗標")
    func raisedBehaviorDropsTheConflictingFlags() {
        // `.fullScreenPrimary` 與 `.fullScreenAuxiliary` 互斥，`.moveToActiveSpace`
        // 與 `.canJoinAllSpaces` 互斥。同時帶著的話 AppKit 會自己挑一個，
        // 挑到哪一個沒有保證，那就是安靜地失效。
        let raised = CleaningVisibility.raisedCollectionBehavior(
            from: [.fullScreenPrimary, .moveToActiveSpace]
        )
        #expect(raised.contains(.fullScreenPrimary) == false)
        #expect(raised.contains(.moveToActiveSpace) == false)
    }

    @Test("原本那些不相干的旗標留著")
    func raisedBehaviorKeepsTheRest() {
        // 清潔模式期間主視窗的外觀、大小、位置都不變（見 #1 的 user story 16）。
        // 順手把視窗其他行為改掉也算變，而且回到待命時還原不回去。
        let raised = CleaningVisibility.raisedCollectionBehavior(
            from: [.managed, .participatesInCycle]
        )
        #expect(raised.contains(.managed))
        #expect(raised.contains(.participatesInCycle))
    }
}
