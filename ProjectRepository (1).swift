import Foundation
import Combine

@MainActor
final class ProjectRepository: ObservableObject {
    @Published private(set) var sessions: [SessionModel] = []

    private let fileStore: FileStore
    private let metadataStore: MetadataStore

    init(fileStore: FileStore, metadataStore: MetadataStore) {
        self.fileStore = fileStore
        self.metadataStore = metadataStore
    }

    // MARK: - Sessions
    func loadAllSessions() async {
        let ids = await metadataStore.allSessionIds()
        var loaded: [SessionModel] = []
        for id in ids {
            if let session = try? await metadataStore.loadSession(id) {
                loaded.append(session)
            }
        }
        sessions = loaded.sorted { $0.updatedAt > $1.updatedAt }
    }

    func createSession(title: String = "", mode: SessionMode = .voice) async throws -> SessionModel {
        var session = SessionModel(title: title, mode: mode)
        if session.title.isEmpty { session.title = Date().sessionTitle }
        try await metadataStore.saveSession(session)
        sessions.insert(session, at: 0)
        AppLogger.info("Created session: \(session.id)")
        return session
    }

    func updateSession(_ session: SessionModel) async throws {
        var s = session
        s.touch()
        try await metadataStore.saveSession(s)
        if let idx = sessions.firstIndex(where: { $0.id == s.id }) {
            sessions[idx] = s
        }
    }

    func deleteSession(_ id: UUID) async throws {
        try await metadataStore.deleteSession(id)
        sessions.removeAll { $0.id == id }
        AppLogger.info("Deleted session: \(id)")
    }

    // MARK: - Clips
    func loadClips(for sessionId: UUID) async throws -> [ClipModel] {
        try await metadataStore.loadClips(for: sessionId)
    }

    func saveClips(_ clips: [ClipModel], for sessionId: UUID) async throws {
        try await metadataStore.saveClips(clips, for: sessionId)
        // Update session clip count and duration
        let duration = clips.reduce(0.0) { $0 + $1.duration }
        if var session = sessions.first(where: { $0.id == sessionId }) {
            session.clipCount = clips.count
            session.durationSeconds = duration
            try await updateSession(session)
        }
    }

    func appendClip(_ clip: ClipModel) async throws {
        var clips = (try? await loadClips(for: clip.sessionId)) ?? []
        clips.append(clip)
        try await saveClips(clips, for: clip.sessionId)
    }

    func deleteClip(id: UUID, from sessionId: UUID) async throws {
        var clips = (try? await loadClips(for: sessionId)) ?? []
        clips.removeAll { $0.id == id }
        try await saveClips(clips, for: sessionId)
    }

    // MARK: - Markers
    func loadMarkers(for sessionId: UUID) async throws -> [MarkerModel] {
        try await metadataStore.loadMarkers(for: sessionId)
    }

    func saveMarkers(_ markers: [MarkerModel], for sessionId: UUID) async throws {
        try await metadataStore.saveMarkers(markers, for: sessionId)
    }

    func addMarker(_ marker: MarkerModel) async throws {
        var markers = (try? await loadMarkers(for: marker.sessionId)) ?? []
        markers.append(marker)
        markers.sort { $0.timestamp < $1.timestamp }
        try await saveMarkers(markers, for: marker.sessionId)
    }

    // MARK: - Transcript
    func loadTranscript(for sessionId: UUID) async -> [TranscriptSegmentModel] {
        await metadataStore.loadTranscript(for: sessionId)
    }

    func saveTranscript(_ segments: [TranscriptSegmentModel], for sessionId: UUID) async throws {
        try await metadataStore.saveTranscript(segments, for: sessionId)
    }
}
