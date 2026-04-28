import Foundation
@preconcurrency import FluidAudio

@Observable
@MainActor
final class ParakeetModelStore {

    enum Status: Equatable {
        case unknown
        case notDownloaded
        case downloading(progress: Double?, message: String)
        case loading
        case ready
        case failed(String)
    }

    private let sttPipeline: STTPipeline
    private var prewarmTask: Task<Void, Never>?

    private(set) var status: Status = .unknown

    init(sttPipeline: STTPipeline) {
        self.sttPipeline = sttPipeline
        refreshStatus()
    }

    var label: String {
        switch status {
        case .unknown:
            return "Prüfe Modell..."
        case .notDownloaded:
            return "Nicht geladen"
        case .downloading(_, let message):
            return message
        case .loading:
            return "Lade Modell..."
        case .ready:
            return "Bereit"
        case .failed:
            return "Fehler"
        }
    }

    var detail: String {
        switch status {
        case .unknown:
            return "NeoWispr prüft den FluidAudio-Cache."
        case .notDownloaded:
            return "Parakeet V3 wird automatisch im Hintergrund geladen."
        case .downloading:
            return "Download läuft. Das passiert nur einmal."
        case .loading:
            return "CoreML kompiliert und lädt Parakeet V3."
        case .ready:
            return "Parakeet V3 ist lokal verfügbar."
        case .failed(let message):
            return message
        }
    }

    var progress: Double? {
        if case .downloading(let progress, _) = status {
            return progress
        }
        return nil
    }

    var isWorking: Bool {
        switch status {
        case .downloading, .loading:
            return true
        default:
            return false
        }
    }

    func refreshStatus() {
        status = isModelCached ? .ready : .notDownloaded
    }

    func prewarmIfNeeded() {
        guard prewarmTask == nil else { return }
        guard STTPipeline.Provider.current == .parakeet else {
            refreshStatus()
            return
        }
        guard status != .ready else { return }

        status = isModelCached
            ? .loading
            : .downloading(progress: 0, message: "Lade Parakeet V3...")

        prewarmTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.sttPipeline.prewarmParakeetIfNeeded { progress in
                    Task { @MainActor [weak self] in
                        self?.apply(progress)
                    }
                }
                self.status = .ready
            } catch {
                self.status = .failed(error.localizedDescription)
            }
            self.prewarmTask = nil
        }
    }

    private var isModelCached: Bool {
        let cacheDir = AsrModels.defaultCacheDirectory(for: .v3)
        return AsrModels.modelsExist(at: cacheDir, version: .v3)
    }

    private func apply(_ progress: DownloadUtils.DownloadProgress) {
        switch progress.phase {
        case .listing:
            status = .downloading(progress: progress.fractionCompleted, message: "Suche Modell-Dateien...")
        case .downloading(let completedFiles, let totalFiles):
            let suffix = totalFiles > 0 ? " \(completedFiles)/\(totalFiles)" : ""
            status = .downloading(
                progress: progress.fractionCompleted,
                message: "Lade Parakeet V3\(suffix)..."
            )
        case .compiling(let modelName):
            status = .downloading(
                progress: progress.fractionCompleted,
                message: "Kompiliere \(modelName)..."
            )
        }
    }
}
