import SwiftUI
import AppKit

// MARK: - Fönstret som cybergumman bor i: ligger överst på skärmen.
// Klick = starta/stoppa diktering. Dra = flytta. Tar aldrig fokus, så texten hamnar
// där markören redan står (t.ex. i Claudes skrivfält).


/// Panel som tar emot klick men aldrig blir aktiv – fokus stannar i appen du skriver i.
private final class OwlPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Skiljer klick från dragning: klick startar/stoppar, dragning flyttar figuren.
private final class OwlHost: NSHostingView<GrannyView> {
    var onClick: (() -> Void)?
    var onMoved: ((NSPoint) -> Void)?
    private var start: NSPoint?
    private var origin: NSPoint?
    private var dragged = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with e: NSEvent) {
        start = NSEvent.mouseLocation; origin = window?.frame.origin; dragged = false
    }
    override func mouseDragged(with e: NSEvent) {
        guard let start, let origin, let w = window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - start.x, dy = now.y - start.y
        if !dragged && hypot(dx, dy) < 4 { return }
        dragged = true
        w.setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y + dy))
    }
    override func mouseUp(with e: NSEvent) {
        if dragged, let o = window?.frame.origin { onMoved?(o) } else { onClick?() }
        start = nil
    }
}

@MainActor
final class Owl {
    static let shared = Owl()
    private var panel: NSPanel?
    private let key = "gummansPosition"
    private let shownKey = "visaUgglan"

    var isShown: Bool {
        get { UserDefaults.standard.object(forKey: shownKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: shownKey); newValue ? show() : hide() }
    }

    func show() {
        let p = panel ?? make()
        panel = p
        p.orderFrontRegardless()
    }

    func hide() { panel?.orderOut(nil) }

    private func make() -> NSPanel {
        let p = OwlPanel(contentRect: NSRect(origin: .zero, size: GrannyView.size),
                         styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .floating
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let host = OwlHost(rootView: GrannyView(model: Dictation.shared.hud.model))
        host.onClick = { Dictation.shared.toggle() }
        host.onMoved = { [key] o in UserDefaults.standard.set(NSStringFromPoint(o), forKey: key) }
        p.contentView = host
        if let s = UserDefaults.standard.string(forKey: key) {
            p.setFrameOrigin(NSPointFromString(s))
        } else if let vf = NSScreen.main?.visibleFrame {
            p.setFrameOrigin(NSPoint(x: vf.maxX - 170, y: vf.minY + 40))   // nere till höger
        }
        return p
    }
}
