import AppKit
import ServiceManagement
import AVFoundation
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var accessTimer: Timer?

    func applicationDidFinishLaunching(_ note: Notification) {
        Vocabulary.ensureFile()
        _ = History.shared
        let dictation = Dictation.shared
        dictation.needsSetup = { SetupWindow.shared.show() }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIcon(recording: false)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        // Kortkommandot kräver Hjälpmedel. Vänta tyst tills det är beviljat.
        startKeysWhenAllowed()

        if Figure.shared.isShown { Figure.shared.show() }
        if PianissimoModel.isInstalled { Task { try? await SpeechEngine.shared.load() } }
        if !SetupModel.shared.allReady { SetupWindow.shared.show() }

        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            MainActor.assumeIsolated {
                (NSApp.delegate as? AppDelegate)?.setIcon(recording: Dictation.shared.isRecording)
            }
        }
    }

    private func startKeysWhenAllowed() {
        Log.write("Start – Hjälpmedel: \(AXIsProcessTrusted() ? "ja" : "NEJ")")
        if AXIsProcessTrusted(), KeyListener.shared.start() { return }
        accessTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { t in
            MainActor.assumeIsolated {
                if AXIsProcessTrusted(), KeyListener.shared.start() { t.invalidate() }
            }
        }
    }

    private var shownRecording: Bool?
    func setIcon(recording: Bool) {
        guard shownRecording != recording else { return }
        shownRecording = recording
        let name = recording ? "waveform.circle.fill" : "waveform"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "Parlissima")
        img?.isTemplate = true
        statusItem.button?.image = img
    }

    // MARK: Menyn byggs om varje gång den öppnas

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let setup = SetupModel.shared
        setup.refresh()

        let status: String
        if setup.downloading { status = "Hämtar Klangs modell … \(Int(setup.progress * 100)) %" }
        else if !setup.allReady { status = "Inte klar – öppna Inställningar" }
        else { status = "Redo · håll höger alt och prata, eller klicka på pingvinen" }
        menu.addItem(disabled(status))
        menu.addItem(.separator())

        let recent = NSMenuItem(title: "Senaste (sparas i 2 timmar)", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        let items = History.shared.items
        if items.isEmpty { sub.addItem(disabled("Inga dikteringar än")) }
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
        for item in items.prefix(15) {
            let preview = item.text.count > 60 ? String(item.text.prefix(60)) + " …" : item.text
            let row = NSMenuItem(title: "\(fmt.string(from: item.date))  \(preview)", action: nil, keyEquivalent: "")
            let actions = NSMenu()
            actions.addItem(action("Kopiera texten", #selector(copyItem(_:)), item.id))
            actions.addItem(action("Kör Pianissimo igen på ljudet", #selector(retryItem(_:)), item.id))
            row.submenu = actions
            sub.addItem(row)
        }
        if !items.isEmpty {
            sub.addItem(.separator())
            sub.addItem(action("Radera alla nu", #selector(clearHistory), nil))
        }
        recent.submenu = sub
        menu.addItem(recent)

        let figure = action("Visa pingvinen", #selector(toggleFigure), nil)
        figure.state = Figure.shared.isShown ? .on : .off
        menu.addItem(figure)
        menu.addItem(action("Ordlista …", #selector(openVocabulary), nil))
        menu.addItem(action("Inställningar och behörigheter …", #selector(openSetup), nil))
        let login = action("Starta vid inloggning", #selector(toggleLogin), nil)
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(disabled("Klang Pianissimo · helt lokalt"))
        menu.addItem(action("Avsluta Parlissima", #selector(quit), nil, key: "q"))
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: ""); i.isEnabled = false; return i
    }
    private func action(_ title: String, _ sel: Selector, _ id: UUID?, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        i.target = self
        i.representedObject = id
        return i
    }
    private func item(_ sender: NSMenuItem) -> History.Item? {
        guard let id = sender.representedObject as? UUID else { return nil }
        return History.shared.items.first { $0.id == id }
    }

    @objc private func copyItem(_ s: NSMenuItem) {
        guard let it = item(s) else { return }
        Inserter.copy(it.text)
        Dictation.shared.hud.show(.done("Kopierad – tryck ⌘V"), hideAfter: 1.5)
    }
    @objc private func retryItem(_ s: NSMenuItem) { if let it = item(s) { Dictation.shared.retry(it) } }
    @objc private func clearHistory() { History.shared.clearAll() }
    @objc private func openVocabulary() {
        Vocabulary.ensureFile()
        NSWorkspace.shared.open([Vocabulary.file], withApplicationAt: URL(fileURLWithPath: "/System/Applications/TextEdit.app"),
                                configuration: NSWorkspace.OpenConfiguration())
    }
    @objc private func openSetup() { SetupWindow.shared.show() }
    @objc private func toggleFigure() { Figure.shared.isShown.toggle() }
    @objc private func toggleLogin() {
        let s = SMAppService.mainApp
        if s.status == .enabled { try? s.unregister() } else { try? s.register() }
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

// Dolt testläge för utveckling: Parlissima --test <ljudfil>  (hämtar modellen vid behov och skriver ut texten)
if let i = CommandLine.arguments.firstIndex(of: "--test"), i + 1 < CommandLine.arguments.count {
    let path = CommandLine.arguments[i + 1]
    let done = DispatchSemaphore(value: 0)
    Task.detached {
        do {
            if !PianissimoModel.isInstalled {
                print("Hämtar modellen …")
                try await PianissimoModel.install { _ in }
            }
            let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
            let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
            try file.read(into: buf)
            let conv = AVAudioConverter(from: file.processingFormat, to: Recorder.format)!
            let out = AVAudioPCMBuffer(pcmFormat: Recorder.format, frameCapacity: AVAudioFrameCount(Double(file.length) * 16_000 / file.processingFormat.sampleRate) + 1024)!
            var fed = false
            conv.convert(to: out, error: nil) { _, st in
                if fed { st.pointee = .endOfStream; return nil }; fed = true; st.pointee = .haveData; return buf
            }
            let samples = Array(UnsafeBufferPointer(start: out.floatChannelData![0], count: Int(out.frameLength)))
            let t0 = Date()
            let text = try await SpeechEngine.shared.transcribe(samples)
            print(Vocabulary.apply(text))
            print(String(format: "(%.2f s)", Date().timeIntervalSince(t0)))
        } catch { print("FEL:", error.localizedDescription) }
        done.signal()
    }
    done.wait()
    exit(0)
}

// Bygget: Parlissima --icon <ut.png>  (appikonen: pingvinen på GrowingSmart-indigo, 1024 x 1024)
if let i = CommandLine.arguments.firstIndex(of: "--icon"), i + 1 < CommandLine.arguments.count {
    MainActor.assumeIsolated {
        let icon = ZStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0x45/255, green: 0x3a/255, blue: 0x82/255), Brand.night],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(RadialGradient(colors: [Brand.coral.opacity(0.35), .clear], center: .center, startRadius: 10, endRadius: 330))
                    .frame(width: 700, height: 700).offset(x: 140, y: -170)
            }
            .frame(width: 824, height: 824)
            .clipShape(RoundedRectangle(cornerRadius: 185, style: .continuous))
            PenguinView(model: HUDModel(), variant: .headphones, iconStyle: true)
                .scaleEffect(5.0).offset(y: 30)
        }
        .frame(width: 1024, height: 1024)
        .clipShape(Rectangle())
        let r = ImageRenderer(content: icon)
        r.scale = 1
        if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
        }
    }
    exit(0)
}

// Dolt läge för utveckling: Parlissima --penguin-preview <ut.png>  (tre pingvinvarianter, vila och lyssnar)
if let i = CommandLine.arguments.firstIndex(of: "--penguin-preview"), i + 1 < CommandLine.arguments.count {
    MainActor.assumeIsolated {
        let grid = VStack(spacing: 6) {
            ForEach(Array(PenguinView.Variant.allCases.enumerated()), id: \.offset) { _, v in
                HStack(spacing: 6) {
                    ForEach(0..<2, id: \.self) { n in
                        let m = HUDModel()
                        let _ = { m.phase = n == 0 ? .hidden : .listening(handsfree: true); m.levels = Array(repeating: n == 1 ? 0.6 : 0, count: 32) }()
                        PenguinView(model: m, variant: v)
                    }
                }
            }
        }
        .padding(16)
        let r = ImageRenderer(content: grid)
        r.scale = 3
        if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
        }
    }
    exit(0)
}

// Dolt läge för utveckling: Parlissima --figure-preview <ut.png>  (ritar pingvinen i alla lägen)
if let i = CommandLine.arguments.firstIndex(of: "--figure-preview"), i + 1 < CommandLine.arguments.count {
    MainActor.assumeIsolated {
        let phases: [HUDModel.Phase] = [.hidden, .listening(handsfree: true), .writing, .done("ok"), .problem("x")]
        let row = HStack(spacing: 8) {
            ForEach(phases.indices, id: \.self) { n in
                let m = HUDModel()
                let _ = { m.phase = phases[n]; m.levels = Array(repeating: n == 1 ? 0.6 : 0, count: 32) }()
                PenguinView(model: m, variant: .headphones)
            }
        }
        .padding(20)
        .background(Color.clear)
        let r = ImageRenderer(content: row)
        r.scale = 3
        if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
        }
    }
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
