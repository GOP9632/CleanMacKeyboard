import CoreGraphics
import Testing

@testable import Wipe

/// 事件送進攔截器的回呼時，該怎麼回應它。
///
/// 這段判斷之所以被抽成一個純值，是因為它是整個攔截器裡唯一「錯了會安靜地
/// 失效」的地方：macOS 會在回呼太慢或使用者做了某些動作時自己把攔截停掉，
/// 停掉之後不會有任何錯誤，只有鍵盤悄悄復活，而畫面還寫著清潔中。
/// 攔截器本體要真的裝一個 CGEventTap 才跑得起來，測試裡碰不得
/// （碰了跑測試那台電腦當場沒有鍵盤），這一段沒有那個問題。
@Suite("攔截回呼的回應")
struct EventTapResponseTests {
    /// 系統用來通知「攔截被停掉了」的兩個事件種類。這兩個原始值是 Apple 定的
    /// （`kCGEventTapDisabledByTimeout` 與 `kCGEventTapDisabledByUserInput`），
    /// 這裡抄一次過來當獨立的對照。
    private static let disabledByTimeout = CGEventType(rawValue: 0xFFFF_FFFE)!
    private static let disabledByUserInput = CGEventType(rawValue: 0xFFFF_FFFF)!

    @Test("鍵盤事件一律丟掉")
    func keyboardEventsAreDiscarded() {
        #expect(EventTapResponse(eventType: .keyDown) == .discard)
        #expect(EventTapResponse(eventType: .keyUp) == .discard)
        #expect(EventTapResponse(eventType: .flagsChanged) == .discard)
    }

    @Test("觸控板與滑鼠事件一律丟掉")
    func pointerEventsAreDiscarded() {
        // 全輸入鎖底下才會收到這些事件，收到就是要丟。
        #expect(EventTapResponse(eventType: .mouseMoved) == .discard)
        #expect(EventTapResponse(eventType: .leftMouseDown) == .discard)
        #expect(EventTapResponse(eventType: .scrollWheel) == .discard)
    }

    @Test("系統因逾時停用攔截時要重新啟用")
    func aTimedOutTapIsReenabled() {
        // 回呼處理得太慢，macOS 會直接把攔截停掉。不重新啟用的話，鍵盤會在
        // 清潔模式進行中悄悄復活，而畫面還寫著清潔中。
        #expect(EventTapResponse(eventType: Self.disabledByTimeout) == .reenable)
    }

    @Test("系統因使用者輸入停用攔截時要重新啟用")
    func aTapDisabledByUserInputIsReenabled() {
        #expect(EventTapResponse(eventType: Self.disabledByUserInput) == .reenable)
    }
}
