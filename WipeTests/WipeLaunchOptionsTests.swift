import Foundation
import Testing

@testable import Wipe

/// 乾跑模式的開關。
///
/// 乾跑是指真的讀鍵盤、真的跑完整個流程，但不真的鎖住鍵盤。真的攔截接上去
/// 之後它仍然要留著：判定邏輯出問題時，沒有它就得冒著把自己鎖在外面的風險
/// 除錯（見 `docs/seams.md`）。
///
/// 預設是**真的攔截**。乾跑要自己開，而且只有開發建置開得起來：正式建置若
/// 跑成乾跑，畫面會寫著清潔中而鍵盤還活著，那正是這個 app 最不能發生的事。
@Suite("啟動選項")
struct WipeLaunchOptionsTests {
    /// 一個用完就丟的偏好網域，代表一次啟動。
    private static func makeDefaults() -> UserDefaults {
        let name = "WipeLaunchOptionsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("什麼都沒指定時走真的攔截")
    func realInterceptionIsTheDefault() {
        #expect(WipeLaunchOptions.dryRunIsEnabled(in: Self.makeDefaults()) == false)
    }

    @Test("啟動參數打開乾跑")
    func theLaunchArgumentTurnsDryRunOn() {
        // Xcode 的 scheme 裡加一個 `-WipeDryRun YES`，就會落在這個鍵上。
        let defaults = Self.makeDefaults()
        defaults.set(true, forKey: WipeLaunchOptions.dryRunKey)

        #expect(WipeLaunchOptions.dryRunIsEnabled(in: defaults))
    }

    @Test("明確關掉乾跑就是真的攔截")
    func theLaunchArgumentTurnsDryRunOffAgain() {
        let defaults = Self.makeDefaults()
        defaults.set(false, forKey: WipeLaunchOptions.dryRunKey)

        #expect(WipeLaunchOptions.dryRunIsEnabled(in: defaults) == false)
    }
}
