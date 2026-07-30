import AppKit

/// 用 macOS 內建系統音效實作的音效輸出。
///
/// 刻意不自己做音檔：使用者已經認得這幾個聲音，借用它們比塞一組陌生的
/// 提示音更不突兀。
@MainActor
final class SystemSoundOutput: SoundOutput {
    func play(_ sound: WipeSound) {
        NSSound(named: Self.systemSoundName(for: sound))?.play()
    }

    /// 每個時刻對應的系統音效名稱。
    ///
    /// 挑選的原則是「聽得出輕重」：倒數的每一聲最輕，鎖上與解鎖最明確，
    /// 逾時與拒絕帶一點警示意味。`timedOut` 與 `unlocked` 必須是不同的音效，
    /// 有測試守著。
    static func systemSoundName(for sound: WipeSound) -> NSSound.Name {
        switch sound {
        case .preparingTick: "Tink"
        case .locked: "Submarine"
        case .unlockGestureDetected: "Pop"
        case .unlockGestureReset: "Morse"
        case .unlocked: "Glass"
        case .timedOut: "Funk"
        case .refused: "Basso"
        }
    }
}
