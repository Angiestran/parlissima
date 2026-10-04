import Foundation
import CoreML
import CryptoKit
import FluidAudio

// Klang Pianissimo (KlangAI/pianissimo-sv, CC BY 4.0, Klang AI AB) – svensk
// taligenkänning, finjusterad från NVIDIA Parakeet TDT 0.6B v3 (CC BY 4.0).
// Vi kör Core ML-konverteringen markstrom/pianissimo-sv-coreml (CC BY 4.0) på
// Macens Neural Engine via FluidAudio (Apache 2.0).
//
// Säkerhet: modellen hämtas en gång från en fastlåst revision och varje fil
// kontrolleras mot sin SHA-256 innan den används. Filförteckningen och
// kontrollsummorna kommer från Mindtalk (MIT) som hämtar samma revision.

enum PianissimoModel {
    static let repo = "markstrom/pianissimo-sv-coreml"
    static let revision = "106fa163a138a0db6737e0c50494269e07f508d0"
    static let toCompile = ["Preprocessor", "Encoder", "Decoder", "JointDecisionv3"]

    struct RemoteFile { let path: String; let size: Int64; let sha256: String }

    static let files: [RemoteFile] = [
        .init(path: "Decoder.mlpackage/Data/com.apple.CoreML/model.mlmodel", size: 11811, sha256: "4a36039f091573251bd8bcb55e8f5fa6dc3bad32052d825b1e3b2a3840879990"),
        .init(path: "Decoder.mlpackage/Data/com.apple.CoreML/weights/weight.bin", size: 23604992, sha256: "9e34a5cc5da3477cf0e49126f55d4754a6a332b5df52a22812d6ddbd84af0e39"),
        .init(path: "Decoder.mlpackage/Manifest.json", size: 617, sha256: "99e8049015d297e58291cfe279c832f01e88959ca91894be939753b19f694827"),
        .init(path: "Encoder.mlpackage/Data/com.apple.CoreML/model.mlmodel", size: 677050, sha256: "9c9e8a95b18b35142f00ac3c8c186c669057f7ca4a097b2e463c99486eb8eeb8"),
        .init(path: "Encoder.mlpackage/Data/com.apple.CoreML/weights/weight.bin", size: 649181632, sha256: "e9623b969e8f31ba12bfbec7cdcdacb3bfb74e5a3a9bd3a812e4a942c1b1b9ed"),
        .init(path: "Encoder.mlpackage/Manifest.json", size: 617, sha256: "6d235c39782d2e839142f0df9a6fc3096a6258da05f8be1c1d95547d936cf619"),
        .init(path: "JointDecisionv3.mlpackage/Data/com.apple.CoreML/model.mlmodel", size: 10827, sha256: "af1b876c8677cc8c6676573801038ce6da4972eba4817b1caa2eb09b9ff5ed32"),
        .init(path: "JointDecisionv3.mlpackage/Data/com.apple.CoreML/weights/weight.bin", size: 12642764, sha256: "1f841daf3a6ce483ac136cd7a5e48d6071543e7c5eddcbba4525bda74695cb61"),
        .init(path: "JointDecisionv3.mlpackage/Manifest.json", size: 617, sha256: "42ab119e793f459e4a8d4a86f77714f093a54ebea55a14786981962985e8121d"),
        .init(path: "Preprocessor.mlpackage/Data/com.apple.CoreML/model.mlmodel", size: 17913, sha256: "44426745838b32d86e0de13054eea2b7c4439e95dadef0bcfa528bdfc93eb630"),
        .init(path: "Preprocessor.mlpackage/Data/com.apple.CoreML/weights/weight.bin", size: 1953088, sha256: "c69139820fc62c199f92c83d2c97458f8aaff337e5026abd9606ff03ba52b8e1"),
        .init(path: "Preprocessor.mlpackage/Manifest.json", size: 617, sha256: "caffd54a12af3df9bb673f100239919e1047ece8c4035f75819f4adc1d71b6a9"),
        .init(path: "parakeet_vocab.json", size: 151122, sha256: "7ec60e05f1b24480736ec0eed40900f4626bce1fa9a60fd700ec7e2a59198735"),
        .init(path: "LICENSE-and-attribution.txt", size: 2402, sha256: "cebcc87c23d9b4df78a1e1655b20c5f82e66babde45362a58fe6a2cb64f3dc91"),
    ]

    static var totalBytes: Int64 { files.reduce(0) { $0 + $1.size } }

    static var appSupport: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tala", isDirectory: true)
    }
    static var directory: URL { appSupport.appendingPathComponent("pianissimo-sv", isDirectory: true) }
    private static var marker: URL { directory.appendingPathComponent(".klar") }

    static var isInstalled: Bool { FileManager.default.fileExists(atPath: marker.path) }

    /// Hämtar, kontrollerar och kompilerar modellen. `progress` får 0...1.
    static func install(progress: @escaping @Sendable (Double) -> Void) async throws {
        let fm = FileManager.default
        try fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let staging = appSupport.appendingPathComponent(".hamtning-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: staging) }
        let raw = staging.appendingPathComponent("raw")
        let ready = staging.appendingPathComponent("ready")
        try fm.createDirectory(at: ready, withIntermediateDirectories: true)

        var done: Int64 = 0
        let total = Double(totalBytes)
        for file in files {
            try Task.checkCancellation()
            let dest = raw.appendingPathComponent(file.path)
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            let base = done
            try await download(file, to: dest) { written in progress(0.9 * Double(base + written) / total) }
            guard try sha256(of: dest) == file.sha256 else { throw TalaError.checksum(file.path) }
            done += file.size
        }
        for (i, name) in toCompile.enumerated() {
            let pkg = raw.appendingPathComponent("\(name).mlpackage")
            let compiled = try await MLModel.compileModel(at: pkg)
            try fm.moveItem(at: compiled, to: ready.appendingPathComponent("\(name).mlmodelc"))
            try? fm.removeItem(at: pkg)
            progress(0.9 + 0.1 * Double(i + 1) / Double(toCompile.count))
        }
        for item in try fm.contentsOfDirectory(atPath: raw.path) {
            try fm.moveItem(at: raw.appendingPathComponent(item), to: ready.appendingPathComponent(item))
        }
        try Data().write(to: ready.appendingPathComponent(".klar"))
        if fm.fileExists(atPath: directory.path) { try fm.removeItem(at: directory) }
        try fm.moveItem(at: ready, to: directory)
        progress(1)
    }

    private static func download(_ file: RemoteFile, to dest: URL,
                                 progress: @escaping @Sendable (Int64) -> Void) async throws {
        let url = URL(string: "https://huggingface.co/\(repo)/resolve/\(revision)/\(file.path)")!
        let delegate = DownloadDelegate(destination: dest, progress: progress)
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            delegate.continuation = cont
            session.downloadTask(with: url).resume()
        }
        if let code = delegate.status, !(200..<300).contains(code) { throw TalaError.http(file.path, code) }
    }

    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 8 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

enum TalaError: LocalizedError {
    case checksum(String), http(String, Int), notInstalled, noMicrophone
    var errorDescription: String? {
        switch self {
        case .checksum(let f): return "Filen \(f) stämde inte med kontrollsumman. Försök igen."
        case .http(let f, let c): return "Kunde inte hämta \(f) (HTTP \(c))."
        case .notInstalled: return "Klangs modell är inte hämtad än."
        case .noMicrophone: return "Hittar ingen fungerande mikrofon."
        }
    }
}

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let destination: URL
    let progress: @Sendable (Int64) -> Void
    var continuation: CheckedContinuation<Void, Error>?
    var status: Int?
    private var moveError: Error?

    init(destination: URL, progress: @escaping @Sendable (Int64) -> Void) {
        self.destination = destination; self.progress = progress
    }
    func urlSession(_ s: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite _: Int64) {
        progress(totalBytesWritten)
    }
    func urlSession(_ s: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        status = (downloadTask.response as? HTTPURLResponse)?.statusCode
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
        } catch { moveError = error }
    }
    func urlSession(_ s: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let e = error ?? moveError { continuation?.resume(throwing: e) } else { continuation?.resume() }
        continuation = nil
    }
}

/// Håller Pianissimo laddad så att dikteringen svarar direkt.
actor SpeechEngine {
    static let shared = SpeechEngine()
    private var asr: AsrManager?

    func load() async throws {
        if asr != nil { return }
        guard PianissimoModel.isInstalled else { throw TalaError.notInstalled }
        let models = try AsrModels.loadLocal(from: PianissimoModel.directory, version: .v3)
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        var warm = TdtDecoderState.make(decoderLayers: 2)
        _ = try? await manager.transcribe([Float](repeating: 0, count: 16_000), decoderState: &warm)
        asr = manager
    }

    /// 16 kHz mono. Korta klipp fylls ut med tystnad – modellen vill ha minst en sekund.
    func transcribe(_ samples: [Float]) async throws -> String {
        try await load()
        guard let asr else { throw TalaError.notInstalled }
        let pad = [Float](repeating: 0, count: 4_800)
        var audio = pad + samples + pad
        if audio.count < 24_000 { audio += [Float](repeating: 0, count: 24_000 - audio.count) }
        var state = TdtDecoderState.make(decoderLayers: 2)
        let result = try await asr.transcribe(audio, decoderState: &state)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
