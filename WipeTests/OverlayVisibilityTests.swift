import AppKit
import Testing

@testable import Wipe

/// 遮蔽層要在什麼時候出現、長什麼樣子。
///
/// 這一組守的是那幾個純值：哪一個階段加哪一個設定才鋪、視窗層級提到多高、
/// 底色是不是真的不跟隨系統外觀。這幾件事錯了都不會有編譯錯誤，只會安靜地
/// 失效成「使用者選了遮蔽層，畫面上卻什麼都沒發生」，或是更糟的
/// 「淺色模式下鋪出一片亮的，擦螢幕時看不見灰塵」。
///
/// 真的蓋滿每一個外接螢幕只有真機驗得到，那是手動驗收清單的第 4 項。
@Suite("遮蔽層要不要鋪、長什麼樣子")
@MainActor
struct OverlayVisibilityTests {
    @Test("設定選遮蔽層，清潔中才鋪")
    func overlayCoversOnlyWhileCleaning() {
        #expect(OverlayVisibility.isEngaged(during: .cleaning, presentation: .overlay))
    }

    @Test("待命不鋪", arguments: ScreenPresentation.allCases)
    func standbyNeverCovers(_ presentation: ScreenPresentation) {
        // 待命是使用者看最久的畫面，而且什麼都沒鎖。這時候鋪一層黑的
        // 等於把整台電腦關掉。
        #expect(OverlayVisibility.isEngaged(during: .standby, presentation: presentation) == false)
    }

    @Test("準備清潔不鋪", arguments: ScreenPresentation.allCases)
    func preparingNeverCovers(_ presentation: ScreenPresentation) {
        // 這個階段一個事件都還沒攔，使用者隨時可以按 Esc 或再點一次圓環反悔
        // （見 #1 的 user story 6）。鋪上去等於把那兩條反悔的路蓋掉。
        #expect(OverlayVisibility.isEngaged(during: .preparing, presentation: presentation) == false)
    }

    @Test("設定選主視窗，清潔中也不鋪")
    func mainWindowPresentationNeverCovers() {
        #expect(OverlayVisibility.isEngaged(during: .cleaning, presentation: .mainWindow) == false)
    }

    @Test("遮蔽層的層級高過一般 app 用得到的每一個層級")
    func overlayLevelIsAboveEveryOrdinaryLevel() {
        let ordinary: [NSWindow.Level] = [
            .normal, .floating, .submenu, .tornOffMenu, .modalPanel,
            .mainMenu, .statusBar, .popUpMenu,
        ]
        for level in ordinary {
            #expect(
                OverlayVisibility.windowLevel.rawValue > level.rawValue,
                "遮蔽層的層級沒有高過 \(level.rawValue)"
            )
        }
    }

    @Test("遮蔽層跟著每一個 Space 走，也跟得進全螢幕 app")
    func overlayFollowsEverySpace() {
        // 跟主視窗置頂同一個理由：全螢幕 app 各自佔一個 Space，沒有這兩個旗標
        // 的視窗留在原本那個 Space，使用者切過去就看到沒被蓋住的畫面。
        #expect(OverlayVisibility.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(OverlayVisibility.collectionBehavior.contains(.fullScreenAuxiliary))
    }

    @Test("遮蔽層的底色在淺色與深色下是同一個值")
    func backdropIgnoresSystemAppearance() throws {
        // 這是遮蔽層唯一不跟隨系統外觀的理由：它的用途之一是讓使用者看見
        // 螢幕上的灰塵（見 #1 的 user story 20、21）。淺色模式下跟著變亮的話
        // 這個用途就沒了。
        //
        // 其他顏色的規矩相反，每一個都必須有淺色與深色兩個值
        // （見 `WipeColorTests.colorHasBothAppearances`），所以底色刻意不是
        // `WipeColor` 的一個 case。
        let light = try Self.backdrop(in: .aqua)
        let dark = try Self.backdrop(in: .darkAqua)
        #expect(light == dark, "遮蔽層的底色跟著系統外觀變了")
    }

    @Test("遮蔽層的底色夠深，而且不透明", arguments: [NSAppearance.Name.aqua, .darkAqua])
    func backdropIsDarkAndOpaque(_ appearance: NSAppearance.Name) throws {
        let backdrop = try Self.backdrop(in: appearance)
        #expect(backdrop.brightnessComponent < 0.15, "遮蔽層的底色不夠深")
        #expect(backdrop.alphaComponent == 1, "遮蔽層的底色不是不透明的")
    }

    @Test("遮蔽層自己指定深色外觀")
    func overlayForcesDarkAppearance() {
        // 底色是自己畫的，但底色上面那個圓環用的是資源目錄裡有兩個值的顏色。
        // 視窗不指定深色的話，淺色模式下畫上去的會是給白底用的那一份，
        // 在這片黑上對比會不夠。
        #expect(OverlayVisibility.appearanceName == .darkAqua)
    }

    private static func backdrop(in appearanceName: NSAppearance.Name) throws -> NSColor {
        let appearance = try #require(NSAppearance(named: appearanceName))
        var resolved: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            resolved = OverlayVisibility.backdropNSColor?.usingColorSpace(.sRGB)
        }
        return try #require(resolved, "找不到遮蔽層的底色資源")
    }
}
