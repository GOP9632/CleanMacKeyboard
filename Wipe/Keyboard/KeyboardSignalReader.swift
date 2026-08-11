import Foundation

/// 把一連串鍵盤判讀累加成鍵盤訊號。
///
/// 兩個真實的鍵盤訊號來源共用這一段：事件從 AppKit 的本機監看器來的
/// （`LocalKeyboardSignalSource`），以及從輸入攔截器來的
/// （`InterceptedKeyboardSignalSource`）。累加規則只有一份，兩條路才不會
/// 對同一組按鍵給出不同的答案。
///
/// 它是純值，沒有回呼也不認得階段：誰該被通知、什麼時候該忘掉，是來源的事。
struct KeyboardSignalReader {
    /// 目前按著的非修飾鍵。
    ///
    /// 用集合而不是一個布林值，是因為兩顆按鍵一起按著時，放開其中一顆
    /// 不算全部放開。
    private var pressedKeyCodes: Set<UInt16> = []

    /// 讀一次判讀，交出那一刻的鍵盤訊號。
    mutating func read(_ reading: KeyboardEventReading) -> KeyboardSignal {
        switch reading.kind {
        case .keyDown: pressedKeyCodes.insert(reading.keyCode)
        case .keyUp: pressedKeyCodes.remove(reading.keyCode)
        case .modifiersChanged: break
        }

        // 左右 Command 與其他修飾鍵每一次都從旗標重讀，不是自己累加出來的。
        // 這樣即使漏收了某一次事件，下一次事件就會把狀態校正回來，
        // 不會一直錯下去。
        return KeyboardSignal(
            leftCommandIsDown: reading.leftCommandIsDown,
            rightCommandIsDown: reading.rightCommandIsDown,
            otherModifiersAreDown: reading.otherModifiersAreDown,
            otherKeyIsDown: pressedKeyCodes.isEmpty == false
        )
    }

    /// 忘掉所有按著的鍵。
    ///
    /// 停止監看時一定要做：不然停下來的那一刻剛好按著的鍵會一直留在狀態裡，
    /// 下一次開始就從一個不存在的按鍵開始。
    mutating func forgetEverything() {
        pressedKeyCodes = []
    }
}
