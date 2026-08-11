import CoreGraphics
import Testing

@testable import Wipe

/// 真的攔截起來之後，鍵盤事件不會再送到 Wipe 自己身上：攔截器把它們丟掉了，
/// 本機監看器一個也收不到。解鎖手勢要繼續有效，訊號就只能來自攔截器手上的
/// 那個 `CGEvent`（見 `docs/seams.md` 的鍵盤訊號來源）。
///
/// 所以這一組測試守的是：判讀從 `CGEvent` 那一頭讀出來的時候，分左右的低位元
/// 沒有在轉換途中被弄丟，keyCode 也是從對的欄位讀的。期望值用的是
/// `KeyboardFlags`，那組值在 #3 已經對著真鍵盤驗過。
///
/// 它**不能**回答「真的鍵盤送進攔截器的值長不長這樣」：事件是測試自己合成的。
/// 那一條跟 #3 一樣只有真機驗得到，而它是整個解鎖手勢的單點依賴。
@Suite("被攔截下來的事件的判讀")
struct InterceptedKeyboardReadingTests {
    @Test("左 Command 的位元在 CGEvent 上讀得到")
    func readsLeftCommand() throws {
        let event = try #require(
            CGEvent.fake(
                keyCode: KeyboardEventReading.leftCommandKeyCode,
                rawFlags: KeyboardFlags.leftCommand
            )
        )

        let reading = try #require(KeyboardEventReading(event, type: .flagsChanged))

        #expect(reading.kind == .modifiersChanged)
        #expect(reading.rawFlags == KeyboardFlags.leftCommand)
        #expect(reading.keyCode == KeyboardEventReading.leftCommandKeyCode)
        #expect(reading.leftCommandIsDown)
        #expect(reading.rightCommandIsDown == false)
    }

    @Test("右 Command 跟左邊分得開")
    func readsRightCommandSeparately() throws {
        let event = try #require(
            CGEvent.fake(
                keyCode: KeyboardEventReading.rightCommandKeyCode,
                rawFlags: KeyboardFlags.rightCommand
            )
        )

        let reading = try #require(KeyboardEventReading(event, type: .flagsChanged))

        #expect(reading.rightCommandIsDown)
        #expect(reading.leftCommandIsDown == false)
    }

    @Test("按下與放開分得出來")
    func readsKeyDownAndKeyUp() throws {
        let event = try #require(CGEvent.fake(keyCode: 49, rawFlags: KeyboardFlags.nothing))

        #expect(KeyboardEventReading(event, type: .keyDown)?.kind == .keyDown)
        #expect(KeyboardEventReading(event, type: .keyUp)?.kind == .keyUp)
    }

    @Test("不是鍵盤事件就沒有判讀")
    func ignoresNonKeyboardEvents() throws {
        // 全輸入鎖底下攔截器也會收到滑鼠事件。那些事件照樣要被丟掉，
        // 但它們不帶任何解鎖手勢需要的訊息。
        let event = try #require(CGEvent.fake(keyCode: 49, rawFlags: KeyboardFlags.nothing))

        #expect(KeyboardEventReading(event, type: .mouseMoved) == nil)
    }
}
