import AVFoundation
import Combine

final class AudioSessionManager {
    private let session = AVAudioSession.sharedInstance()

    // MARK: - Configure
    func configure() throws {
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            try session.setActive(true)
            AppLogger.info("AudioSession configured: \(session.category.rawValue)")
        } catch {
            throw AppError.audio(.sessionConfiguration(underlying: error))
        }
    }

    func configureForPlayback() throws {
        do {
            try session.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            throw AppError.audio(.sessionConfiguration(underlying: error))
        }
    }

    func deactivate() {
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Queries
    var inputLatency: TimeInterval { session.inputLatency }
    var outputLatency: TimeInterval { session.outputLatency }
    var sampleRate: Double { session.sampleRate }
    var inputChannelCount: Int { Int(session.inputNumberOfChannels) }
    var availableInputs: [AVAudioSessionPortDescription] { session.availableInputs ?? [] }
    var currentInput: AVAudioSessionPortDescription? { session.currentRoute.inputs.first }

    // MARK: - Route change publisher
    var routeChangePublisher: AnyPublisher<AVAudioSession.RouteChangeReason, Never> {
        NotificationCenter.default
            .publisher(for: AVAudioSession.routeChangeNotification)
            .compactMap { note -> AVAudioSession.RouteChangeReason? in
                guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt else { return nil }
                return AVAudioSession.RouteChangeReason(rawValue: raw)
            }
            .eraseToAnyPublisher()
    }

    var interruptionPublisher: AnyPublisher<AVAudioSession.InterruptionType, Never> {
        NotificationCenter.default
            .publisher(for: AVAudioSession.interruptionNotification)
            .compactMap { note -> AVAudioSession.InterruptionType? in
                guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else { return nil }
                return AVAudioSession.InterruptionType(rawValue: raw)
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Preferred input
    func setPreferredInput(_ port: AVAudioSessionPortDescription?) throws {
        try session.setPreferredInput(port)
    }
}
