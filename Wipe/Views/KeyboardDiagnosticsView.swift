import AppKit
import SwiftUI

/// 真機驗證用的診斷畫面。
///
/// 它要回答的問題只有一個：這台機器上的左 Command 和右 Command 分不分得開。
/// 上面那兩個指示燈給人看，下面的紀錄給票看，旗標原始值要能原樣貼回 #3。
///
/// **這不是產品功能。**答案拿到之後，這個檔案連同視窗一起拆掉。
struct KeyboardDiagnosticsView: View {
    private enum Layout {
        static let spacing: CGFloat = 16
        static let headerSpacing: CGFloat = 4
        static let footerSpacing: CGFloat = 8
        static let logMinHeight: CGFloat = 220
        static let logPadding: CGFloat = 8
        static let logBackgroundOpacity: Double = 0.4
        static let minWidth: CGFloat = 560
        static let minHeight: CGFloat = 460
        static let cornerRadius: CGFloat = 8
        static let rowSpacing: CGFloat = 2
    }

    @State private var source = LocalKeyboardSignalSource()
    @State private var log = KeyboardDiagnosticsLog()
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            header
            indicators
            logSection
            footer
        }
        .padding()
        .frame(minWidth: Layout.minWidth, minHeight: Layout.minHeight)
        .onAppear {
            source.onReading = { log.record($0) }
            source.start()
        }
        .onDisappear {
            source.stop()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Layout.headerSpacing) {
            Text(WipeText.diagnosticsHeadline.localizedKey, bundle: .wipe)
                .font(.headline)
            Text(WipeText.diagnosticsInstructions.localizedKey, bundle: .wipe)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 兩個指示燈。真機驗證時使用者的視線在鍵盤上，抬頭只會瞄一眼，
    /// 所以結論要用顏色講，不能只寫在紀錄裡。
    private var indicators: some View {
        HStack(spacing: Layout.spacing) {
            CommandIndicator(
                label: .diagnosticsLeftCommand,
                isDown: source.signal.leftCommandIsDown
            )
            CommandIndicator(
                label: .diagnosticsRightCommand,
                isDown: source.signal.rightCommandIsDown
            )
        }
    }

    private var logSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Layout.rowSpacing) {
                    if log.entries.isEmpty {
                        Text(WipeText.diagnosticsLogEmpty.localizedKey, bundle: .wipe)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(log.entries) { entry in
                        Text(entry.text)
                            .font(.system(.caption, design: .monospaced))
                            .id(entry.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Layout.logPadding)
            }
            .textSelection(.enabled)
            .frame(minHeight: Layout.logMinHeight)
            .background(
                .quaternary.opacity(Layout.logBackgroundOpacity),
                in: RoundedRectangle(cornerRadius: Layout.cornerRadius)
            )
            // 自動滾到最新一行。驗證時手在鍵盤上，沒有手可以拉捲軸。
            .onChange(of: log.latestEntryID) { _, latest in
                guard let latest else { return }
                proxy.scrollTo(latest, anchor: .bottom)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Layout.footerSpacing) {
            HStack {
                Text(entryCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Button(action: copyLog) {
                    Text(WipeText.diagnosticsLogCopy.localizedKey, bundle: .wipe)
                }
                .disabled(log.entries.isEmpty)
                Button { log.clear() } label: {
                    Text(WipeText.diagnosticsLogClear.localizedKey, bundle: .wipe)
                }
                .disabled(log.entries.isEmpty)
            }
            Text(WipeText.diagnosticsPassThroughNote.localizedKey, bundle: .wipe)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 已經記了幾筆，上限是幾筆。上限寫出來，使用者才知道舊的那幾筆是被丟掉的，
    /// 不是漏記。
    private var entryCountText: String {
        let format = WipeText.diagnosticsLogCount.localized(in: locale)
        return String(format: format, locale: locale, log.entries.count, log.capacity)
    }

    /// 把整份紀錄放進剪貼簿，方便直接貼回票上。
    private func copyLog() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(log.entries.map(\.text).joined(separator: "\n"), forType: .string)
    }
}

/// 一顆 Command 的指示燈。
private struct CommandIndicator: View {
    let label: WipeText
    let isDown: Bool

    private enum Layout {
        static let dotSize: CGFloat = 14
        static let spacing: CGFloat = 10
        static let labelSpacing: CGFloat = 2
        static let cornerRadius: CGFloat = 10
        static let padding: CGFloat = 12
        static let backgroundOpacity: Double = 0.12
    }

    /// 按著時是解鎖手勢進度的那個亮青色，放開時是待命的中性灰。
    ///
    /// 刻意不用清潔中的青色：那個顏色的意思是「現在正在清潔模式」，
    /// 借來表示「這顆鍵被按著」會稀釋掉它（見 ADR-0003，顏色在 Wipe 裡
    /// 承擔辨識功能）。這兩顆鍵日後就是解鎖手勢的兩顆鍵，用那個顏色才對得上。
    private var tint: WipeColor { isDown ? .unlockProgress : .standby }

    var body: some View {
        HStack(spacing: Layout.spacing) {
            Circle()
                .fill(tint.color)
                .frame(width: Layout.dotSize, height: Layout.dotSize)
            VStack(alignment: .leading, spacing: Layout.labelSpacing) {
                Text(label.localizedKey, bundle: .wipe)
                    .font(.body)
                Text(
                    (isDown ? WipeText.diagnosticsStateDown : .diagnosticsStateUp).localizedKey,
                    bundle: .wipe
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Layout.padding)
        .background(
            tint.color.opacity(Layout.backgroundOpacity),
            in: RoundedRectangle(cornerRadius: Layout.cornerRadius)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    KeyboardDiagnosticsView()
}
