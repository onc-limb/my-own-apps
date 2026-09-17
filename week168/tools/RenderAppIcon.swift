import AppKit
import CoreText

// Week168 app icon (D-109): "168" on a dark ground, with a red rule below standing for the cap.
// The numerals and the rule are laid out as one group and centred together, so the icon has no
// dead space. Rendered down to 29pt because that is the size the decision has to survive.

let ink = NSColor(srgbRed: 0x16 / 255, green: 0x18 / 255, blue: 0x1C / 255, alpha: 1)
let paper = NSColor(srgbRed: 0xF3 / 255, green: 0xF0 / 255, blue: 0xE9 / 255, alpha: 1)
let red = NSColor(srgbRed: 0xD8 / 255, green: 0x44 / 255, blue: 0x3C / 255, alpha: 1)

struct Layout {
    // "168" at heavy weight is a wide mark, so width is the binding constraint, not height.
    // Leave ~16% on each side: the rounded mask iOS applies would clip anything closer.
    var width: CGFloat = 0.68     // glyph width as a fraction of the canvas
    var tracking: CGFloat = 0.05  // negative kerning, as a fraction of the point size
    var gap: CGFloat = 0.062      // space between the numerals and the rule
    var rule: CGFloat = 0.042     // rule thickness
}

/// Point size at which "168" is exactly `targetWidth` wide, found from one measurement.
func pointSize(forWidth targetWidth: CGFloat, layout: Layout) -> CGFloat {
    let reference: CGFloat = 100
    let font = NSFont.systemFont(ofSize: reference, weight: .heavy)
    let probe = NSAttributedString(string: "168", attributes: [
        .font: font, .kern: -reference * layout.tracking,
    ])
    let measured = CTLineGetBoundsWithOptions(CTLineCreateWithAttributedString(probe), .useOpticalBounds).width
    return reference * targetWidth / measured
}

func render(size: CGFloat, layout: Layout = Layout()) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else { fatalError("no context") }

    ink.setFill()
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))

    // Heavy weight keeps the counters of 6 and 8 open once the icon shrinks.
    let points = pointSize(forWidth: size * layout.width, layout: layout)
    let font = NSFont.systemFont(ofSize: points, weight: .heavy)
    let text = NSAttributedString(string: "168", attributes: [
        .font: font, .foregroundColor: paper, .kern: -points * layout.tracking,
    ])
    let line = CTLineCreateWithAttributedString(text)
    let glyphs = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

    let ruleHeight = size * layout.rule
    let gap = size * layout.gap
    let groupHeight = glyphs.height + gap + ruleHeight
    let groupBottom = (size - groupHeight) / 2

    let x = (size - glyphs.width) / 2 - glyphs.minX
    context.textPosition = CGPoint(x: x, y: groupBottom + ruleHeight + gap - glyphs.minY)
    CTLineDraw(line, context)

    // The rule spans the numerals, so the two read as one mark rather than two objects.
    red.setFill()
    let rule = CGRect(x: (size - glyphs.width) / 2, y: groupBottom, width: glyphs.width, height: ruleHeight)
    context.addPath(CGPath(roundedRect: rule, cornerWidth: ruleHeight / 2,
                           cornerHeight: ruleHeight / 2, transform: nil))
    context.fillPath()

    image.unlockFocus()
    return image
}

/// App Store Connect rejects app icons that carry an alpha channel, so composite onto an
/// opaque bitmap rather than exporting the image's own representation.
func write(_ image: NSImage, to path: String) {
    let side = Int(image.size.width)
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                                     bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false,
                                     isPlanar: false, colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0) else { fatalError("no bitmap") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: CGRect(x: 0, y: 0, width: CGFloat(side), height: CGFloat(side)))
    NSGraphicsContext.restoreGraphicsState()
    guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("encode failed") }
    try! png.write(to: URL(fileURLWithPath: path))
}

let outputDirectory = CommandLine.arguments[1]
let master = render(size: 1024)
write(master, to: "\(outputDirectory)/icon-1024.png")

// Downscale the master the way iOS does, instead of re-rendering at each size.
for side in [180, 120, 87, 80, 60, 58, 40, 29] {
    let scaled = NSImage(size: NSSize(width: side, height: side))
    scaled.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    master.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
    scaled.unlockFocus()
    write(scaled, to: "\(outputDirectory)/icon-\(side).png")
}

// A contact sheet of the small sizes on one canvas, so legibility can be compared at a glance.
let sheetSizes: [CGFloat] = [120, 87, 60, 40, 29]
let sheetPad: CGFloat = 24
let sheetWidth = sheetSizes.reduce(sheetPad) { $0 + $1 + sheetPad }
let sheet = NSImage(size: NSSize(width: sheetWidth, height: 120 + sheetPad * 2))
sheet.lockFocus()
NSColor(srgbRed: 0.42, green: 0.42, blue: 0.44, alpha: 1).setFill()
NSBezierPath.fill(CGRect(x: 0, y: 0, width: sheetWidth, height: 120 + sheetPad * 2))
NSGraphicsContext.current?.imageInterpolation = .high
var cursor = sheetPad
for side in sheetSizes {
    master.draw(in: CGRect(x: cursor, y: sheetPad + (120 - side) / 2, width: side, height: side))
    cursor += side + sheetPad
}
sheet.unlockFocus()
if let tiff = sheet.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    try! png.write(to: URL(fileURLWithPath: "\(outputDirectory)/contact-sheet.png"))
}
print("rendered to \(outputDirectory)")
