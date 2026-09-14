import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
func draw(size: Int, filename: String) throws {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let factor = CGFloat(size) / 1024
    let transform = NSAffineTransform()
    transform.scale(by: factor)
    transform.concat()
    let rect = NSRect(x: 92, y: 92, width: 840, height: 840)
    let outer = NSBezierPath(roundedRect: rect, xRadius: 188, yRadius: 188)
    NSGradient(starting: NSColor(calibratedRed: 0.22, green: 0.28, blue: 0.4, alpha: 1), ending: NSColor(calibratedRed: 0.07, green: 0.10, blue: 0.17, alpha: 1))!.draw(in: outer, angle: -70)
    let keyboard = NSBezierPath(roundedRect: NSRect(x: 208, y: 302, width: 608, height: 392), xRadius: 46, yRadius: 46)
    NSColor.white.withAlphaComponent(0.12).setFill(); keyboard.fill()
    NSColor.white.withAlphaComponent(0.28).setStroke(); keyboard.lineWidth = 3; keyboard.stroke()
    for row in 0..<3 {
        for column in 0..<6 {
            let key = NSBezierPath(roundedRect: NSRect(x: 244 + column * 91, y: 577 - row * 83, width: 73, height: 64), xRadius: 13, yRadius: 13)
            if row == 1 && column == 2 { NSColor(calibratedRed: 0.47, green: 0.81, blue: 0.96, alpha: 1).setFill() }
            else { NSColor.white.withAlphaComponent(0.88).setFill() }
            key.fill()
        }
    }
    NSColor.white.withAlphaComponent(0.65).setFill()
    NSBezierPath(roundedRect: NSRect(x: 348, y: 335, width: 328, height: 47), xRadius: 12, yRadius: 12).fill()
    image.unlockFocus()
    let representation = NSBitmapImageRep(data: image.tiffRepresentation!)!
    try representation.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(filename))
}
for size in [16, 32, 128, 256, 512] {
    try draw(size: size, filename: "icon_\(size)x\(size).png")
    try draw(size: size * 2, filename: "icon_\(size)x\(size)@2x.png")
}
