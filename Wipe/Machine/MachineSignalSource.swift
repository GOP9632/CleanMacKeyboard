import Foundation

/// 機器層級的訊號，是機器訊號來源對外的全部內容。
///
/// 兩個都是闔蓋解鎖的訊號。蓋子是主要的，睡眠喚醒是次要的：接上外接螢幕
/// 與電源時闔蓋不會睡眠，只監聽睡眠的話，保險會剛好在使用者最需要它的
/// 場合失效（見 #1 的實作決策）。
enum MachineSignal: String, CaseIterable, Equatable {
    /// 螢幕蓋子從開著變成闔上。
    case lidClosed

    /// 系統從睡眠喚醒。
    case systemWoke
}

/// 清潔流程控制器的機器訊號來源。
///
/// 這是控制器的注入相依之一，所以測試可以直接說「蓋子現在闔上了」，
/// 不需要有一隻手去闔蓋子，也不需要真的讓機器睡著（見 `docs/seams.md`）。
///
/// 它刻意**不**提供「蓋子現在是開還是闔」這個狀態，只送事件。理由是清潔模式
/// 認的是「闔上」這個動作，不是「闔著」這個狀態：接著外接螢幕闔蓋使用的
/// 使用者，蓋子本來就一直是闔著的，若認狀態，他永遠進不了清潔模式。
///
/// 同一個理由決定了 `start()` 的起點：開始監看的那一刻蓋子是什麼狀態就當成
/// 起點，之後變成闔上才算一次（見 `LidCloseDetector`）。
@MainActor
protocol MachineSignalSource: AnyObject {
    /// 每一次機器訊號都會被呼叫一次。
    var onSignal: ((MachineSignal) -> Void)? { get set }

    func start()
    func stop()
}
