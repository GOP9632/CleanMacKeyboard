import Foundation

/// 只為了定位 bundle 而存在的類別。
private final class WipeBundleAnchor {}

extension Bundle {
    /// 放著 Wipe 顏色與字串資源的 bundle。
    ///
    /// 用類別定位而不是 `Bundle.main`，這樣從測試裡呼叫也一定指到 Wipe.app，
    /// 不會因為測試的執行方式改變而失準。
    static let wipe = Bundle(for: WipeBundleAnchor.self)
}
