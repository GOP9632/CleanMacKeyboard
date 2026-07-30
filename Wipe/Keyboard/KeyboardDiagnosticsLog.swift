import Foundation
import Observation

/// 診斷紀錄裡的一行。
struct KeyboardDiagnosticsEntry: Identifiable, Equatable {
    /// 遞增的序號。同時是畫面自動滾動用的識別碼，所以清空之後不會重來。
    let sequence: Int
    let date: Date
    let reading: KeyboardEventReading

    var id: Int { sequence }

    /// 這一行顯示出來的樣子：時間，加上這次判讀本身的排版。
    var text: String {
        Self.timeFormatter.string(from: date) + "  " + reading.diagnosticText
    }

    /// 固定格式的時間，跟著資料走而不是跟著使用者的地區設定走。
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

/// 真機驗證用的診斷紀錄。
///
/// 存在的目的只有一個：在真的鍵盤上回答「左 Command 和右 Command 分不分得開」。
/// 它不是產品功能，答案拿到之後這一整塊會被拆掉。
@MainActor
@Observable
final class KeyboardDiagnosticsLog {
    /// 保留的筆數上限。真機驗證會按上幾百次，紀錄不可以無限成長。
    let capacity: Int

    private(set) var entries: [KeyboardDiagnosticsEntry] = []

    /// 已經發出去的序號。刻意不隨著清空歸零：序號同時是自動滾動用的識別碼，
    /// 撞號會讓畫面滾到錯的一行。
    private var nextSequence = 1

    init(capacity: Int = 200) {
        self.capacity = max(1, capacity)
    }

    /// 最新一筆的識別碼。畫面靠它決定要滾到哪裡。
    var latestEntryID: KeyboardDiagnosticsEntry.ID? { entries.last?.id }

    func record(_ reading: KeyboardEventReading, at date: Date = Date()) {
        entries.append(
            KeyboardDiagnosticsEntry(sequence: nextSequence, date: date, reading: reading)
        )
        nextSequence += 1
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
        }
    }

    func clear() {
        entries.removeAll()
    }
}
