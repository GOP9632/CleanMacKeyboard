import AppKit
import IOKit

/// 真實世界那一頭的機器訊號來源。
///
/// 蓋子那一條問的是 IOKit：`IOPMrootDomain` 上有一個 `AppleClamshellState`
/// 屬性，闔上是 `true`。喚醒那一條聽的是 `NSWorkspace` 的
/// `didWakeNotification`。兩條都不需要任何系統授權。
///
/// 蓋子刻意用**定期去問**而不是註冊事件通知。IOKit 那邊確實有
/// `kIOPMMessageClamshellStateChange` 可以註冊，但那個常數是 C 巨集算出來的，
/// Swift 這邊拿不到，只能自己把數值抄進來；抄錯或哪天變了都不會有編譯錯誤，
/// 只會安靜地不通知。闔蓋解鎖是保險，它安靜地失效等於使用者被鎖在外面，
/// 所以這裡選代價看得見的那一種：每半秒讀一次登錄檔屬性，而且只在清潔模式
/// 期間讀（見 `docs/seams.md`）。
///
/// 一連串狀態怎麼變成一次「剛剛闔上」，是 `LidCloseDetector` 的事。那一段有
/// 測試，這一段沒有：這裡剩下的就只是問系統跟掛計時器。
@MainActor
final class SystemMachineSignalSource: MachineSignalSource {
    var onSignal: ((MachineSignal) -> Void)?

    private var lidTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var lid = LidCloseDetector(lidIsClosed: false)

    /// 多久問一次蓋子。
    ///
    /// 半秒是「使用者闔上蓋子之後感覺得到馬上就解開了」與「不要為了一個保險
    /// 一直吵 IOKit」之間的取捨。這個延遲不影響安全性：真正在攔截的是輸入
    /// 攔截器，晚半秒解除不會讓任何按鍵漏出去。
    static let lidPollInterval: TimeInterval = 0.5

    func start() {
        // 重複呼叫不可以裝上第二組監看，否則一次闔蓋會送出兩個訊號。
        guard lidTimer == nil else { return }

        lid = LidCloseDetector(lidIsClosed: Self.readLidIsClosed() ?? false)

        // 用 `Timer(timeInterval:)` 自己加進 run loop，而不是 `scheduledTimer`：
        // 後者只會跑在預設模式，使用者按著選單不放的時候計時器會停掉。
        let timer = Timer(timeInterval: Self.lidPollInterval, repeats: true) { [weak self] _ in
            // 計時器掛在主 run loop 上，所以這個區塊一定在主執行緒被呼叫，
            // 只是它的型別上沒有寫出來。
            MainActor.assumeIsolated { self?.pollLid() }
        }
        RunLoop.main.add(timer, forMode: .common)
        lidTimer = timer

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // 上一行指定了 `.main`，所以這個區塊也一定在主執行緒上。
            MainActor.assumeIsolated { self?.onSignal?(.systemWoke) }
        }
    }

    func stop() {
        lidTimer?.invalidate()
        lidTimer = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
    }

    /// 問一次蓋子。
    private func pollLid() {
        guard let isClosed = Self.readLidIsClosed() else { return }
        guard lid.observe(lidIsClosed: isClosed) else { return }
        onSignal?(.lidClosed)
    }

    /// 現在蓋子是不是闔著的。沒有蓋子的機型（例如 Mac mini）回傳 `nil`。
    private static func readLidIsClosed() -> Bool? {
        let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard root != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(root) }

        let property = IORegistryEntryCreateCFProperty(
            root,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        )
        return property?.takeRetainedValue() as? Bool
    }

    deinit {
        // 這裡不能碰 `lid`（deinit 不在 main actor 上），但計時器與觀察者一定
        // 要拆掉，否則它們會抱著一個死掉的物件。
        lidTimer?.invalidate()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }
}
