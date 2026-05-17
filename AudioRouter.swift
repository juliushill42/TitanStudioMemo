import AVFoundation
import Combine

enum AudioInputSource: String, CaseIterable, Identifiable {
    case builtInMic = "Built-in Mic"
    case headsetMic = "Headset Mic"
    case bluetoothHFP = "Bluetooth"
    case usbAudio = "USB Audio"
    case lineIn = "Line In"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .builtInMic:  return "mic.fill"
        case .headsetMic:  return "headphones"
        case .bluetoothHFP: return "dot.radiowaves.left.and.right"
        case .usbAudio:    return "cable.connector"
        case .lineIn:      return "arrow.down.circle"
        }
    }
}

@MainActor
final class AudioRouter: ObservableObject {
    @Published private(set) var availableSources: [AVAudioSessionPortDescription] = []
    @Published private(set) var activeSource: AVAudioSessionPortDescription?
    @Published private(set) var preferredSource: AudioInputSource = .builtInMic

    private let engine: AudioEngineManager
    private let sessionManager: AudioSessionManager
    private var cancellables = Set<AnyCancellable>()

    init(engine: AudioEngineManager, sessionManager: AudioSessionManager) {
        self.engine = engine
        self.sessionManager = sessionManager
        refreshSources()
        observeRouteChanges()
    }

    // MARK: - Source management
    func refreshSources() {
        availableSources = sessionManager.availableInputs
        activeSource = sessionManager.currentInput
    }

    func select(source: AVAudioSessionPortDescription) throws {
        try sessionManager.setPreferredInput(source)
        activeSource = source
        AppLogger.info("AudioRouter: selected input → \(source.portName)")
    }

    func selectDefault() throws {
        try sessionManager.setPreferredInput(nil)
        activeSource = sessionManager.currentInput
    }

    // MARK: - Route change observation
    private func observeRouteChanges() {
        sessionManager.routeChangePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshSources()
            }
            .store(in: &cancellables)
    }
}
