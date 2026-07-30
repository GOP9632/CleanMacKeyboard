import Foundation

/// 清潔模式要攔截哪些輸入裝置。
enum InterceptionScope: String, CaseIterable, Equatable {
    /// 鍵盤鎖：只攔截鍵盤，觸控板與滑鼠仍然可用。
    ///
    /// 這是預設值。留著滑鼠是刻意的：萬一解鎖手勢失靈，使用者還有一條
    /// 非鍵盤的求救路徑。
    case keyboard

    /// 全輸入鎖：連觸控板與滑鼠（含游標移動）一起攔截。
    ///
    /// 防護完整，代價是沒有滑鼠可以求救，所以逾時解鎖與闔蓋解鎖在這個範圍
    /// 底下更重要。
    case allInput
}

/// 清潔流程控制器的輸入攔截器。
///
/// 這是唯一一個**測試裡絕對不能用真貨**的接縫：真的攔截了，跑測試的那台
/// 電腦就當場沒有鍵盤。控制器只認得這個形狀，不知道另一頭是 CGEventTap
/// 還是一個什麼都不做的替身，所以乾跑模式不需要第二個接縫
/// （見 `docs/seams.md`）。
@MainActor
protocol InputInterceptor: AnyObject {
    /// 目前正在攔截的範圍。`nil` 代表沒有在攔截。
    var activeScope: InterceptionScope? { get }

    /// 以指定範圍開始攔截。
    func startIntercepting(scope: InterceptionScope)

    /// 解除攔截。
    ///
    /// 重複呼叫必須是安全的：控制器寧可多解一次，也不要漏解一次。
    func stopIntercepting()
}
