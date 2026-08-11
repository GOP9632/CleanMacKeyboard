import AppKit
import ApplicationServices

/// 真實世界那一頭的輔助使用授權。
///
/// 「現在有沒有」問的是 `AXIsProcessTrusted()`，那是系統唯一的官方答案。
///
/// 這裡只問「輔助使用」。#1 提到部分情況另需「輸入監控」，但那個授權要不要、
/// 什麼時候要，只有真的去建立 event tap 之後才知道，所以留給 #11。
///
/// 這一整個檔案沒有自動化測試，跟 `SystemSecureInputProbe` 同一個理由：
/// 測試那一頭是 `FakeAccessibilityAuthorization`，這裡剩下的只是問系統與
/// 開一個 URL（見 `docs/seams.md`）。授權流程完整走一遍是手動驗收清單
/// 第 5 項。
@MainActor
final class SystemAccessibilityAuthorization: AccessibilityAuthorization {
    var isTrusted: Bool { AXIsProcessTrusted() }

    func openSettings() {
        // 先送出一次系統的授權請求。重點不是它的回傳值，是它的副作用：
        // macOS 會把 Wipe 登記進「輔助使用」那份清單。少了這一步，使用者
        // 到了那一頁可能會找不到 Wipe，只剩下自己把 app 拖進去這條路，
        // 而這個畫面存在的理由正是不要讓使用者卡在這裡。
        //
        // 它同時會讓 macOS 自己彈一個對話框。那個對話框的語言跟隨系統設定，
        // Wipe 控制不了，所以引導畫面自己也要把話講完整，不能指望它。
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
        guard let url = Self.settingsURL else { return }
        NSWorkspace.shared.open(url)
    }

    /// 系統設定裡「隱私權與安全性 › 輔助使用」那一頁。
    ///
    /// 這是一個字串，不是編譯期檢查得到的東西，所以組不出來就安靜地不開。
    /// 那時使用者手上還有系統自己彈出來的那個對話框，路沒有斷。
    private static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )
}
