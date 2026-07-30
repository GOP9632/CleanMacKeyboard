import AppKit
import Testing

@testable import Wipe

/// 鍵盤訊號來源是清潔流程控制器的注入相依之一（見 #1 的實作決策）。
///
/// 這一票只要它能在**不需要任何系統授權**的情況下讀到左右 Command，
/// 而且**不攔截也不修改**任何事件。攔截是另一條路（CGEventTap，見 ADR-0001），
/// 跟這個來源沒有關係。
@Suite("本機鍵盤訊號來源")
@MainActor
struct LocalKeyboardSignalSourceTests {
    private func flagsChanged(_ keyCode: UInt16, _ rawFlags: UInt) throws -> NSEvent {
        try #require(NSEvent.fake(.flagsChanged, keyCode: keyCode, rawFlags: rawFlags))
    }

    @Test("事件原封不動地還回去，不攔截也不修改")
    func passesEventsThrough() throws {
        // 這是本機監看器的合約：回傳同一個事件等於沒有插手。
        // 回傳 nil 才是攔截，而攔截不是這個來源的工作。
        let source = LocalKeyboardSignalSource()
        let event = try flagsChanged(55, KeyboardFlags.leftCommand)

        let returned = source.handle(event)

        #expect(returned === event)
        #expect(returned.modifierFlags.rawValue == KeyboardFlags.leftCommand)
        #expect(returned.keyCode == 55)
    }

    @Test("讀得到左 Command 按下與放開")
    func tracksLeftCommand() throws {
        let source = LocalKeyboardSignalSource()
        #expect(source.signal.leftCommandIsDown == false)

        source.handle(try flagsChanged(55, KeyboardFlags.leftCommand))
        #expect(source.signal.leftCommandIsDown)
        #expect(source.signal.rightCommandIsDown == false)

        source.handle(try flagsChanged(55, KeyboardFlags.nothing))
        #expect(source.signal.leftCommandIsDown == false)
    }

    @Test("讀得到右 Command，而且跟左邊分得開")
    func tracksRightCommand() throws {
        let source = LocalKeyboardSignalSource()

        source.handle(try flagsChanged(54, KeyboardFlags.rightCommand))
        #expect(source.signal.rightCommandIsDown)
        #expect(source.signal.leftCommandIsDown == false)

        source.handle(try flagsChanged(55, KeyboardFlags.bothCommands))
        #expect(source.signal.leftCommandIsDown)
        #expect(source.signal.rightCommandIsDown)
    }

    @Test("夾帶其他修飾鍵時看得出來")
    func tracksOtherModifiers() throws {
        let source = LocalKeyboardSignalSource()

        source.handle(try flagsChanged(55, KeyboardFlags.leftCommand))
        #expect(source.signal.otherModifiersAreDown == false)

        source.handle(try flagsChanged(56, KeyboardFlags.leftCommandWithShift))
        #expect(source.signal.otherModifiersAreDown)
    }

    @Test("其他按鍵按著的時候看得出來")
    func tracksOtherKeys() throws {
        // 解鎖手勢的「出現第三顆按鍵就重新計時」要靠這個訊號（#1 的 user story 26）。
        let source = LocalKeyboardSignalSource()
        #expect(source.signal.otherKeyIsDown == false)

        source.handle(try #require(NSEvent.fake(.keyDown, keyCode: 49, rawFlags: KeyboardFlags.nothing)))
        #expect(source.signal.otherKeyIsDown)

        source.handle(try #require(NSEvent.fake(.keyUp, keyCode: 49, rawFlags: KeyboardFlags.nothing)))
        #expect(source.signal.otherKeyIsDown == false)
    }

    @Test("兩顆按鍵一起按著時，放開其中一顆不算全部放開")
    func tracksEachOtherKeySeparately() throws {
        let source = LocalKeyboardSignalSource()

        source.handle(try #require(NSEvent.fake(.keyDown, keyCode: 49, rawFlags: KeyboardFlags.nothing)))
        source.handle(try #require(NSEvent.fake(.keyDown, keyCode: 50, rawFlags: KeyboardFlags.nothing)))
        source.handle(try #require(NSEvent.fake(.keyUp, keyCode: 49, rawFlags: KeyboardFlags.nothing)))

        #expect(source.signal.otherKeyIsDown)
    }

    @Test("每一次事件都把判讀交出去一次")
    func reportsEveryReading() throws {
        let source = LocalKeyboardSignalSource()
        var readings: [KeyboardEventReading] = []
        source.onReading = { readings.append($0) }

        source.handle(try flagsChanged(55, KeyboardFlags.leftCommand))
        source.handle(try #require(NSEvent.fake(.keyDown, keyCode: 49, rawFlags: KeyboardFlags.leftCommand)))

        #expect(readings.count == 2)
        #expect(readings[0].kind == .modifiersChanged)
        #expect(readings[1].kind == .keyDown)
    }

    @Test("開始監看之後停得下來")
    func startsAndStops() {
        // 測試 process 沒有「輔助使用」授權，所以這裡開得起來本身就說明
        // 本機監看器不需要授權。全域監看器與 CGEventTap 走的是另一條路。
        let source = LocalKeyboardSignalSource()
        #expect(source.isMonitoring == false)

        source.start()
        #expect(source.isMonitoring)

        source.stop()
        #expect(source.isMonitoring == false)
    }

    @Test("裝上監看器之後，真的送進來的事件讀得到")
    func readsEventsThroughTheRealMonitor() throws {
        // 前面的測試都是直接呼叫 handle，繞過了監看器本身。這一個把事件送進
        // AppKit 的派送路徑，確認真正裝上去的那條路也通。
        let source = LocalKeyboardSignalSource()
        source.start()
        defer { source.stop() }

        NSApp.sendEvent(try flagsChanged(55, KeyboardFlags.leftCommand))

        #expect(source.signal.leftCommandIsDown)
        #expect(source.signal.rightCommandIsDown == false)
    }

    @Test("重複呼叫開始不會裝上第二個監看器")
    func startIsIdempotent() {
        let source = LocalKeyboardSignalSource()
        source.start()
        source.start()
        source.stop()

        #expect(source.isMonitoring == false)
    }

    @Test("停止監看之後不記得任何按著的鍵")
    func stopForgetsEverything() throws {
        // 沒有這一步的話，停下來時剛好按著的鍵會一直留在狀態裡。
        let source = LocalKeyboardSignalSource()
        source.start()
        source.handle(try flagsChanged(55, KeyboardFlags.leftCommand))
        source.handle(try #require(NSEvent.fake(.keyDown, keyCode: 49, rawFlags: KeyboardFlags.leftCommand)))

        source.stop()

        #expect(source.signal == .idle)
    }
}
