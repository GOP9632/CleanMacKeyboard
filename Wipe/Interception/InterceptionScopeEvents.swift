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
    ///
    /// 媒體鍵那一種不在 `tappedEventTypes` 裡，只能在這裡直接補上位元，
    /// 理由見 `systemDefinedMask`。它兩個範圍都要：媒體鍵是鍵盤上的鍵。
    var eventMask: CGEventMask {
        tappedEventTypes.reduce(Self.systemDefinedMask) { $0 | (1 << CGEventMask($1.rawValue)) }
    }

    /// 鍵盤那三種事件。修飾鍵變化也在裡面：少了它，按著 Command 擦鍵盤
    /// 就會讓別的 app 收到一連串組合鍵。
    private static let keyboardEventTypes: [CGEventType] = [.keyDown, .keyUp, .flagsChanged]

    /// 上排媒體鍵（音量、亮度、播放）走的事件種類，`NX_SYSDEFINED`。
    ///
    /// 少了它，抹布掃過上排照樣會調音量與亮度，那就不是使用者要的
    /// 「鍵盤完全沒有反應」（見 #1 的 user story 10）。
    ///
    /// 位元編號直接寫死，因為 `CGEventType` 根本沒有這個成員：它是 IOKit 的
    /// 常數（`IOLLEvent.h` 的 `NX_SYSDEFINED`），Swift 那一頭拿不到。
    ///
    /// 這一種事件裡混著媒體鍵以外的系統訊息，這裡是整批丟掉，沒有分類：
    /// 從 `CGEvent` 分辨子種類要先轉成 `NSEvent`，而分錯的代價是安靜地
    /// 漏掉幾顆鍵。清潔模式期間這些訊息全部不送出去，時間上限就是逾時那幾
    /// 分鐘，然後一切照舊。擦上排真的沒反應、其餘功能沒受影響，這兩件事
    /// 只有真機驗得到。
    private static let systemDefinedMask: CGEventMask = 1 << 14

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
