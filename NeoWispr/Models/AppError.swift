import Foundation

enum RecordingError: LocalizedError {
    case microphoneNotAvailable
    case microphonePermissionDenied
    case audioEngineStartFailed(Error)
    case wavExportFailed(Error)

    var errorDescription: String? {
        switch self {
        case .microphoneNotAvailable:
            return "Kein Mikrofon gefunden."
        case .microphonePermissionDenied:
            return "Mikrofon-Zugriff fehlt"
        case .audioEngineStartFailed(let error):
            return "Audio-Engine konnte nicht gestartet werden: \(error.localizedDescription)"
        case .wavExportFailed(let error):
            return "WAV-Export fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}

enum STTError: LocalizedError {
    case whisperNotFound(String)
    case modelNotFound(String)
    case whisperFailed(String)
    case transcriptionEmpty
    case timeout

    var errorDescription: String? {
        switch self {
        case .whisperNotFound(let path):
            return "whisper-cli nicht gefunden: \(path). Installiere mit: brew install whisper-cpp"
        case .modelNotFound(let path):
            return "Whisper-Modell nicht gefunden: \(path)"
        case .whisperFailed(let stderr):
            return "Transkription fehlgeschlagen: \(stderr)"
        case .transcriptionEmpty:
            return "Keine Sprache erkannt."
        case .timeout:
            return "Transkription Timeout (30s)."
        }
    }
}

enum AudioError: LocalizedError {
    case formatConversionFailed
    case noAudioData

    var errorDescription: String? {
        switch self {
        case .formatConversionFailed:
            return "Audio-Format-Konvertierung fehlgeschlagen."
        case .noAudioData:
            return "Keine Audio-Daten aufgenommen."
        }
    }
}

enum LLMError: LocalizedError {
    case providerNotAvailable(String)
    case timeout
    case processFailed(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .providerNotAvailable(let detail):
            return "LLM-Provider nicht verfügbar: \(detail)"
        case .timeout:
            return "LLM-Verbesserung Timeout."
        case .processFailed(let stderr):
            return "LLM-Verbesserung fehlgeschlagen: \(stderr)"
        case .emptyResponse:
            return "LLM lieferte leere Antwort."
        }
    }
}
