import Foundation

enum RecordingState: Equatable {
    case idle
    case recording(startedAt: Date)
    case transcribing
    case processing
    case injecting
    case error(String)

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    var isProcessing: Bool {
        switch self {
        case .transcribing, .processing, .injecting: return true
        default: return false
        }
    }

    var statusIcon: String {
        switch self {
        case .idle:          return "mic"
        case .recording:     return "mic.fill"
        case .transcribing:  return "waveform"
        case .processing:    return "sparkles"
        case .injecting:     return "checkmark.circle"
        case .error:         return "exclamationmark.triangle"
        }
    }
}
