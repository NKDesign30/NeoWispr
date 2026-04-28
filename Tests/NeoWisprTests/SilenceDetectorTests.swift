import AVFoundation
import XCTest
@testable import NeoWispr

final class SilenceDetectorTests: XCTestCase {

    func testDetectsSilenceAfterTimeout() {
        var detector = SilenceDetector(threshold: 0.01, timeoutSeconds: 1.0)
        let startedAt = Date()

        XCTAssertFalse(detector.process(rms: 0.001, now: startedAt))
        XCTAssertFalse(detector.process(rms: 0.001, now: startedAt.addingTimeInterval(0.5)))
        XCTAssertTrue(detector.process(rms: 0.001, now: startedAt.addingTimeInterval(1.1)))
    }

    func testSpeechResetsSilenceWindow() throws {
        var detector = SilenceDetector(threshold: 0.01, timeoutSeconds: 1.0)
        let startedAt = Date()

        XCTAssertFalse(detector.process(buffer: try makeBuffer(rms: 0.001), now: startedAt))
        XCTAssertFalse(detector.process(buffer: try makeBuffer(rms: 0.1), now: startedAt.addingTimeInterval(0.5)))
        XCTAssertFalse(detector.process(buffer: try makeBuffer(rms: 0.001), now: startedAt.addingTimeInterval(1.6)))
    }

    private func makeBuffer(rms: Float) throws -> AVAudioPCMBuffer {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 160)!
        buffer.frameLength = 160

        guard let channel = buffer.floatChannelData?[0] else {
            throw XCTSkip("No float channel data")
        }
        for index in 0..<Int(buffer.frameLength) {
            channel[index] = rms
        }
        return buffer
    }
}
