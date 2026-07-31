import Foundation

/// 設定畫面給使用者選的那幾個值，以及每一個時刻在畫面上的名字。
///
/// 選項清單跟 `WipeSettings` 的範圍是兩回事：範圍說的是「哪些值是合法的」，
/// 這裡說的是「我們願意讓使用者從哪幾個裡面挑」。兩者分開的理由是逾時：
/// 範圍的下限低到 30 秒是為了開發版的預設值，但正式版不該把 30 秒端到
/// 使用者面前。
///
/// 它擺在 Flow 而不是 Views，因為 `WipeSettingsStore` 讀檔的時候要用到它
/// （見 `nearestTimeout(to:)`）。它本身不是視圖，所以測得到，而逾時的選項
/// 清單是 ADR-0002 的守門人，值得逐項檢查（見 `SettingsOptionsTests`）。
enum SettingsOptions {
    /// 逾時可以選的長度。
    ///
    /// 這是 `WipeSettings.timeoutSecondsRange` 的一個子集合，最長 15 分鐘，
    /// 而且**沒有**「關閉」或「永不」那一項可以選。清單本身就是 ADR-0002
    /// 在設定畫面上的樣子：型別上沒有 nil 可以填，畫面上也沒有格子可以點。
    static let timeoutSeconds: [TimeInterval] = {
        var options: [TimeInterval] = [60, 2 * 60, 3 * 60, 5 * 60, 10 * 60, 15 * 60]
        #if DEBUG
        // 開發版的預設值是 30 秒，選單裡沒有它的話，讀檔時會被靠成一分鐘。
        // 這一項不會出現在交出去的建置裡。
        options.insert(30, at: 0)
        #endif
        return options
    }()

    /// 把一個秒數對到選項清單裡最接近的一項。
    ///
    /// 存下來的值不一定剛好是清單裡的某一項：可能來自舊版本，也可能是
    /// Debug 建置存下的 30 秒被 Release 建置讀到。
    ///
    /// 這件事在**讀檔的時候**就做掉，不是等到畫面上才遮。選單顯示不出來的值
    /// 只會變成空白，但真正危險的是「畫面寫著一分鐘、實際三十秒就跳」。
    /// 逾時是保險，它的數字說一套做一套比顯示成空白嚴重得多。
    ///
    /// 剛好卡在兩項中間時靠短的那一邊。清單是由短到長排的，而 `min(by:)`
    /// 遇到一樣近的會留著先看到的那個，所以這個行為是免費的。方向也是對的：
    /// 保險早一點跳比晚一點跳安全。
    static func nearestTimeout(to seconds: TimeInterval) -> TimeInterval {
        timeoutSeconds.min { abs($0 - seconds) < abs($1 - seconds) } ?? seconds
    }

    /// 每一個時刻在設定畫面上的名字。
    ///
    /// `WipeSound` 是控制器的詞彙，不認識畫面，所以對照表放在這裡。
    /// 用 switch 而不是字典是刻意的：日後多一個時刻，這裡會編不過，
    /// 不會靜悄悄地少一列。
    static func soundLabel(for sound: WipeSound) -> WipeText {
        switch sound {
        case .preparingTick: .settingsSoundPreparingTick
        case .locked: .settingsSoundLocked
        case .unlockGestureDetected: .settingsSoundUnlockGestureDetected
        case .unlockGestureReset: .settingsSoundUnlockGestureReset
        case .unlocked: .settingsSoundUnlocked
        case .timedOut: .settingsSoundTimedOut
        case .refused: .settingsSoundRefused
        }
    }
}
