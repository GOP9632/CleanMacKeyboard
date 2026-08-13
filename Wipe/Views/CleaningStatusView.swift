import SwiftUI

/// 主視窗與遮蔽層共用的那一疊：圓環，加上底下那兩行字。
///
/// 抽出來共用是因為遮蔽層會把主視窗整個蓋住，蓋住之後這一疊就是使用者僅剩的
/// 狀態來源：現在鎖的是什麼、還有多久自動解除（見 #1 的 user story 13、18）。
/// 兩邊各寫一份的話，改了其中一邊另一邊不會跟著動，而遮蔽層底下的那一份
/// 沒有人會發現它是舊的。
///
/// 這一層很薄，跟 `MainWindowView` 同一個理由：它只把控制器算好的值映射成
/// 畫面上的東西，自己沒有狀態機也沒有時鐘（見 `docs/seams.md`）。
struct CleaningStatusView: View {
    let controller: CleaningFlowController

    /// 點擊圓環要做的事。`nil` 代表這個圓環不可點擊，遮蔽層走的是這一條。
    var onActivateRing: (() -> Void)?

    @Environment(\.locale) private var locale

    /// 圓環與底下那兩行之間的間距。主視窗把它接著往下用，整疊的節奏才一致。
    static let spacing: CGFloat = 20

    var body: some View {
        VStack(spacing: Self.spacing) {
            RingView(phase: ringPhase, onActivate: onActivateRing)
            scopeLabel
            timeoutLabel
        }
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

    /// 現在鎖住的是哪些東西。
    ///
    /// 兩種攔截範圍留下的求救路徑不一樣，所以這一行講的是範圍的名字加上那條
    /// 路徑還在不在（見 `InterceptionScope.statusText`）。全輸入鎖底下這件事
    /// 最要緊：使用者得知道自己現在只剩闔蓋與逾時兩條路。
    ///
    /// 它顯示的是控制器手上真的裝上去的那個範圍，不是設定裡現在選的那一個
    /// （見 `CleaningFlowController.activeInterceptionScope`）。
    ///
    /// 待命時擺一個空白字串而不是整塊拿掉，跟逾時那一行同一個理由：主視窗在
    /// 清潔模式期間不變形，大小也不變（見 #1 的 user story 16）。整塊拿掉的話，
    /// 每一次進出清潔模式視窗都會長高一行再縮回來。
    ///
    /// 也因此這一行限定一行：兩種語言的兩句話都短到塞得下，有測試量著
    /// （見 `SecondaryLineLayoutTests`）。留兩行的版位會在待命時留下一塊
    /// 空白，而待命是使用者看最久的那個畫面。
    private var scopeLabel: some View {
        Text(scopeText ?? " ")
            .font(RingMetrics.secondaryLineFont)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .opacity(scopeText == nil ? 0 : 1)
            .accessibilityHidden(scopeText == nil)
    }

    private var scopeText: String? {
        controller.activeInterceptionScope?.statusText.localized(in: locale)
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
            .font(RingMetrics.secondaryLineFont)
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
}
