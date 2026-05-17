import Foundation

// MARK: - Session
struct SessionModel: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var notes: String
    var tags: [String]
    var mode: SessionMode
    var durationSeconds: TimeInterval
    var clipCount: Int

    init(
        id: UUID = UUID(),
        title: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        notes: String = "",
        tags: [String] = [],
        mode: SessionMode = .voice,
        durationSeconds: TimeInterval = 0,
        clipCount: Int = 0
    ) {
        self.id = id
        self.title = title.isEmpty ? createdAt.sessionTitle : title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.notes = notes
        self.tags = tags
        self.mode = mode
        self.durationSeconds = durationSeconds
        self.clipCount = clipCount
    }

    mutating func touch() { updatedAt = Date() }
}

enum SessionMode: String, Codable, CaseIterable, Identifiable {
    case voice       = "Voice"
    case songwriting = "Songwriting"
    case podcast     = "Podcast"
    case interview   = "Interview"

    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .voice:       return "mic"
        case .songwriting: return "music.note"
        case .podcast:     return "antenna.radiowaves.left.and.right"
        case .interview:   return "person.2"
        }
    }
}

// MARK: - Clip
struct ClipModel: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var sessionId: UUID
    var fileURL: URL
    var trackId: Int
    var startTime: TimeInterval
    var endTime: TimeInterval
    var isMuted: Bool
    var gain: Float
    var label: String

    var duration: TimeInterval { endTime - startTime }

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        fileURL: URL,
        trackId: Int = 0,
        startTime: TimeInterval = 0,
        endTime: TimeInterval = 0,
        isMuted: Bool = false,
        gain: Float = 1.0,
        label: String = ""
    ) {
        self.id = id
        self.sessionId = sessionId
        self.fileURL = fileURL
        self.trackId = trackId
        self.startTime = startTime
        self.endTime = endTime
        self.isMuted = isMuted
        self.gain = gain
        self.label = label
    }
}

// MARK: - Transcript Segment
struct TranscriptSegmentModel: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var sessionId: UUID
    var clipId: UUID
    var text: String
    var startTime: TimeInterval
    var endTime: TimeInterval
    var confidence: Float
    var speakerLabel: String?

    var duration: TimeInterval { endTime - startTime }
}

// MARK: - Marker
struct MarkerModel: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var sessionId: UUID
    var label: String
    var timestamp: TimeInterval
    var color: MarkerColor

    enum MarkerColor: String, Codable, CaseIterable {
        case orange, red, green, blue, purple, yellow
    }
}

// MARK: - Stem Job
struct StemJobModel: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var sessionId: UUID?
    var sourceURL: URL
    var status: StemJobStatus
    var mode: StemMode
    var progress: Double
    var outputURLs: [StemTrack: URL]
    var createdAt: Date
    var completedAt: Date?
    var errorMessage: String?

    enum StemJobStatus: String, Codable {
        case queued, processing, complete, failed
    }

    enum StemMode: String, Codable, CaseIterable, Identifiable {
        case twoStem = "Vocals / Accompaniment"
        case fourStem = "Vocals / Drums / Bass / Other"
        case fiveStem = "Vocals / Drums / Bass / Piano / Other"
        var id: String { rawValue }
    }

    enum StemTrack: String, Codable, CaseIterable {
        case vocals, drums, bass, other, piano, accompaniment
        var displayName: String { rawValue.capitalized }
        var systemImage: String {
            switch self {
            case .vocals:        return "mic.fill"
            case .drums:         return "waveform"
            case .bass:          return "waveform.path"
            case .other:         return "music.note"
            case .piano:         return "pianokeys"
            case .accompaniment: return "guitars"
            }
        }
    }
}

// MARK: - TranscriptJob
struct TranscriptJobModel: Identifiable, Codable, Sendable {
    var id: UUID
    var sessionId: UUID
    var clipId: UUID
    var status: TranscriptJobStatus
    var locale: String
    var createdAt: Date
    var completedAt: Date?
    var errorMessage: String?

    enum TranscriptJobStatus: String, Codable {
        case queued, processing, complete, failed
    }
}
