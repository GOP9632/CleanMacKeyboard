import SwiftUI

/// app 唯一的常駐視窗的內容。
///
/// 這一層很薄，刻意如此：它把控制器算好的值映射成圓環要畫的東西，把使用者的
/// 動作轉給控制器，自己沒有狀態機也沒有時鐘。用眼睛看得出來對不對的東西
/// 用眼睛驗，看不出來的規則住在控制器裡，那裡有測試（見 `docs/seams.md`）。
struct MainWindowView: View {
    let controller: CleaningFlowController

    @Environment(\.locale) private var locale

    private enum Layout {
        static let padding: CGFloat = 44
        static let spacing: CGFloat = 20
    }

    var body: some View {
        VStack(spacing: Layout.spacing) {
            RingView(phase: ringPhase) { controller.activateRing() }
            timeoutLabel
        }
        .padding(Layout.padding)
        .frame(minWidth: RingMetrics.diameter + Layout.padding * 2)
        .background(escapeShortcut)
    }

    /// 目前階段在圓環上的樣子。
    private var ringPhase: RingPhase {
        switch controller.stage {
        case .standby:
            .standby
        case .preparing:
            // 這個分支底下剩餘秒數一定有值，`?? 0` 只是把 optional 拆開。
            .preparing(
                secondsRemaining: controller.preparingSecondsRemaining ?? 0,
                progress: controller.preparingProgress
            )
        case .cleaning:
            // 環在清潔中只表達解鎖手勢的按住進度。逾時剩餘時間刻意不畫在環上，
            // 它在下面那行文字裡。
            .cleaning(holdProgress: controller.unlockHoldProgress)
        }
    }

    /// 逾時剩餘時間。
    ///
    /// 它在圓環外面，不佔用圓環：環要留給解鎖手勢的按住進度，那是使用者
    /// 唯一需要盯著看的東西，逾時只會被偶爾瞄一眼。
    ///
    /// 沒有東西可顯示的時候擺一個空白字串，而不是整塊拿掉，這樣圓環不會
    /// 因為進出清潔模式而上下跳動。
    private var timeoutLabel: some View {
        Text(timeoutText ?? " ")
            .font(.callout)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .opacity(timeoutText == nil ? 0 : 1)
            .accessibilityHidden(timeoutText == nil)
    }

    private var timeoutText: String? {
        guard let remaining = controller.timeoutSecondsRemaining else { return nil }
        let format = WipeText.mainTimeoutRemaining.localized(in: locale)
        return String(format: format, locale: locale, ClockText.minutesAndSeconds(remaining))
    }

    /// Esc 取消準備清潔。
    ///
    /// 用一顆看不見的按鈕，而不是 `onExitCommand`：按鈕的鍵盤快捷鍵註冊在
    /// 視窗上，不必先有哪個元件拿到焦點。只在準備清潔期間啟用，其他時候
    /// 這顆按鈕是停用的，Esc 照常交給系統處理。
    private var escapeShortcut: some View {
        Button("", action: { controller.cancel() })
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .disabled(controller.stage != .preparing)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
    }
}

#Preview {
    MainWindowView(controller: .dryRun())
}
