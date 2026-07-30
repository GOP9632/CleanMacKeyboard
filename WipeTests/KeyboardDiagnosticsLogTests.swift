import Foundation
import Testing

@testable import Wipe

/// 診斷紀錄要能在真機上一直開著不出事，所以它有筆數上限；
/// 也要能清空重來，因為驗證時會反覆按很多次。
@Suite("診斷紀錄")
@MainActor
struct KeyboardDiagnosticsLogTests {
    @Test("依序記下每一次事件")
    func recordsInOrder() {
        let log = KeyboardDiagnosticsLog()
        log.record(makeReading(KeyboardFlags.leftCommand))
        log.record(makeReading(KeyboardFlags.rightCommand, keyCode: 54))

        #expect(log.entries.count == 2)
        #expect(log.entries[0].reading.leftCommandIsDown)
        #expect(log.entries[1].reading.rightCommandIsDown)
    }

    @Test("每一筆有各自的序號，序號遞增")
    func entriesAreIdentifiable() {
        let log = KeyboardDiagnosticsLog()
        log.record(makeReading(KeyboardFlags.leftCommand))
        log.record(makeReading(KeyboardFlags.leftCommand))

        let sequences = log.entries.map(\.sequence)
        #expect(sequences == sequences.sorted())
        #expect(Set(sequences).count == sequences.count)
    }

    @Test("超過上限時丟掉最舊的，留下最新的")
    func capsTheNumberOfEntries() {
        let capacity = 5
        let log = KeyboardDiagnosticsLog(capacity: capacity)
        for keyCode in UInt16(0)..<UInt16(capacity * 3) {
            log.record(makeReading(KeyboardFlags.leftCommand, keyCode: keyCode))
        }

        #expect(log.entries.count == capacity)
        // 留下來的必須是最後那幾筆：驗證時看的永遠是剛剛按的那一下。
        #expect(log.entries.first?.reading.keyCode == UInt16(capacity * 2))
        #expect(log.entries.last?.reading.keyCode == UInt16(capacity * 3 - 1))
    }

    @Test("清空之後沒有任何一筆")
    func clears() {
        let log = KeyboardDiagnosticsLog()
        log.record(makeReading(KeyboardFlags.leftCommand))
        log.clear()

        #expect(log.entries.isEmpty)
    }

    @Test("清空之後序號繼續往前，不會跟舊的撞號")
    func sequenceKeepsGoingAfterClear() throws {
        // 序號同時是自動滾動用的識別碼。重複的識別碼會讓畫面滾到錯的一行。
        let log = KeyboardDiagnosticsLog()
        log.record(makeReading(KeyboardFlags.leftCommand))
        let before = try #require(log.entries.last?.sequence)
        log.clear()
        log.record(makeReading(KeyboardFlags.leftCommand))
        let after = try #require(log.entries.last?.sequence)

        #expect(after > before)
    }

    @Test("最新一筆的識別碼給自動滾動用")
    func exposesTheLatestEntry() {
        let log = KeyboardDiagnosticsLog()
        #expect(log.latestEntryID == nil)

        log.record(makeReading(KeyboardFlags.leftCommand))
        #expect(log.latestEntryID == log.entries.last?.id)
    }

    @Test("每一行是時間加上那次判讀")
    func entryTextIsTimeThenReading() {
        let log = KeyboardDiagnosticsLog()
        let reading = makeReading(KeyboardFlags.leftCommand)
        log.record(reading, at: Date(timeIntervalSince1970: 0))

        let entry = log.entries[0]
        #expect(entry.date == Date(timeIntervalSince1970: 0))
        #expect(entry.text.hasSuffix(reading.diagnosticText))
        // 時間在前面，兩次事件的先後才看得出來。
        #expect(entry.text.hasPrefix(reading.diagnosticText) == false)
    }
}
