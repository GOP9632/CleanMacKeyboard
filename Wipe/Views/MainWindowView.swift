import SwiftUI

/// app 唯一的常駐視窗的內容。
struct MainWindowView: View {
    private enum Layout {
        static let padding: CGFloat = 44
    }

    var body: some View {
        // 這一版只顯示待命。點一下進入清潔模式是清潔流程控制器的事（T3，#4），
        // 所以這裡刻意不傳 onActivate，圓環現在不可點擊：寧可先沒有按鈕，
        // 也不要一顆按得下去但什麼都不會發生的按鈕。
        RingView(phase: .standby)
            .padding(Layout.padding)
            .frame(
                minWidth: RingMetrics.diameter + Layout.padding * 2,
                minHeight: RingMetrics.diameter + Layout.padding * 2
            )
    }
}

#Preview {
    MainWindowView()
}
