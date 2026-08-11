import Foundation
import Observation

/// 事件從輸入攔截器來的鍵盤訊號來源。
///
/// 攔截器在丟掉事件之前先把判讀交給這裡，解鎖手勢才有東西可以判
/// （為什麼需要這條路，見 `docs/seams.md` 的鍵盤訊號來源）。
///
/// 它跟 `LocalKeyboardSignalSource` 插在同一個接縫上，形狀一樣，差別只在
/// 事件從哪裡來。它自己不碰任何系統 API，所以測得到，也不必為了測試
/// 真的裝一個攔截。
@MainActor
@Observable
final class InterceptedKeyboardSignalSource: KeyboardSignalSource {
    private(set) var signal: KeyboardSignal = .idle

    @ObservationIgnored
    var onSignal: ((KeyboardSignal) -> Void)?

    @ObservationIgnored
    var onReading: ((KeyboardEventReading) -> Void)?

    @ObservationIgnored
    private var reader = KeyboardSignalReader()

    /// 現在收不收事件。
    ///
    /// 控制器只在清潔中要鍵盤，其他時候放手。攔截器在準備清潔期間本來就
    /// 還沒裝上去，這個旗標守的是另一件事：攔截先裝好、階段才進到清潔中，
    /// 中間那一小段時間送進來的事件不該算數。
    @ObservationIgnored
    private var isListening = false

    func start() {
        // 每一次開始都從乾淨的狀態出發。上一輪按著的鍵留下來的話，
        // 一進清潔模式就會看到一顆不存在的第三顆按鍵。
        reader.forgetEverything()
        signal = .idle
        isListening = true
    }

    func stop() {
        isListening = false
        reader.forgetEverything()
        signal = .idle
    }

    /// 忘掉目前按著的鍵，但繼續收事件。
    ///
    /// 攔截被系統停掉再接回來的時候要做這件事：空窗期間的事件 Wipe 一個也
    /// 沒看到，使用者在那時放開的鍵會永遠留著，變成一顆壓著不放的幽靈按鍵。
    /// 解鎖手勢碰到第三顆按鍵就歸零，所以留著它等於使用者再也解不開，
    /// 而永遠解不開比誤觸嚴重得多。
    ///
    /// 修飾鍵不必忘：它們每一次事件都從旗標重讀，下一次事件就校正回來了。
    func forgetPressedKeys() {
        reader.forgetEverything()
    }

    /// 攔截器交來一次判讀。
    ///
    /// 每一次事件都交出去一次，即使訊號跟上一次一模一樣：手勢的歸零是一個
    /// 事件而不是一個狀態，只在狀態變了才通知會漏掉按鍵重複
    /// （見 `KeyboardSignalSource.onSignal`）。
    func receive(_ reading: KeyboardEventReading) {
        guard isListening else { return }
        signal = reader.read(reading)
        onSignal?(signal)
        onReading?(reading)
    }
}
