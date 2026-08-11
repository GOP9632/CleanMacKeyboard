import SwiftUI

/// 還沒拿到輔助使用授權時，主視窗裡放的就是這一整個畫面。
///
/// 它取代圓環，而不是站在圓環旁邊。這是刻意的：一顆可以按但按了沒用的
/// 開始按鈕，對非工程背景的使用者來說就是「這個 app 壞了」，而授權是整條
/// 流程裡最容易讓人放棄的一步，值得用一整個畫面把話講完（見 #9）。
///
/// 畫面上有兩段話是不能省的。一段是這個授權讓 Wipe 拿到什麼能力，
/// 另一段是 Wipe 只拿它來丟棄事件、不記錄也不上傳。使用者要交出的是
/// 「看得到每一次按鍵」這種等級的權限，那就得讓他有足夠的資訊自己判斷。
///
/// 這一層跟主視窗一樣薄：它只把文字排好、把按鈕轉給外面，自己不問系統
/// 也不記任何狀態。「什麼時候該顯示這個畫面」住在 `AuthorizationGate`，
/// 那裡有測試。
struct AuthorizationGuideView: View {
    /// 按下按鈕時帶使用者去系統設定。
    let openSettings: () -> Void

    private enum Layout {
        static let width: CGFloat = 380
        static let padding: CGFloat = 32
        static let spacing: CGFloat = 20
        static let noteSpacing: CGFloat = 12
        static let iconWidth: CGFloat = 18
        static let noteCornerRadius: CGFloat = 8
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            header
            Text(WipeText.authorizationSteps.localizedKey, bundle: .wipe)
            notes
            openSettingsButton
            Text(WipeText.authorizationAutoDetect.localizedKey, bundle: .wipe)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: Layout.width, alignment: .leading)
        .padding(Layout.padding)
    }

    /// 標題那一行。
    ///
    /// 圖示用強調色的青色，不用警告紅：還沒授權不是故障，只是還沒做完的
    /// 一步。紅色留給真的有問題的時候（見 ADR-0003）。
    private var header: some View {
        Label {
            Text(WipeText.authorizationTitle.localizedKey, bundle: .wipe)
                .font(.title3.weight(.semibold))
        } icon: {
            Image(systemName: "hand.raised.fill")
                .foregroundStyle(WipeColor.accent.color)
        }
    }

    /// 誠實的那兩句：拿到什麼能力，以及 Wipe 拿它來做什麼、不做什麼。
    private var notes: some View {
        VStack(alignment: .leading, spacing: Layout.noteSpacing) {
            note(.authorizationCapability, systemImage: "eye")
            note(.authorizationPromise, systemImage: "trash")
        }
        .font(.callout)
        .padding(Layout.noteSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: Layout.noteCornerRadius))
    }

    private func note(_ text: WipeText, systemImage: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Layout.noteSpacing) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: Layout.iconWidth, alignment: .center)
            Text(text.localizedKey, bundle: .wipe)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var openSettingsButton: some View {
        Button(action: openSettings) {
            Text(WipeText.authorizationOpenSettings.localizedKey, bundle: .wipe)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        // 這是整個畫面唯一的動作，所以它同時吃 Return 鍵。
        .keyboardShortcut(.defaultAction)
    }
}

#Preview {
    AuthorizationGuideView(openSettings: {})
}
