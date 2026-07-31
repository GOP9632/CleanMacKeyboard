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

    // MARK: - 帶單位的長度（設定畫面用）

    static let english = Locale(identifier: "en")
    static let chinese = Locale(identifier: "zh-Hant")

    @Test("整分鐘不會拖著一個「0 秒」")
    func wholeMinutesHideTheZeroSeconds() {
        // 交給 Foundation 排的目的之一就是這件事。設定畫面上的「5 分鐘」
        // 若排成「5 分鐘 0 秒」會很難看。
        let text = ClockText.duration(5 * 60, in: Self.english)
        #expect(!text.contains("0 second"))
        #expect(text != ClockText.duration(30, in: Self.english))
    }

    @Test("跟著語言走，不會中英混雜")
    func followsTheGivenLocale() {
        #expect(ClockText.duration(30, in: Self.english) != ClockText.duration(30, in: Self.chinese))
    }

    @Test("單複數交給 Foundation，不會排出 1 minutes")
    func pluralsAreHandled() {
        // 自己拼字串的話，字串目錄要為每一個單位各準備一組複數變化。
        #expect(ClockText.duration(60, in: Self.english) != ClockText.duration(2 * 60, in: Self.english))
        #expect(!ClockText.duration(60, in: Self.english).contains("minutes"))
    }

    @Test("負數當作零")
    func negativeDurationIsFloored() {
        #expect(ClockText.duration(-5, in: Self.english) == ClockText.duration(0, in: Self.english))
    }
}
