import AppKit
import SwiftUI

/// 把「清潔模式期間畫面一直看得見」真的套到主視窗上。
///
/// 這一層很薄，跟 `MainWindowView` 同一個理由：它只把 `CleaningVisibility`
/// 算好的值交給 AppKit，自己不判斷任何事。判斷住在那個純值裡，那裡有測試
/// （見 `docs/seams.md`）。
///
/// 它沒有變成第八個接縫。置頂與阻止變暗都是畫面呈現的一部分，而畫面呈現不是
/// 接縫：控制器只說現在是哪個階段，怎麼呈現是這一層的事。真的蓋得過全螢幕
/// app、真的不會變暗，都只有真機驗得到（手動驗收清單第 3 與第 6 項）。
///
/// 用一個看不見的 `NSView` 借視窗，是因為 SwiftUI 的 `Window` 場景沒有提供
/// 拿到底下那個 `NSWindow` 的途徑。SwiftUI 自己那個 `windowLevel(_:)` 幫不上忙：
/// 它要 macOS 15，而本專案支援到 macOS 14（見 `Config/Common.xcconfig`），
/// 而且它給得出的最高層級也不夠蓋過全螢幕 app
/// （見 `CleaningVisibility.raisedWindowLevel`）。
struct MainWindowVisibility: NSViewRepresentable {
    /// 目前階段。它變了 SwiftUI 才會來叫 `updateNSView`。
    let stage: CleaningStage

    func makeNSView(context: Context) -> NSView {
        // 一個零尺寸、什麼都不畫的視圖。它唯一的用途是站在視圖階層裡，
        // 好讓這裡問得到 `window`。
        NSView(frame: .zero)
    }

    /// SwiftUI 每重畫一次主視窗就會來一次，不是只有階段變動那一刻。
    ///
    /// 清潔中主視窗每一格都在重畫（環上的按住進度會動），所以這裡一秒會被叫
    /// 三十次左右。那不是浪費：`Coordinator` 兩個方向都擋著重複，而萬一某一次
    /// 進來時視圖還沒接上視窗，下一格就會自己補上。
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.apply(
            engaged: CleaningVisibility.isEngaged(during: stage),
            to: nsView.window
        )
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        // 視圖被拆掉的時候一定要還原。少了這一行，視窗留在置頂層級、螢幕留著
        // 那份不變暗的宣告，而已經沒有人有辦法把它們收回來了。
        coordinator.apply(engaged: false, to: nsView.window)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// 記著「原本長什麼樣子」的那個東西。
    ///
    /// 它必須有狀態：回到待命時要還原的是**進入清潔模式之前**那一份視窗設定，
    /// 不是某一組寫死的預設值。視窗的層級與集合行為都可能被系統或其他機制改過，
    /// 拿預設值蓋回去等於偷偷換掉使用者的視窗（見 #1 的 user story 16）。
    @MainActor
    final class Coordinator {
        private let sleepBlock = DisplaySleepBlock()

        /// 被置頂著的那個視窗，加上它原本長什麼樣子。
        ///
        /// `nil` 代表現在沒有置頂中，也代表沒有東西要還原。這幾個值永遠一起設、
        /// 一起清空，所以綁成一個；分成好幾個 optional 的話，還原那一段就得在
        /// 好幾個「不可能是 nil」的地方各拆一次包。
        private var raised: RaisedWindow?

        private struct RaisedWindow {
            /// 用 weak：視窗的生命週期不歸這裡管，而視窗先走一步的話也沒有
            /// 東西需要還原了。
            weak var window: NSWindow?
            let level: NSWindow.Level
            let behavior: NSWindow.CollectionBehavior
            let styleMask: NSWindow.StyleMask
        }

        func apply(engaged: Bool, to window: NSWindow?) {
            // 兩件事一起開、一起關。它們是同一個承諾的兩半：畫面一直看得見。
            sleepBlock.setEngaged(engaged)
            if engaged {
                raise(window)
            } else {
                restore()
            }
        }

        /// 置頂。已經置頂中就什麼都不做。
        ///
        /// 那個 `guard` 是關鍵：重複進來的話會把「原本長什麼樣子」覆蓋成
        /// 「已經被改過的樣子」，回到待命時就再也還原不回去了。
        private func raise(_ window: NSWindow?) {
            guard let window, raised == nil else { return }
            raised = RaisedWindow(
                window: window,
                level: window.level,
                behavior: window.collectionBehavior,
                styleMask: window.styleMask
            )
            window.level = CleaningVisibility.raisedWindowLevel
            window.collectionBehavior = CleaningVisibility.raisedCollectionBehavior(
                from: window.collectionBehavior
            )
            window.styleMask = CleaningVisibility.raisedStyleMask(from: window.styleMask)
            // 這裡刻意不碰 `setFrame` 與 `orderFront`。清潔模式期間主視窗維持
            // 原來的大小和位置（見 #1 的 user story 16），層級調高本身就足以
            // 讓它浮上來。樣式只動關閉與縮小那兩顆按鈕，理由見
            // `CleaningVisibility.raisedStyleMask(from:)`。
        }

        /// 還原成進入清潔模式之前那一份。
        private func restore() {
            defer { raised = nil }
            guard let raised, let window = raised.window else { return }
            window.level = raised.level
            window.collectionBehavior = raised.behavior
            window.styleMask = raised.styleMask
        }
    }
}
