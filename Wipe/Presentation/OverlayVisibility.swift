import AppKit
import SwiftUI

/// 遮蔽層要在什麼時候出現、長什麼樣子。
///
/// 這一整包都是純值，跟 AppKit 那一頭真的怎麼開視窗分開放
/// （見 `OverlayWindows`），所以測得到。
///
/// 為什麼需要這件事：使用者在辦公室或咖啡廳擦筆電時，工作內容會整片攤在那邊
/// （見 #1 的 user story 19）。除了遮住，這一層還有兩個用途：擦螢幕的時候
/// 看得見灰塵，以及萬一輸入攔截失效時擋下誤點。
enum OverlayVisibility {
    /// 現在要不要鋪遮蔽層。
    ///
    /// 兩個條件都要成立：設定選的是遮蔽層，而且已經真的在清潔中。
    ///
    /// 準備清潔刻意不鋪。那個階段一個事件都還沒攔，使用者隨時可以按 Esc 或
    /// 再點一次圓環反悔（見 #1 的 user story 6），鋪上去等於把那兩條反悔的路
    /// 一起蓋掉。
    static func isEngaged(during stage: CleaningStage, presentation: ScreenPresentation) -> Bool {
        stage == .cleaning && presentation == .overlay
    }

    /// 遮蔽層的視窗層級。
    ///
    /// 跟主視窗置頂用的是同一個層級，理由也一樣：要蓋得過的不只是一般視窗，
    /// 全螢幕 app、選單列與 Dock 都各有自己的層級
    /// （見 `CleaningVisibility.raisedWindowLevel`）。
    ///
    /// 遮蔽層啟用時主視窗不做任何處置，維持普通層級，所以這一層蓋得過它，
    /// 兩者不會互相搶（見 `CONTEXT.md` 的遮蔽層）。
    static let windowLevel: NSWindow.Level = .screenSaver

    /// 遮蔽層的視窗集合行為。
    ///
    /// 這裡直接給一組固定值，不像主視窗那樣從原本那一份算出來：遮蔽層的視窗
    /// 是這個 app 自己開的，開完就是這個樣子，沒有「原本」可以保留。
    ///
    /// - `canJoinAllSpaces` 與 `fullScreenAuxiliary`：讓這個視窗有資格出現在
    ///   別的 Space 與全螢幕 app 上面。
    /// - `stationary`：切換 Space 的時候不要跟著滑動。
    /// - `ignoresCycle`：不要出現在 Cmd + \` 的視窗循環裡。
    ///
    /// **這兩個旗標沒有讓遮蔽層跟過去每一個桌面。**#14 在真機上驗過：鍵盤鎖
    /// 底下觸控板是活的，用多指手勢切到另一個桌面，那個桌面沒有被蓋住。
    /// 換句話說遮蔽層守得住它所在的那個桌面，守不住「使用者把桌面切走」。
    ///
    /// 這個行為是接受的，理由是切得走的前提是觸控板還活著，而那正是鍵盤鎖
    /// 自己說明白的取捨（見 `CONTEXT.md` 的攔截範圍）。真的要連這條路一起
    /// 堵住就是切到全輸入鎖，手勢在那底下沒有作用。所以畫面上不承諾隱私
    /// 遮蔽在鍵盤鎖底下滴水不漏。
    static let collectionBehavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle,
    ]

    /// 遮蔽層視窗的外觀。**固定深色，不跟隨系統。**
    ///
    /// 底色是自己畫的，指定深色是為了底色上面那個圓環：它用的顏色在資源目錄
    /// 裡有淺色與深色兩個值，不指定的話，淺色模式下畫上去的會是給白底用的
    /// 那一份，在這片黑上對比會不夠。
    static let appearanceName: NSAppearance.Name = .darkAqua

    /// 遮蔽層底色的資源名稱。
    ///
    /// 它刻意不是 `WipeColor` 的一個 case：那個型別裡的每一個顏色都必須有
    /// 淺色與深色兩個值，有測試守著（見 `WipeColorTests`），而這一個的規矩
    /// 正好相反，兩種外觀下都是同一個值（見 #1 的 user story 21）。
    static let backdropAssetName = "OverlayBackdrop"

    /// 遮蔽層的底色。
    static var backdropColor: Color { Color(backdropAssetName, bundle: .wipe) }

    /// 同一個底色的 AppKit 形式。視窗的背景色與測試都走這裡。
    static var backdropNSColor: NSColor? { NSColor(named: backdropAssetName, bundle: .wipe) }
}
