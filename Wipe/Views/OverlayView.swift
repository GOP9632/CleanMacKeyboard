import SwiftUI

/// 一個螢幕上的遮蔽層長什麼樣子：一整片深色，圓環在正中央。
///
/// 每一個螢幕各一份，因為使用者擦的時候眼睛可能在任何一個螢幕上，
/// 只有主螢幕看得到狀態的話，另一個螢幕就只是一片黑。
///
/// 深色是這裡刻意固定的，不跟隨系統：這一層的用途之一是讓使用者看見螢幕上的
/// 灰塵（見 #1 的 user story 20、21）。固定的方式是視窗那一頭指定深色外觀
/// 加上這裡的底色兩種外觀同一個值（見 `OverlayVisibility`）。
struct OverlayView: View {
    let controller: CleaningFlowController

    var body: some View {
        ZStack {
            OverlayVisibility.backdropColor
            // 圓環不給 `onActivate`，所以它不可點擊。清潔中本來就不接受點擊
            // （見 `RingPhase.allowsActivation`），這裡再斷一次是因為遮蔽層
            // 的第二個用途正是擋下誤點，它自己不該是那個被誤點的東西。
            CleaningStatusView(controller: controller)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

#Preview {
    OverlayView(controller: .dryRun())
        .frame(width: 600, height: 400)
}
