import AppKit
import SwiftUI

/// Wipe 的固定配色。
///
/// 這些顏色**不跟隨系統強調色**，見 `docs/adr/0003-fixed-accent-colour.md`。
/// 理由是顏色在這個 app 裡承擔真實的辨識功能：使用者擦拭時視線在鍵盤上，
/// 只能瞄到畫面上的色塊。若跟隨系統強調色，使用者把系統設成紅色時
/// 「清潔中」就會與「攔截失效」同色，設成黃色則與「準備清潔」同色。
///
/// 淺色與深色模式仍然跟隨系統，每個顏色在資源目錄裡都有兩個值。
enum WipeColor: String, CaseIterable {
    /// 待命的中性灰。
    case standby = "StandbyGray"
    /// 準備清潔的琥珀色。
    case preparing = "PreparingAmber"
    /// 清潔中的青色。
    case cleaning = "CleaningCyan"
    /// 解鎖手勢按住進度的亮青色。
    case unlockProgress = "UnlockProgressCyan"
    /// 警告紅。只用在真正的問題上，不用於任何常態狀態。
    case warning = "WarningRed"

    /// Wipe 的強調色。刻意就是清潔中的那個青色，而且是固定的。
    static let accent = WipeColor.cleaning

    /// 資源目錄裡那個管整個 app 的強調色資源名稱。
    ///
    /// 它的色值必須與 `WipeColor.accent` 一模一樣，有測試守著。
    /// 之所以需要它，是因為 macOS 的控制項預設會用使用者選的系統強調色，
    /// 只有 app 自己的全域強調色資源蓋得掉。在個別視圖上寫 tint 蓋不到所有地方，
    /// 也蓋不到日後才長出來的視窗（例如遮蔽層）。
    static let globalAccentAssetName = "AccentColor"

    /// 這個顏色在資源目錄裡的名稱。
    var assetName: String { rawValue }

    var color: Color { Color(assetName, bundle: .wipe) }

    /// 同一個顏色的 AppKit 形式。給需要量測或驗證實際色值的地方使用。
    var nsColor: NSColor? { NSColor(named: assetName, bundle: .wipe) }
}
