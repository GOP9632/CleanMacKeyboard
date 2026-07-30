import SwiftUI

@main
struct WipeApp: App {
    // 這裡刻意沒有 tint。強調色由資源目錄裡的全域強調色資源決定
    // （見 Config/Wipe.xcconfig 與 WipeColor.globalAccentAssetName），
    // 這樣每一個場景都吃得到同一個固定青色，不會漏掉哪一個。
    var body: some Scene {
        // 用 Window 而不是 WindowGroup：Wipe 只有一個常駐視窗，
        // 不需要「新增視窗」，也不需要多開一份。
        Window(WipeText.appName.localizedKey, id: Self.mainWindowID) {
            MainWindowView()
        }
        .windowResizability(.contentSize)

        // 這個場景就是 Cmd + , 的來源，內容目前是空的（見 T5，#6）。
        Settings {
            SettingsView()
        }
    }

    static let mainWindowID = "main"
}
