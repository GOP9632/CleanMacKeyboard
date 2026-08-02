import AppKit
import Carbon.HIToolbox
import IOKit

/// 真實世界那一頭的安全輸入探測。
///
/// 「現在是不是安全輸入模式」問的是 Carbon 的 `IsSecureEventInputEnabled()`。
/// 這是系統唯一的官方答案，而且便宜到可以每一格問一次。
///
/// 「是哪個 app 造成的」沒有官方 API，只能從 IO 登錄檔挖：`IOConsoleUsers`
/// 裡的每一個登入階段可能帶著一個 `kCGSSessionSecureInputPID`，那就是把
/// 安全輸入模式打開的那個程序。挖不到就挖不到，拒絕照樣成立，只是畫面上
/// 少一句「去關掉哪個 app」。
///
/// 這一整個檔案沒有自動化測試，跟 `SystemMachineSignalSource` 同一個理由：
/// 測試那一頭是 `FakeSecureInputProbe`，這裡剩下的只是問系統
/// （見 `docs/seams.md`）。
@MainActor
final class SystemSecureInputProbe: SecureInputProbe {
    var isSecureInputActive: Bool { IsSecureEventInputEnabled() }

    var responsibleAppName: String? {
        guard let pid = Self.secureInputProcessID() else { return nil }
        // 找不到對應的 app 是正常的：造成安全輸入模式的可能是一個沒有 app
        // 身分的程序，例如 loginwindow。
        return NSRunningApplication(processIdentifier: pid)?.localizedName
    }

    /// 目前把安全輸入模式打開的那個程序。
    ///
    /// 這裡讀的是 IO 登錄檔根節點上的 `IOConsoleUsers`，它是一組登入階段的
    /// 字典。有人打開安全輸入模式時，對應的那個階段裡會多一個
    /// `kCGSSessionSecureInputPID`。
    ///
    /// 鍵名是字串常數，不是編譯期檢查得到的東西，所以整條路徑上每一步都
    /// 允許失敗：查不到就是 `nil`，不會讓 app 掛掉，也不會影響到拒絕本身。
    private static func secureInputProcessID() -> pid_t? {
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        guard root != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(root) }

        let property = IORegistryEntryCreateCFProperty(
            root,
            "IOConsoleUsers" as CFString,
            kCFAllocatorDefault,
            0
        )
        guard let sessions = property?.takeRetainedValue() as? [[String: Any]] else { return nil }

        for session in sessions {
            // 只認大於零的值。放手之後那個鍵可能還留著一個 0，
            // 把 0 當成答案只會多繞一圈去查一個不存在的程序。
            if let pid = session["kCGSSessionSecureInputPID"] as? pid_t, pid > 0 { return pid }
        }
        return nil
    }
}
