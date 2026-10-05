import SwiftUI
import AppKit

/// GrowingSmart-färger för mörka ytor: indigo-grafit, ljus korall, ljusblått, vit text.
enum Brand {
    static let graphite = Color(red: 0x32/255, green: 0x2a/255, blue: 0x5e/255)
    static let night = Color(red: 0x16/255, green: 0x12/255, blue: 0x2b/255)
    static let coral = Color(red: 0xff/255, green: 0x8a/255, blue: 0x96/255)
    static let sky = Color(red: 0x9f/255, green: 0xc8/255, blue: 0xff/255)
    static let soft = Color.white.opacity(0.78)

    static var background: LinearGradient {
        LinearGradient(colors: [graphite, night], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Indikatorn högst upp på skärmen

@MainActor
final class HUDModel: ObservableObject {
    enum Phase: Equatable {
        case hidden
        case listening(handsfree: Bool)
        case waiting            // första korta trycket – väntar på dubbeltryck
        case writing
        case done(String)
        case problem(String)
    }
    @Published var phase: Phase = .hidden
    @Published var levels: [Float] = Array(repeating: 0, count: 32)
    @Published var started = Date()

    func push(_ level: Float) {
        levels.removeFirst()
        levels.append(level)
    }
}

struct HUDView: View {
    @ObservedObject var model: HUDModel

    var body: some View {
        HStack(spacing: 14) {
            icon
            content
        }
        .padding(.horizontal, 20)
        .frame(height: 64)
        .background(
            Capsule().fill(Brand.background)
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
        )
        .fixedSize()
        .padding(24)
        .animation(.easeOut(duration: 0.18), value: model.phase)
    }

    @ViewBuilder private var icon: some View {
        switch model.phase {
        case .listening, .waiting:
            Circle().fill(Brand.coral).frame(width: 12, height: 12)
                .shadow(color: Brand.coral.opacity(0.9), radius: 6)
        case .writing:
            ProgressView().controlSize(.small).tint(.white)
        case .done:
            Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundStyle(Brand.sky)
        case .problem:
            Image(systemName: "exclamationmark.circle.fill").font(.system(size: 20)).foregroundStyle(Brand.coral)
        case .hidden:
            EmptyView()
        }
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .listening(let handsfree):
            Waveform(levels: model.levels).frame(width: 150, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                TimelineView(.periodic(from: model.started, by: 1)) { ctx in
                    Text(Self.clock(ctx.date.timeIntervalSince(model.started)))
                        .font(.system(size: 17, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                }
                Text(handsfree ? "Klicka på pingvinen eller tryck höger alt" : "Släpp när du är klar")
                    .font(.system(size: 14)).foregroundStyle(Brand.soft)
            }
        case .waiting:
            Text("Tryck igen för handsfree").font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
        case .writing:
            Text("Skriver …").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
        case .done(let msg), .problem(let msg):
            Text(msg).font(.system(size: 15, weight: .medium)).foregroundStyle(.white).lineLimit(2)
                .frame(maxWidth: 360, alignment: .leading)
        case .hidden:
            EmptyView()
        }
    }

    static func clock(_ t: TimeInterval) -> String {
        let s = max(0, Int(t))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

struct Waveform: View {
    let levels: [Float]
    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(levels.indices, id: \.self) { i in
                Capsule()
                    .fill(Brand.coral.opacity(0.55 + 0.45 * Double(levels[i])))
                    .frame(width: 2.5, height: max(3, CGFloat(levels[i]) * 30))
            }
        }
        .animation(.linear(duration: 0.08), value: levels)
    }
}

@MainActor
final class HUDPanel {
    let model = HUDModel()
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    func show(_ phase: HUDModel.Phase, hideAfter: TimeInterval? = nil) {
        hideWork?.cancel()
        if case .listening = phase, !isListening { model.started = Date() }
        model.phase = phase
        let panel = self.panel ?? makePanel()
        self.panel = panel
        place(panel)
        panel.orderFrontRegardless()
        if let hideAfter {
            let work = DispatchWorkItem { [weak self] in self?.hide() }
            hideWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + hideAfter, execute: work)
        }
    }

    func hide() {
        hideWork?.cancel()
        model.phase = .hidden
        model.levels = Array(repeating: 0, count: model.levels.count)
        panel?.orderOut(nil)
    }

    private var isListening: Bool { if case .listening = model.phase { return true }; return false }

    private func makePanel() -> NSPanel {
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 112),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .statusBar
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let host = NSHostingView(rootView: HUDView(model: model))
        host.frame = p.contentRect(forFrameRect: p.frame)
        host.autoresizingMask = [.width, .height]
        p.contentView = host
        return p
    }

    /// Mitt på skärmen där muspekaren är, precis under menyraden.
    private func place(_ p: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let vf = screen?.visibleFrame else { return }
        let size = p.frame.size
        p.setFrameOrigin(NSPoint(x: vf.midX - size.width / 2, y: vf.maxY - size.height + 8))
    }
}
