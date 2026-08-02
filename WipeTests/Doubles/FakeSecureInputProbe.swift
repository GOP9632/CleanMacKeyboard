import Foundation

@testable import Wipe

/// 測試用的安全輸入探測：測試自己說「現在正在安全輸入模式」。
///
/// 真實那一頭要有一個密碼欄位拿到焦點，而且那件事一發生，跑測試的那台電腦
/// 就真的進了安全輸入模式。換成這個替身之後，兩條路徑都只是一次函式呼叫
/// （見 `docs/seams.md`）。
@MainActor
final class FakeSecureInputProbe: SecureInputProbe {
    private(set) var isSecureInputActive = false
    private(set) var responsibleAppName: String?

    /// 安全輸入模式開始了，順便說是誰造成的。
    ///
    /// `appName` 給 `nil` 代表查不出是哪個 app，那是真實世界裡會發生的事：
    /// 有些程序找不到對應的 app 名稱。
    func turnOn(blaming appName: String? = nil) {
        isSecureInputActive = true
        responsibleAppName = appName
    }

    /// 安全輸入模式結束了。
    func turnOff() {
        isSecureInputActive = false
        responsibleAppName = nil
    }
}
