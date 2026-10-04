import AppKit
import ApplicationServices
import Carbon

/// Klistrar in text där markören står och lägger sedan tillbaka det du hade i urklipp.
@MainActor
enum Inserter {
    /// Står markören i ett lösenordsfält? Då klistrar Tala aldrig in något.
    static var inPasswordField: Bool {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.2)
        var focused: CFTypeRef?
        if AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
           let element = focused, CFGetTypeID(element) == AXUIElementGetTypeID() {
            var subrole: CFTypeRef?
            AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSubroleAttribute as CFString, &subrole)
            return (subrole as? String) == (kAXSecureTextFieldSubrole as String)
        }
        return IsSecureEventInputEnabled()
    }

    static func paste(_ text: String) {
        let pb = NSPasteboard.general
        let saved = snapshot(pb)
        pb.clearContents()
        pb.setString(text, forType: .string)
        // Säg åt urklippshanterare att inte spara den här texten.
        pb.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        let ours = pb.changeCount

        let src = CGEventSource(stateID: .combinedSessionState)
        let v = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard pb.changeCount == ours else { return }   // något annat har kopierats under tiden
            pb.clearContents()
            if let saved, !saved.isEmpty { pb.writeObjects(saved) }
        }
    }

    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Kopia av urklipp att lägga tillbaka. Lösenord från lösenordshanterare läggs aldrig tillbaka.
    private static func snapshot(_ pb: NSPasteboard) -> [NSPasteboardItem]? {
        let secret = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"]
            .map { NSPasteboard.PasteboardType(rawValue: $0) }
        let items = pb.pasteboardItems ?? []
        if items.contains(where: { $0.types.contains(where: secret.contains) }) { return nil }
        return items.map { item in
            let copy = NSPasteboardItem()
            for t in item.types { if let d = item.data(forType: t) { copy.setData(d, forType: t) } }
            return copy
        }
    }
}
