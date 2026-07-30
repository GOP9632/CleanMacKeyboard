import AppKit
import Testing

@testable import Wipe

/// 測試跑在 Wipe.app 自己的 process 裡，所以這裡看到的選單與視窗就是使用者
/// 會看到的那一份。
@Suite("app 外殼")
@MainActor
struct AppShellTests {
    @Test("Cmd + , 打得開設定")
    func settingsShortcutExists() throws {
        let mainMenu = try #require(NSApp.mainMenu)
        let item = Self.firstItem(in: mainMenu) {
            $0.keyEquivalent == "," && $0.keyEquivalentModifierMask == [.command]
        }
        #expect(item != nil, "選單裡找不到 Cmd + , 的項目")
    }

    @Test("是一個普通 app，不是選單列常駐程式")
    func isRegularApp() {
        // 這一版沒有選單列常駐圖示，只有一個普通 app 視窗。
        #expect(NSApp.activationPolicy() == .regular)
    }

    @Test("有一個普通的標題列視窗")
    func hasOneOrdinaryWindow() {
        let ordinaryWindows = NSApp.windows.filter { $0.styleMask.contains(.titled) }
        #expect(ordinaryWindows.isEmpty == false)
    }

    private static func firstItem(in menu: NSMenu, where predicate: (NSMenuItem) -> Bool) -> NSMenuItem? {
        for item in menu.items {
            if predicate(item) { return item }
            if let submenu = item.submenu,
               let found = firstItem(in: submenu, where: predicate) {
                return found
            }
        }
        return nil
    }
}
