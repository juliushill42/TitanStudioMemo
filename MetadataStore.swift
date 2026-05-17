import Foundation

actor MetadataStore {
    private let fileStore: FileStore
    private var encoder = JSONEncoder()
    private var decoder = JSONDecoder()

    init(fileStore: FileStore) throws {
        self.fileStore = fileStore
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Session metadata
    func saveSession(_ session: SessionModel) throws {
        let url = fileStore.metadataURL(for: session.id)
        try fileStore.write(session, to: url)
    }

    func loadSession(_ id: UUID) throws -> SessionModel {
        let url = fileStore.metadataURL(for: id)
        return try fileStore.read(SessionModel.self, from: url)
    }

    func deleteSession(_ id: UUID) throws {
        try fileStore.deleteSession(id)
    }

    // MARK: - Clips
    func saveClips(_ clips: [ClipModel], for sessionId: UUID) throws {
        let url = fileStore.clipsMetadataURL(for: sessionId)
        try fileStore.write(clips, to: url)
    }

    func loadClips(for sessionId: UUID) throws -> [ClipModel] {
        let url = fileStore.clipsMetadataURL(for: sessionId)
        return (try? fileStore.read([ClipModel].self, from: url)) ?? []
    }

    // MARK: - Markers
    func saveMarkers(_ markers: [MarkerModel], for sessionId: UUID) throws {
        let url = fileStore.markersMetadataURL(for: sessionId)
        try fileStore.write(markers, to: url)
    }

    func loadMarkers(for sessionId: UUID) throws -> [MarkerModel] {
        let url = fileStore.markersMetadataURL(for: sessionId)
        return (try? fileStore.read([MarkerModel].self, from: url)) ?? []
    }

    // MARK: - Transcript segments
    func saveTranscript(_ segments: [TranscriptSegmentModel], for sessionId: UUID) throws {
        let url = fileStore.transcriptURL(for: sessionId)
        try fileStore.write(segments, to: url)
    }

    func loadTranscript(for sessionId: UUID) -> [TranscriptSegmentModel] {
        let url = fileStore.transcriptURL(for: sessionId)
        return (try? fileStore.read([TranscriptSegmentModel].self, from: url)) ?? []
    }

    // MARK: - All sessions (index scan)
    func allSessionIds() -> [UUID] {
        fileStore.allSessionDirectories.compactMap { dir in
            UUID(uuidString: dir.lastPathComponent)
        }
    }
}

// MARK: - Convenience init
extension MetadataStore {
    convenience init() async throws {
        let fs = FileStore()
        try self.init(fileStore: fs)
    }
}
