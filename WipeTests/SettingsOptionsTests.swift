import Foundation
import Testing

@testable import Wipe

/// 設定畫面本身用眼睛驗比較划算（見 `docs/seams.md`），但「選單裡有沒有一個
/// 拆掉保險的選項」用眼睛看不出來，而且錯了很嚴重。那份清單住在這裡，有測試。
@Suite("設定畫面的選項")
struct SettingsOptionsTests {
    @Test("逾時的每一個選項都在合法範圍內", arguments: SettingsOptions.timeoutSeconds)
    func everyTimeoutOptionIsInRange(_ seconds: TimeInterval) {
        #expect(WipeSettings.timeoutSecondsRange.contains(seconds))
    }

    @Test("逾時最長 15 分鐘")
    func longestTimeoutOptionIsFifteenMinutes() throws {
        let longest: TimeInterval = try #require(SettingsOptions.timeoutSeconds.max())
        #expect(longest == 15 * 60)
        // 選單的上限就是型別上的上限，兩邊不可以各走各的。
        #expect(longest == WipeSettings.timeoutSecondsRange.upperBound)
    }

    @Test("逾時沒有「關閉」或「永不」可以選")
    func thereIsNoNeverOption() {
        // 清單裡沒有零、沒有負數、沒有無限大，型別上也沒有 nil 可以填。
        // 這是 ADR-0002 在設定畫面上的樣子。
        for seconds in SettingsOptions.timeoutSeconds {
            #expect(seconds > 0)
            #expect(seconds.isFinite)
        }
        #expect(!SettingsOptions.timeoutSeconds.isEmpty)
    }

    @Test("逾時的選項由短到長排好，而且沒有重複")
    func timeoutOptionsAreSortedAndUnique() {
        #expect(SettingsOptions.timeoutSeconds == SettingsOptions.timeoutSeconds.sorted())
        #expect(Set(SettingsOptions.timeoutSeconds).count == SettingsOptions.timeoutSeconds.count)
    }

    @Test("預設的逾時就在選單裡")
    func theDefaultTimeoutIsSelectable() {
        // 不在的話，一打開設定就會看到自己的設定被悄悄改成別的值。
        #expect(SettingsOptions.timeoutSeconds.contains(WipeSettings.defaultTimeoutSeconds))
    }

    @Test("選單以外的值會靠到最接近的一項")
    func offListValuesSnapToTheNearestOption() {
        // 例如舊版本存下的 4 分 10 秒：選單裡沒有它，靠到 5 分鐘而不是變成空白。
        #expect(SettingsOptions.nearestTimeout(to: 4 * 60 + 10) == 5 * 60)
        #expect(SettingsOptions.nearestTimeout(to: 61) == 60)
        // 剛好卡在兩項中間時靠短的那一邊：保險早一點跳比晚一點跳安全。
        #expect(SettingsOptions.nearestTimeout(to: 4 * 60) == 3 * 60)
        // 靠過去之後仍然是選單裡的一項。
        #expect(SettingsOptions.timeoutSeconds.contains(SettingsOptions.nearestTimeout(to: 12 * 60)))
    }

    @Test("已經在選單裡的值不會被動到", arguments: SettingsOptions.timeoutSeconds)
    func valuesAlreadyOnTheListAreLeftAlone(_ seconds: TimeInterval) {
        #expect(SettingsOptions.nearestTimeout(to: seconds) == seconds)
    }

    @Test("七個時刻在設定畫面上各有各的名字")
    func everySoundHasItsOwnLabel() {
        // 兩個時刻共用同一個標籤的話，聲音那一頁會出現兩列一模一樣的字，
        // 使用者關掉的會是另一個。這種錯用眼睛掃過去看不太出來。
        let labels = WipeSound.allCases.map(SettingsOptions.soundLabel(for:))
        #expect(Set(labels).count == WipeSound.allCases.count)
    }

    @Test("讀檔時逾時會被靠到選單裡的一項")
    func loadedTimeoutIsAlwaysSelectable() {
        // 靠攏發生在讀檔，不是發生在畫面上，所以畫面顯示的數字一定就是
        // 真正生效的數字。這一條由 `WipeSettingsStoreTests` 從 store 那一頭
        // 驗，這裡守的是「靠過去之後一定落在選單裡」。
        for seconds in stride(from: 30.0, through: 15 * 60, by: 37) {
            #expect(SettingsOptions.timeoutSeconds.contains(SettingsOptions.nearestTimeout(to: seconds)))
        }
    }
}
