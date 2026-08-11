import CoreGraphics

/// 事件送進攔截回呼時，攔截器要做的事。
///
/// 回呼收到的東西有兩種：一種是使用者真的按下去的事件，那些一律丟掉；
/// 另一種是 macOS 用來說「我把你的攔截停掉了」的通知，那些要重新啟用。
///
/// 這段判斷被抽出來是因為它是整個攔截器裡唯一「錯了會安靜地失效」的地方：
/// 系統停用攔截不會有任何錯誤訊息，只有鍵盤悄悄復活，而畫面還寫著清潔中。
/// 攔截器本體要真的裝一個 CGEventTap 才跑得起來，測試裡碰不得；
/// 這一段是純值，測得到（見 `EventTapResponseTests`）。
enum EventTapResponse: Equatable {
    /// 丟掉這個事件，它不會送到任何 app。
    case discard

    /// 系統把攔截停掉了，重新啟用它。
    ///
    /// 兩個原因都走這條路：回呼處理得太慢（`kCGEventTapDisabledByTimeout`），
    /// 以及系統因為某些使用者輸入自行停用（`kCGEventTapDisabledByUserInput`）。
    /// 兩者都不是使用者按出來的事件，沒有東西要丟。
    case reenable

    init(eventType: CGEventType) {
        switch eventType {
        case .tapDisabledByTimeout, .tapDisabledByUserInput: self = .reenable
        default: self = .discard
        }
    }
}
