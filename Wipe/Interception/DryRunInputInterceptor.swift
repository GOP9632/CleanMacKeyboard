import Foundation

/// 乾跑用的輸入攔截器：記下自己被要求做什麼，但什麼都不做。
///
/// 乾跑是指真的讀鍵盤、真的跑完整個流程，但不真的鎖住鍵盤。開發期間需要它，
/// 否則每改一行程式都要冒著把自己鎖在外面的風險。
///
/// 它不是第二個接縫，只是插在同一個接縫上的另一組替身（見 `docs/seams.md`）。
/// 真正的攔截是 #11 與 #12，換掉的是這個類別，控制器一行都不用改。
@MainActor
final class DryRunInputInterceptor: InputInterceptor {
    private(set) var activeScope: InterceptionScope?

    /// 乾跑永遠成功。什麼都不做的東西沒有裝不上去的道理，而「裝不上去」
    /// 那條路在真的攔截接上來之前不需要有人假裝（見 #11）。
    func startIntercepting(scope: InterceptionScope) -> Bool {
        activeScope = scope
        return true
    }

    func stopIntercepting() {
        activeScope = nil
    }
}
