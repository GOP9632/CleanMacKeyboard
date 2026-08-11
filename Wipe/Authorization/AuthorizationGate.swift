import Foundation
import Observation

/// 主視窗裡放圓環還是授權引導畫面，由這個閘門決定。
///
/// 它做的事只有一件：定期問一次現在有沒有輔助使用授權。使用者去系統設定
/// 打完勾之後，畫面自己會換回圓環，不需要重開 app，而那正是這一整段流程
/// 最容易斷掉的地方（見 #9）。
///
/// **它兩個方向都認。**授權事後被收回時閘門會再關上，因為那時使用者確實
/// 是一個「未授權的使用者」，而未授權的人不該看到一顆可以按但按了沒用的
/// 開始按鈕。代價是問系統這件事一直在跑，那是一個很便宜的查詢，換來的是
/// 畫面不會停在一個過期的答案上。
///
/// 什麼時候真的把畫面換掉是視圖那一層的事：清潔模式進行中不換
/// （見 `MainWindowView`），否則等於在使用者閉著眼睛擦機器的時候抽掉他
/// 唯一的狀態來源。
///
/// 它不是清潔流程控制器的一部分。授權是「畫面要不要出現」的閘門，發生在
/// 流程之前；控制器管的是進了畫面之後的狀態機。也因為分開，控制器在待命時
/// 可以照樣把時鐘停掉，不必為了盯著一個授權旗標一直空轉。
@MainActor
@Observable
final class AuthorizationGate {
    /// 現在可不可以顯示圓環。
    private(set) var isAuthorized: Bool

    @ObservationIgnored private let authorization: AccessibilityAuthorization

    /// 這個閘門自己的時鐘，跟控制器那一個是不同的實體。
    ///
    /// 時鐘接縫的約定是「重複呼叫是換掉前一個」（見 `WipeClock`），兩邊共用
    /// 同一個實體的話會互相把對方的計時器拆掉。
    @ObservationIgnored private let clock: WipeClock

    init(authorization: AccessibilityAuthorization, clock: WipeClock) {
        self.authorization = authorization
        self.clock = clock
        self.isAuthorized = authorization.isTrusted
        clock.startTicking(every: Self.pollInterval) { [weak self] in
            self?.poll()
        }
    }

    /// app 跑起來時插的那一組：真的問系統，真的開系統設定。
    static func system() -> AuthorizationGate {
        AuthorizationGate(authorization: SystemAccessibilityAuthorization(), clock: SystemClock())
    }

    /// 預覽用：當作授權已經給了。
    ///
    /// 預覽跑的那個 process 通常沒有輔助使用授權，用真貨的話每一個主視窗
    /// 的預覽看到的都會是引導畫面，圓環反而預覽不到。引導畫面自己有一份預覽。
    static func granted() -> AuthorizationGate {
        AuthorizationGate(authorization: GrantedAuthorization(), clock: SystemClock())
    }

    /// 帶使用者去系統設定的「輔助使用」那一頁。引導畫面上那顆按鈕叫的是這個。
    func openSettings() {
        authorization.openSettings()
    }

    private func poll() {
        isAuthorized = authorization.isTrusted
    }

    /// 多久問一次系統。
    ///
    /// 使用者打完勾之後正盯著引導畫面等它反應，所以間隔要短到讓人覺得是
    /// 「立刻」。這個查詢很便宜，一秒一次的代價遠低於讓使用者以為 Wipe
    /// 沒有偵測到。
    static let pollInterval: TimeInterval = 1

    /// 只給預覽用的替身：永遠說有授權，帶路那一步什麼都不做。
    private final class GrantedAuthorization: AccessibilityAuthorization {
        let isTrusted = true
        func openSettings() {}
    }
}
