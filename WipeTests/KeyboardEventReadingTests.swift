import AppKit
import Testing

@testable import Wipe

/// 這一票要回答的問題就在這裡：左 Command 和右 Command 分不分得開。
///
/// 判讀本身是純函式，所以先在這裡把每一種旗標組合釘死，真機驗證只需要確認
/// 「真的鍵盤送出來的旗標值」跟 `KeyboardFlags` 假設的一樣。
@Suite("修飾鍵旗標的判讀")
struct KeyboardEventReadingTests {
    @Test("按左 Command 只有左邊為真")
    func leftCommand() {
        let left = makeReading(KeyboardFlags.leftCommand)
        #expect(left.leftCommandIsDown)
        #expect(left.rightCommandIsDown == false)
    }

    @Test("按右 Command 只有右邊為真")
    func rightCommand() {
        let right = makeReading(
            KeyboardFlags.rightCommand,
            keyCode: KeyboardEventReading.rightCommandKeyCode
        )
        #expect(right.leftCommandIsDown == false)
        #expect(right.rightCommandIsDown)
    }

    @Test("兩顆一起按時兩邊都為真")
    func bothCommands() {
        let both = makeReading(KeyboardFlags.bothCommands)
        #expect(both.leftCommandIsDown)
        #expect(both.rightCommandIsDown)
    }

    @Test("全部放開時兩邊都為假")
    func nothingDown() {
        let none = makeReading(KeyboardFlags.nothing)
        #expect(none.leftCommandIsDown == false)
        #expect(none.rightCommandIsDown == false)
    }

    @Test("左右 Command 的判讀不會互相污染")
    func sidesAreIndependent() {
        // 這是整個解鎖手勢的單點依賴：兩個旗標位元必須真的是兩個位元。
        #expect(KeyboardEventReading.leftCommandMask != KeyboardEventReading.rightCommandMask)
        #expect(KeyboardEventReading.leftCommandMask & KeyboardEventReading.rightCommandMask == 0)
    }

    @Test("Caps Lock 不算夾帶其他修飾鍵")
    func capsLockIsNotAnotherModifier() {
        // 見 #1 的 user story 33：Caps Lock 開著的使用者照樣要解得開。
        let withCapsLock = makeReading(KeyboardFlags.leftCommandWithCapsLock)
        #expect(withCapsLock.leftCommandIsDown)
        #expect(withCapsLock.otherModifiersAreDown == false)
    }

    @Test("fn 與數字鍵台的位元不算夾帶其他修飾鍵")
    func systemAddedModifiersAreNotCounted() {
        // macOS 會替方向鍵一類的按鍵自己附上這兩個位元，不是使用者按的。
        let withFunctionKeys = makeReading(KeyboardFlags.leftCommandWithFunctionKeys)
        #expect(withFunctionKeys.leftCommandIsDown)
        #expect(withFunctionKeys.otherModifiersAreDown == false)
    }

    @Test("Shift 算夾帶其他修飾鍵")
    func shiftIsAnotherModifier() {
        let withShift = makeReading(KeyboardFlags.leftCommandWithShift)
        #expect(withShift.leftCommandIsDown)
        #expect(withShift.otherModifiersAreDown)
    }

    @Test("只按 Command 不算夾帶其他修飾鍵")
    func commandAloneIsClean() {
        #expect(makeReading(KeyboardFlags.bothCommands).otherModifiersAreDown == false)
    }

    @Test("原始旗標值以十六進位呈現，方便貼回票上")
    func rawFlagsAreReadable() {
        #expect(makeReading(KeyboardFlags.leftCommand).rawFlagsText == "0x00100108")
        #expect(makeReading(KeyboardFlags.nothing).rawFlagsText == "0x00000100")
    }

    @Test("認得左右 Command 的 keyCode")
    func commandKeyCodes() {
        #expect(KeyboardEventReading.leftCommandKeyCode == 55)
        #expect(KeyboardEventReading.rightCommandKeyCode == 54)
    }

    @Test("一行紀錄帶著旗標值、keyCode 與左右判讀")
    func diagnosticTextCarriesEverythingTheTicketAsksFor() {
        // #3 的驗收條件：紀錄要顯示原始修飾鍵旗標值、keyCode，以及左右各自的判讀。
        let line = makeReading(KeyboardFlags.leftCommand).diagnosticText

        #expect(line.contains("flagsChanged"))
        #expect(line.contains("keyCode  55"))
        #expect(line.contains("raw 0x00100108"))
        #expect(line.contains("L=down"))
        #expect(line.contains("R=up"))
    }

    @Test("左右兩邊的欄位一樣寬，整段貼出去對得齊")
    func diagnosticTextIsAligned() {
        let left = makeReading(KeyboardFlags.leftCommand).diagnosticText
        let right = makeReading(
            KeyboardFlags.rightCommand,
            keyCode: KeyboardEventReading.rightCommandKeyCode
        ).diagnosticText

        #expect(left.count == right.count)
    }

    @Test("修飾鍵事件轉得出判讀，旗標值與 keyCode 原封不動")
    func readsAModifierEvent() throws {
        let event = try #require(
            NSEvent.fake(
                .flagsChanged,
                keyCode: KeyboardEventReading.rightCommandKeyCode,
                rawFlags: KeyboardFlags.rightCommand
            )
        )
        let reading = try #require(KeyboardEventReading(event))
        #expect(reading.kind == .modifiersChanged)
        #expect(reading.rawFlags == KeyboardFlags.rightCommand)
        #expect(reading.keyCode == KeyboardEventReading.rightCommandKeyCode)
        #expect(reading.rightCommandIsDown)
    }

    @Test("一般按鍵的事件也轉得出判讀")
    func readsAKeyEvent() throws {
        let event = try #require(NSEvent.fake(.keyDown, keyCode: 49, rawFlags: KeyboardFlags.nothing))
        let reading = try #require(KeyboardEventReading(event))
        #expect(reading.kind == .keyDown)
        #expect(reading.keyCode == 49)
    }

    @Test("不是鍵盤事件就沒有判讀")
    func ignoresNonKeyboardEvents() throws {
        let click = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
        #expect(KeyboardEventReading(click) == nil)
    }
}
