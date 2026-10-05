import AppKit
import ApplicationServices

/// Själva dikteringen: tangent → inspelning → Pianissimo → ordlista → inklistring.
@MainActor
final class Dictation {
    static let shared = Dictation()

    let hud = HUDPanel()
    private let recorder = Recorder()

    private enum State { case idle, recording, writing }
    private var state = State.idle
    private var handsfree = false
    private var pressedAt = Date.distantPast
    private var firstTapAt: Date?          // kort tryck som väntar på ett andra
    private var tapCheck: DispatchWorkItem?

    private let tapLimit: TimeInterval = 0.3      // kortare än så = tryck, inte håll
    private let doubleTapWindow: TimeInterval = 0.5

    var needsSetup: (() -> Void)?

    init() {
        recorder.onLevel = { level in
            DispatchQueue.main.async { Dictation.shared.hud.model.push(level) }
        }
        let keys = KeyListener.shared
        keys.onPress = { [unowned self] in pressed() }
        keys.onRelease = { [unowned self] in released() }
        keys.onChord = { [unowned self] in chord() }
        keys.onEscape = { [unowned self] in escape() }
    }

    var isRecording: Bool { state == .recording }

    // MARK: Tangenten

    private func pressed() {
        switch state {
        case .writing:
            return
        case .recording:
            if handsfree { finish(); return }        // handsfree: ett tryck avslutar
            pressedAt = Date()                       // andra trycket i ett dubbeltryck
        case .idle:
            startRecording(handsfree: false)
        }
    }

    /// Ugglan: ett klick startar (handsfree), nästa klick skriver in texten.
    func toggle() {
        switch state {
        case .idle: startRecording(handsfree: true)
        case .recording: finish()
        case .writing: break
        }
    }

    private func startRecording(handsfree: Bool) {
        guard PianissimoModel.isInstalled, Recorder.micAuthorized else { needsSetup?(); return }
        do {
            try recorder.start()
        } catch {
            hud.show(.problem("Mikrofonen startade inte. Välj mikrofon i Systeminställningar → Ljud."), hideAfter: 4)
            return
        }
        state = .recording
        self.handsfree = handsfree
        firstTapAt = nil
        pressedAt = Date()
        Sound.start()
        hud.show(.listening(handsfree: handsfree))
        Task { try? await SpeechEngine.shared.load() }   // om modellen inte redan är laddad
    }

    private func released() {
        guard state == .recording, !handsfree else { return }
        let held = Date().timeIntervalSince(pressedAt)
        if held >= tapLimit { finish(); return }

        if firstTapAt != nil {                                // andra korta trycket → handsfree
            tapCheck?.cancel()
            firstTapAt = nil
            handsfree = true
            hud.show(.listening(handsfree: true))
            return
        }
        firstTapAt = Date()                                   // första korta trycket: vänta på ett till
        hud.show(.waiting)
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.firstTapAt != nil, self.state == .recording, !self.handsfree else { return }
            self.cancel()                                     // bara ett snabbt tryck – ingen diktering
        }
        tapCheck = work
        DispatchQueue.main.asyncAfter(deadline: .now() + doubleTapWindow, execute: work)
    }

    /// ⌥ + annan tangent är ett kortkommando (t.ex. ⌥2 för @), inte en diktering.
    private func chord() {
        guard state == .recording, !handsfree, Date().timeIntervalSince(pressedAt) < 1.5 else { return }
        cancel()
    }

    private func escape() -> Bool {
        guard state == .recording else { return false }
        cancel()
        hud.show(.problem("Avbrutet – inget skrevs"), hideAfter: 1.2)
        return true
    }

    // MARK: Flödet

    private func cancel() {
        tapCheck?.cancel()
        _ = recorder.stop()
        state = .idle
        handsfree = false
        firstTapAt = nil
        hud.hide()
    }

    private func finish() {
        tapCheck?.cancel()
        let samples = recorder.stop()
        handsfree = false
        firstTapAt = nil
        Sound.stop()
        guard samples.count > 16_000 / 3 else { state = .idle; hud.hide(); return }   // under ⅓ s
        state = .writing
        hud.show(.writing)
        Task { await self.transcribe(samples) }
    }

    private func transcribe(_ samples: [Float]) async {
        defer { state = .idle }
        do {
            let raw = try await SpeechEngine.shared.transcribe(samples)
            let text = Vocabulary.apply(raw)
            guard !text.isEmpty else {
                hud.show(.problem("Jag hörde inget tal"), hideAfter: 2)
                return
            }
            _ = History.shared.add(text: text, samples: samples)
            if Inserter.inPasswordField {
                hud.show(.problem("Lösenordsfält – inget inklistrat. Texten finns under Senaste."), hideAfter: 3)
                return
            }
            let target = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
            // Utan Hjälpmedel blockerar macOS inklistringen tyst. Då får du texten i urklipp i stället.
            guard AXIsProcessTrusted() else {
                Inserter.copy(text)
                Log.write("Hjälpmedel saknas – texten lagd i urklipp (aktiv app: \(target))")
                Sound.error()
                hud.show(.problem("Texten ligger i urklipp – tryck ⌘V. Slå på Parlissima under Hjälpmedel så klistras den in själv."), hideAfter: 6)
                return
            }
            Inserter.paste(text)
            Log.write("Inklistrat i \(target)")
            let words = text.split(separator: " ").count
            hud.show(.done("\(words) ord inklistrade"), hideAfter: 1.2)
        } catch {
            Sound.error()
            hud.show(.problem(error.localizedDescription), hideAfter: 4)
        }
    }

    /// Kör Pianissimo igen på ett sparat ljud och lägger texten i urklipp.
    func retry(_ item: History.Item) {
        guard state == .idle, let samples = History.shared.samples(for: item) else { return }
        state = .writing
        hud.show(.writing)
        Task {
            defer { state = .idle }
            do {
                let text = Vocabulary.apply(try await SpeechEngine.shared.transcribe(samples))
                History.shared.update(item.id, text: text)
                Inserter.copy(text)
                hud.show(.done("Ny text i urklipp – tryck ⌘V"), hideAfter: 2)
            } catch {
                hud.show(.problem(error.localizedDescription), hideAfter: 4)
            }
        }
    }
}

enum Sound {
    private static func play(_ name: String, volume: Float) {
        guard let s = NSSound(named: NSSound.Name(name))?.copy() as? NSSound else { return }
        s.volume = volume
        s.play()
    }
    static func start() { play("Tink", volume: 0.35) }
    static func stop() { play("Pop", volume: 0.35) }
    static func error() { play("Basso", volume: 0.3) }
}

/// Enkel logg för felsökning (inga dikterade texter skrivs hit). ~/Library/Logs/Parlissima.log
enum Log {
    static func write(_ line: String) {
        let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/Parlissima.log")
        let stamp = ISO8601DateFormatter().string(from: Date())
        let data = Data("\(stamp)  \(line)\n".utf8)
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(data); try? h.close() }
        else { try? data.write(to: url) }
    }
}
