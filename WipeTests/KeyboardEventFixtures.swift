import AppKit

@testable import Wipe

/// 鍵盤測試共用的旗標值與假事件。
///
/// 這些數字是實際觀察到的旗標值的形狀：高位 `0x100000` 是「有按 Command」，
/// 低位 `0x8` / `0x10` 才分左右，`0x100` 是 macOS 一直帶著的位元，跟按了什麼無關。
///
/// 它們是**假設**，不是證據。真機驗證要確認的正是「真的鍵盤送出來的值長這樣」，
/// 見 #3。
enum KeyboardFlags {
    static let nothing: UInt = 0x0000_0100
    static let leftCommand: UInt = 0x0010_0108
    static let rightCommand: UInt = 0x0010_0110
    static let bothCommands: UInt = 0x0010_0118
    /// Caps Lock 亮著的那個位元。它是切換式的，亮著的時候每一次事件都帶著它。
    static let capsLockBit: UInt = 0x0001_0000
    static let leftCommandWithCapsLock: UInt = leftCommand | capsLockBit
    static let leftCommandWithShift: UInt = 0x0012_0102 | leftCommand
    /// macOS 替方向鍵一類的按鍵自己附上的兩個位元，不是使用者按的。
    static let leftCommandWithFunctionKeys: UInt = 0x00A0_0000 | leftCommand
}

extension NSEvent {
    /// 測試用的假事件。合成出來的事件保得住分左右的那幾個低位元，
    /// 所以判讀邏輯可以在沒有真鍵盤的情況下被測到。
    static func fake(_ type: NSEvent.EventType, keyCode: UInt16, rawFlags: UInt) -> NSEvent? {
        let characters = type == .flagsChanged ? "" : "a"
        return keyEvent(
            with: type,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: rawFlags),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        )
    }
}

extension CGEvent {
    /// 測試用的假 CGEvent。
    ///
    /// 這是攔截器那一頭收到的事件形式。合成一個事件不需要任何授權，也不會把
    /// 它送出去，所以測試裡做這件事是安全的；真的裝一個 CGEventTap 才是
    /// 碰不得的那一步。
    ///
    /// 事件本體一律是一次按下，事件**種類**由呼叫端另外傳給判讀。這跟真的
    /// 攔截回呼是同一個形狀：種類是系統一起交下來的參數，不是從事件本身問的
    /// （見 `KeyboardEventReading.init(_:type:)`）。
    static func fake(keyCode: UInt16, rawFlags: UInt) -> CGEvent? {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        event?.flags = CGEventFlags(rawValue: UInt64(rawFlags))
        return event
    }
}

/// 測試用的判讀。預設是修飾鍵變化，因為這一票關心的就是修飾鍵。
func makeReading(
    _ rawFlags: UInt,
    keyCode: UInt16 = KeyboardEventReading.leftCommandKeyCode,
    kind: KeyboardEventReading.Kind = .modifiersChanged
) -> KeyboardEventReading {
    KeyboardEventReading(kind: kind, rawFlags: rawFlags, keyCode: keyCode)
}
