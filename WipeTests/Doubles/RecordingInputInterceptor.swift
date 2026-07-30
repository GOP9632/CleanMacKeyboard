import Foundation

@testable import Wipe

/// 測試用的輸入攔截器：只記下有人叫過它，什麼都不做。
///
/// 這個接縫在測試裡絕對不能用真貨，否則跑測試的那台電腦當場失去鍵盤。
@MainActor
final class RecordingInputInterceptor: InputInterceptor {
    private(set) var activeScope: InterceptionScope?

    /// 每一次被要求開始攔截的範圍，照發生順序。
    private(set) var requestedScopes: [InterceptionScope] = []

    /// 被要求解除的次數。
    private(set) var stopCount = 0

    /// 從頭到現在有沒有被要求攔截過。
    ///
    /// 「取消準備清潔的過程中從未要求攔截」這種測試要的是這個，
    /// 而不是「現在沒在攔截」。
    var wasEverAskedToIntercept: Bool { requestedScopes.isEmpty == false }

    func startIntercepting(scope: InterceptionScope) {
        activeScope = scope
        requestedScopes.append(scope)
    }

    func stopIntercepting() {
        activeScope = nil
        stopCount += 1
    }
}
