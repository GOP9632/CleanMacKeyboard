import Testing

@testable import Wipe

/// 清潔模式期間的鍵盤訊號來源。
///
/// 攔截一旦真的裝上去，鍵盤事件就不會再送到 Wipe 自己身上，本機監看器
/// 一個也收不到。解鎖手勢要繼續有效，訊號就得從攔截器手上那條路進來，
/// 而這個來源就是那條路的終點（見 `docs/seams.md` 的鍵盤訊號來源）。
///
/// 它跟 `LocalKeyboardSignalSource` 插在同一個接縫上，形狀一樣，
/// 差別只在事件從哪裡來：一個從 AppKit 的本機監看器，一個從攔截器。
@Suite("被攔截下來的鍵盤訊號來源")
@MainActor
struct InterceptedKeyboardSignalSourceTests {
    @Test("讀得到左右 Command，而且分得開")
    func tracksBothCommandsSeparately() {
        let source = InterceptedKeyboardSignalSource()
        source.start()

        source.receive(makeReading(KeyboardFlags.leftCommand))
        #expect(source.signal.leftCommandIsDown)
        #expect(source.signal.rightCommandIsDown == false)

        source.receive(makeReading(KeyboardFlags.bothCommands))
        #expect(source.signal.isHoldingBothCommands)
    }

    @Test("其他按鍵按著的時候看得出來")
    func tracksOtherKeys() {
        // 解鎖手勢的「出現第三顆按鍵就重新計時」要靠這個訊號。
        let source = InterceptedKeyboardSignalSource()
        source.start()

        source.receive(makeReading(KeyboardFlags.bothCommands, keyCode: 49, kind: .keyDown))
        #expect(source.signal.otherKeyIsDown)

        source.receive(makeReading(KeyboardFlags.bothCommands, keyCode: 49, kind: .keyUp))
        #expect(source.signal.otherKeyIsDown == false)
    }

    @Test("兩顆按鍵一起按著時，放開其中一顆不算全部放開")
    func tracksEachOtherKeySeparately() {
        let source = InterceptedKeyboardSignalSource()
        source.start()

        source.receive(makeReading(KeyboardFlags.nothing, keyCode: 49, kind: .keyDown))
        source.receive(makeReading(KeyboardFlags.nothing, keyCode: 50, kind: .keyDown))
        source.receive(makeReading(KeyboardFlags.nothing, keyCode: 49, kind: .keyUp))

        #expect(source.signal.otherKeyIsDown)
    }

    @Test("每一次事件都交出去一次，即使狀態跟上一次一樣")
    func reportsEveryEvent() {
        // 手勢的歸零是一個事件，不是一個狀態：一顆被壓著不動的鍵每重複一次
        // 就該交出去一次（見 `KeyboardSignalSource.onSignal`）。
        let source = InterceptedKeyboardSignalSource()
        source.start()
        var signals: [KeyboardSignal] = []
        var readings: [KeyboardEventReading] = []
        source.onSignal = { signals.append($0) }
        source.onReading = { readings.append($0) }

        source.receive(makeReading(KeyboardFlags.bothCommands, keyCode: 49, kind: .keyDown))
        source.receive(makeReading(KeyboardFlags.bothCommands, keyCode: 49, kind: .keyDown))

        #expect(signals.count == 2)
        #expect(readings.count == 2)
    }

    @Test("還沒開始之前收到的事件不算數")
    func ignoresEventsBeforeStart() {
        // 控制器只在清潔中才要鍵盤。進到清潔中之前按著什麼都不算，
        // 否則剛好按著兩顆 Command 進來的人會立刻解開。
        let source = InterceptedKeyboardSignalSource()
        var signals: [KeyboardSignal] = []
        source.onSignal = { signals.append($0) }

        source.receive(makeReading(KeyboardFlags.bothCommands))

        #expect(signals.isEmpty)
        #expect(source.signal == .idle)
    }

    @Test("攔截斷過一次之後，按著的鍵重新算起")
    func forgettingPressedKeysClearsGhosts() {
        // 攔截被系統停掉的那段空窗裡，事件照常送到其他 app，Wipe 一個也沒看到。
        // 使用者在那段時間放開的鍵會永遠留著，變成一顆壓著不放的幽靈按鍵，
        // 而第三顆按鍵會讓解鎖手勢每一次都歸零，也就是使用者再也解不開。
        let source = InterceptedKeyboardSignalSource()
        source.start()
        source.receive(makeReading(KeyboardFlags.nothing, keyCode: 49, kind: .keyDown))
        #expect(source.signal.otherKeyIsDown)

        source.forgetPressedKeys()
        source.receive(makeReading(KeyboardFlags.bothCommands))

        #expect(source.signal.otherKeyIsDown == false)
        #expect(source.signal.isHoldingBothCommands)
    }

    @Test("忘掉按著的鍵之後照樣繼續收事件")
    func forgettingPressedKeysDoesNotStopListening() {
        // 忘掉幽靈按鍵不等於放手。清潔模式還在，手勢也還要判。
        let source = InterceptedKeyboardSignalSource()
        source.start()
        var signals: [KeyboardSignal] = []
        source.onSignal = { signals.append($0) }

        source.forgetPressedKeys()
        source.receive(makeReading(KeyboardFlags.leftCommand))

        #expect(signals.count == 1)
    }

    @Test("停下來之後不記得任何按著的鍵，也不再交出任何事件")
    func stopForgetsEverything() {
        let source = InterceptedKeyboardSignalSource()
        source.start()
        source.receive(makeReading(KeyboardFlags.bothCommands, keyCode: 49, kind: .keyDown))
        var signals: [KeyboardSignal] = []
        source.onSignal = { signals.append($0) }

        source.stop()
        source.receive(makeReading(KeyboardFlags.bothCommands))

        #expect(source.signal == .idle)
        #expect(signals.isEmpty)
    }

    @Test("再開始一次時，上一輪按著的鍵不會留下來")
    func restartingStartsClean() {
        let source = InterceptedKeyboardSignalSource()
        source.start()
        source.receive(makeReading(KeyboardFlags.nothing, keyCode: 49, kind: .keyDown))
        source.stop()

        source.start()
        source.receive(makeReading(KeyboardFlags.bothCommands))

        #expect(source.signal.otherKeyIsDown == false)
        #expect(source.signal.isHoldingBothCommands)
    }
}
