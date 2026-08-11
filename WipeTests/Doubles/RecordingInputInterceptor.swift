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

    /// 接下來被要求攔截時裝不裝得上去。
    ///
    /// 真實世界裡「授權給了但攔截還是建立不起來」是會發生的
    /// （見 `InterceptionUnavailableTests`）。這個旗標就是測試表達那件事的方式。
    private var canIntercept = true

    /// 從頭到現在有沒有被要求攔截過。
    ///
    /// 「取消準備清潔的過程中從未要求攔截」這種測試要的是這個，
    /// 而不是「現在沒在攔截」。
    var wasEverAskedToIntercept: Bool { requestedScopes.isEmpty == false }

    func startIntercepting(scope: InterceptionScope) -> Bool {
        // 失敗的時候照樣記下「有人叫過我」。控制器確實要求了攔截，
        // 只是沒裝上去，這兩件事在測試裡要分得開。
        requestedScopes.append(scope)
        guard canIntercept else { return false }
        activeScope = scope
        return true
    }

    func confirmIntercepting() -> Bool { activeScope != nil }

    func stopIntercepting() {
        activeScope = nil
        stopCount += 1
    }

    /// 裝上去的攔截跑到一半死掉。
    ///
    /// 真實世界裡這會發生：系統把攔截停掉、授權在清潔中被收回。
    /// 測試用這個表達「事件從現在起不再進到 Wipe 手上」。
    func loseInterception() { activeScope = nil }

    /// 接下來的攔截都裝不上去。
    func breakInterception() { canIntercept = false }

    /// 攔截又裝得上去了。
    func fixInterception() { canIntercept = true }
}
