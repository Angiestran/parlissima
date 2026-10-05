import Foundation
import AVFoundation

/// Senaste dikteringar (text + ljud) i en privat mapp. Raderas automatiskt efter två timmar.
@MainActor
final class History: ObservableObject {
    static let shared = History()
    static let keep: TimeInterval = 2 * 60 * 60

    struct Item: Identifiable, Codable {
        let id: UUID
        let date: Date
        var text: String
        var audioFile: String
    }

    @Published private(set) var items: [Item] = []

    private let dir = PianissimoModel.appSupport.appendingPathComponent("Senaste", isDirectory: true)
    private var index: URL { dir.appendingPathComponent("senaste.json") }

    init() {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        if let data = try? Data(contentsOf: index),
           let saved = try? JSONDecoder().decode([Item].self, from: data) { items = saved }
        prune()
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            MainActor.assumeIsolated { History.shared.prune() }
        }
    }

    func add(text: String, samples: [Float]) -> Item {
        let id = UUID()
        let file = "\(id.uuidString).wav"
        Self.writeWav(samples, to: dir.appendingPathComponent(file))
        let item = Item(id: id, date: Date(), text: text, audioFile: file)
        items.insert(item, at: 0)
        save()
        return item
    }

    func update(_ id: UUID, text: String) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].text = text
        save()
    }

    func samples(for item: Item) -> [Float]? { Self.readWav(dir.appendingPathComponent(item.audioFile)) }

    /// Tar bort allt äldre än två timmar, både text och ljud.
    func prune() {
        let limit = Date().addingTimeInterval(-Self.keep)
        let old = items.filter { $0.date < limit }
        for item in old { try? FileManager.default.removeItem(at: dir.appendingPathComponent(item.audioFile)) }
        items.removeAll { $0.date < limit }
        // Städa även bort ljudfiler som inte längre hör till något.
        let known = Set(items.map(\.audioFile))
        for f in (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        where f.hasSuffix(".wav") && !known.contains(f) {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(f))
        }
        save()
    }

    func clearAll() {
        items.removeAll()
        prune()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: index, options: [.atomic, .completeFileProtection])
    }

    private static func writeWav(_ samples: [Float], to url: URL) {
        guard let buf = AVAudioPCMBuffer(pcmFormat: Recorder.format, frameCapacity: AVAudioFrameCount(samples.count)),
              let file = try? AVAudioFile(forWriting: url, settings: Recorder.format.settings) else { return }
        buf.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { buf.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        try? file.write(from: buf)
    }

    private static func readWav(_ url: URL) -> [Float]? {
        guard let file = try? AVAudioFile(forReading: url),
              let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buf)) != nil, let data = buf.floatChannelData?[0] else { return nil }
        return Array(UnsafeBufferPointer(start: data, count: Int(buf.frameLength)))
    }
}

/// Egen ordlista: rader som "fel => rätt". Rättar hela ord oavsett versaler.
enum Vocabulary {
    static var file: URL { PianissimoModel.appSupport.appendingPathComponent("ordlista.txt") }

    static let starter = """
    # Parlissima – ordlista
    # En rad per ord: det Pianissimo hör => så ska det stavas.
    # Rader som börjar med # ignoreras. Spara filen, så gäller den direkt.

    claud => Claude
    klod => Claude
    chat gpt => ChatGPT
    linked in => LinkedIn
    """

    static func ensureFile() {
        if !FileManager.default.fileExists(atPath: file.path) {
            try? FileManager.default.createDirectory(at: PianissimoModel.appSupport, withIntermediateDirectories: true)
            try? starter.write(to: file, atomically: true, encoding: .utf8)
        }
    }

    static func apply(_ text: String) -> String {
        guard let content = try? String(contentsOf: file, encoding: .utf8) else { return text }
        var out = text
        for line in content.split(separator: "\n") {
            let l = line.trimmingCharacters(in: .whitespaces)
            guard !l.isEmpty, !l.hasPrefix("#") else { continue }
            let parts = l.components(separatedBy: "=>")
            guard parts.count == 2 else { continue }
            let from = parts[0].trimmingCharacters(in: .whitespaces)
            let to = parts[1].trimmingCharacters(in: .whitespaces)
            guard !from.isEmpty else { continue }
            let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: from) + "(?![\\p{L}\\p{N}])"
            out = out.replacingOccurrences(of: pattern, with: NSRegularExpression.escapedTemplate(for: to),
                                           options: [.regularExpression, .caseInsensitive])
        }
        return out
    }
}
