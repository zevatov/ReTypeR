import Foundation
import AppKit
import CoreGraphics

let projectPath = "/Users/stanislav/Desktop/проекты/ReTypeR"
let originalLogoPath = "\(projectPath)/Добавить заголовок.png"
let iconPngPath = "\(projectPath)/icon.png"
let appIconPngPath = "\(projectPath)/Sources/App/AppIcon.png"
let appIconIcnsPath = "\(projectPath)/Sources/App/AppIcon.icns"
let rootIconIcnsPath = "\(projectPath)/icon.icns"
let dmgBgPath = "\(projectPath)/dmg_background.png"
let githubIconPath = "\(projectPath)/github_white.png"
let telegramIconPath = "\(projectPath)/telegram_white.png"
let assetsCatalogPath = "\(projectPath)/Sources/App/Assets.xcassets/AppIcon.appiconset"

func log(_ message: String) {
    print("[PrepareAssets] \(message)")
}

// 1. Load original logo
let logoURL = URL(fileURLWithPath: originalLogoPath)
guard let originalImage = NSImage(contentsOf: logoURL),
      let tiffData = originalImage.tiffRepresentation,
      let imageRep = NSBitmapImageRep(data: tiffData),
      let cgImage = imageRep.cgImage else {
    log("Error: Failed to load original logo from \(originalLogoPath)")
    exit(1)
}

let origW = cgImage.width
let origH = cgImage.height
log("Loaded logo: \(origW)x\(origH)")

// 2. Crop to square (3180x3180) to remove the bottom white space
let cropRect = CGRect(x: 0, y: 0, width: 3180, height: 3180)
guard let croppedCgImage = cgImage.cropping(to: cropRect) else {
    log("Error: Failed to crop logo to square")
    exit(1)
}

// Save as icon.png (flat square, white letters intact!)
let squareRep = NSBitmapImageRep(cgImage: croppedCgImage)
squareRep.size = NSSize(width: 3180, height: 3180)
guard let squarePngData = squareRep.representation(using: .png, properties: [:]) else {
    log("Error: Failed to generate PNG data for square icon")
    exit(1)
}
try squarePngData.write(to: URL(fileURLWithPath: iconPngPath))
log("Saved sharp cropped icon.png")

// 3. Create rounded corner (squircle) icon for AppIcon.png (1024x1024)
let canvasSize = 1024
guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(
        data: nil,
        width: canvasSize,
        height: canvasSize,
        bitsPerComponent: 8,
        bytesPerRow: canvasSize * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else {
    log("Error: Failed to create CGContext for rounded icon")
    exit(1)
}

context.clear(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))

// Apple squircle standard container
let iconSize: CGFloat = 824
let offset = (CGFloat(canvasSize) - iconSize) / 2.0
let rect = CGRect(x: offset, y: offset, width: iconSize, height: iconSize)
let cornerRadius: CGFloat = 180.0

let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
context.addPath(path)
context.clip()

// Draw cropped logo into the rounded rect mask
context.draw(croppedCgImage, in: rect)

guard let maskedCgImage = context.makeImage() else {
    log("Error: Failed to make masked image")
    exit(1)
}

let maskedRep = NSBitmapImageRep(cgImage: maskedCgImage)
maskedRep.size = NSSize(width: 1024, height: 1024)
guard let maskedPngData = maskedRep.representation(using: .png, properties: [:]) else {
    log("Error: Failed to generate PNG data for AppIcon")
    exit(1)
}
try maskedPngData.write(to: URL(fileURLWithPath: appIconPngPath))
log("Saved rounded AppIcon.png")

// 4. Generate ICNS files & Overwrite Assets.xcassets PNG files
func buildIcnsAndOverwriteAssets(fromPng pngPath: String, toIcns icnsPath: String, assetsDir: String) {
    let fileManager = FileManager.default
    let tempIconset = "\(pngPath).iconset"
    
    try? fileManager.removeItem(atPath: tempIconset)
    try? fileManager.createDirectory(atPath: tempIconset, withIntermediateDirectories: true, attributes: nil)
    
    struct IconSetSize {
        let size: Int
        let scale: Int
        var name: String {
            return scale == 2 ? "icon_\(size)x\(size)@2x.png" : "icon_\(size)x\(size).png"
        }
        var pixelDim: Int {
            return size * scale
        }
    }
    
    let sizes = [
        IconSetSize(size: 16, scale: 1),
        IconSetSize(size: 16, scale: 2),
        IconSetSize(size: 32, scale: 1),
        IconSetSize(size: 32, scale: 2),
        IconSetSize(size: 128, scale: 1),
        IconSetSize(size: 128, scale: 2),
        IconSetSize(size: 256, scale: 1),
        IconSetSize(size: 256, scale: 2),
        IconSetSize(size: 512, scale: 1),
        IconSetSize(size: 512, scale: 2)
    ]
    
    for item in sizes {
        let destFile = "\(tempIconset)/\(item.name)"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        process.arguments = ["-z", "\(item.pixelDim)", "\(item.pixelDim)", pngPath, "--out", destFile]
        try? process.run()
        process.waitUntilExit()
        
        // Also overwrite inside Assets.xcassets/AppIcon.appiconset
        let assetsDestFile = "\(assetsDir)/\(item.name)"
        if fileManager.fileExists(atPath: assetsDestFile) {
            try? fileManager.removeItem(atPath: assetsDestFile)
        }
        try? fileManager.copyItem(atPath: destFile, toPath: assetsDestFile)
    }
    
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", tempIconset, "-o", icnsPath]
    try? process.run()
    process.waitUntilExit()
    
    try? fileManager.removeItem(atPath: tempIconset)
    log("Generated ICNS at: \(icnsPath)")
    log("Overwrote all PNG files inside: \(assetsDir)")
}

buildIcnsAndOverwriteAssets(fromPng: appIconPngPath, toIcns: appIconIcnsPath, assetsDir: assetsCatalogPath)
// Copy the same rounded icns to root icon.icns for the volume icon
try? FileManager.default.removeItem(atPath: rootIconIcnsPath)
try FileManager.default.copyItem(atPath: appIconIcnsPath, toPath: rootIconIcnsPath)
log("Copied ICNS to root icon.icns")

// 5. Generate DMG background image
let bgSize = NSSize(width: 660, height: 480)
let bgImage = NSImage(size: bgSize)
bgImage.lockFocus()

// Draw brand gradient: #ff3131 (red) to #ff914d (orange) under 135 degrees
let brandStart = NSColor(red: 255/255, green: 49/255, blue: 49/255, alpha: 1)  // #ff3131 (red)
let brandEnd = NSColor(red: 255/255, green: 145/255, blue: 77/255, alpha: 1)  // #ff914d (orange)
let gradient = NSGradient(starting: brandStart, ending: brandEnd)
gradient?.draw(in: NSRect(origin: .zero, size: bgSize), angle: -45)

// Draw Background Info-graphics / UI Elements (opacity 0.05-0.08)
let infoColor = NSColor.white.withAlphaComponent(0.06)
let infoAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 18, weight: .bold),
    .foregroundColor: infoColor
]

// 1. Draw small crosses (+ / x) in corners
func drawCross(at point: NSPoint) {
    let crossPath = NSBezierPath()
    crossPath.move(to: NSPoint(x: point.x - 5, y: point.y))
    crossPath.line(to: NSPoint(x: point.x + 5, y: point.y))
    crossPath.move(to: NSPoint(x: point.x, y: point.y - 5))
    crossPath.line(to: NSPoint(x: point.x, y: point.y + 5))
    crossPath.lineWidth = 1.5
    NSColor.white.withAlphaComponent(0.12).setStroke()
    crossPath.stroke()
}

drawCross(at: NSPoint(x: 30, y: 30))
drawCross(at: NSPoint(x: bgSize.width - 30, y: 30))
drawCross(at: NSPoint(x: 30, y: bgSize.height - 30))
drawCross(at: NSPoint(x: bgSize.width - 30, y: bgSize.height - 30))

// 2. Draw copy-paste & keyboard theme symbols
"⌘C".draw(at: NSPoint(x: 80, y: 380), withAttributes: infoAttrs)
"⌘V".draw(at: NSPoint(x: bgSize.width - 120, y: 380), withAttributes: infoAttrs)
"|".draw(at: NSPoint(x: 290, y: 360), withAttributes: infoAttrs)

let letterAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 14, weight: .medium),
    .foregroundColor: infoColor
]
"A".draw(at: NSPoint(x: 110, y: 80), withAttributes: letterAttrs)
"Б".draw(at: NSPoint(x: bgSize.width - 120, y: 80), withAttributes: letterAttrs)
"R".draw(at: NSPoint(x: bgSize.width / 2 - 10, y: 75), withAttributes: letterAttrs)

// Draw translucent panel for icons (Y-centered around Y=240 in AppKit)
let panelPath = NSBezierPath(roundedRect: NSRect(x: 50, y: 150, width: 560, height: 180), xRadius: 16, yRadius: 16)
NSColor.white.withAlphaComponent(0.08).set()
panelPath.fill()
NSColor.white.withAlphaComponent(0.15).set()
panelPath.lineWidth = 1.5
panelPath.stroke()

// Draw Title "ReTypeR" (Flat style)
let titleText = "ReTypeR"
let titleFont = NSFont.systemFont(ofSize: 34, weight: .bold)
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: titleFont,
    .foregroundColor: NSColor.white
]
let titleSize = titleText.size(withAttributes: titleAttrs)
titleText.draw(at: NSPoint(x: (bgSize.width - titleSize.width)/2, y: bgSize.height - 55), withAttributes: titleAttrs)

// Draw Subtitle
let subtitleText = "Перетащите ReTypeR в Applications для установки"
let subtitleFont = NSFont.systemFont(ofSize: 13, weight: .medium)
let subtitleAttrs: [NSAttributedString.Key: Any] = [
    .font: subtitleFont,
    .foregroundColor: NSColor.white.withAlphaComponent(0.85)
]
let subtitleSize = subtitleText.size(withAttributes: subtitleAttrs)
subtitleText.draw(at: NSPoint(x: (bgSize.width - subtitleSize.width)/2, y: bgSize.height - 80), withAttributes: subtitleAttrs)

// Draw Version
let versionText = "Версия 1.0.0"
let versionFont = NSFont.systemFont(ofSize: 11, weight: .regular)
let versionAttrs: [NSAttributedString.Key: Any] = [
    .font: versionFont,
    .foregroundColor: NSColor.white.withAlphaComponent(0.6)
]
let versionSize = versionText.size(withAttributes: versionAttrs)
versionText.draw(at: NSPoint(x: (bgSize.width - versionSize.width)/2, y: bgSize.height - 100), withAttributes: versionAttrs)

// Draw beautiful custom Chevron Arrow (thick solid shape, centered at X=330, Y=240 in AppKit)
let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: 300, y: 240))
arrowPath.line(to: NSPoint(x: 335, y: 240))
arrowPath.line(to: NSPoint(x: 335, y: 228))
arrowPath.line(to: NSPoint(x: 360, y: 246)) // Arrow tip
arrowPath.line(to: NSPoint(x: 335, y: 264))
arrowPath.line(to: NSPoint(x: 335, y: 252))
arrowPath.line(to: NSPoint(x: 300, y: 252))
arrowPath.close()

NSColor.white.withAlphaComponent(0.45).set()
arrowPath.fill()

// Draw GitHub / Telegram links with white logo icons (moved up to Y=80 for safety)
let linkFont = NSFont.systemFont(ofSize: 11, weight: .regular)
let linkAttrs: [NSAttributedString.Key: Any] = [
    .font: linkFont,
    .foregroundColor: NSColor.white.withAlphaComponent(0.85)
]

let logoSize = NSSize(width: 18, height: 18)

// GitHub Link: Logo at X=50, Text next to it
if let ghIcon = NSImage(contentsOfFile: githubIconPath) {
    ghIcon.draw(in: NSRect(x: 50, y: 80, width: logoSize.width, height: logoSize.height), from: .zero, operation: .sourceOver, fraction: 0.85)
}
let githubText = "github.com/your_github_repo"
githubText.draw(at: NSPoint(x: 74, y: 82), withAttributes: linkAttrs)

// Telegram Link: Text and Logo aligned to the right
let telegramText = "t.me/your_telegram_channel"
let tgTextSize = telegramText.size(withAttributes: linkAttrs)
let tgTextX = bgSize.width - tgTextSize.width - 50
let tgLogoX = tgTextX - 24

if let tgIcon = NSImage(contentsOfFile: telegramIconPath) {
    tgIcon.draw(in: NSRect(x: tgLogoX, y: 80, width: logoSize.width, height: logoSize.height), from: .zero, operation: .sourceOver, fraction: 0.85)
}
telegramText.draw(at: NSPoint(x: tgTextX, y: 82), withAttributes: linkAttrs)

bgImage.unlockFocus()

// Save DMG background
guard let bgTiffData = bgImage.tiffRepresentation,
      let bgBitmapRep = NSBitmapImageRep(data: bgTiffData),
      let bgPngData = bgBitmapRep.representation(using: .png, properties: [:]) else {
    log("Error: Failed to save DMG background")
    exit(1)
}
try bgPngData.write(to: URL(fileURLWithPath: dmgBgPath))
log("Successfully generated dmg_background.png")
log("Asset preparation complete!")
