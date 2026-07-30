import AppKit
import Testing

@testable import Wipe

/// 配色測試守的是 ADR-0003：顏色在 Wipe 裡承擔辨識功能，所以每個狀態的色相
/// 必須留在自己的區間裡，不可以互相靠近，也不可以跟著系統強調色跑。
@Suite("固定配色")
@MainActor
struct WipeColorTests {
    private struct Components: Equatable {
        let hueDegrees: Double
        let saturation: Double
        let brightness: Double
    }

    /// 青色的色相區間。清潔中與解鎖進度都必須落在裡面。
    private static let cyanHueDegrees = 170.0...205.0
    /// 琥珀色的色相區間。
    private static let amberHueDegrees = 25.0...50.0

    private static let appearances: [NSAppearance.Name] = [.aqua, .darkAqua]

    private static func components(
        ofAsset name: String,
        appearance appearanceName: NSAppearance.Name
    ) throws -> Components {
        let appearance = try #require(NSAppearance(named: appearanceName))
        var resolved: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            resolved = NSColor(named: name, bundle: .wipe)?.usingColorSpace(.sRGB)
        }
        let value = try #require(resolved, "找不到顏色資源 \(name)")
        return Components(
            hueDegrees: Double(value.hueComponent) * 360,
            saturation: Double(value.saturationComponent),
            brightness: Double(value.brightnessComponent)
        )
    }

    private static func components(
        of color: WipeColor,
        appearance appearanceName: NSAppearance.Name
    ) throws -> Components {
        try components(ofAsset: color.assetName, appearance: appearanceName)
    }

    @Test("每一個顏色在資源目錄裡都找得到", arguments: WipeColor.allCases)
    func colorResolves(_ color: WipeColor) {
        #expect(color.nsColor != nil, "找不到顏色資源 \(color.assetName)")
    }

    @Test("每一個顏色在淺色與深色下都有各自的值", arguments: WipeColor.allCases)
    func colorHasBothAppearances(_ color: WipeColor) throws {
        let light = try Self.components(of: color, appearance: .aqua)
        let dark = try Self.components(of: color, appearance: .darkAqua)
        #expect(
            light != dark,
            "\(color.assetName) 淺色與深色是同一個值，深色模式下對比會不夠"
        )
    }

    @Test("待命是中性灰，不帶明顯色相", arguments: appearances)
    func standbyIsNeutral(_ appearance: NSAppearance.Name) throws {
        let gray = try Self.components(of: .standby, appearance: appearance)
        #expect(gray.saturation < 0.1)
    }

    @Test("準備清潔落在琥珀色的區間", arguments: appearances)
    func preparingIsAmber(_ appearance: NSAppearance.Name) throws {
        let amber = try Self.components(of: .preparing, appearance: appearance)
        #expect(Self.amberHueDegrees.contains(amber.hueDegrees))
        #expect(amber.saturation > 0.5)
    }

    @Test("清潔中落在青色的區間", arguments: appearances)
    func cleaningIsCyan(_ appearance: NSAppearance.Name) throws {
        let cyan = try Self.components(of: .cleaning, appearance: appearance)
        #expect(Self.cyanHueDegrees.contains(cyan.hueDegrees))
        #expect(cyan.saturation > 0.5)
    }

    @Test("解鎖進度是同一個青色轉亮", arguments: appearances)
    func unlockProgressIsBrighterCyan(_ appearance: NSAppearance.Name) throws {
        let cyan = try Self.components(of: .cleaning, appearance: appearance)
        let bright = try Self.components(of: .unlockProgress, appearance: appearance)
        #expect(Self.cyanHueDegrees.contains(bright.hueDegrees))
        #expect(bright.brightness > cyan.brightness)
    }

    @Test("警告是紅色，而且離其他狀態色都很遠", arguments: appearances)
    func warningIsRed(_ appearance: NSAppearance.Name) throws {
        let red = try Self.components(of: .warning, appearance: appearance)
        #expect(red.hueDegrees <= 12 || red.hueDegrees >= 348)
        #expect(red.saturation > 0.5)
    }

    @Test("強調色就是清潔中的那個青色")
    func accentIsCleaningCyan() {
        #expect(WipeColor.accent == .cleaning)
    }

    @Test("全域強調色資源與清潔中的青色是同一個值", arguments: appearances)
    func globalAccentMatchesAccentColor(_ appearance: NSAppearance.Name) throws {
        // 兩個資源必須一致，否則系統控制項的顏色會跟圓環對不起來。
        let global = try Self.components(
            ofAsset: WipeColor.globalAccentAssetName,
            appearance: appearance
        )
        let accent = try Self.components(of: WipeColor.accent, appearance: appearance)
        #expect(global == accent)
    }

    @Test("app 宣告了自己的全域強調色，所以不會跟隨系統強調色")
    func appDeclaresGlobalAccentColor() {
        // 這一項是 ADR-0003 真正生效的機制。少了它，沒被 tint 蓋到的控制項
        // 會退回使用者的系統強調色。
        let declared = Bundle.wipe.infoDictionary?["NSAccentColorName"] as? String
        #expect(declared == WipeColor.globalAccentAssetName)
    }
}
