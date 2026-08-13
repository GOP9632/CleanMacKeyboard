// Wipe app 圖示產生器
//
// 設計依據：
// - 主體是一顆 Mac 鍵帽，表面刻暫停符號，下方刻使用者簽名 AL。
//   鍵帽本來就是會刻字的東西，所以簽名不是貼上去的 logo，而是用了鍵帽本身的語言。
// - 暫停符號的兩根粗直條是極小尺寸下唯一還讀得懂的形狀，所以它在每個尺寸都在，
//   位置也固定，讓大小圖之間有視覺連續性。
// - 青色不寫在這個檔案裡，執行時直接讀 app 的 CleaningCyan 色票。
//   圖示去對齊 app，不是反過來，見 docs/adr/0003-fixed-accent-colour.md。
//
// 分尺寸策略（#15 驗收條件要求小尺寸另做簡化版，不從大圖縮小）：
// - 16、32 像素：只留暫停符號，幾何以整數像素對齊，避免糊掉。
// - 64 像素：鍵帽加暫停符號，砍掉簽名。
// - 128 像素以上：完整版，鍵帽加暫停符號加簽名。

import AppKit
import CoreGraphics
import CoreText
import Foundation

// MARK: - 顏色

struct RGB {
    let r, g, b: CGFloat
    init(_ r: Int, _ g: Int, _ b: Int) {
        self.r = CGFloat(r) / 255
        self.g = CGFloat(g) / 255
        self.b = CGFloat(b) / 255
    }
    func cgColor(alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: r, green: g, blue: b, alpha: alpha)
    }
}

/// 一個色票的淺色與深色兩個值。
struct ColorSet {
    let light: RGB
    let dark: RGB
}

/// 讀 app 資源目錄裡的色票。
///
/// 這個產生器刻意不留自己的一份色值。色票是唯一的來源，改了色票重跑一次就對齊，
/// 兩份色值各自漂移的情況不會發生。讀不到就直接中止，因為悄悄退回內建值產出的
/// 是一組看起來正常、顏色卻跟 app 對不上的圖。
func loadColorSet(named name: String) -> ColorSet {
    // 從目前的工作目錄一路往上找資源目錄，所以在 repo 裡的哪一層執行都可以。
    // 不用 #filePath 定位：那個值是編譯時命令列上寫的字串，README 那行
    // `swiftc -O DrawIcon.swift` 給的是相對路徑，換一個工作目錄就指到別的地方。
    let relativePath = "Wipe/Resources/Assets.xcassets/Colors/\(name).colorset/Contents.json"

    func fail(_ reason: String) -> Never {
        FileHandle.standardError.write(
            "讀不到色票 \(name)：\(reason)\n請在 repo 裡面執行，會往上找 \(relativePath)\n"
                .data(using: .utf8)!
        )
        exit(1)
    }

    var directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    var found: URL?
    while found == nil {
        let candidate = directory.appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: candidate.path) {
            found = candidate
            break
        }
        let parent = directory.deletingLastPathComponent()
        if parent.path == directory.path { break }
        directory = parent
    }

    guard let url = found else { fail("從工作目錄往上找不到這個檔案") }
    guard let data = try? Data(contentsOf: url) else { fail("檔案讀不開") }
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let entries = root["colors"] as? [[String: Any]]
    else { fail("格式不是預期的 colorset") }

    func rgb(from entry: [String: Any]) -> RGB? {
        guard let color = entry["color"] as? [String: Any],
              let components = color["components"] as? [String: String]
        else { return nil }
        func channel(_ key: String) -> Int? {
            guard let raw = components[key] else { return nil }
            if raw.hasPrefix("0x") { return Int(raw.dropFirst(2), radix: 16) }
            return Int(raw)
        }
        guard let r = channel("red"), let g = channel("green"), let b = channel("blue") else {
            return nil
        }
        return RGB(r, g, b)
    }

    func isDark(_ entry: [String: Any]) -> Bool {
        guard let appearances = entry["appearances"] as? [[String: Any]] else { return false }
        return appearances.contains { $0["value"] as? String == "dark" }
    }

    guard let lightEntry = entries.first(where: { !isDark($0) }), let light = rgb(from: lightEntry) else {
        fail("找不到淺色的值")
    }
    guard let darkEntry = entries.first(where: { isDark($0) }), let dark = rgb(from: darkEntry) else {
        fail("找不到深色的值")
    }
    return ColorSet(light: light, dark: dark)
}

/// app 的青色強調色。淺色值用在淺色鍵帽表面上，深色值用在簡化版的深色底上。
let cyan = loadColorSet(named: "CleaningCyan")

/// 底色。深石墨，讓青色維持在點綴的份量。
///
/// 青底的變體試過並否決，理由是暫停符號的青色與底色太接近，符號失去對比，
/// 整體變成一片青。那是已經做完的取捨，所以這裡只留採用的那一組。
enum Backdrop {
    static let top = RGB(0x2E, 0x34, 0x3C)
    static let bottom = RGB(0x15, 0x18, 0x1C)
}

/// 鍵帽配色。表面近白，側面稍深，只用兩層色階表示厚度，不做寫實光影。
enum Keycap {
    static let faceTop = RGB(0xFC, 0xFC, 0xFD)
    static let faceBottom = RGB(0xE3, 0xE6, 0xEB)
    static let side = RGB(0xB4, 0xB9, 0xC1)
    static let signature = RGB(0x4A, 0x4F, 0x57)
}

// MARK: - 幾何

/// Superellipse 路徑。Apple 的圖示圓角是連續曲率，不是圓弧，
/// superellipse 逼近會比 CGPath 的圓角矩形接近。`n` 越大角越方。
///
/// 這是逼近，不是 macOS 真正的 squircle：真正的形狀在角與邊之間還有一段直邊。
func superellipsePath(in rect: CGRect, n: CGFloat) -> CGPath {
    let samples = 720
    let path = CGMutablePath()
    let a = rect.width / 2
    let b = rect.height / 2
    let cx = rect.midX
    let cy = rect.midY
    for i in 0...samples {
        let t = CGFloat(i) / CGFloat(samples) * 2 * .pi
        let ct = cos(t)
        let st = sin(t)
        let x = cx + a * pow(abs(ct), 2 / n) * (ct < 0 ? -1 : 1)
        let y = cy + b * pow(abs(st), 2 / n) * (st < 0 ? -1 : 1)
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

/// 圓角矩形。鍵帽用得上，圓角比容器小得多才像鍵帽。
func roundedPath(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// 用由下往上的直線漸層填滿一個路徑。
func fillWithVerticalGradient(_ ctx: CGContext, _ path: CGPath, from top: RGB, to bottom: RGB) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let box = path.boundingBox
    let space = CGColorSpaceCreateDeviceRGB()
    let colors = [bottom.cgColor(), top.cgColor()] as CFArray
    guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else {
        ctx.restoreGState()
        return
    }
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: box.midX, y: box.minY),
        end: CGPoint(x: box.midX, y: box.maxY),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
    ctx.restoreGState()
}

// MARK: - 繪圖

enum Detail {
    /// 只有暫停符號。16、32 像素用。
    case minimal
    /// 鍵帽加暫停符號，無簽名。64 像素用。
    case mid
    /// 完整版。128 像素以上用。
    case full
}

func detail(forPixelSize size: Int) -> Detail {
    if size <= 32 { return .minimal }
    if size <= 64 { return .mid }
    return .full
}

/// 畫一組暫停符號的兩根直條。
func drawPause(
    _ ctx: CGContext,
    center: CGPoint,
    barWidth: CGFloat,
    barHeight: CGFloat,
    gap: CGFloat,
    radius: CGFloat,
    color: CGColor
) {
    let totalWidth = barWidth * 2 + gap
    let left = center.x - totalWidth / 2
    let bottom = center.y - barHeight / 2
    ctx.setFillColor(color)
    for x in [left, left + barWidth + gap] {
        let rect = CGRect(x: x, y: bottom, width: barWidth, height: barHeight)
        ctx.addPath(roundedPath(rect, radius: min(radius, barWidth / 2)))
        ctx.fillPath()
    }
}

/// 畫簽名 AL。用圓體粗體，在鍵帽上像刻上去的次要字符。
func drawSignature(_ ctx: CGContext, text: String, center: CGPoint, capHeight: CGFloat, color: CGColor) {
    // 先用 capHeight 反推字級，讓字母實際高度等於指定值。
    let probeSize: CGFloat = 100
    let base = NSFont.systemFont(ofSize: probeSize, weight: .bold)
    let rounded = base.fontDescriptor.withDesign(.rounded).flatMap {
        NSFont(descriptor: $0, size: probeSize)
    } ?? base
    let pointSize = probeSize * capHeight / rounded.capHeight
    let font = NSFont(descriptor: rounded.fontDescriptor, size: pointSize) ?? rounded

    let attributed = NSAttributedString(string: text, attributes: [
        .font: font,
        .foregroundColor: NSColor(cgColor: color) ?? .black,
        .kern: pointSize * 0.04,
    ])
    let line = CTLineCreateWithAttributedString(attributed)
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)

    ctx.saveGState()
    ctx.textPosition = CGPoint(
        x: center.x - bounds.width / 2 - bounds.minX,
        y: center.y - bounds.height / 2 - bounds.minY
    )
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

func drawIcon(size: Int, signature: String) -> CGImage? {
    let side = CGFloat(size)
    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high
    ctx.clear(CGRect(x: 0, y: 0, width: side, height: side))

    let level = detail(forPixelSize: size)

    // 容器。macOS 圖示格線是 1024 畫布裡 824 的圖形，也就是四邊各留 100。
    // 小尺寸改用整數像素邊距，避免半像素邊緣。
    let inset: CGFloat = level == .minimal ? max(1, (side * 0.0977).rounded()) : side * 0.0977
    let container = CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
    let containerPath = level == .minimal
        ? superellipsePath(in: container, n: 3.4)
        : superellipsePath(in: container, n: 4.0)
    fillWithVerticalGradient(ctx, containerPath, from: Backdrop.top, to: Backdrop.bottom)

    switch level {
    case .minimal:
        // 以整數像素定幾何，16 像素下也要有清楚的兩根條與中間的縫。
        let barW = max(2, (side * 0.21875).rounded())
        let gap = max(2, (side * 0.125).rounded())
        let barH = max(4, (side * 0.5625).rounded())
        let totalW = barW * 2 + gap
        let originX = ((side - totalW) / 2).rounded()
        let originY = ((side - barH) / 2).rounded()
        ctx.setFillColor(cyan.dark.cgColor())
        for x in [originX, originX + barW + gap] {
            // 小尺寸的圓角只做極小值，太圓會讓 3 像素寬的條看起來像圓點。
            let radius: CGFloat = side >= 32 ? (barW * 0.28).rounded() : 0
            ctx.addPath(roundedPath(CGRect(x: x, y: originY, width: barW, height: barH), radius: radius))
            ctx.fillPath()
        }

    case .mid, .full:
        let unit = side / 1024

        // 鍵帽。先畫往下位移的深色形狀當側面厚度，再蓋上表面。
        let capSide: CGFloat = 574 * unit
        let capRadius: CGFloat = 82 * unit
        let capCenterY: CGFloat = 528 * unit
        let depth: CGFloat = 26 * unit
        let faceRect = CGRect(
            x: (side - capSide) / 2,
            y: capCenterY - capSide / 2,
            width: capSide,
            height: capSide
        )
        ctx.setFillColor(Keycap.side.cgColor())
        ctx.addPath(roundedPath(faceRect.offsetBy(dx: 0, dy: -depth), radius: capRadius))
        ctx.fillPath()
        fillWithVerticalGradient(ctx, roundedPath(faceRect, radius: capRadius),
                                 from: Keycap.faceTop, to: Keycap.faceBottom)

        // 暫停符號放在鍵帽表面偏上，簽名放下方。
        // 這正是真實 Mac 鍵帽的排版：主符號在上，次要字符在下。
        let hasSignature = (level == .full)
        let pauseCenterY = hasSignature ? 598 * unit : capCenterY
        drawPause(
            ctx,
            center: CGPoint(x: side / 2, y: pauseCenterY),
            barWidth: 72 * unit,
            barHeight: 208 * unit,
            gap: 52 * unit,
            radius: 24 * unit,
            color: cyan.light.cgColor()
        )

        if hasSignature {
            // 簽名刻意比暫停符號小。暫停符號是辨識主體，簽名是次要字符，
            // 兩者不該搶同一個視覺層級。
            drawSignature(
                ctx,
                text: signature,
                center: CGPoint(x: side / 2, y: 378 * unit),
                capHeight: 82 * unit,
                color: Keycap.signature.cgColor()
            )
        }
    }

    return ctx.makeImage()
}

// MARK: - 輸出

func writePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        FileHandle.standardError.write("無法建立 \(url.path)\n".data(using: .utf8)!)
        return
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

/// 對照表。上排深底、下排淺底顯示實際像素大小，最下面把 16 與 32 放大 8 倍，
/// 讓小尺寸的可讀性可以真的被檢查，而不是靠猜。
func writeContactSheet(signature: String, to url: URL) {
    let sizes = [16, 32, 64, 128, 256, 512]
    let padding = 40
    let gutter = 48
    let labelSpace = 34

    let actualRowWidth = sizes.reduce(0) { $0 + max($1, 64) + gutter } + padding * 2
    let zoomFactor = 8
    let zoomRowWidth = [16, 32].reduce(0) { $0 + $1 * zoomFactor + gutter } + padding * 2
    let width = max(actualRowWidth, zoomRowWidth, 900)

    let rowHeight = 512 + labelSpace + gutter
    let zoomRowHeight = 32 * zoomFactor + labelSpace + gutter
    let height = padding * 2 + rowHeight * 2 + zoomRowHeight + 60

    guard let ctx = CGContext(
        data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return }

    // 背景切兩半，左右各半沒有意義，改成整體中性灰，兩排各自畫底色方塊。
    ctx.setFillColor(RGB(0x8A, 0x8A, 0x8E).cgColor())
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

    func label(_ text: String, at point: CGPoint, size: CGFloat, color: RGB) {
        let font = NSFont.monospacedSystemFont(ofSize: size, weight: .medium)
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: NSColor(cgColor: color.cgColor()) ?? .black,
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        ctx.textPosition = point
        CTLineDraw(line, ctx)
    }

    var y = height - padding - 512 - labelSpace

    // 深底一排
    ctx.setFillColor(RGB(0x1C, 0x1C, 0x1E).cgColor())
    ctx.fill(CGRect(x: 0, y: y - gutter / 2, width: width, height: 512 + labelSpace + gutter))
    var x = padding
    for size in sizes {
        guard let image = drawIcon(size: size, signature: signature) else { continue }
        ctx.draw(image, in: CGRect(x: x, y: y, width: size, height: size))
        label("\(size)", at: CGPoint(x: x, y: y - 24), size: 18, color: RGB(0xE8, 0xE8, 0xEA))
        x += max(size, 64) + gutter
    }

    // 淺底一排
    y -= rowHeight
    ctx.setFillColor(RGB(0xF2, 0xF2, 0xF4).cgColor())
    ctx.fill(CGRect(x: 0, y: y - gutter / 2, width: width, height: 512 + labelSpace + gutter))
    x = padding
    for size in sizes {
        guard let image = drawIcon(size: size, signature: signature) else { continue }
        ctx.draw(image, in: CGRect(x: x, y: y, width: size, height: size))
        label("\(size)", at: CGPoint(x: x, y: y - 24), size: 18, color: RGB(0x3A, 0x3A, 0x3C))
        x += max(size, 64) + gutter
    }

    // 放大檢查排。關掉插值，看到的就是實際像素。
    y -= zoomRowHeight + 20
    ctx.setFillColor(RGB(0x55, 0x55, 0x58).cgColor())
    ctx.fill(CGRect(x: 0, y: y - gutter / 2, width: width, height: zoomRowHeight + gutter))
    ctx.interpolationQuality = .none
    x = padding
    for size in [16, 32] {
        guard let image = drawIcon(size: size, signature: signature) else { continue }
        let side = size * zoomFactor
        ctx.draw(image, in: CGRect(x: x, y: y, width: side, height: side))
        label("\(size) px 放大 \(zoomFactor)x", at: CGPoint(x: x, y: y - 24), size: 18, color: RGB(0xE8, 0xE8, 0xEA))
        x += side + gutter
    }

    guard let image = ctx.makeImage() else { return }
    writePNG(image, to: url)
}

// MARK: - 主流程

let outputRoot = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath)
let signature = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "AL"

// iconset 需要的十張圖。16 到 32 走簡化版，64 走中階，128 以上走完整版。
let iconsetEntries: [(name: String, size: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

let iconset = outputRoot.appendingPathComponent("Wipe.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for entry in iconsetEntries {
    guard let image = drawIcon(size: entry.size, signature: signature) else { continue }
    writePNG(image, to: iconset.appendingPathComponent("\(entry.name).png"))
}
writeContactSheet(
    signature: signature,
    to: outputRoot.appendingPathComponent("contact-sheet.png")
)
print("完成，輸出在 \(outputRoot.path)")
