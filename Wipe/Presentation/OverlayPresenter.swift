import AppKit
import SwiftUI

/// 讓遮蔽層跟著清潔流程走：清潔中鋪出去，離開清潔模式收回來。
///
/// 它刻意**不**掛在主視窗的視圖階層上，而是站在 `WipeApp` 手上直接盯著控制器。
/// 這一點是整個遮蔽層最要緊的一個決定：遮蔽層會把主視窗整個蓋住，而被完全
/// 蓋住的視窗 AppKit 會停掉它的繪製更新。收回的指令若要經過那個視窗重畫一次
/// 才送得出來，就變成「它蓋住了唯一能把它收掉的東西」：逾時解鎖明明已經解開，
/// 畫面上那片黑還在，使用者看不到任何東西，只能強制結束 Wipe。
///
/// 站在外面還有第二個好處：主視窗被關掉也不影響遮蔽層。遮蔽層那一種呈現方式
/// 底下主視窗不做任何處置，關閉鈕是活的（見 `CONTEXT.md` 的遮蔽層），關掉之後
/// 使用者剩下的狀態來源就是遮蔽層自己。
///
/// 這一層很薄：要不要鋪的判斷在 `OverlayVisibility`，真的開視窗在
/// `OverlayWindows`，這裡只負責把控制器的變動接到那兩者中間。
@MainActor
final class OverlayPresenter {
    private let controller: CleaningFlowController
    private let windows: OverlayWindows

    init(controller: CleaningFlowController) {
        self.controller = controller
        self.windows = OverlayWindows {
            // 每一個螢幕各一份。控制器是 `@Observable` 的，所以環上會動的東西
            // 由 SwiftUI 自己重畫，不必經過這裡。遮蔽層自己沒有被誰蓋住，
            // 它的重畫不受上面說的那件事影響。
            NSHostingView(rootView: OverlayView(controller: controller))
        }
    }

    /// 開始盯著控制器。**要有人叫它一次**，否則遮蔽層永遠不會出現。
    func start() {
        synchronizeAndObserve()
    }

    /// 現在鋪著的那幾個視窗。
    var openWindows: [NSWindow] { windows.windows }

    /// 讀一次現在該不該鋪，順便掛上「下次變動叫我」。
    private func synchronizeAndObserve() {
        let engaged = withObservationTracking {
            OverlayVisibility.isEngaged(
                during: controller.stage,
                presentation: controller.settings.screenPresentation
            )
        } onChange: { [weak self] in
            // 這個區塊在值真的變之前被叫，這裡讀到的還是舊的，所以排到下一輪
            // 再讀一次。它同時是重新掛回去：一次註冊只認一次變動。
            Task { @MainActor [weak self] in
                self?.synchronizeAndObserve()
            }
        }
        windows.setEngaged(engaged)
    }
}
