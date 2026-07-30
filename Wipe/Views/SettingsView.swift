import SwiftUI

/// 設定視窗。這一版是空的，存在的目的只是讓 Cmd + , 打得開。
///
/// 真正的內容分成「一般」與「聲音」兩個頁籤，見 T5（#6）。
struct SettingsView: View {
    private enum Layout {
        static let width: CGFloat = 420
        static let height: CGFloat = 160
        static let spacing: CGFloat = 8
    }

    var body: some View {
        VStack(spacing: Layout.spacing) {
            Text(WipeText.settingsPlaceholderTitle.localizedKey, bundle: .wipe)
                .font(.headline)
            Text(WipeText.settingsPlaceholderDetail.localizedKey, bundle: .wipe)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(width: Layout.width, height: Layout.height)
    }
}

#Preview {
    SettingsView()
}
