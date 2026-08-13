import Foundation

/// app 圖示在資源目錄裡的名稱。
///
/// 需要這個常數的理由與 `WipeColor.globalAccentAssetName` 一樣：同一個字串同時寫在
/// `Config/Wipe.xcconfig` 的 `ASSETCATALOG_COMPILER_APPICON_NAME` 與資源目錄的
/// 目錄名上。兩邊對不起來時不會有編譯錯誤，app 照樣跑，只是 Dock 上顯示的變成系統
/// 那個通用的空白圖示。有一個地方寫著正確答案，測試才有東西可以比對。
///
/// 圖示的原始素材與產生器在 `design/icon/`，各尺寸的設計取捨寫在那裡的 README。
enum WipeIcon {
    /// 資源目錄裡那個 appiconset 的名稱。
    static let assetName = "AppIcon"
}
