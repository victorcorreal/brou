// Package Brou's shared opaque artwork as a macOS icon. The master is the
// same one used by the iPhone app; only the system-specific framing differs.
import AppKit

let arguments = CommandLine.arguments
let out = URL(fileURLWithPath: arguments.dropFirst().first ?? "AppIcon.iconset")
let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("Brand/Brou.png")
guard let artwork = NSImage(contentsOf: source) else {
    fatalError("Missing Brou artwork at \(source.path)")
}
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func png(pixels: Int, framed: Bool) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels,
        pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: pixels * 4,
        bitsPerPixel: 32)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    let size = CGFloat(pixels)
    let scale = size / 1024
    let plate = framed
        ? NSRect(x: 100 * scale, y: 100 * scale, width: 824 * scale, height: 824 * scale)
        : NSRect(x: 0, y: 0, width: size, height: size)
    if framed {
        let shape = NSBezierPath(roundedRect: plate, xRadius: 184.3 * scale, yRadius: 184.3 * scale)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = .black.withAlphaComponent(0.16)
        shadow.shadowBlurRadius = 24 * scale
        shadow.shadowOffset = NSSize(width: 0, height: -10 * scale)
        shadow.set()
        NSColor.black.setFill()
        shape.fill()
        NSGraphicsContext.restoreGraphicsState()
        shape.addClip()
    }
    artwork.draw(in: plate, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        let name = "icon_\(points)x\(points)\(suffix).png"
        try png(pixels: points * scale, framed: true).write(to: out.appendingPathComponent(name))
    }
}

// Icon Composer supplies the platform's outer mask in Dark, Clear and Tinted
// Dock styles. Its layer is a full square, without baked-in outer corners.
if arguments.count > 2 {
    let doc = URL(fileURLWithPath: arguments[2])
    let assets = doc.appendingPathComponent("Assets")
    try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
    try png(pixels: 1024, framed: false).write(to: assets.appendingPathComponent("Brou.png"))
    let document: [String: Any] = [
        "fill": ["solid": "srgb:0.00000,0.00000,0.00000,1.00000"],
        "groups": [[
            "layers": [["name": "Brou", "image-name": "Brou.png", "glass": false]],
            "shadow": ["kind": "none", "opacity": 0.0],
            "specular": false,
            "translucency": ["enabled": false, "value": 0.0]
        ]],
        "supported-platforms": ["squares": ["macOS"]]
    ]
    try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys])
        .write(to: doc.appendingPathComponent("icon.json"))
}
