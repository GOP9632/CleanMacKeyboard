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

    /// 兩顆 Command 都按著，而且沒有夾帶其他修飾鍵。
    ///
    /// 這是解鎖手勢開始計時的條件。第三顆按鍵刻意不在這裡：那一條是以
    /// 「按下」為觸發的歸零，不是持續成立的條件（見 `UnlockGesture`）。
    var isHoldingBothCommands: Bool {
        leftCommandIsDown && rightCommandIsDown && otherModifiersAreDown == false
    }
}

/// 清潔流程控制器的鍵盤訊號來源。
///
/// 這是控制器的注入相依之一，所以測試可以塞進一個假的來源，不需要真鍵盤。
/// 它**只讀不攔**：攔截是輸入攔截器的工作，走的是另一條路（見 ADR-0001）。
@MainActor
protocol KeyboardSignalSource: AnyObject {
    /// 目前的鍵盤狀態。
    var signal: KeyboardSignal { get }

    /// 每一次鍵盤事件都會被呼叫一次，帶著那一刻的狀態。
    ///
    /// 控制器走的是這條路而不是自己定期去讀 `signal`，因為解鎖手勢的「出現
    /// 第三顆按鍵就重新計時」是一個**事件**，不是一個狀態：一顆被壓著不動的鍵
    /// 只該歸零一次。定期讀狀態的話，那顆鍵只要壓著就會一直歸零，
    /// 使用者會永遠解不開（見 `UnlockGesture`）。
    var onSignal: ((KeyboardSignal) -> Void)? { get set }

    /// 每一次鍵盤事件都會被呼叫一次，帶著那次事件的原始判讀。
    ///
    /// 控制器本身只需要 `signal`，這條路是給診斷用的：要回答
    /// 「左右 Command 分不分得開」，光看結論不夠，還要看得到旗標原始值。
    var onReading: ((KeyboardEventReading) -> Void)? { get set }

    func start()
    func stop()
}
