import Foundation

@testable import Wipe

/// 測試用的機器訊號來源：測試自己說「蓋子現在闔上了」，不需要有手去闔蓋子。
///
/// 這是接縫存在的最好例子。真實那一頭要有一台接著外接螢幕的筆電、一隻手，
/// 還要真的讓機器睡著再叫醒；換成這個替身之後，兩條路徑都只是一次函式呼叫。
@MainActor
final class FakeMachineSignalSource: MachineSignalSource {
    var onSignal: ((MachineSignal) -> Void)?

    /// 現在有沒有在監看。控制器只在清潔中需要機器訊號，其他時候應該放手。
    private(set) var isMonitoring = false

    func start() { isMonitoring = true }

    func stop() { isMonitoring = false }

    /// 送一次機器訊號進去。
    ///
    /// 沒在監看的時候照送不誤，刻意跟真的來源不一樣：這裡要測的是控制器
    /// 自己那道「只有清潔中算數」的關，替身若先幫忙擋掉，那道關就等於沒測。
    func send(_ signal: MachineSignal) {
        onSignal?(signal)
    }

    /// 蓋子闔上了。
    func closeLid() { send(.lidClosed) }

    /// 系統從睡眠喚醒。
    func wake() { send(.systemWoke) }
}
