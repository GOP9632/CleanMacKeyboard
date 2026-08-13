import AppKit

/// 清潔模式期間主視窗要一直看得見。
///
/// 這一整包只有三個值：哪一個階段要生效、視窗層級提到多高、置頂期間視窗的
/// 集合行為換成什麼。它們是純值，跟 AppKit 那一頭真的怎麼套上去分開放
/// （見 `MainWindowVisibility`），所以測得到。
///
/// 為什麼需要這件事：清潔模式期間鍵盤已經鎖住了，使用者沒辦法用 Cmd + Tab
/// 把視窗叫回來。這時只要有任何背景 app 跳到前景，圓環與逾時剩餘時間就被蓋掉，
/// 而那兩個東西是使用者判斷「到底鎖了沒」的唯一來源（見 #1 的 user story 14、15）。
enum CleaningVisibility {
    /// 這個階段要不要讓畫面一直看得見。
    ///
    /// 只有清潔中算。準備清潔期間一個事件都還沒攔，使用者的鍵盤與滑鼠都活著，
    /// 隨時可以按 Esc 反悔，沒有「被鎖住又看不到」這個處境。
    ///
    /// 這裡刻意只看階段，不看畫面呈現的設定。遮蔽層還沒有被畫出來（#14），
    /// 所以今天選了遮蔽層的使用者看到的仍然是主視窗，那時置頂照樣是對的。
    /// #14 落地時這一段要拆成兩半：阻止螢幕變暗兩種呈現方式底下都成立，
    /// 但主視窗的置頂不成立，遮蔽層啟用時主視窗不做任何處置，自然被蓋住
    /// （見 `CONTEXT.md` 的遮蔽層）。
    static func isEngaged(during stage: CleaningStage) -> Bool {
        stage == .cleaning
    }

    /// 置頂時的視窗層級。
    ///
    /// 用 `.screenSaver` 而不是 `.floating`，因為要蓋得過的不只是一般視窗：
    /// 全螢幕 app、選單列與 Dock 都各有自己的層級，`.floating` 只贏得了第一個。
    ///
    /// 這個層級同時會蓋過系統自己彈出來的對話框。那是可以接受的：清潔模式期間
    /// 輸入本來就被攔著，那些對話框在這幾分鐘裡按不動也是一樣的（見 `CONTEXT.md`
    /// 的不變條件），而逾時一到畫面就還原了。
    static let raisedWindowLevel: NSWindow.Level = .screenSaver

    /// 置頂期間的視窗集合行為，從原本那一份算出來。
    ///
    /// 只調層級是不夠的。全螢幕 app 各自佔一個 Space，而普通視窗只待在自己
    /// 原本那個 Space 裡；使用者切到全螢幕 app，主視窗連同它的高層級一起被
    /// 留在後面，畫面上什麼都看不到。
    ///
    /// 吃原本那一份再改，而不是直接給一組固定值：清潔模式期間主視窗維持原來的
    /// 樣子（見 #1 的 user story 16），順手把其他行為改掉也算變。回到待命時
    /// 還原的也是原本那一份（見 `MainWindowVisibility`）。
    static func raisedCollectionBehavior(
        from original: NSWindow.CollectionBehavior
    ) -> NSWindow.CollectionBehavior {
        var raised = original
        // 這兩個各自跟下面要加的那一個互斥。同時帶著的話 AppKit 會自己挑一個，
        // 挑到哪一個沒有保證，那就是安靜地失效。
        raised.remove([.fullScreenPrimary, .moveToActiveSpace])
        raised.insert([.canJoinAllSpaces, .fullScreenAuxiliary])
        return raised
    }
}
