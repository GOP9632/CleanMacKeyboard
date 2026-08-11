import CoreGraphics
import Testing

@testable import Wipe

/// 攔截範圍要換成「事件攔截器要監看哪些事件」。
///
/// 這張對照表是鍵盤鎖與全輸入鎖唯一的差別，錯了不會有編譯錯誤，只會安靜地
/// 攔錯東西：鍵盤鎖多攔了滑鼠，使用者就失去那條非鍵盤的求救路徑；全輸入鎖
/// 少攔了游標移動，畫面說著全輸入鎖而游標還在動，那就是製造假象
/// （見 `CONTEXT.md` 的不變條件）。
///
/// 期望值裡的位元編號直接寫死，不從 `CGEventType` 的成員算回去：那些數字是
/// Apple 的標頭檔定的，抄一次過來才有一個獨立的對照對象。
@Suite("攔截範圍對應到的事件")
struct InterceptionScopeEventsTests {
    /// `CGEventType` 在 Apple 標頭檔裡的原始值。
    private enum Bit {
        static let leftMouseDown = 1
        static let leftMouseUp = 2
        static let rightMouseDown = 3
        static let rightMouseUp = 4
        static let mouseMoved = 5
        static let leftMouseDragged = 6
        static let rightMouseDragged = 7
        static let keyDown = 10
        static let keyUp = 11
        static let flagsChanged = 12
        static let scrollWheel = 22
        static let otherMouseDown = 25
        static let otherMouseUp = 26
        static let otherMouseDragged = 27
    }

    private static func mask(_ bits: [Int]) -> CGEventMask {
        bits.reduce(0) { $0 | (1 << CGEventMask($1)) }
    }

    @Test("鍵盤鎖只監看鍵盤事件")
    func keyboardScopeWatchesOnlyKeyboardEvents() {
        #expect(InterceptionScope.keyboard.eventMask == Self.mask([
            Bit.keyDown, Bit.keyUp, Bit.flagsChanged,
        ]))
    }

    @Test("鍵盤鎖不碰觸控板與滑鼠")
    func keyboardScopeLeavesThePointerAlone() {
        // 這一條是保險本身：解鎖手勢失靈的時候，滑鼠是使用者唯一的求救路徑
        // （見 `InterceptionScope.keyboard`）。
        let mask = InterceptionScope.keyboard.eventMask
        for bit in [Bit.mouseMoved, Bit.leftMouseDown, Bit.leftMouseDragged, Bit.scrollWheel] {
            #expect(mask & (1 << CGEventMask(bit)) == 0)
        }
    }

    @Test("全輸入鎖連游標移動一起監看")
    func allInputScopeWatchesThePointerToo() {
        #expect(InterceptionScope.allInput.eventMask == Self.mask([
            Bit.keyDown, Bit.keyUp, Bit.flagsChanged,
            Bit.leftMouseDown, Bit.leftMouseUp,
            Bit.rightMouseDown, Bit.rightMouseUp,
            Bit.otherMouseDown, Bit.otherMouseUp,
            Bit.mouseMoved,
            Bit.leftMouseDragged, Bit.rightMouseDragged, Bit.otherMouseDragged,
            Bit.scrollWheel,
        ]))
    }

    @Test("全輸入鎖涵蓋鍵盤鎖攔的每一件事")
    func allInputScopeIsASupersetOfTheKeyboardScope() {
        let keyboard = InterceptionScope.keyboard.eventMask
        #expect(InterceptionScope.allInput.eventMask & keyboard == keyboard)
    }
}
