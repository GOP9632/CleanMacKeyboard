/// 攔截範圍在清潔模式期間畫面上的那一句話。
///
/// 它擺在這裡而不是 `InterceptionScope` 旁邊，理由跟 `InterceptionScopeEvents`
/// 一樣，只是方向相反：範圍本身是流程的詞彙，而「畫面上寫什麼」是介面那一頭
/// 的事。同一個範圍在事件那一頭有一份對照表，在文字這一頭有另一份。
extension InterceptionScope {
    /// 清潔模式期間說明目前攔截範圍的那一句話。
    ///
    /// 兩句話的形狀一樣：範圍的名字，加上**那條求救路徑還在不在**。使用者要
    /// 判斷的就是這一件事，而它在全輸入鎖底下最要緊。
    ///
    /// 兩句都刻意很短。這一行在清潔中一直掛在圓環底下，寫成一段說明就沒有人
    /// 會看，而看不到等於沒有寫。
    ///
    /// 用 switch 而不是字典是刻意的：日後多一種範圍，這裡會編不過，
    /// 不會靜悄悄地少一句話。
    var statusText: WipeText {
        switch self {
        case .keyboard: .mainScopeKeyboard
        case .allInput: .mainScopeAllInput
        }
    }
}
