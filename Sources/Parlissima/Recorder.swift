import AVFoundation

/// Spelar in från Macens valda mikrofon till 16 kHz mono i minnet. Inget sparas på disk.
final class Recorder: @unchecked Sendable {
    var onLevel: (@Sendable (Float) -> Void)?

    private var engine = AVAudioEngine()
    private let lock = NSLock()
    private var samples: [Float] = []
    private(set) var isRunning = false

    static let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000,
                                      channels: 1, interleaved: false)!

    static var micAuthorized: Bool { AVCaptureDevice.authorizationStatus(for: .audio) == .authorized }
    static func requestMic() async -> Bool { await AVCaptureDevice.requestAccess(for: .audio) }

    func start() throws {
        guard !isRunning else { return }
        lock.lock(); samples = []; lock.unlock()
        engine = AVAudioEngine()   // ny motor varje gång följer bytt standardmikrofon
        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        guard inFormat.sampleRate > 0,
              let converter = AVAudioConverter(from: inFormat, to: Self.format) else { throw ParlissimaError.noMicrophone }
        input.installTap(onBus: 0, bufferSize: 1024, format: inFormat, block: Self.tap(self, converter))
        engine.prepare()
        do { try engine.start() } catch { input.removeTap(onBus: 0); throw error }
        isRunning = true
    }

    func stop() -> [Float] {
        if isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            isRunning = false
        }
        lock.lock(); defer { lock.unlock() }
        let out = samples
        samples = []
        return out
    }

    private static func tap(_ rec: Recorder, _ converter: AVAudioConverter) -> AVAudioNodeTapBlock {
        { buffer, _ in
            let ratio = format.sampleRate / buffer.format.sampleRate
            guard let out = AVAudioPCMBuffer(pcmFormat: format,
                                             frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32)
            else { return }
            var fed = false
            var error: NSError?
            converter.convert(to: out, error: &error) { _, status in
                if fed { status.pointee = .noDataNow; return nil }
                fed = true; status.pointee = .haveData; return buffer
            }
            guard error == nil, let data = out.floatChannelData?[0] else { return }
            let chunk = Array(UnsafeBufferPointer(start: data, count: Int(out.frameLength)))
            var sum: Float = 0
            for v in chunk { sum += v * v }
            let rms = chunk.isEmpty ? 0 : (sum / Float(chunk.count)).squareRoot()
            rec.lock.lock(); rec.samples += chunk; rec.lock.unlock()
            rec.onLevel?(min(1, rms * 12))
        }
    }
}
