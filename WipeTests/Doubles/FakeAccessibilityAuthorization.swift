import Foundation

@testable import Wipe

/// 測試用的輔助使用授權：測試自己說「現在有沒有授權」。
///
/// 真實那一頭要使用者親手去系統設定打勾，而且打完勾之後沒有辦法從程式裡
/// 收回來。換成這個替身之後，「授權完成後自動偵測」這條規則只是兩次函式
/// 呼叫（見 `docs/seams.md`）。
@MainActor
final class FakeAccessibilityAuthorization: AccessibilityAuthorization {
    private(set) var isTrusted: Bool

    /// 被要求帶使用者去系統設定的次數。
    private(set) var openSettingsCount = 0

    init(isTrusted: Bool = false) {
        self.isTrusted = isTrusted
    }

    func openSettings() {
        openSettingsCount += 1
    }

    /// 使用者去系統設定打勾了。
    func grant() {
        isTrusted = true
    }

    /// 使用者把勾拿掉了。
    func revoke() {
        isTrusted = false
    }
}
