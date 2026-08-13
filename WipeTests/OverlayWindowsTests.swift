import AppKit
import Testing

@testable import Wipe

/// 遮蔽層真的鋪出去，然後真的收回來。
///
/// `OverlayVisibilityTests` 守的是那幾個值本身，這一組守的是「鋪上去、收回來」
/// 這個動作。收回來這一段特別值得守：清潔模式期間有沒有鋪看得出來，回到待命
/// 之後有沒有收乾淨看不出來，而沒收乾淨的遮蔽層是一片蓋住整台電腦的黑，
/// 使用者只能強制結束 Wipe。
///
/// 螢幕清單從外面給，所以插拔外接螢幕這件事測得到，不需要真的插拔。真的蓋滿
/// 每一個外接螢幕仍然只有真機驗得到，那是手動驗收清單的第 4 項。
///
/// 這一組會在畫面上短暫閃出幾個小視窗，那是真的 `NSWindow`。刻意用小方框而
/// 不是整個螢幕的尺寸，測試跑起來才不會遮住開發者的畫面。
@Suite("遮蔽層的鋪上與收回")
@MainActor
struct OverlayWindowsTests {
    /// 假裝是螢幕的幾塊小方框。
    private static let oneScreen = [CGRect(x: 0, y: 0, width: 120, height: 80)]
    private static let twoScreens = oneScreen + [CGRect(x: 200, y: 0, width: 100, height: 60)]

    private static func makeWindows() -> OverlayWindows {
        OverlayWindows { NSView(frame: .zero) }
    }

    @Test("鋪的時候每一塊螢幕各一個視窗，位置對得上")
    func coversEveryScreen() {
        let overlay = Self.makeWindows()

        overlay.synchronize(with: Self.twoScreens)

        #expect(overlay.windows.map(\.frame) == Self.twoScreens)
        overlay.synchronize(with: [])
    }

    @Test("收回來一個都不留")
    func removesEveryWindow() {
        let overlay = Self.makeWindows()
        overlay.synchronize(with: Self.twoScreens)
        let opened = overlay.windows

        overlay.synchronize(with: [])

        #expect(overlay.windows.isEmpty)
        for window in opened {
            #expect(window.isVisible == false, "收回來之後視窗還在畫面上")
        }
    }

    @Test("重複要求同一組螢幕不會越開越多")
    func repeatedSynchronizeKeepsTheSameWindows() {
        // 清潔中主視窗每一格都在重畫（環上的按住進度會動），這裡一秒會被叫
        // 三十次左右。每一次都重建的話，畫面會閃成一片。
        let overlay = Self.makeWindows()

        overlay.synchronize(with: Self.oneScreen)
        let first = overlay.windows
        overlay.synchronize(with: Self.oneScreen)

        #expect(overlay.windows.count == 1)
        #expect(overlay.windows.first === first.first, "同一組螢幕卻把視窗重建了")
        overlay.synchronize(with: [])
    }

    @Test("插上一個螢幕就多鋪一塊，原本那塊留著")
    func addsAWindowForANewScreen() {
        let overlay = Self.makeWindows()
        overlay.synchronize(with: Self.oneScreen)
        let first = overlay.windows.first

        overlay.synchronize(with: Self.twoScreens)

        #expect(overlay.windows.map(\.frame) == Self.twoScreens)
        #expect(overlay.windows.first === first, "多一個螢幕就把原本那塊重建了")
        overlay.synchronize(with: [])
    }

    @Test("拔掉一個螢幕就收掉多的那一塊")
    func removesTheWindowOfAGoneScreen() {
        let overlay = Self.makeWindows()
        overlay.synchronize(with: Self.twoScreens)
        let extra = overlay.windows.last

        overlay.synchronize(with: Self.oneScreen)

        #expect(overlay.windows.map(\.frame) == Self.oneScreen)
        #expect(extra?.isVisible == false, "拔掉的那個螢幕的視窗還在")
        overlay.synchronize(with: [])
    }

    @Test("螢幕挪了位置，鋪著的那塊跟著挪過去")
    func followsAMovedScreen() {
        // 使用者在系統設定裡把外接螢幕拖到另一邊，或是換了解析度，螢幕的
        // frame 會變。沒跟著挪的話，那個螢幕會露出一角沒被蓋到。
        let overlay = Self.makeWindows()
        overlay.synchronize(with: Self.oneScreen)
        let moved = [CGRect(x: 500, y: 300, width: 160, height: 90)]

        overlay.synchronize(with: moved)

        #expect(overlay.windows.map(\.frame) == moved)
        overlay.synchronize(with: [])
    }

    @Test("鋪出去的是一個沒有邊框、不透明、蓋在最上面的深色視窗")
    func theWindowLooksRight() throws {
        let overlay = Self.makeWindows()
        overlay.synchronize(with: Self.oneScreen)
        let window = try #require(overlay.windows.first)

        #expect(window.level == OverlayVisibility.windowLevel)
        #expect(window.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(window.collectionBehavior.contains(.fullScreenAuxiliary))
        #expect(window.styleMask.contains(.titled) == false, "遮蔽層帶著標題列")
        #expect(window.isOpaque, "遮蔽層是半透明的，底下的東西看得見")
        #expect(window.appearance?.name == OverlayVisibility.appearanceName)
        // 遮蔽層的第二個用途是在輸入攔截失效時擋下誤點（見 `CONTEXT.md`）。
        // 忽略滑鼠事件的話，點擊會直接穿過去按到底下的東西。
        #expect(window.ignoresMouseEvents == false, "誤點會穿過遮蔽層")

        overlay.synchronize(with: [])
    }

    @Test("遮蔽層不會把鍵盤焦點搶走")
    func theWindowNeverBecomesKey() throws {
        // 搶走焦點的話，主視窗上那顆 Esc 的快捷鍵就失效了。清潔中它本來就
        // 用不到，但遮蔽層收回來之後焦點要回得去。
        let overlay = Self.makeWindows()
        overlay.synchronize(with: Self.oneScreen)
        let window = try #require(overlay.windows.first)

        #expect(window.canBecomeKey == false)

        overlay.synchronize(with: [])
    }

    @Test("鋪著的那塊被壓到底下去了，下一次對齊會把它叫回最上面")
    func bringsAnOrderedOutWindowBack() {
        // 「已經鋪著」跟「已經鋪著而且真的在最上面」是兩件事。這一層保證的是
        // 後者，所以每一次對齊都重新叫一遍，即使螢幕清單一個字都沒變。
        let overlay = Self.makeWindows()
        overlay.synchronize(with: Self.oneScreen)
        overlay.windows.first?.orderOut(nil)

        overlay.synchronize(with: Self.oneScreen)

        #expect(overlay.windows.first?.isVisible == true, "被壓下去之後就再也浮不上來了")
        overlay.synchronize(with: [])
    }

    @Test("真的鋪出去的時候蓋的是真的每一個螢幕")
    func engagingCoversTheRealScreens() {
        // 前面幾項給的都是假裝是螢幕的小方框，繞過了「螢幕清單從哪裡來」。
        // 這一項守的就是那一段：接錯的話上面每一項都還是綠的，而真機上
        // 會有螢幕沒被蓋到。
        let overlay = Self.makeWindows()
        overlay.setEngaged(true)

        #expect(overlay.windows.count == NSScreen.screens.count)
        #expect(overlay.windows.map(\.frame) == NSScreen.screens.map(\.frame))

        overlay.setEngaged(false)
        #expect(overlay.windows.isEmpty)
    }
}
