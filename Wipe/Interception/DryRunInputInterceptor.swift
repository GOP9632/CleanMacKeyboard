import Foundation

/// 乾跑用的輸入攔截器：記下自己被要求做什麼，但什麼都不做。
///
/// 乾跑是指真的讀鍵盤、真的跑完整個流程，但不真的鎖住鍵盤。開發期間需要它，
/// 否則每改一行程式都要冒著把自己鎖在外面的風險。
///
/// 它不是第二個接縫，只是插在同一個接縫上的另一組替身（見 `docs/seams.md`）。
/// 真正的攔截是 `EventTapInputInterceptor`，換掉的就是這個類別，
/// 控制器一行都不用改。預設走真的攔截，開發建置用啟動參數 `-WipeDryRun YES`
/// 才換回這裡（見 `WipeLaunchOptions`）。
@MainActor
final class DryRunInputInterceptor: InputInterceptor {
    private(set) var activeScope: InterceptionScope?

    /// 乾跑永遠成功。什麼都不做的東西沒有裝不上去的道理，而「裝不上去」
    /// 那條路由真的攔截器負責回報（見 `EventTapInputInterceptor`）。
    func startIntercepting(scope: InterceptionScope) -> Bool {
        activeScope = scope
        return true
    }

    /// 什麼都不做的東西不會被系統停掉，所以它活著與否就只看有沒有人叫它開始。
    func confirmIntercepting() -> Bool { activeScope != nil }

    func stopIntercepting() {
        activeScope = nil
    }
}
