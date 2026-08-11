import CoreGraphics

/// 攔截範圍換成「事件攔截器要監看哪些事件」。
///
/// 這張表是鍵盤鎖與全輸入鎖之間唯一的差別。它擺在這裡而不是 `InputInterceptor`
/// 裡面，是因為範圍本身是流程的詞彙（設定裡選得到、控制器讀得到），
/// 而 `CGEventType` 是實作那一頭的事，只有真的事件攔截器需要它。
extension InterceptionScope {
    /// 這個範圍要監看的事件種類。
    ///
    /// 只有列在這裡的事件會進到攔截器的回呼，也只有它們會被丟掉。
    var tappedEventTypes: [CGEventType] {
        switch self {
        case .keyboard: Self.keyboardEventTypes
        case .allInput: Self.keyboardEventTypes + Self.pointerEventTypes
        }
    }

    /// 這個範圍要監看的事件遮罩，也就是 `CGEvent.tapCreate` 收的那個形式。
    var eventMask: CGEventMask {
        tappedEventTypes.reduce(0) { $0 | (1 << CGEventMask($1.rawValue)) }
    }

    /// 鍵盤那三種事件。修飾鍵變化也在裡面：少了它，按著 Command 擦鍵盤
    /// 就會讓別的 app 收到一連串組合鍵。
    private static let keyboardEventTypes: [CGEventType] = [.keyDown, .keyUp, .flagsChanged]

    /// 觸控板與滑鼠。
    ///
    /// 游標移動（`.mouseMoved`）與三種拖曳都要在裡面，否則抹布掃過觸控板時
    /// 游標照樣會跑，而全輸入鎖承諾的正是游標定住。
    ///
    /// 觸控板的多指手勢（雙指捲動以外的滑動、縮放）不在 `CGEventType` 的公開
    /// 列舉裡，攔不攔得到只有真機驗得出來，那是 #12 的驗收項目。
    private static let pointerEventTypes: [CGEventType] = [
        .leftMouseDown, .leftMouseUp,
        .rightMouseDown, .rightMouseUp,
        .otherMouseDown, .otherMouseUp,
        .mouseMoved,
        .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
        .scrollWheel,
    ]
}
