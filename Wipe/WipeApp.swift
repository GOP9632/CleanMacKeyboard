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
    /// 預設插的是真的攔截那一組（見 `CleaningFlowController.live(settings:)`）。
    /// 開發建置可以用啟動參數 `-WipeDryRun YES` 換回乾跑那一組，換掉的只有
    /// 插在接縫上的那幾個替身，控制器本身一行都不用改（見 docs/seams.md）。
    @State private var controller: CleaningFlowController

    /// 輔助使用授權的閘門。主視窗裡放圓環還是授權引導畫面由它決定。
    ///
    /// 它跟控制器並排，不是控制器的一部分：授權是「畫面要不要出現」的閘門，
    /// 發生在流程之前（見 `AuthorizationGate`）。
    @State private var gate: AuthorizationGate

    init() {
        let store = WipeSettingsStore()
        _store = State(initialValue: store)
        // 乾跑與真攔截的取捨只在這一行上做，而且只在啟動時做一次：
        // 跑到一半換掉攔截器，等於在使用者閉著眼睛擦機器的時候抽掉他腳下的地板。
        _controller = State(
            initialValue: WipeLaunchOptions.dryRunIsEnabled()
                ? .dryRun(settings: store)
                : .live(settings: store)
        )
        _gate = State(initialValue: .system())
    }

    // 這裡刻意沒有 tint。強調色由資源目錄裡的全域強調色資源決定
    // （見 Config/Wipe.xcconfig 與 WipeColor.globalAccentAssetName），
    // 這樣每一個場景都吃得到同一個固定青色，不會漏掉哪一個。
    var body: some Scene {
        // 用 Window 而不是 WindowGroup：Wipe 只有一個常駐視窗，
        // 不需要「新增視窗」，也不需要多開一份。
        Window(WipeText.appName.localizedKey, id: Self.mainWindowID) {
            MainWindowView(controller: controller, gate: gate)
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
