import SwiftUI
import Combine

@MainActor
final class AppEnvironment: ObservableObject {
    // MARK: - State
    @Published private(set) var isBootstrapping: Bool = true
    @Published private(set) var permissionsGranted: Bool = false
    @Published private(set) var fatalError: AppError?

    // MARK: - Core Services (lazy-init after bootstrap)
    private(set) var audioSession: AudioSessionManager!
    private(set) var audioEngine: AudioEngineManager!
    private(set) var audioFormat: AudioFormatManager!
    private(set) var audioRouter: AudioRouter!
    private(set) var audioFileService: AudioFileService!

    // MARK: - Persistence
    private(set) var projectRepository: ProjectRepository!
    private(set) var fileStore: FileStore!
    private(set) var metadataStore: MetadataStore!
    private(set) var recoveryManager: RecoveryManager!

    // MARK: - AI
    private(set) var speechAnalyzer: SpeechAnalyzerAdapter!
    private(set) var stemEngine: StemSeparationEngine!
    private(set) var insightsEngine: SessionInsightsEngine!

    // MARK: - Bootstrap
    func bootstrap() async {
        AppLogger.info("AppEnvironment bootstrap start")
        defer {
            isBootstrapping = false
            AppLogger.info("AppEnvironment bootstrap complete")
        }

        do {
            // 1. Persistence layer
            fileStore = FileStore()
            metadataStore = try await MetadataStore()
            projectRepository = ProjectRepository(fileStore: fileStore, metadataStore: metadataStore)
            recoveryManager = RecoveryManager(projectRepository: projectRepository, fileStore: fileStore)

            // 2. Audio layer
            audioFormat = AudioFormatManager()
            audioSession = AudioSessionManager()
            audioFileService = AudioFileService(fileStore: fileStore, formatManager: audioFormat)
            audioEngine = AudioEngineManager(sessionManager: audioSession, formatManager: audioFormat)
            audioRouter = AudioRouter(engine: audioEngine, sessionManager: audioSession)

            // 3. AI layer
            speechAnalyzer = SpeechAnalyzerAdapter()
            stemEngine = StemSeparationEngine(fileStore: fileStore)
            insightsEngine = SessionInsightsEngine(speechAnalyzer: speechAnalyzer)

            // 4. Recovery sweep
            await recoveryManager.sweepOrphanedSessions()

            // 5. Permissions
            let granted = await Permissions.requestAll()
            permissionsGranted = granted

            if granted {
                try audioSession.configure()
            }
        } catch {
            fatalError = AppError.bootstrap(underlying: error)
            AppLogger.error("Bootstrap failed: \(error)")
        }
    }

    func retryPermissions() async {
        let granted = await Permissions.requestAll()
        permissionsGranted = granted
        if granted {
            try? audioSession.configure()
        }
    }
}
