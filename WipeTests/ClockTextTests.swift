import Foundation
import Testing

@testable import Wipe

/// 時間怎麼排成文字。畫面本身用眼睛驗，但「分:秒」的補零用眼睛不一定看得到，
/// 錯了卻很難看（例如 4:5 而不是 4:05）。
@Suite("時間文字")
struct ClockTextTests {
    @Test("秒數補零，分鐘不補", arguments: [
        (0, "0:00"),
        (5, "0:05"),
        (59, "0:59"),
        (60, "1:00"),
        (65, "1:05"),
        (15 * 60, "15:00"),
    ])
    func minutesAndSeconds(_ seconds: Int, _ expected: String) {
        #expect(ClockText.minutesAndSeconds(seconds) == expected)
    }

    @Test("負數不會排出奇怪的東西")
    func negativeSecondsAreFloored() {
        #expect(ClockText.minutesAndSeconds(-1) == "0:00")
    }
}
