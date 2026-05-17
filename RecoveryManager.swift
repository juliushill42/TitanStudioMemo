import Foundation

final class RecoveryManager {
    private let projectRepository: ProjectRepository
    private let fileStore: FileStore
    private let fm = FileManager.default

    init(projectRepository: ProjectRepository, fileStore: FileStore) {
        self.projectRepository = projectRepository
        self.fileStore = fileStore
    }

    // MARK: - Orphan sweep
    /// Remove audio files not referenced by any clip in their session.
    @MainActor
    func sweepOrphanedSessions() async {
        await projectRepository.loadAllSessions()
        for session in projectRepository.sessions {
            await sweepOrphanedAudio(for: session.id)
        }
        AppLogger.info("RecoveryManager: orphan sweep complete")
    }

    private func sweepOrphanedAudio(for sessionId: UUID) async {
        guard let clips = try? await projectRepository.loadClips(for: sessionId) else { return }
        let knownURLs = Set(clips.map { $0.fileURL.standardized })
        let audioDir = fileStore.audioDirectory(for: sessionId)

        guard let contents = try? fm.contentsOfDirectory(at: audioDir,
                                                          includingPropertiesForKeys: nil,
                                                          options: .skipsHiddenFiles) else { return }
        for file in contents where !knownURLs.contains(file.standardized) {
            AppLogger.info("RecoveryManager: removing orphan \(file.lastPathComponent)")
            try? fm.removeItem(at: file)
        }
    }

    // MARK: - Temp file cleanup
    func cleanTempFiles() {
        let tmp = fm.temporaryDirectory
        guard let contents = try? fm.contentsOfDirectory(at: tmp,
                                                          includingPropertiesForKeys: [.creationDateKey],
                                                          options: .skipsHiddenFiles) else { return }
        let cutoff = Date().addingTimeInterval(-86400)  // 24h
        for file in contents where file.lastPathComponent.hasPrefix("sm_") {
            if let created = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate,
               created < cutoff {
                try? fm.removeItem(at: file)
            }
        }
    }

    // MARK: - Session integrity check
    func verifySessionIntegrity(_ sessionId: UUID) async -> [RecoveryIssue] {
        var issues: [RecoveryIssue] = []
        guard let clips = try? await projectRepository.loadClips(for: sessionId) else { return [] }
        for clip in clips {
            if !fm.fileExists(atPath: clip.fileURL.path) {
                issues.append(.missingAudioFile(clipId: clip.id, url: clip.fileURL))
            }
        }
        return issues
    }
}

enum RecoveryIssue: CustomStringConvertible {
    case missingAudioFile(clipId: UUID, url: URL)
    case corruptedMetadata(sessionId: UUID)

    var description: String {
        switch self {
        case .missingAudioFile(let id, let url): return "Missing audio for clip \(id): \(url.lastPathComponent)"
        case .corruptedMetadata(let id):         return "Corrupted metadata for session \(id)"
        }
    }
}
