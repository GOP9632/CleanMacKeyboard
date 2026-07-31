import Foundation

/// 清潔模式期間畫面怎麼呈現。
enum ScreenPresentation: String, CaseIterable, Equatable {
    /// 主視窗：只有原本那一個視窗，清潔模式期間暫時置頂，外觀、大小、位置都不變。
    ///
    /// 這是預設值。它最不打擾人，而且使用者對這個視窗在哪裡已經有穩定的預期。
    case mainWindow

    /// 遮蔽層：每一個螢幕各鋪一層深色不透明畫面。
    ///
    /// 除了顯示狀態，它同時提供隱私遮蔽，以及在輸入攔截失效時擋下誤點的
    /// 第二層防護。真正把它畫出來是 #14，這裡先有設定項。
    case overlay
}
