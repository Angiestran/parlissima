// Ritar Talas ikon: korall ljudvåg på GrowingSmart-indigo. Kör: swift scripts/icon.swift <ut.png>
import AppKit
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let rect = NSRect(x: 0, y: 0, width: size, height: size).insetBy(dx: 80, dy: 80)
let path = NSBezierPath(roundedRect: rect, xRadius: 190, yRadius: 190)
NSGradient(colors: [NSColor(red: 0x3d/255, green: 0x33/255, blue: 0x72/255, alpha: 1),
                    NSColor(red: 0x16/255, green: 0x12/255, blue: 0x2b/255, alpha: 1)])!.draw(in: path, angle: -60)
let coral = NSColor(red: 1, green: 0x8a/255, blue: 0x96/255, alpha: 1)
let heights: [CGFloat] = [120, 230, 380, 520, 380, 250, 440, 300, 160]
let barW: CGFloat = 46, gap: CGFloat = 26
let total = CGFloat(heights.count) * barW + CGFloat(heights.count - 1) * gap
var x = (size - total) / 2
for h in heights {
    coral.setFill()
    NSBezierPath(roundedRect: NSRect(x: x, y: (size - h) / 2, width: barW, height: h), xRadius: barW / 2, yRadius: barW / 2).fill()
    x += barW + gap
}
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
