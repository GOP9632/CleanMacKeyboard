import Foundation

/// 七個時刻各自的開關，加上一個總開關。
///
/// 這是設定裡唯一不只是「一個值」的部分，所以獨立成一個型別。控制器不認得
/// 這裡的規則，它只在對的時刻問一句「這一聲該不該響」（見 `docs/seams.md`）。
struct SoundSettings: Equatable {
    /// 總開關。
    ///
    /// 關掉之後不管個別開關是什麼，一聲都不會響。它跟個別開關是兩層而不是
    /// 同一層：安靜的場合把總開關關掉，離開之後打開，個別的取捨要原封不動
    /// 回來，不能被總開關洗掉。
    var isEnabled: Bool

    /// 被個別關掉的時刻。
    ///
    /// 記「關掉的」而不是「開著的」是刻意的。預設全部開著，所以預設值是空集合；
    /// 日後若多一個時刻，舊版本存下的偏好裡不會有它，它會自動是開著的。
    /// 反過來記「開著的」，新加的時刻在舊偏好裡一律是關的，使用者會以為壞了。
    var mutedSounds: Set<WipeSound>

    init(isEnabled: Bool = true, mutedSounds: Set<WipeSound> = []) {
        self.isEnabled = isEnabled
        self.mutedSounds = mutedSounds
    }

    /// 某一個時刻的個別開關。
    subscript(sound: WipeSound) -> Bool {
        get { !mutedSounds.contains(sound) }
        set {
            if newValue {
                mutedSounds.remove(sound)
            } else {
                mutedSounds.insert(sound)
            }
        }
    }

    /// 這一聲現在該不該響。總開關與個別開關都要點頭。
    func plays(_ sound: WipeSound) -> Bool {
        isEnabled && self[sound]
    }
}
