import AppKit
import Testing

@testable import Wipe

/// 圖示測試守的是 #15 裡三件會無聲壞掉的事：圖示有沒有真的接進 app、
/// 小尺寸是不是另做的簡化版、以及圖示上的青色是不是還跟 app 的強調色同一個值。
///
/// 這三件事壞掉時都不會有編譯錯誤，只會在 Dock 上看起來怪怪的。
@Suite("app 圖示")
@MainActor
struct AppIconTests {
    /// macOS 圖示需要的實際像素尺寸。十張切圖涵蓋的就是這七種。
    private static let pixelSizes = [16, 32, 64, 128, 256, 512, 1024]

    /// macOS app 圖示的切圖張數：五種點數各有 1x 與 2x。
    private static let sliceCount = 10

    /// 畫著鍵帽的那幾張。64 像素起就有鍵帽，只是簽名要到 128 才畫。
    private static let sizesWithKeycap = [64, 128, 256, 512, 1024]

    /// 完整版圖示裡鍵帽表面的亮度下限。用來分辨「有鍵帽」與「只有暫停符號」。
    private static let keycapMinBrightness = 0.85
    /// 鍵帽表面的彩度上限。鍵帽是接近白色的中性色，青色的暫停符號彩度遠高於此。
    private static let keycapMaxSaturation = 0.15

    /// 暫停符號至少要佔掉的畫面比例。
    ///
    /// 門檻不設成「只要有一顆青色像素就算數」，因為那種寫法連反鋸齒漏出來的一顆雜點
    /// 都會放行，等於沒守。實測值是簡化版 22% 到 28%、完整版 2.2% 到 2.7%，
    /// 這兩個門檻各留了一半以上的餘裕。
    private static let simplifiedCyanShare = 0.10
    private static let fullCyanShare = 0.015

    private struct Pixel: Equatable {
        let red: Int
        let green: Int
        let blue: Int

        var brightness: Double {
            Double(max(red, max(green, blue))) / 255
        }

        var saturation: Double {
            let high = max(red, max(green, blue))
            guard high > 0 else { return 0 }
            return Double(high - min(red, min(green, blue))) / Double(high)
        }

        /// 是不是鍵帽表面那種又亮又不帶顏色的像素。
        ///
        /// 光看亮度不夠：暫停符號的深色青（`#35D3E6`）藍通道本來就很高，
        /// 只用亮度會把它一起算進來。加上彩度才分得開鍵帽與符號。
        var isKeycapSurface: Bool {
            brightness > AppIconTests.keycapMinBrightness
                && saturation < AppIconTests.keycapMaxSaturation
        }

        /// 兩個色值是不是同一個顏色。容許 ±2，因為色彩空間轉換會有進位誤差。
        func matches(_ other: Pixel) -> Bool {
            abs(red - other.red) <= 2 && abs(green - other.green) <= 2
                && abs(blue - other.blue) <= 2
        }
    }

    /// 取出圖示裡實際像素尺寸等於 `pixelSize` 的所有切圖。
    ///
    /// 用實際像素數挑，不是用點數，因為同一個像素尺寸可能同時是某個點數的 1x
    /// 與另一個點數的 2x。32 像素就是這種情況：它既是 16 點的 2x，也是 32 點的 1x，
    /// 兩張都要檢查。挑不到就代表那個尺寸根本沒有切圖，系統只能拿別張來縮放。
    private static func icon() throws -> NSImage {
        try #require(
            Bundle.wipe.image(forResource: WipeIcon.assetName),
            "資源目錄裡找不到 \(WipeIcon.assetName)"
        )
    }

    private static func artworks(pixelSize: Int) throws -> [NSBitmapImageRep] {
        let image = try icon()
        let matching = image.representations.filter {
            $0.pixelsWide == pixelSize && $0.pixelsHigh == pixelSize
        }
        #expect(!matching.isEmpty, "圖示沒有 \(pixelSize) 像素的切圖")
        return try matching.map { rep in
            var rect = NSRect(x: 0, y: 0, width: rep.size.width, height: rep.size.height)
            let cgImage = try #require(
                rep.cgImage(forProposedRect: &rect, context: nil, hints: nil),
                "\(pixelSize) 像素的切圖取不出點陣資料"
            )
            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            return try #require(
                bitmap.converting(to: .sRGB, renderingIntent: .default),
                "\(pixelSize) 像素的切圖轉不到 sRGB"
            )
        }
    }

    private static func pixels(of rep: NSBitmapImageRep) -> [Pixel] {
        var result: [Pixel] = []
        result.reserveCapacity(rep.pixelsWide * rep.pixelsHigh)
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                result.append(
                    Pixel(
                        red: Int((color.redComponent * 255).rounded()),
                        green: Int((color.greenComponent * 255).rounded()),
                        blue: Int((color.blueComponent * 255).rounded())
                    )
                )
            }
        }
        return result
    }

    /// 把 app 的某個顏色資源在指定外觀下解析成色值，用來跟圖示上的像素比對。
    private static func pixel(
        of color: WipeColor,
        appearance appearanceName: NSAppearance.Name
    ) throws -> Pixel {
        let appearance = try #require(NSAppearance(named: appearanceName))
        var resolved: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            resolved = color.nsColor?.usingColorSpace(.sRGB)
        }
        let value = try #require(resolved, "找不到顏色資源 \(color.assetName)")
        return Pixel(
            red: Int((value.redComponent * 255).rounded()),
            green: Int((value.greenComponent * 255).rounded()),
            blue: Int((value.blueComponent * 255).rounded())
        )
    }

    @Test("app 宣告了自己的圖示")
    func appDeclaresIcon() {
        // 沒有這一行，Dock 上顯示的會是系統的通用 app 圖示。
        let declared = Bundle.wipe.infoDictionary?["CFBundleIconName"] as? String
        #expect(declared == WipeIcon.assetName)
    }

    @Test("每一個需要的尺寸都有自己的切圖", arguments: pixelSizes)
    func everySizeHasArtwork(_ pixelSize: Int) throws {
        _ = try Self.artworks(pixelSize: pixelSize)
    }

    @Test("十張切圖一張都不少")
    func everySliceIsDeclared() throws {
        // 光數尺寸不夠。有兩種像素尺寸各由兩張切圖供應（32 像素是 16 點的 2x
        // 也是 32 點的 1x，256 與 512 同理），少掉其中一張時另一張會頂上，
        // 按尺寸檢查完全看不出來。真正會壞的是那個點數在該倍率下沒有圖可用。
        let image = try Self.icon()
        #expect(
            image.representations.count == Self.sliceCount,
            "圖示只有 \(image.representations.count) 張切圖，應該是 \(Self.sliceCount) 張"
        )
    }

    @Test("16 與 32 像素是另做的簡化版，不是大圖縮小的", arguments: [16, 32])
    func smallSizesAreSimplified(_ pixelSize: Int) throws {
        // 簡化版只有深底加暫停符號，鍵帽整個拿掉了。大圖縮小的話，
        // 鍵帽那片接近白色的表面會佔掉畫面中央一大塊。
        for artwork in try Self.artworks(pixelSize: pixelSize) {
            let bright = Self.pixels(of: artwork).filter(\.isKeycapSurface)
            #expect(
                bright.isEmpty,
                "\(pixelSize) 像素那張還看得到鍵帽的亮面，代表它是大圖縮小的"
            )
        }
    }

    @Test("64 像素以上是完整版，鍵帽還在", arguments: sizesWithKeycap)
    func largeSizesKeepTheKeycap(_ pixelSize: Int) throws {
        for artwork in try Self.artworks(pixelSize: pixelSize) {
            let all = Self.pixels(of: artwork)
            let bright = all.filter(\.isKeycapSurface)
            #expect(
                Double(bright.count) / Double(all.count) > 0.1,
                "\(pixelSize) 像素那張看不到鍵帽的亮面"
            )
        }
    }

    @Test("完整版的暫停符號用的是清潔中那個青色的淺色值", arguments: sizesWithKeycap)
    func largeArtworkUsesLightCyan(_ pixelSize: Int) throws {
        // 圖示不自創色值。這一項壞掉代表 app 改了青色而圖示沒跟上，
        // 對齊方向是圖示去對齊 app。
        let cyan = try Self.pixel(of: .cleaning, appearance: .aqua)
        try Self.expectCyanShare(
            atLeast: Self.fullCyanShare,
            matching: cyan,
            pixelSize: pixelSize
        )
    }

    @Test("簡化版的暫停符號用的是同一個青色的深色值", arguments: [16, 32])
    func smallArtworkUsesDarkCyan(_ pixelSize: Int) throws {
        // 簡化版畫在深底上，所以取的是同一個色票的深色模式值。
        let cyan = try Self.pixel(of: .cleaning, appearance: .darkAqua)
        try Self.expectCyanShare(
            atLeast: Self.simplifiedCyanShare,
            matching: cyan,
            pixelSize: pixelSize
        )
    }

    /// 檢查某個尺寸的每一張切圖上，暫停符號那個青色都佔到足夠的面積。
    private static func expectCyanShare(
        atLeast share: Double,
        matching cyan: Pixel,
        pixelSize: Int
    ) throws {
        for artwork in try artworks(pixelSize: pixelSize) {
            let all = pixels(of: artwork)
            let matching = all.filter { $0.matches(cyan) }
            let actual = Double(matching.count) / Double(all.count)
            #expect(
                actual > share,
                """
                \(pixelSize) 像素那張的青色只佔 \(actual)，不到 \(share)。
                暫停符號不見了，或者圖示的青色與 app 的色票對不上。
                """
            )
        }
    }
}
