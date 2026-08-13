import Testing

@testable import Wipe

/// 清潔模式期間螢幕不可以因為閒置而變暗或關閉。
///
/// 這一組守的是那份宣告的開關有沒有成對：漏掉收回那一次，使用者的螢幕就再也
/// 不會自己變暗，直到他發現並重開 Wipe 為止。這是一個會跟著使用者跑出清潔模式
/// 的副作用，比看不到圓環還久。
///
/// 宣告真的擋得住變暗、而且真的不影響闔蓋睡眠，只有真機驗得到，那是手動驗收
/// 清單的第 6 項。這裡只驗開關本身。
@Suite("阻止螢幕閒置變暗")
@MainActor
struct DisplaySleepBlockTests {
    @Test("一開始沒有宣告")
    func startsQuiet() {
        // 待命時 Wipe 就是一個普通 app，不該干涉使用者的節能設定。
        #expect(DisplaySleepBlock().isEngaged == false)
    }

    @Test("要求之後宣告生效")
    func engages() {
        let block = DisplaySleepBlock()
        block.setEngaged(true)
        #expect(block.isEngaged)
        block.setEngaged(false)
    }

    @Test("收回之後宣告消失")
    func releases() {
        let block = DisplaySleepBlock()
        block.setEngaged(true)
        block.setEngaged(false)
        #expect(block.isEngaged == false)
    }

    @Test("重複要求同一個狀態不會留下第二份宣告")
    func repeatedRequestsStayBalanced() {
        // 畫面那一層是每次階段變動就整組重算一次，所以同一個狀態會被要求很多次
        // （見 `MainWindowVisibility`）。每一次都真的去宣告一份的話，收回一次
        // 只收得回最後那一份，其餘的會留到 app 結束。
        let block = DisplaySleepBlock()
        block.setEngaged(true)
        block.setEngaged(true)
        block.setEngaged(false)
        #expect(block.isEngaged == false)
        // 收回之後再收一次不會出事，也不會把狀態弄成別的東西。
        block.setEngaged(false)
        #expect(block.isEngaged == false)
    }
}
