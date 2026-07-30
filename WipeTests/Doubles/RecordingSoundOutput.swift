import Foundation

@testable import Wipe

/// 測試用的音效輸出：只記下被要求播哪一聲，不發出任何聲音。
@MainActor
final class RecordingSoundOutput: SoundOutput {
    /// 被要求播放的音效，照發生順序。順序有意義：例如倒數的最後一聲
    /// 必須在鎖上那一聲之前。
    private(set) var played: [WipeSound] = []

    func play(_ sound: WipeSound) {
        played.append(sound)
    }

    func count(of sound: WipeSound) -> Int {
        played.filter { $0 == sound }.count
    }
}
