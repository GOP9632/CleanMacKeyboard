import SwiftUI

/// app 唯一的常駐視窗的內容。
///
/// 這一層很薄，刻意如此：它把控制器算好的值映射成圓環要畫的東西，把使用者的
/// 動作轉給控制器，自己沒有狀態機也沒有時鐘。用眼睛看得出來對不對的東西
/// 用眼睛驗，看不出來的規則住在控制器裡，那裡有測試（見 `docs/seams.md`）。
struct MainWindowView: View {
    let controller: CleaningFlowController

    /// 有沒有拿到輔助使用授權。沒有的話這個視窗裡放的是別的東西。
    let gate: AuthorizationGate

    @Environment(\.locale) private var locale

    private enum Layout {
        static let padding: CGFloat = 44
        static let spacing: CGFloat = 20
    }

    /// 還沒授權時整個視窗換成引導畫面，而不是在圓環旁邊加一句提示。
    ///
    /// 沒有授權的圓環是一顆可以按但按了沒用的按鈕，那對非工程背景的使用者
    /// 來說就是「這個 app 壞了」（見 #9）。授權拿到的那一刻這裡自己會換回
    /// 圓環，不需要重開 app，因為 `AuthorizationGate` 一直在問。
    @ViewBuilder
    var body: some View {
        if showsGuide {
            AuthorizationGuideView { gate.openSettings() }
        } else {
            ring
        }
    }

    /// 現在該顯示引導畫面嗎？
    ///
    /// 只有待命時才換。清潔模式期間就算授權在這一刻被收回也不動畫面：
    /// 使用者正閉著眼睛擦機器，這時把整個視窗換掉等於抽掉他唯一的狀態來源。
    /// 那條路由攔截那一頭說話（見 `CleaningRefusal.interceptionUnavailable`），
    /// 而清潔模式一結束，這裡自然就換成引導畫面了。
    ///
    /// 準備清潔也算在「不換」裡：倒數跑到一半畫面被抽掉，使用者不會知道
    /// 那個倒數還在不在。
    private var showsGuide: Bool {
        !gate.isAuthorized && controller.stage == .standby
    }

    private var ring: some View {
        VStack(spacing: Layout.spacing) {
            RingView(phase: ringPhase) { controller.activateRing() }
            timeoutLabel
            refusalLabel
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

    /// 為什麼進不去清潔模式。
    ///
    /// 沒有東西擋著的時候整塊拿掉，不像逾時那樣留一行空白：這是例外狀態，
    /// 難得出現一次，值得讓視窗變高一點來換使用者真的看到它。
    ///
    /// 這是 Wipe 誠實回報的那一面（見 ADR-0002）。使用者正是因為相信畫面上的
    /// 狀態才敢閉著眼睛擦，所以「沒進去」不能只是安靜地什麼都沒發生。
    @ViewBuilder
    private var refusalLabel: some View {
        if let refusalText {
            Label(refusalText, systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(WipeColor.warning.color)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: RingMetrics.diameter)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var refusalText: String? {
        guard let refusal = controller.refusal else { return nil }
        switch refusal {
        case .secureInput(let appName):
            // 查不出是哪個 app 的時候仍然說明狀況，只是少了那一句「去關掉誰」。
            guard let appName else { return WipeText.mainRefusalSecureInput.localized(in: locale) }
            let format = WipeText.mainRefusalSecureInputApp.localized(in: locale)
            return String(format: format, locale: locale, appName)
        case .interceptionUnavailable:
            // 這一條只有在授權已經給了的情況下才走得到，所以話直接說到底：
            // 重開 Wipe。再叫使用者去看一次授權設定只會讓他更迷路。
            return WipeText.mainRefusalInterceptionUnavailable.localized(in: locale)
        }
    }

    /// Esc 取消準備清潔。
    ///
    /// 用一顆看不見的按鈕，而不是 `onExitCommand`：按鈕的鍵盤快捷鍵註冊在
    /// 視窗上，不必先有哪個元件拿到焦點。只在準備清潔期間啟用，其他時候
    /// 這顆按鈕是停用的，Esc 照常交給系統處理。
    ///
    /// 標題給的是一個空的視圖而不是空字串：字串那一版會被 Xcode 當成一個
    /// 要翻譯的文字抽進字串目錄，在裡面留下一個沒有鍵名的空條目。
    private var escapeShortcut: some View {
        Button(action: { controller.cancel() }) { EmptyView() }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .disabled(controller.stage != .preparing)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
    }
}

#Preview {
    MainWindowView(controller: .dryRun(), gate: .granted())
}
