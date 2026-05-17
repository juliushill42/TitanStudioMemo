StudioMemoStudioMemo is a professional, high-performance Swift application designed for iPhone and iPad. It serves as an integrated environment for spoken-word recording, songwriting, transcript-linked editing, and local AI-powered audio stem separation.The app bypasses standard high-level scheduling overheads where necessary to communicate directly with hardware matrices, guaranteeing zero-byte loss patterns on unexpected system depletion while keeping the UI responsive.📱 Key CapabilitiesDirect Mic Capture: High-fidelity, low-latency audio capture using hardware-matched routing.Background Audio Execution: Continuous, uninterrupted multitrack recording and playback.Asynchronous local AI Transcription: Speech-to-text pipeline linked directly to a spatial editing timeline.AI Stem Separation Lab: Local multi-track separation engine to isolate vocals, drums, bass, and instrumental backing tracks.Automated Crash Journal Recovery: Transactional metadata tracking that guarantees project state restoration after physical battery depletion or system interruptions.Multi-Format Export Pipeline: High-fidelity PCM (WAV) and AAC (M4A) compilation engines with down-mixing capabilities.🗂 Project ArchitectureThe directory layout adheres strictly to a clean, modular structure separating infrastructure concerns, domain-specific AI processing, persistence, and feature views.StudioMemo/
  App/
    StudioMemoApp.swift          # Core App entry point & permission barrier
    AppRouter.swift              # Programmatic Navigation State Matrix
    AppEnvironment.swift         # Dependency injection container & global state
    AppTheme.swift               # Consistent design system tokens and Hex colors
  Core/
    Audio/
      AudioSessionManager.swift  # Direct iOS AVAudioSession hardware binding
      AudioEngineManager.swift   # Low-level AVAudioEngine control
      AudioFormatManager.swift   # Sample rate & bit depth configuration
      AudioRouter.swift          # Capture route selection (e.g., system vs mic)
      AudioFileService.swift     # Multi-channel disk streaming & buffering
    AI/
      SpeechAnalyzerAdapter.swift# Speech-to-text processing bridge
      TranscriptJob.swift        # Background transcription queue manager
      TranscriptModels.swift     # Segment, timestamp, and confidence data
      StemSeparationEngine.swift # Core AI Model executor for audio separation
      StemJob.swift              # Separation lifecycle job state machines
      SessionInsightsEngine.swift# Audio intelligence metadata summaries
    Persistence/
      ProjectRepository.swift    # High-level domain aggregate repository
      FileStore.swift            # Sandbox directory management (WAV/stems)
      MetadataStore.swift        # Local SQLite/CoreData state database
      RecoveryManager.swift      # Journaling framework for crash state rebuilds
    Utilities/
      AppError.swift             # Main localized domain error taxonomy
      Logger.swift               # OSLogger framework wrapping and filtering
      Permissions.swift          # Asynchronous system authorization handlers
      AsyncState.swift           # Generic lifecycle states (Idle, Loading, Success, Failure)
      DateHelpers.swift          # Localized time and ISO formatting
  Features/
    Home/                        # Navigation dashboard and workspace switcher
    Capture/                     # High-fidelity recording interfaces & meters
    Timeline/                    # Visual waveform clip arranger and editor
    Session/                     # Metadata details, listings, and text notes
    Transcription/               # Interactive text-linked editor
    StemLab/                     # AI stem importer, worker tracking, and mixer
    Export/                      # Master consolidation and system share sheets
    Settings/                    # DSP configuration and license management
🧱 Production Build PhasingTo maintain complete stability and eliminate scope creep, development is divided into five rigorous, functional phases:Phase 1: Foundation & Base CaptureDeploy core App shell, routing state, and strict UI permission gates.Configure base SQLite/CoreData persistence & directory sandboxing.Construct direct microphone capture and real-time hardware level monitoring.Build project/session listing interfaces.Phase 2: Playback & Timeline SpatializationImplement interactive waveform renderings of recorded audio.Build multi-track playback, scrubbing, and temporal marker placements.Integrate the transcript UI container into the timeline layout.Phase 3: Transcription Engine & Linked EditingBuild local speech recognition pipelines (transcription jobs).Coordinate text selection back to physical timeline audio clips.Generate automatic AI session titles and intelligent spoken summaries.Phase 4: Local AI Stem Separation LabDevelop file ingestion with scoped-security sandbox permissions.Deploy background worker queues with thread-priority adjustments.Design the multi-track console mixer (featuring individual track gain controls).Phase 5: Hardening & Fault ToleranceEstablish transaction-based journal recovery to protect against mid-record crashes.Integrate descriptive diagnostic states and error logging.Run complete Integration test suites across targeted devices.🛠 Setup & Launch RequirementsMinimum RequirementsOS Platform: iOS 17.0+ / iPadOS 17.0+Development Tool: Xcode 15.0+Swift Version: Swift 5.9+Device Access ConfigurationsStudioMemo requires physical device testing for standard features due to Simulator audio constraints. Ensure you update your Info.plist with:NSMicrophoneUsageDescription — Required to stream low-latency vocal inputs into the Core Audio engine.UIBackgroundModes — Configured with audio to prevent the operating system from terminating capture threads when the device sleeps.📈 Quality Assurance & Launch CriteriaZero-Byte Loss Guarantee: Active recording passes must automatically recover valid audio files even if the host thread is suddenly terminated by the OS.Deterministic UI State: Heavy AI processing tasks (Stem Isolation/Transcription) are explicitly assigned to background execution queues to prevent rendering frames from dropping below $60\text{ fps}$.Sandbox Compliance: Scoped security tokens are immediately utilized upon raw audio file imports to bypass sandbox access rejections.
