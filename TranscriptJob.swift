import Foundation
import Combine

// MARK: - TranscriptJob (Phase 3 worker)
@MainActor
final class TranscriptJob: ObservableObject, Identifiable {
    let id: UUID
    let model: TranscriptJobModel
    @Published private(set) var state: AsyncState<[TranscriptSegmentModel]> = .idle
    @Published private(set) var partialText: String = ""

    private let adapter: SpeechAnalyzerAdapter
    private let repository: ProjectRepository

    init(model: TranscriptJobModel, adapter: SpeechAnalyzerAdapter, repository: ProjectRepository) {
        self.id = model.id
        self.model = model
        self.adapter = adapter
        self.repository = repository
    }

    func run(clipURL: URL) async {
        state = .loading
        do {
            var segments = try await adapter.transcribeFile(url: clipURL)
            // Stamp correct IDs
            segments = segments.map { seg in
                var s = seg
                s.sessionId = model.sessionId
                s.clipId = model.clipId
                return s
            }
            try await repository.saveTranscript(segments, for: model.sessionId)
            state = .success(segments)
        } catch let e as AppError {
            state = .failure(e)
        } catch {
            state = .failure(.unknown(error))
        }
    }

    func cancel() {
        Task { await adapter.cancelCurrentTask() }
    }
}

// MARK: - TranscriptModels (additional display types)
struct TranscriptDisplayModel {
    let segments: [TranscriptSegmentModel]
    var fullText: String { segments.map(\.text).joined(separator: " ") }
    var wordCount: Int   { fullText.split(separator: " ").count }
    var duration: TimeInterval { segments.last?.endTime ?? 0 }
    var averageConfidence: Float {
        guard !segments.isEmpty else { return 0 }
        return segments.reduce(0) { $0 + $1.confidence } / Float(segments.count)
    }
}
