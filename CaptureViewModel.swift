import SwiftUI
import Combine
import AVFoundation

@MainActor
final class CaptureViewModel: ObservableObject {
    // MARK: - State
    @Published private(set) var recordingState: RecordingState = .idle
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var meterLevel: Float = -160
    @Published private(set) var clips: [ClipModel] = []
    @Published var error: AppError?

    enum RecordingState: Equatable {
        case idle, recording, paused, stopped
    }

    // MARK: - Dependencies
    private let session: SessionModel
    private let engine: AudioEngineManager
    private let fileService: AudioFileService
    private let repository: ProjectRepository

    // MARK: - Timer
    private var timer: AnyCancellable?
    private var timerStart: Date?
    private var accumulatedTime: TimeInterval = 0

    // MARK: - Active recording
    private var activeClipId: UUID?
    private var activeClipURL: URL?
    private var cancellables = Set<AnyCancellable>()

    init(session: SessionModel, engine: AudioEngineManager, fileService: AudioFileService, repository: ProjectRepository) {
        self.session = session
        self.engine = engine
        self.fileService = fileService
        self.repository = repository
        bindMeter()
    }

    private func bindMeter() {
        engine.$meterLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$meterLevel)
    }

    // MARK: - Load existing clips
    func loadClips() async {
        clips = (try? await repository.loadClips(for: session.id)) ?? []
    }

    // MARK: - Record
    func startRecording() async {
        guard recordingState == .idle || recordingState == .stopped else { return }
        do {
            if !engine.isRunning { try engine.start() }
            let clipId = UUID()
            let url = fileService.newRecordingURL(sessionId: session.id, clipId: clipId)
            try engine.startRecording(to: url)
            activeClipId = clipId
            activeClipURL = url
            recordingState = .recording
            startTimer()
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .unknown(error)
        }
    }

    func pauseRecording() {
        guard recordingState == .recording else { return }
        engine.pauseRecording()
        recordingState = .paused
        pauseTimer()
    }

    func resumeRecording() {
        guard recordingState == .paused else { return }
        do {
            try engine.resumeRecording()
            recordingState = .recording
            startTimer()
        } catch {
            self.error = .unknown(error)
        }
    }

    func stopRecording() async {
        guard recordingState == .recording || recordingState == .paused else { return }
        engine.stopRecording()
        stopTimer()
        recordingState = .stopped

        guard let clipId = activeClipId, let url = activeClipURL else { return }
        let duration = fileService.duration(of: url)
        let clip = ClipModel(
            id: clipId,
            sessionId: session.id,
            fileURL: url,
            trackId: clips.count,
            startTime: 0,
            endTime: duration
        )
        do {
            try await repository.appendClip(clip)
            clips.append(clip)
        } catch let e as AppError {
            error = e
        }
        activeClipId = nil
        activeClipURL = nil
    }

    func deleteClip(_ clip: ClipModel) async {
        do {
            try await repository.deleteClip(id: clip.id, from: session.id)
            try fileService.deleteClip(at: clip.fileURL)
            clips.removeAll { $0.id == clip.id }
        } catch let e as AppError {
            error = e
        }
    }

    // MARK: - Timer helpers
    private func startTimer() {
        timerStart = Date()
        timer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let start = self.timerStart else { return }
                self.elapsedTime = self.accumulatedTime + Date().timeIntervalSince(start)
            }
    }

    private func pauseTimer() {
        accumulatedTime = elapsedTime
        timerStart = nil
        timer?.cancel()
        timer = nil
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
        timerStart = nil
        accumulatedTime = 0
        elapsedTime = 0
    }

    deinit {
        timer?.cancel()
    }
}
