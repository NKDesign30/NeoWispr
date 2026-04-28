@preconcurrency import AVFoundation
import Foundation

final class AudioCaptureModule {

    private let engine = AVAudioEngine()
    private var audioBuffers: [AVAudioPCMBuffer] = []
    private var silenceDetector: SilenceDetector
    private var onSilenceDetected: (@Sendable () -> Void)?

    // whisper.cpp erwartet: 16kHz, mono, Float32 PCM
    private let whisperFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    init() {
        self.silenceDetector = SilenceDetector()
    }

    func configure(threshold: Float, timeoutSeconds: Double, onSilence: @escaping @Sendable () -> Void) {
        silenceDetector = SilenceDetector(threshold: threshold, timeoutSeconds: timeoutSeconds)
        onSilenceDetected = onSilence
    }

    func start() throws {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            throw RecordingError.microphonePermissionDenied
        }

        audioBuffers.removeAll()
        silenceDetector.reset()

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let converter = AVAudioConverter(from: inputFormat, to: whisperFormat) else {
            throw AudioError.formatConversionFailed
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.processBuffer(buffer, converter: converter)
        }

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            if AVCaptureDevice.authorizationStatus(for: .audio) != .authorized {
                throw RecordingError.microphonePermissionDenied
            }
            throw RecordingError.audioEngineStartFailed(error)
        }
    }

    func stop() throws -> URL {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        return try writeToWAV()
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter) {
        let frameCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * whisperFormat.sampleRate / buffer.format.sampleRate
        )
        guard frameCapacity > 0,
              let convertedBuffer = AVAudioPCMBuffer(pcmFormat: whisperFormat, frameCapacity: frameCapacity)
        else { return }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

        guard error == nil else { return }

        audioBuffers.append(convertedBuffer)

        if silenceDetector.process(buffer: convertedBuffer) {
            let callback = onSilenceDetected
            DispatchQueue.main.async {
                callback?()
            }
        }
    }

    private func writeToWAV() throws -> URL {
        guard !audioBuffers.isEmpty else {
            throw AudioError.noAudioData
        }

        let tempURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("neowispr-\(UUID().uuidString).wav")

        let outputFile = try AVAudioFile(
            forWriting: tempURL,
            settings: whisperFormat.settings
        )

        for buffer in audioBuffers {
            try outputFile.write(from: buffer)
        }

        audioBuffers.removeAll()
        return tempURL
    }
}
