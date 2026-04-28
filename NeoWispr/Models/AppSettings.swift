import Foundation

enum AppSettings {
    // Hotkey
    static let hotkey               = "hotkey"           // legacy, unused — neuer Recorder via KeyboardShortcuts
    static let hotkeyMode           = "hotkey_mode"      // "toggle" | "hold"
    static let commandModeEnabled   = "command_mode_enabled"

    // Transcription
    static let sttProvider          = "stt_provider"     // "whisper-cli" | "whisperkit" | "parakeet"
    static let whisperKitModel      = "whisperkit_model" // z.B. "openai_whisper-base"
    static let modelPath            = "model_path"
    static let language             = "language"
    static let voiceInkDefaultsMigrated = "voiceink_defaults_migrated"
    static let autoStartEnabled     = "auto_start"
    static let silenceThreshold     = "silence_threshold"
    static let silenceTimeout       = "silence_timeout"

    // LLM Post-Processing
    static let llmEnabled           = "llm_enabled"
    static let llmProvider          = "llm_provider"     // "claude-haiku" | "ollama" | "groq"
    static let dictationStyle       = "dictation_style"  // DictationStyle.rawValue
    static let llmAutoDisableOnError = "llm_auto_disable_on_error"
    static let powerModeEnabled     = "power_mode_enabled"
    static let removeFillerWords    = "remove_filler_words"
    static let customPrompt         = "custom_prompt"
    static let includeClipboardContext = "include_clipboard_context"

    // Groq (kostenloser LLM-Provider, OpenAI-kompatible API, schnelle LPU-Inferenz)
    static let groqApiKey           = "groq_api_key"     // Legacy-Migrationskey, neue Secrets liegen in Keychain
    static let groqModel            = "groq_model"       // z.B. "llama-3.3-70b-versatile" | "llama-3.1-8b-instant"
}
