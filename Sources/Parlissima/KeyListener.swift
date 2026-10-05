import AppKit
import Carbon.HIToolbox

/// Lyssnar på höger option (⌥) och höger control (⌃) – båda fungerar likadant.
/// - Håll in: spelar in tills du släpper.
/// - Dubbeltryck: handsfree, avsluta med ett tryck till.
/// - Esc: avbryter utan att något skrivs.
/// - ⌥ + annan tangent (t.ex. ⌥2 för @): räknas som kortkommando, inte diktering.
@MainActor
final class KeyListener {
    static let shared = KeyListener()

    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    var onChord: (() -> Void)?
    var onEscape: (() -> Bool)?

    /// Dikteringstangenter → deras egen bit i event-flaggorna (skiljer höger från vänster).
    private let keys: [UInt16: UInt64] = [
        UInt16(kVK_RightOption): 0x40,          // NX_DEVICERALTKEYMASK  – höger option
        UInt16(kVK_RightControl): 0x2000,       // NX_DEVICERCTLKEYMASK – höger control
    ]
    private var tap: CFMachPort?
    private var isDown = false
    private(set) var isRunning = false

    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }
        let events: CGEventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: events,
            callback: { _, type, event, _ in
                MainActor.assumeIsolated { KeyListener.shared.handle(type, event) }
            }, userInfo: nil) else { return false }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if type == .flagsChanged, let mask = keys[code] {
            let down = event.flags.rawValue & mask != 0
            if down != isDown {
                isDown = down
                // Gör jobbet efter att tangenttryckningen släppts vidare – mikrofonen får inte sinka tangentbordet.
                DispatchQueue.main.async { down ? self.onPress?() : self.onRelease?() }
            }
            return pass
        }
        if type == .keyDown {
            if Int(code) == kVK_Escape, event.getIntegerValueField(.keyboardEventAutorepeat) == 0,
               onEscape?() == true { return nil }
            if isDown { DispatchQueue.main.async { self.onChord?() } }
        }
        return pass
    }
}
