import AppKit

/// 清潔模式期間主視窗要一直看得見。
///
/// 這一整包都是純值：哪一個階段要生效、視窗層級提到多高、置頂期間視窗的
/// 集合行為與樣式換成什麼。它們跟 AppKit 那一頭真的怎麼套上去分開放
/// （見 `MainWindowVisibility`），所以測得到。
///
/// 遮蔽層那一種畫面呈現的對應物是 `OverlayVisibility`。兩邊只有阻止螢幕變暗
/// 是共用的，其餘各走各的。
///
/// 為什麼需要這件事：清潔模式期間鍵盤已經鎖住了，使用者沒辦法用 Cmd + Tab
/// 把視窗叫回來。這時只要有任何背景 app 跳到前景，圓環與逾時剩餘時間就被蓋掉，
/// 而那兩個東西是使用者判斷「到底鎖了沒」的唯一來源（見 #1 的 user story 14、15）。
enum CleaningVisibility {
    /// 這個階段要不要阻止螢幕因為閒置而變暗。
    ///
    /// 只有清潔中算。準備清潔期間一個事件都還沒攔，使用者的鍵盤與滑鼠都活著，
    /// 隨時可以按 Esc 反悔，沒有「被鎖住又看不到」這個處境。
    ///
    /// 這一條兩種畫面呈現底下都成立，所以它不看設定：遮蔽層也一樣要一直
    /// 看得見，而擦機器的那幾分鐘裡使用者不碰鍵盤也不碰觸控板，那正是系統
    /// 判斷閒置的依據。
    static func displaySleepIsBlocked(during stage: CleaningStage) -> Bool {
        stage == .cleaning
    }

    /// 這個階段加上這個畫面呈現，主視窗要不要置頂。
    ///
    /// 比上面那一條多看一個設定。選了遮蔽層的時候主視窗**不做任何處置**，
    /// 自然被蓋住（見 `CONTEXT.md` 的遮蔽層）：那一層自己就蓋在所有東西上面，
    /// 主視窗跟著提高層級只會變成一個沒有人看得到、卻已經被改過樣式的視窗，
    /// 回到待命還多一次還原。
    static func mainWindowIsRaised(
        during stage: CleaningStage,
        presentation: ScreenPresentation
    ) -> Bool {
        stage == .cleaning && presentation == .mainWindow
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

    /// 置頂期間的視窗樣式，從原本那一份算出來。
    ///
    /// 差別只有關閉與縮小這兩顆按鈕，它們在清潔模式期間會變灰。鍵盤鎖底下
    /// 觸控板還活著，使用者點得到它們；視窗一旦消失，畫面上就沒有狀態可看了，
    /// 而鍵盤還鎖著，他只能等逾時。那正是這一票要防的處境。
    ///
    /// 用樣式而不是把按鈕本身停用，是因為關掉視窗的路不只那顆按鈕：選單裡的
    /// 「關閉」與 Dock 圖示都走得到。樣式是同一個開關的上游，三條路一起關。
    ///
    /// 按鈕變灰確實讓視窗的外觀變了一點，跟「外觀不變」有張力
    /// （見 #1 的 user story 16）。取捨是刻意的：那幾分鐘裡整個 app 本來就不
    /// 接受操作，而一顆會讓狀態消失的按鈕跟這一票的目的直接衝突。
    static func raisedStyleMask(from original: NSWindow.StyleMask) -> NSWindow.StyleMask {
        original.subtracting([.closable, .miniaturizable])
    }

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
