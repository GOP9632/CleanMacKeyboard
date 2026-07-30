import Foundation

/// Wipe 會出聲的七個時刻。
///
/// 這是音效接縫的全部詞彙。測試不需要聽聲音，只需要確認「在對的時刻叫了
/// 對的那一聲」，所以這裡是時刻，不是檔名。哪一個時刻配哪一個系統音效，
/// 是 `SystemSoundOutput` 的事。
enum WipeSound: String, CaseIterable {
    /// 準備清潔的緩衝倒數，每一秒一聲。
    case preparingTick

    /// 真正鎖上的那一刻。這一聲就是「可以開始擦了」的許可。
    case locked

    /// 偵測到解鎖手勢。使用者看不到螢幕時，它代表「認到了，繼續按住」。
    case unlockGestureDetected

    /// 解鎖手勢的計時被歸零。
    case unlockGestureReset

    /// 解鎖成功。
    case unlocked

    /// 逾時自動解除。
    ///
    /// 必須與 `unlocked` 不同，否則使用者分不出是自己解開的還是保險跳掉了。
    case timedOut

    /// 拒絕進入清潔模式。
    case refused
}

/// 清潔流程控制器的音效輸出。
///
/// 控制器只說「現在該響哪一聲」，不知道那是系統音效還是一個什麼都不做的
/// 替身。哪幾聲要靜音是設定的事（見 #6），不是控制器的事。
@MainActor
protocol SoundOutput: AnyObject {
    func play(_ sound: WipeSound)
}
