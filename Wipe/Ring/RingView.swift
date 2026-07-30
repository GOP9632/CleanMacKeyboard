import SwiftUI

/// 主視窗與遮蔽層共用的圓環。
///
/// 這個元件刻意不知道任何流程：它收一個 `RingPhase` 畫出來，收一個
/// `onActivate` 決定要不要接受點擊。放進遮蔽層時它只是被放在另一個背景上，
/// 不需要第二份實作。
struct RingView: View {
    let phase: RingPhase

    /// 點擊圓環要做的事。`nil` 代表這個圓環不可點擊。
    var onActivate: (() -> Void)?

    @Environment(\.locale) private var locale

    private var isInteractive: Bool { onActivate != nil && phase.allowsActivation }

    var body: some View {
        if isInteractive, let onActivate {
            Button(action: onActivate) { ring }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityAddTraits(.isButton)
        } else {
            ring
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel)
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(
                    phase.tint.color.opacity(RingMetrics.trackOpacity),
                    lineWidth: RingMetrics.strokeWidth
                )
            arc
            center
        }
        .frame(width: RingMetrics.diameter, height: RingMetrics.diameter)
        .contentShape(Circle())
    }

    @ViewBuilder
    private var arc: some View {
        if let progress = phase.progress {
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    phase.tint.color,
                    style: StrokeStyle(lineWidth: RingMetrics.strokeWidth, lineCap: .round)
                )
                // 從十二點鐘方向開始畫，而不是三點鐘方向。
                .rotationEffect(.degrees(-90))
        } else {
            Circle()
                .stroke(phase.tint.color, lineWidth: RingMetrics.strokeWidth)
        }
    }

    private var center: some View {
        VStack(spacing: RingMetrics.centerLineSpacing) {
            Text(phase.title.localizedKey, bundle: .wipe)
                .font(RingMetrics.centerTitleFont)
                .multilineTextAlignment(.center)
                .lineLimit(RingMetrics.centerTitleLineLimit)
                .minimumScaleFactor(RingMetrics.centerTitleMinimumScale)
                .allowsTightening(true)

            if let secondsText {
                Text(secondsText)
                    .font(RingMetrics.centerSecondsFont)
                    .monospacedDigit()
            }
        }
        .foregroundStyle(phase.tint.color)
        .frame(width: RingMetrics.centerTextWidth)
    }

    /// 中央標題底下那一行的文字。目前只有準備清潔的剩餘秒數會用到。
    private var secondsText: String? {
        guard let seconds = phase.secondsRemaining else { return nil }
        let format = WipeText.ringPreparingSeconds.localized(in: locale)
        return String(format: format, locale: locale, seconds)
    }

    private var accessibilityLabel: String {
        [phase.title.localized(in: locale), secondsText]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

#Preview("待命") {
    RingView(phase: .standby)
        .padding(40)
}

#Preview("準備清潔") {
    RingView(phase: .preparing(secondsRemaining: 2, progress: 0.33))
        .padding(40)
}

#Preview("清潔中") {
    RingView(phase: .cleaning(holdProgress: 0.6))
        .padding(40)
}
