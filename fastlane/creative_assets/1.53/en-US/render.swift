import AppKit
import CoreGraphics

struct CreativeAsset {
    let width: Int
    let height: Int
    let backgroundName: String
    let outputName: String
    let headline: String
    let supportingText: String
}

func loadImage(_ url: URL) throws -> CGImage {
    guard let image = NSImage(contentsOf: url),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw NSError(domain: "CreativeAssets", code: 1)
    }
    return cgImage
}

func drawImage(_ image: CGImage, in rect: CGRect, context: CGContext) {
    let scale = max(rect.width / CGFloat(image.width), rect.height / CGFloat(image.height))
    let width = CGFloat(image.width) * scale
    let height = CGFloat(image.height) * scale
    let destination = CGRect(
        x: rect.midX - width / 2,
        y: rect.midY - height / 2,
        width: width,
        height: height
    )
    context.draw(image, in: destination)
}

func drawText(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color
    ]
    (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
}

func render(_ asset: CreativeAsset, root: URL, screenshot: CGImage) throws {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: asset.width,
        pixelsHigh: asset.height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high

    let context = graphics.cgContext
    let bounds = CGRect(x: 0, y: 0, width: asset.width, height: asset.height)
    let background = try loadImage(root.appending(path: "sources/\(asset.backgroundName)"))
    drawImage(background, in: bounds, context: context)

    let colors = [
        NSColor(calibratedRed: 0.015, green: 0.065, blue: 0.13, alpha: 0.92).cgColor,
        NSColor(calibratedRed: 0.015, green: 0.065, blue: 0.13, alpha: 0.62).cgColor,
        NSColor(calibratedRed: 0.015, green: 0.065, blue: 0.13, alpha: 0.12).cgColor
    ] as CFArray
    let locations: [CGFloat] = [0, 0.56, 1]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations)!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: asset.height / 2),
        end: CGPoint(x: asset.width, y: asset.height / 2),
        options: []
    )

    let scale = CGFloat(asset.width) / 3840
    let left = CGFloat(asset.width) * 0.065
    let phoneHeight = CGFloat(asset.height) * 0.87
    let phoneWidth = phoneHeight * 0.47
    let phoneX = CGFloat(asset.width) - phoneWidth - CGFloat(asset.width) * 0.075
    let phoneY = (CGFloat(asset.height) - phoneHeight) / 2
    let frame = CGRect(x: phoneX, y: phoneY, width: phoneWidth, height: phoneHeight)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12 * scale), blur: 38 * scale, color: NSColor.black.withAlphaComponent(0.52).cgColor)
    let framePath = NSBezierPath(roundedRect: frame, xRadius: 76 * scale, yRadius: 76 * scale)
    NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
    framePath.fill()
    context.restoreGState()

    let inset = 18 * scale
    let screen = frame.insetBy(dx: inset, dy: inset)
    let screenPath = NSBezierPath(roundedRect: screen, xRadius: 62 * scale, yRadius: 62 * scale)
    context.saveGState()
    context.addPath(screenPath.cgPath)
    context.clip()
    drawImage(screenshot, in: screen, context: context)
    context.restoreGState()

    let notch = CGRect(
        x: frame.midX - 56 * scale,
        y: frame.maxY - 34 * scale,
        width: 112 * scale,
        height: 12 * scale
    )
    NSColor(calibratedWhite: 0.035, alpha: 1).setFill()
    NSBezierPath(roundedRect: notch, xRadius: 6 * scale, yRadius: 6 * scale).fill()

    drawText("BASKETBALL RECORD", x: left, y: CGFloat(asset.height) * 0.79, size: 34 * scale, weight: .bold, color: NSColor(calibratedRed: 1, green: 0.42, blue: 0.16, alpha: 1))
    drawText(asset.headline, x: left, y: CGFloat(asset.height) * 0.59, size: 142 * scale, weight: .bold, color: .white)
    let accent = CGRect(x: left, y: CGFloat(asset.height) * 0.53, width: 170 * scale, height: 13 * scale)
    NSColor(calibratedRed: 1, green: 0.34, blue: 0.11, alpha: 1).setFill()
    NSBezierPath(roundedRect: accent, xRadius: 6 * scale, yRadius: 6 * scale).fill()
    drawText(asset.supportingText, x: left, y: CGFloat(asset.height) * 0.43, size: 54 * scale, weight: .medium, color: NSColor(calibratedWhite: 0.96, alpha: 1))
    drawText("LIVE SCORING  ·  VOICE INPUT  ·  CAREER STATS", x: left, y: CGFloat(asset.height) * 0.31, size: 30 * scale, weight: .semibold, color: NSColor(calibratedWhite: 0.9, alpha: 1))

    NSGraphicsContext.restoreGraphicsState()
    let output = root.appending(path: asset.outputName)
    guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.92]) else {
        throw NSError(domain: "CreativeAssets", code: 2)
    }
    try data.write(to: output)
}

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let screenshotURL = URL(fileURLWithPath: CommandLine.arguments[2])
let screenshot = try loadImage(screenshotURL)
let assets = [
    CreativeAsset(
        width: 3840,
        height: 1646,
        backgroundName: "court-header-background.png",
        outputName: "product-page-header.jpg",
        headline: "Every play. On record.",
        supportingText: "Keep your eyes on the game."
    ),
    CreativeAsset(
        width: 2880,
        height: 1920,
        backgroundName: "court-search-background.png",
        outputName: "search-results.jpg",
        headline: "Score live.\nReview every play.",
        supportingText: "One clear view of the whole game."
    )
]

for asset in assets {
    try render(asset, root: root, screenshot: screenshot)
}
