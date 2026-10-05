import SwiftUI
import AppKit
import ApplicationServices

/// Allt som behövs innan första dikteringen: Klangs modell, mikrofon och hjälpmedel.
@MainActor
final class SetupModel: ObservableObject {
    static let shared = SetupModel()

    @Published var modelReady = PianissimoModel.isInstalled
    @Published var downloading = false
    @Published var progress: Double = 0
    @Published var downloadError: String?
    @Published var micReady = Recorder.micAuthorized
    @Published var accessReady = AXIsProcessTrusted()

    var allReady: Bool { modelReady && micReady && accessReady }

    func refresh() {
        modelReady = PianissimoModel.isInstalled
        micReady = Recorder.micAuthorized
        accessReady = AXIsProcessTrusted()
    }

    func downloadModel() {
        guard !downloading else { return }
        downloading = true
        downloadError = nil
        progress = 0
        Task {
            do {
                try await PianissimoModel.install { p in Task { @MainActor in SetupModel.shared.progress = p } }
                modelReady = true
                try? await SpeechEngine.shared.load()
            } catch {
                downloadError = error.localizedDescription
            }
            downloading = false
        }
    }

    func askMic() {
        Task {
            _ = await Recorder.requestMic()
            micReady = Recorder.micAuthorized
            if !micReady {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
            }
        }
    }

    func askAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

struct SetupView: View {
    @ObservedObject var model = SetupModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Parlissima").font(.system(size: 40, weight: .heavy)).foregroundStyle(.white)
                Text("Svensk diktering med Klang Pianissimo. Allt stannar på din Mac.")
                    .font(.system(size: 16)).foregroundStyle(Brand.soft)
            }

            step(1, "Klangs språkmodell", done: model.modelReady,
                 detail: model.modelReady ? "Hämtad och kontrollerad." :
                         model.downloading ? "Hämtar \(Int(model.progress * 100)) % – ungefär 690 MB, en gång."
                                           : "Hämtas en gång från Hugging Face, ungefär 690 MB.") {
                if model.downloading {
                    ProgressView(value: model.progress).tint(Brand.coral).frame(width: 150)
                } else if !model.modelReady {
                    button("Hämta") { model.downloadModel() }
                }
            }
            if let err = model.downloadError {
                Text(err).font(.system(size: 14)).foregroundStyle(Brand.coral)
            }

            step(2, "Mikrofon", done: model.micReady,
                 detail: "Så att Parlissima kan höra dig. Ljudet lämnar aldrig datorn.") {
                if !model.micReady { button("Tillåt") { model.askMic() } }
            }

            step(3, "Hjälpmedel", done: model.accessReady,
                 detail: "Så att kortkommandot fungerar överallt och texten kan klistras in. Slå på Parlissima i listan.") {
                if !model.accessReady { button("Öppna inställningar") { model.askAccess() } }
            }

            Divider().overlay(Color.white.opacity(0.15))

            if model.allReady {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Klart! Klicka på pingvinen och prata.")
                        .font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                    Text("Klicka igen när du är klar. Du kan också hålla in höger option (⌥) eller höger control (⌃). Esc avbryter. Dikteringar sparas i två timmar under Senaste i menyraden.")
                        .font(.system(size: 14)).foregroundStyle(Brand.soft)
                }
            }

            Spacer(minLength: 0)
            Text("Taligenkänning: Klang Pianissimo, Klang AI AB (CC BY 4.0) · Core ML: markstrom · FluidAudio (Apache 2.0)")
                .font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.55))
        }
        .padding(36)
        .frame(width: 560, height: 560, alignment: .topLeading)
        .background(Brand.background)
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in model.refresh() }
    }

    private func step<Trailing: View>(_ n: Int, _ title: String, done: Bool, detail: String,
                                      @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle().fill(done ? Brand.sky.opacity(0.22) : Color.white.opacity(0.1)).frame(width: 36, height: 36)
                if done { Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Brand.sky) }
                else { Text("\(n)").font(.system(size: 16, weight: .bold)).foregroundStyle(.white) }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                Text(detail).font(.system(size: 14)).foregroundStyle(Brand.soft).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            trailing()
        }
    }

    private func button(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Brand.night)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Capsule().fill(Brand.coral))
        }
        .buttonStyle(.plain)
    }
}

@MainActor
final class SetupWindow {
    static let shared = SetupWindow()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 560),
                             styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isReleasedWhenClosed = false
            w.appearance = NSAppearance(named: .darkAqua)
            w.contentView = NSHostingView(rootView: SetupView())
            w.center()
            window = w
        }
        SetupModel.shared.refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
