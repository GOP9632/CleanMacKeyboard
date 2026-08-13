import AppKit

/// 把遮蔽層真的鋪到每一個螢幕上，然後真的收回來。
///
/// 一個螢幕一個視窗。不用一個橫跨所有螢幕的大視窗，是因為 macOS 的視窗不能
/// 跨螢幕保證每一塊都蓋滿：螢幕的排列可以是不連續的，中間那塊空白算進來會
/// 讓視窗大得沒有道理，而且切換 Space 的行為也對不上。
///
/// 螢幕清單從外面給（見 `synchronize(with:)`），所以插拔外接螢幕這件事測得到。
/// 真實那一頭是 `NSScreen.screens` 加上系統的螢幕參數變動通知。
@MainActor
final class OverlayWindows {
    /// 現在鋪著的那幾個視窗，依照給進來的螢幕順序排列。
    ///
    /// 空陣列代表現在沒有鋪，也代表沒有東西要收。
    private(set) var windows: [NSWindow] = []

    /// 每一個視窗裡要放什麼。一個螢幕叫一次，因為一個 `NSView` 只進得了
    /// 一個視窗。
    private let makeContentView: () -> NSView

    /// 現在該不該鋪。螢幕參數變動時要靠它決定是重新對齊還是維持收著。
    private var isEngaged = false

    private var screenObserver: NSObjectProtocol?

    init(makeContentView: @escaping () -> NSView) {
        self.makeContentView = makeContentView
        // 插拔外接螢幕、改解析度、把螢幕拖到另一邊，走的都是這一個通知。
        // 沒有它的話，清潔模式期間插上來的那個螢幕會整片露在外面。
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // 上一行指定了 `.main`，所以這個區塊一定在主執行緒上。
            MainActor.assumeIsolated { self?.synchronizeWithCurrentScreens() }
        }
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    /// 鋪或收。**這是唯一的入口**，兩個方向都走這裡。
    func setEngaged(_ engaged: Bool) {
        isEngaged = engaged
        synchronizeWithCurrentScreens()
    }

    /// 讓鋪著的視窗跟給進來的這組螢幕對齊。
    ///
    /// 多的關掉、少的補上、剩下的搬到對的位置。刻意不是「整組拆掉重開」：
    /// 螢幕拔掉一個的時候，剩下那幾個螢幕上的黑不該跟著閃一下。
    ///
    /// 每一次都重新叫一遍 `orderFrontRegardless`，即使什麼都沒變。這個方法
    /// 難得被叫一次（進出清潔模式，或是螢幕清單變動），而「已經鋪著」跟
    /// 「已經鋪著而且真的在最上面」是兩件事，後者才是這一層要保證的。
    ///
    /// - Parameter frames: 每一個螢幕一塊，用全域座標。空陣列代表收回來。
    func synchronize(with frames: [CGRect]) {
        while windows.count > frames.count {
            let extra = windows.removeLast()
            extra.orderOut(nil)
            extra.close()
        }
        while windows.count < frames.count {
            windows.append(makeWindow())
        }
        for (window, frame) in zip(windows, frames) {
            if window.frame != frame {
                window.setFrame(frame, display: true)
            }
            // 用 `orderFrontRegardless` 而不是 `makeKeyAndOrderFront`：遮蔽層
            // 只負責蓋住，不該把鍵盤焦點搶過來。而且 Wipe 不在前景時它也要
            // 浮上來，`orderFront` 在那種情況下不保證。
            window.orderFrontRegardless()
        }
    }

    private func synchronizeWithCurrentScreens() {
        synchronize(with: isEngaged ? NSScreen.screens.map(\.frame) : [])
    }

    /// 開一個遮蔽層的視窗。
    private func makeWindow() -> NSWindow {
        let window = OverlayScreenWindow(
            contentRect: .zero,
            // 沒有標題列、沒有邊框。它不是一個使用者操作得到的視窗，
            // 而是一塊蓋在螢幕上的布。
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        // 關掉之後這個物件要還活著，因為關掉它的那一段還握著它。
        window.isReleasedWhenClosed = false
        window.level = OverlayVisibility.windowLevel
        window.collectionBehavior = OverlayVisibility.collectionBehavior
        window.appearance = NSAppearance(named: OverlayVisibility.appearanceName)
        window.backgroundColor = OverlayVisibility.backdropNSColor ?? .black
        window.isOpaque = true
        window.hasShadow = false
        // Wipe 不在前景時遮蔽層也要留在畫面上。清潔模式期間使用者按不了
        // Cmd + Tab，前景是誰不歸他管。
        window.hidesOnDeactivate = false
        // 刻意**不**忽略滑鼠事件。遮蔽層的第二個用途是在輸入攔截失效時擋下
        // 誤點（見 `CONTEXT.md` 的遮蔽層），忽略的話點擊會直接穿過去。
        window.ignoresMouseEvents = false
        window.isExcludedFromWindowsMenu = true
        window.contentView = makeContentView()
        return window
    }
}

/// 一塊蓋在螢幕上的布。
///
/// 它唯一覆寫的就是那個「幫你把視窗塞回看得到的範圍」的預設行為。AppKit 會
/// 把視窗往下擠到選單列底下，而遮蔽層要蓋的正是整個螢幕，包含選單列那一條。
private final class OverlayScreenWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
