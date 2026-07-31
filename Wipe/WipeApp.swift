import SwiftUI

@main
struct WipeApp: App {
    /// 使用者的設定，存在硬碟上的那一份。
    ///
    /// 設定視窗改它，控制器讀它，所以它必須是同一個實體：兩邊各拿一份的話，
    /// 使用者改完設定得重開 app 才會生效。
    @State private var store: WipeSettingsStore

    /// 整個 app 只有一個清潔流程控制器，組裝在這裡。
    ///
    /// 現在插的是乾跑那一組替身：時鐘與音效是真的，輸入攔截器什麼都不做，
    /// 所以整個階段流程跑得完，但不會真的鎖住鍵盤。接上真正的攔截是 #11，
    /// 換掉的只有這一行裡的那個替身（見 docs/seams.md）。
    @State private var controller: CleaningFlowController

    init() {
        let store = WipeSettingsStore()
        _store = State(initialValue: store)
        _controller = State(initialValue: .dryRun(settings: store))
    }

    // 這裡刻意沒有 tint。強調色由資源目錄裡的全域強調色資源決定
    // （見 Config/Wipe.xcconfig 與 WipeColor.globalAccentAssetName），
    // 這樣每一個場景都吃得到同一個固定青色，不會漏掉哪一個。
    var body: some Scene {
        // 用 Window 而不是 WindowGroup：Wipe 只有一個常駐視窗，
        // 不需要「新增視窗」，也不需要多開一份。
        Window(WipeText.appName.localizedKey, id: Self.mainWindowID) {
            MainWindowView(controller: controller)
        }
        .windowResizability(.contentSize)

        // 真機驗證用的診斷視窗（見 T2，#3）。它不隨 app 啟動打開，
        // 使用者要自己從「視窗」選單叫出來。
        //
        // 只在 Debug 建置裡存在。這不是產品的一部分：「左右 Command 分不分得開」
        // 有了答案之後整塊會被拆掉，在那之前也不該出現在任何交出去的建置裡。
        #if DEBUG
        Window(WipeText.diagnosticsWindowTitle.localizedKey, id: Self.keyboardDiagnosticsWindowID) {
            KeyboardDiagnosticsView()
        }
        #endif

        // 這個場景就是 Cmd + , 的來源。
        Settings {
            SettingsView(store: store)
        }
    }

    static let mainWindowID = "main"
    static let keyboardDiagnosticsWindowID = "keyboard-diagnostics"
}
