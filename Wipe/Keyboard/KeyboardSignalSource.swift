import Foundation

/// 鍵盤在某一瞬間的狀態，是鍵盤訊號來源對外的全部內容。
///
/// 解鎖手勢需要的四件事都在這裡：左右 Command 各自的按放狀態、是否夾帶
/// 其他修飾鍵、是否有其他按鍵按下（見 #1 的實作決策）。
struct KeyboardSignal: Equatable {
    var leftCommandIsDown = false
    var rightCommandIsDown = false
    var otherModifiersAreDown = false
    var otherKeyIsDown = false

    /// 什麼都沒按。
    static let idle = KeyboardSignal()
}

/// 清潔流程控制器的鍵盤訊號來源。
///
/// 這是控制器的注入相依之一，所以測試可以塞進一個假的來源，不需要真鍵盤。
/// 它**只讀不攔**：攔截是輸入攔截器的工作，走的是另一條路（見 ADR-0001）。
@MainActor
protocol KeyboardSignalSource: AnyObject {
    /// 目前的鍵盤狀態。
    var signal: KeyboardSignal { get }

    /// 每一次鍵盤事件都會被呼叫一次，帶著那次事件的原始判讀。
    ///
    /// 控制器本身只需要 `signal`，這條路是給診斷用的：要回答
    /// 「左右 Command 分不分得開」，光看結論不夠，還要看得到旗標原始值。
    var onReading: ((KeyboardEventReading) -> Void)? { get set }

    func start()
    func stop()
}
