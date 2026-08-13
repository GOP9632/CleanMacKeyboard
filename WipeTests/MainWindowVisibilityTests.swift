import AppKit
import SwiftUI
import Testing

@testable import Wipe

/// 置頂真的套到一個視窗上，然後真的還原回去。
///
/// `CleaningVisibilityTests` 守的是那幾個值本身，這一組守的是「套上去、拿回來」
/// 這個動作。還原這一段特別值得守：清潔模式期間視窗置頂看得出來對不對，
/// 回到待命之後有沒有還原乾淨看不出來，而沒還原的視窗會從此蓋在所有東西上面。
@Suite("主視窗的置頂與還原")
@MainActor
struct MainWindowVisibilityTests {
    /// 一個不顯示出來的視窗，只拿來被改層級。
    private static func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        return window
    }

    @Test("清潔中把視窗提到置頂層級")
    func raisesTheWindow() {
        let window = Self.makeWindow()
        let coordinator = MainWindowVisibility.Coordinator()

        coordinator.apply(engaged: true, to: window)

        #expect(window.level == CleaningVisibility.raisedWindowLevel)
        #expect(window.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(window.collectionBehavior.contains(.fullScreenAuxiliary))

        coordinator.apply(engaged: false, to: window)
    }

    @Test("回到待命還原成原本那一份")
    func restoresTheWindow() {
        let window = Self.makeWindow()
        let originalLevel = window.level
        let originalBehavior = window.collectionBehavior
        let coordinator = MainWindowVisibility.Coordinator()

        coordinator.apply(engaged: true, to: window)
        coordinator.apply(engaged: false, to: window)

        #expect(window.level == originalLevel)
        #expect(window.collectionBehavior == originalBehavior)
    }

    @Test("重複要求置頂不會把原本那一份弄丟")
    func repeatedRaisesKeepTheOriginal() {
        // 畫面那一層每次階段變動就整組重算一次，同一個狀態會被要求很多次。
        // 第二次進來若又存一次「原本長什麼樣子」，存到的會是已經被改過的那一份，
        // 回到待命就再也還原不回去了。
        let window = Self.makeWindow()
        let originalLevel = window.level
        let originalBehavior = window.collectionBehavior
        let coordinator = MainWindowVisibility.Coordinator()

        coordinator.apply(engaged: true, to: window)
        coordinator.apply(engaged: true, to: window)
        coordinator.apply(engaged: false, to: window)

        #expect(window.level == originalLevel)
        #expect(window.collectionBehavior == originalBehavior)
    }

    @Test("視窗還沒接上的時候不出事")
    func survivesAMissingWindow() {
        // app 剛啟動時那個看不見的視圖還沒進到視窗裡，`window` 是 nil。
        // 那一刻階段一定是待命，所以什麼都不用做，但不可以當掉。
        let coordinator = MainWindowVisibility.Coordinator()
        coordinator.apply(engaged: false, to: nil)
        coordinator.apply(engaged: true, to: nil)
        coordinator.apply(engaged: false, to: nil)
    }

    @Test("掛在 SwiftUI 底下時真的接得到視窗")
    func wiringReachesTheWindow() {
        // 前面那幾項是直接叫 `Coordinator`，繞過了 SwiftUI。這一項守的是中間
        // 那一段：那個看不見的視圖有沒有真的進到視窗裡、階段變了有沒有真的被
        // 重新套用一次。這一段斷掉的話上面每一項都還是綠的，而真機上什麼都
        // 不會發生。
        let window = Self.makeWindow()
        let originalLevel = window.level
        let hosting = NSHostingView(rootView: MainWindowVisibility(stage: .standby))
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        #expect(window.level == originalLevel)

        hosting.rootView = MainWindowVisibility(stage: .cleaning)
        hosting.layoutSubtreeIfNeeded()
        #expect(window.level == CleaningVisibility.raisedWindowLevel)

        hosting.rootView = MainWindowVisibility(stage: .standby)
        hosting.layoutSubtreeIfNeeded()
        #expect(window.level == originalLevel)
    }

    @Test("清潔中不動視窗的大小與位置")
    func leavesTheFrameAlone() {
        // 清潔模式期間主視窗維持原來的樣子和位置，不變形也不隱藏
        // （見 #1 的 user story 16）。
        let window = Self.makeWindow()
        let frame = window.frame
        let styleMask = window.styleMask
        let coordinator = MainWindowVisibility.Coordinator()

        coordinator.apply(engaged: true, to: window)

        #expect(window.frame == frame)
        #expect(window.styleMask == styleMask)

        coordinator.apply(engaged: false, to: window)
    }
}
