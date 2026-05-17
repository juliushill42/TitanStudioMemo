import AVFoundation
import Speech

enum Permissions {
    // MARK: - Request all required permissions
    @discardableResult
    static func requestAll() async -> Bool {
        let mic = await requestMicrophone()
        let speech = await requestSpeechRecognition()
        return mic && speech
    }

    // MARK: - Microphone
    static func requestMicrophone() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
                AppLogger.info("Microphone permission: \(granted ? "granted" : "denied")")
            }
        }
    }

    static var microphoneStatus: AVAudioApplication.recordPermission {
        AVAudioApplication.shared.recordPermission
    }

    // MARK: - Speech recognition
    static func requestSpeechRecognition() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
                AppLogger.info("Speech recognition permission: \(status.rawValue)")
            }
        }
    }

    static var speechStatus: SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    // MARK: - Status checks (no prompt)
    static var microphoneGranted: Bool { microphoneStatus == .granted }
    static var speechGranted: Bool     { speechStatus == .authorized }
    static var allGranted: Bool        { microphoneGranted && speechGranted }
}
