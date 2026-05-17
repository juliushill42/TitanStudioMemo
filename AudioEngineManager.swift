import AVFoundation
import Combine
import Accelerate

@MainActor
final class AudioEngineManager: ObservableObject {
    // MARK: - Published state
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var meterLevel: Float = -160  // dBFS

    // MARK: - Engine graph
    private let engine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private var mixerNode: AVAudioMixerNode!
    private var playerNode: AVAudioPlayerNode!

    // MARK: - Recording state
    private var recordingFile: AVAudioFile?
    private var recordingURL: URL?
    private var tapInstalled: Bool = false

    // MARK: - Dependencies
    private let sessionManager: AudioSessionManager
    private let formatManager: AudioFormatManager
    private var cancellables = Set<AnyCancellable>()

    init(sessionManager: AudioSessionManager, formatManager: AudioFormatManager) {
        self.sessionManager = sessionManager
        self.formatManager = formatManager
        self.inputNode = engine.inputNode
        setupGraph()
        observeInterruptions()
    }

    // MARK: - Graph setup
    private func setupGraph() {
        mixerNode = AVAudioMixerNode()
        playerNode = AVAudioPlayerNode()

        engine.attach(mixerNode)
        engine.attach(playerNode)

        let format = formatManager.recordingFormat(sampleRate: sessionManager.sampleRate,
                                                    channels: sessionManager.inputChannelCount)
        engine.connect(inputNode, to: mixerNode, format: format)
        engine.connect(mixerNode, to: engine.mainMixerNode, format: format)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
    }

    // MARK: - Engine lifecycle
    func start() throws {
        guard !isRunning else { return }
        do {
            engine.prepare()
            try engine.start()
            isRunning = true
            AppLogger.info("AudioEngine started")
        } catch {
            throw AppError.audio(.engineStart(underlying: error))
        }
    }

    func stop() {
        if isRecording { stopRecording() }
        removeTap()
        engine.stop()
        isRunning = false
        AppLogger.info("AudioEngine stopped")
    }

    // MARK: - Recording
    func startRecording(to url: URL) throws {
        guard isRunning else { throw AppError.audio(.engineNotRunning) }
        guard !isRecording else { return }

        let format = formatManager.recordingFormat(
            sampleRate: sessionManager.sampleRate,
            channels: sessionManager.inputChannelCount
        )

        recordingFile = try AVAudioFile(forWriting: url,
                                         settings: format.settings,
                                         commonFormat: .pcmFormatFloat32,
                                         interleaved: false)
        recordingURL = url

        installTap(format: format)
        isRecording = true
        AppLogger.info("Recording started → \(url.lastPathComponent)")
    }

    func stopRecording() {
        guard isRecording else { return }
        removeTap()
        recordingFile = nil
        isRecording = false
        AppLogger.info("Recording stopped → \(recordingURL?.lastPathComponent ?? "?")")
        recordingURL = nil
    }

    func pauseRecording() {
        guard isRecording else { return }
        removeTap()
        AppLogger.info("Recording paused")
    }

    func resumeRecording() throws {
        guard let file = recordingFile, let url = recordingURL else { return }
        let format = formatManager.recordingFormat(
            sampleRate: sessionManager.sampleRate,
            channels: sessionManager.inputChannelCount
        )
        // Re-open file in append mode
        recordingFile = try AVAudioFile(forWriting: url,
                                         settings: format.settings,
                                         commonFormat: .pcmFormatFloat32,
                                         interleaved: false)
        _ = file  // suppress unused warning
        installTap(format: format)
        AppLogger.info("Recording resumed")
    }

    // MARK: - Tap / metering
    private func installTap(format: AVAudioFormat) {
        guard !tapInstalled else { return }
        mixerNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.processBuffer(buffer)
        }
        tapInstalled = true
    }

    private func removeTap() {
        guard tapInstalled else { return }
        mixerNode.removeTap(onBus: 0)
        tapInstalled = false
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        // Write to file
        if let file = recordingFile {
            do { try file.write(from: buffer) } catch {
                AppLogger.error("Buffer write failed: \(error)")
            }
        }
        // Compute RMS for metering
        guard let channelData = buffer.floatChannelData else { return }
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        var rms: Float = 0
        for ch in 0..<channelCount {
            var chRms: Float = 0
            vDSP_rmsqv(channelData[ch], 1, &chRms, vDSP_Length(frameCount))
            rms += chRms
        }
        rms /= Float(max(channelCount, 1))
        let db = rms > 0 ? 20 * log10(rms) : -160
        Task { @MainActor [weak self] in self?.meterLevel = db }
    }

    // MARK: - Playback
    func scheduleFile(_ file: AVAudioFile, at time: AVAudioTime? = nil, completionHandler: (() -> Void)? = nil) {
        playerNode.scheduleFile(file, at: time, completionHandler: completionHandler)
    }

    func play() { playerNode.play() }
    func pause() { playerNode.pause() }
    func stopPlayback() { playerNode.stop() }

    // MARK: - Interruption handling
    private func observeInterruptions() {
        sessionManager.interruptionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] type in
                guard let self else { return }
                switch type {
                case .began:
                    if self.isRecording { self.pauseRecording() }
                    self.engine.pause()
                case .ended:
                    try? self.engine.start()
                @unknown default: break
                }
            }
            .store(in: &cancellables)
    }
}
