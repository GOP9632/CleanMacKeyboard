import AppKit

/// 一次鍵盤事件的判讀結果。
///
/// 這個型別是純值：它只認得旗標值與 keyCode，不知道 app 在哪個階段，
/// 也不知道解鎖手勢的規則。整個「左右 Command 分不分得開」的答案就落在
/// `leftCommandIsDown` 與 `rightCommandIsDown` 這兩個位元上。
struct KeyboardEventReading: Equatable {
    /// 這次事件是修飾鍵變化，還是一般按鍵的按下與放開。
    ///
    /// 原始值刻意用 AppKit 自己的事件名稱（`flagsChanged`）而不是中文，
    /// 因為它會被印進診斷紀錄再貼回票上，那份紀錄要能直接對回 AppKit 的文件。
    enum Kind: String, Equatable {
        case modifiersChanged = "flagsChanged"
        case keyDown
        case keyUp
    }

    let kind: Kind

    /// 事件帶來的修飾鍵旗標值，未經任何遮罩。
    ///
    /// 刻意保留原始值而不是先轉成 `NSEvent.ModifierFlags`：分左右的資訊就住在
    /// 低 16 位，而 `NSEvent.ModifierFlags.command` 這種公開常數只說得出
    /// 「有沒有按 Command」。診斷紀錄也要把這個值原樣顯示出來。
    let rawFlags: UInt

    /// 造成這次事件的實體按鍵。
    let keyCode: UInt16

    // MARK: - 分左右的位元

    /// 左 Command 的旗標位元（`NX_DEVICELCMDKEYMASK`）。
    static let leftCommandMask: UInt = 0x0000_0008
    /// 右 Command 的旗標位元（`NX_DEVICERCMDKEYMASK`）。
    static let rightCommandMask: UInt = 0x0000_0010

    static let leftCommandKeyCode: UInt16 = 55
    static let rightCommandKeyCode: UInt16 = 54

    /// 除了 Command 以外，會被算成「夾帶其他修飾鍵」的那些鍵。
    ///
    /// 刻意不包含 Caps Lock：見 #1 的 user story 33，Caps Lock 是切換式的，
    /// 開著的使用者不可以因此永遠解不開。也刻意不包含 function 與 numericPad，
    /// 那兩個是 macOS 自己替方向鍵一類的按鍵附上的，不是使用者按的。
    static let disqualifyingModifiers: NSEvent.ModifierFlags = [.shift, .control, .option]

    var leftCommandIsDown: Bool { rawFlags & Self.leftCommandMask != 0 }

    var rightCommandIsDown: Bool { rawFlags & Self.rightCommandMask != 0 }

    /// Command 以外還按著別的修飾鍵。
    var otherModifiersAreDown: Bool {
        NSEvent.ModifierFlags(rawValue: rawFlags)
            .intersection(Self.disqualifyingModifiers)
            .isEmpty == false
    }

    /// 原始旗標值的十六進位形式。診斷紀錄顯示的就是這個字串，
    /// 真機驗證的結果也是照這個格式貼回票上。
    var rawFlagsText: String {
        String(format: "0x%08lx", rawFlags)
    }

    /// 這次判讀在診斷紀錄裡的樣子：事件種類、keyCode、原始旗標值，
    /// 以及左右 Command 各自的判讀結果。
    ///
    /// 排版留在這裡而不是留在紀錄那一行上，因為要對齊的欄位全部是這個型別的東西，
    /// 紀錄只多一個時間。
    ///
    /// 刻意不翻譯：這是要被原樣貼回票上的原始資料（見 #3 的驗收條件），
    /// 換一個語言看到不一樣的字會讓回報對不起來。
    var diagnosticText: String {
        [
            kind.rawValue.padding(toLength: Column.kindWidth, withPad: " ", startingAt: 0),
            "keyCode \(String(keyCode).leftPadded(to: Column.keyCodeWidth))",
            "raw \(rawFlagsText)",
            Self.sideText("L", isDown: leftCommandIsDown),
            Self.sideText("R", isDown: rightCommandIsDown),
        ].joined(separator: Column.separator)
    }

    /// 每一欄補到固定寬度，這樣一整段貼到票上還是對得齊。
    private enum Column {
        static let kindWidth = 12
        static let keyCodeWidth = 3
        /// `L=down` 是最長的那一個。
        static let sideWidth = 6
        static let separator = "  "
    }

    private static func sideText(_ side: String, isDown: Bool) -> String {
        "\(side)=\(isDown ? "down" : "up")"
            .padding(toLength: Column.sideWidth, withPad: " ", startingAt: 0)
    }
}

private extension String {
    func leftPadded(to length: Int) -> String {
        count >= length ? self : String(repeating: " ", count: length - count) + self
    }
}

extension KeyboardEventReading {
    /// 從一個 AppKit 事件讀出判讀。
    ///
    /// 只是讀，不動事件本身。不是鍵盤事件時回傳 `nil`。
    init?(_ event: NSEvent) {
        let kind: Kind
        switch event.type {
        case .flagsChanged: kind = .modifiersChanged
        case .keyDown: kind = .keyDown
        case .keyUp: kind = .keyUp
        default: return nil
        }
        self.init(kind: kind, rawFlags: event.modifierFlags.rawValue, keyCode: event.keyCode)
    }
}
