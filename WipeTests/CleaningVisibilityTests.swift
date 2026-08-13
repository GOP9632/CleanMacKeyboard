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
    @Test("待命不置頂", arguments: ScreenPresentation.allCases)
    func standbyStaysOrdinary(_ presentation: ScreenPresentation) {
        // 待命是使用者看最久的畫面，而且什麼都沒鎖。一個永遠蓋在別人上面的
        // 普通視窗只是討人厭。
        #expect(
            CleaningVisibility.mainWindowIsRaised(during: .standby, presentation: presentation)
                == false
        )
    }

    @Test("準備清潔也不置頂", arguments: ScreenPresentation.allCases)
    func preparingStaysOrdinary(_ presentation: ScreenPresentation) {
        // 這個階段一個事件都還沒攔（見 `CleaningStage.preparing`），使用者的
        // 鍵盤與滑鼠都活著，隨時可以按 Esc 反悔。置頂要解決的是「鍵盤已經鎖了
        // 卻看不到狀態」，那件事到清潔中才發生。
        #expect(
            CleaningVisibility.mainWindowIsRaised(during: .preparing, presentation: presentation)
                == false
        )
    }

    @Test("清潔中置頂")
    func cleaningIsRaised() {
        #expect(CleaningVisibility.mainWindowIsRaised(during: .cleaning, presentation: .mainWindow))
    }

    @Test("設定選遮蔽層時，主視窗不做任何處置")
    func overlayPresentationLeavesTheMainWindowAlone() {
        // 遮蔽層自己就蓋在所有東西上面，主視窗自然被蓋住（見 `CONTEXT.md`）。
        // 跟著提高層級只會變成一個沒有人看得到、樣式卻已經被改過的視窗，
        // 而且回到待命還多一次還原。
        #expect(
            CleaningVisibility.mainWindowIsRaised(during: .cleaning, presentation: .overlay)
                == false
        )
    }

    @Test("只有清潔中阻止螢幕變暗")
    func displaySleepIsBlockedOnlyWhileCleaning() {
        // 這一條刻意不看畫面呈現的設定：遮蔽層一樣要一直看得見，而擦機器的
        // 那幾分鐘裡使用者不碰鍵盤也不碰觸控板，那正是系統判斷閒置的依據。
        #expect(CleaningVisibility.displaySleepIsBlocked(during: .cleaning))
        #expect(CleaningVisibility.displaySleepIsBlocked(during: .standby) == false)
        #expect(CleaningVisibility.displaySleepIsBlocked(during: .preparing) == false)
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

    @Test("置頂時關掉那兩顆會讓視窗消失的按鈕")
    func raisedStyleMaskDropsTheVanishingButtons() {
        // 鍵盤鎖底下觸控板還活著，使用者點得到關閉鈕與縮小鈕。視窗一旦消失，
        // 畫面上就沒有狀態可看了，而鍵盤還鎖著，他只能等逾時。
        //
        // 這一項的代價是那兩顆按鈕在清潔模式期間會變灰，也就是視窗的外觀確實
        // 變了一點，跟「外觀不變」有張力。那幾分鐘裡整個 app 本來就不接受操作，
        // 而一顆會讓狀態消失的按鈕跟這一票的目的直接衝突。
        let raised = CleaningVisibility.raisedStyleMask(
            from: [.titled, .closable, .miniaturizable, .resizable]
        )
        #expect(raised.contains(.closable) == false)
        #expect(raised.contains(.miniaturizable) == false)
    }

    @Test("置頂時仍然是一個有標題列的普通視窗")
    func raisedStyleMaskKeepsTheRest() {
        // 拿掉的只有那兩顆按鈕。標題列與其他樣式都留著，視窗看起來還是
        // 同一個視窗（見 #1 的 user story 16）。
        let raised = CleaningVisibility.raisedStyleMask(
            from: [.titled, .closable, .miniaturizable, .resizable]
        )
        #expect(raised.contains(.titled))
        #expect(raised.contains(.resizable))
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
