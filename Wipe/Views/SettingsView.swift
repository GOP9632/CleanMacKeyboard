import SwiftUI

/// `Cmd + ,` 打開的設定視窗。
///
/// 這一層跟主視窗一樣薄：它把 `WipeSettingsStore` 裡的值畫成控制項，改動
/// 直接寫回去，自己不記任何東西。沒有「儲存」也沒有「套用」按鈕，改了就存，
/// 這是 Mac 設定視窗一貫的樣子。
///
/// **這個畫面同時是 ADR-0002 的守門人。**這裡沒有任何一格可以拆掉安全網：
/// 逾時只能調長短、選項最長 15 分鐘、沒有「永不」；闔蓋解鎖與「解鎖手勢
/// 期間出現第三顆按鍵就重新計時」在整個畫面上找不到對應的控制項，因為
/// `WipeSettings` 裡根本沒有那兩個欄位。日後想在這裡加一個開關之前，
/// 先去讀 `docs/adr/0002-safety-nets-are-not-configurable.md`。
struct SettingsView: View {
    @Bindable var store: WipeSettingsStore

    @Environment(\.locale) private var locale

    /// 兩個頁籤的尺寸。
    ///
    /// 高度一頁一個，不是整個視窗一個：兩頁的長短差很多，共用一個高度的話，
    /// 短的那一頁底下會空一大片。設定視窗換頁時跟著改變高度是 Mac 的常態。
    ///
    /// 「一般」那一頁的高度以整頁塞得下為準。逾時那一段尤其不可以掉到捲軸
    /// 底下：找不到關閉開關的使用者要看得到旁邊那段說明，不然他會以為是
    /// 自己沒找到。
    private enum Layout {
        static let width: CGFloat = 520
        static let generalHeight: CGFloat = 570
        static let soundHeight: CGFloat = 420
    }

    var body: some View {
        TabView {
            general
                .frame(width: Layout.width, height: Layout.generalHeight)
                .tabItem {
                    Label {
                        Text(WipeText.settingsTabGeneral.localizedKey, bundle: .wipe)
                    } icon: {
                        Image(systemName: "gearshape")
                    }
                }

            sound
                .frame(width: Layout.width, height: Layout.soundHeight)
                .tabItem {
                    Label {
                        Text(WipeText.settingsTabSound.localizedKey, bundle: .wipe)
                    } icon: {
                        Image(systemName: "speaker.wave.2")
                    }
                }
        }
    }

    // MARK: - 一般

    private var general: some View {
        Form {
            Section {
                Picker(selection: $store.settings.interceptionScope) {
                    Text(WipeText.settingsScopeKeyboard.localizedKey, bundle: .wipe)
                        .tag(InterceptionScope.keyboard)
                    Text(WipeText.settingsScopeAllInput.localizedKey, bundle: .wipe)
                        .tag(InterceptionScope.allInput)
                } label: {
                    Text(WipeText.settingsScopeTitle.localizedKey, bundle: .wipe)
                }
            } footer: {
                footnote(.settingsScopeFootnote)
            }

            Section {
                Picker(selection: $store.settings.screenPresentation) {
                    Text(WipeText.settingsPresentationMainWindow.localizedKey, bundle: .wipe)
                        .tag(ScreenPresentation.mainWindow)
                    Text(WipeText.settingsPresentationOverlay.localizedKey, bundle: .wipe)
                        .tag(ScreenPresentation.overlay)
                } label: {
                    Text(WipeText.settingsPresentationTitle.localizedKey, bundle: .wipe)
                }
            } footer: {
                footnote(.settingsPresentationFootnote)
            }

            Section {
                Toggle(isOn: $store.settings.bufferIsEnabled) {
                    Text(WipeText.settingsBufferToggle.localizedKey, bundle: .wipe)
                }
                Stepper(
                    value: $store.settings.bufferSeconds,
                    in: WipeSettings.bufferSecondsRange
                ) {
                    labelledValue(
                        .settingsBufferLength,
                        ClockText.duration(TimeInterval(store.settings.bufferSeconds), in: locale)
                    )
                }
                // 緩衝關掉的時候秒數還留在畫面上但點不動，比整列消失好：
                // 使用者看得到自己上次調的值，重新打開時不會被嚇一跳。
                .disabled(!store.settings.bufferIsEnabled)
            } footer: {
                footnote(.settingsBufferFootnote)
            }

            Section {
                Stepper(
                    value: $store.settings.unlockHoldSeconds,
                    in: WipeSettings.unlockHoldSecondsRange,
                    step: 1
                ) {
                    labelledValue(
                        .settingsUnlockHold,
                        ClockText.duration(store.settings.unlockHoldSeconds, in: locale)
                    )
                }
            } footer: {
                footnote(.settingsUnlockFootnote)
            }

            Section {
                // 直接綁值，不在這裡做任何靠攏。存進來的逾時一定已經是清單裡
                // 的一項，因為 `WipeSettingsStore` 讀檔的時候就靠好了。畫面上
                // 顯示的數字與真正生效的數字必須是同一個。
                Picker(selection: $store.settings.timeoutSeconds) {
                    ForEach(SettingsOptions.timeoutSeconds, id: \.self) { seconds in
                        Text(ClockText.duration(seconds, in: locale)).tag(seconds)
                    }
                } label: {
                    Text(WipeText.settingsTimeoutTitle.localizedKey, bundle: .wipe)
                }
            } footer: {
                // 這一段字要寫明逾時不可關閉以及為什麼。使用者找不到關閉的
                // 開關時，第一個念頭會是「這是 bug」，不解釋的話他會去找。
                footnote(.settingsTimeoutFootnote)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - 聲音

    private var sound: some View {
        Form {
            Section {
                Toggle(isOn: $store.settings.sounds.isEnabled) {
                    Text(WipeText.settingsSoundMaster.localizedKey, bundle: .wipe)
                }
            }

            Section {
                ForEach(WipeSound.allCases, id: \.self) { sound in
                    Toggle(isOn: binding(for: sound)) {
                        Text(SettingsOptions.soundLabel(for: sound).localizedKey, bundle: .wipe)
                    }
                }
                // 總開關關掉時個別開關一起變灰，但值不動：再打開的時候
                // 使用者原本的取捨要原封不動回來（見 `SoundSettings`）。
                .disabled(!store.settings.sounds.isEnabled)
            } header: {
                Text(WipeText.settingsSoundIndividual.localizedKey, bundle: .wipe)
            } footer: {
                footnote(.settingsSoundFootnote)
            }
        }
        .formStyle(.grouped)
    }

    private func binding(for sound: WipeSound) -> Binding<Bool> {
        Binding(
            get: { store.settings.sounds[sound] },
            set: { store.settings.sounds[sound] = $0 }
        )
    }

    // MARK: - 共用的小零件

    private func footnote(_ text: WipeText) -> some View {
        Text(text.localizedKey, bundle: .wipe)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    /// 「名稱⋯值」這種一列兩段的標籤，給 `Stepper` 用。
    ///
    /// `Stepper` 自己不顯示目前的值，不寫出來的話使用者只看得到兩顆箭頭。
    private func labelledValue(_ text: WipeText, _ value: String) -> some View {
        HStack {
            Text(text.localizedKey, bundle: .wipe)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView(store: WipeSettingsStore(WipeSettings()))
}
