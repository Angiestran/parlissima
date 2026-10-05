// Ritar bakgrunden till Parlissimas installationsfönster (660 x 400 pt, @2x).
// Kör: swift scripts/dmg-background.swift <ut.png>
import AppKit

let w: CGFloat = 660, h: CGFloat = 400, scale: CGFloat = 2
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w * scale), pixelsHigh: Int(h * scale),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: w, height: h)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(red: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

// Bakgrund: GrowingSmarts varma plum-gradient
NSGradient(colors: [rgb(0x2d1838), rgb(0x1c1230)])!.draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: -70)
// Mjuk korallglöd uppe till höger
NSGradient(colors: [rgb(0xd15261, 0.30), rgb(0xd15261, 0)])!
    .draw(fromCenter: NSPoint(x: w - 90, y: h - 40), radius: 0, toCenter: NSPoint(x: w - 90, y: h - 40), radius: 260, options: [])

// Rubrik och instruktion
func text(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, y: CGFloat) {
    let p = NSMutableParagraphStyle(); p.alignment = .center
    let a: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight),
                                            .foregroundColor: color, .paragraphStyle: p]
    NSAttributedString(string: s, attributes: a).draw(in: NSRect(x: 0, y: y, width: w, height: size * 1.5))
}
text("Installera Parlissima", size: 26, weight: .heavy, color: .white, y: h - 70)
text("Dra Parlissima till mappen Appar", size: 15, weight: .regular, color: rgb(0xf4ede0, 0.85), y: h - 100)

// Ljusa kort bakom ikonerna så att Finders ikonnamn syns tydligt
for cx in [CGFloat(170), CGFloat(490)] {
    let card = NSBezierPath(roundedRect: NSRect(x: cx - 88, y: h - 290, width: 176, height: 170), xRadius: 22, yRadius: 22)
    rgb(0xf4ede0, 0.94).setFill()
    card.fill()
}

// Pil mellan ikonerna (ikonerna ligger vid x 170 och 490, y 190 i fönstret)
let arrow = NSBezierPath()
arrow.lineWidth = 5
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
let ay: CGFloat = h - 205
arrow.move(to: NSPoint(x: 275, y: ay)); arrow.line(to: NSPoint(x: 385, y: ay))
arrow.move(to: NSPoint(x: 365, y: ay + 18)); arrow.line(to: NSPoint(x: 387, y: ay)); arrow.line(to: NSPoint(x: 365, y: ay - 18))
rgb(0xff8598).setStroke()
arrow.stroke()

// Fotnot
text("Första gången: klicka Klar i varningen och sedan Öppna ändå under Systeminställningar › Integritet och säkerhet.",
     size: 11.5, weight: .regular, color: rgb(0xc0c4d6), y: 34)
text("Klang Pianissimo · helt lokalt på din Mac", size: 11, weight: .semibold, color: rgb(0x9db8ff), y: 14)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
