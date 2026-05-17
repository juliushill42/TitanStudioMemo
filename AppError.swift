import Foundation

// MARK: - Top-level app error
enum AppError: Error, LocalizedError {
    case bootstrap(underlying: Error)
    case audio(AudioErrorCode)
    case persistence(PersistenceErrorCode)
    case transcription(TranscriptionErrorCode)
    case stem(StemErrorCode)
    case export(ExportErrorCode)
    case permissions(PermissionErrorCode)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .bootstrap(let e):     return "Startup failed: \(e.localizedDescription)"
        case .audio(let code):      return code.localizedDescription
        case .persistence(let code): return code.localizedDescription
        case .transcription(let c): return c.localizedDescription
        case .stem(let c):          return c.localizedDescription
        case .export(let c):        return c.localizedDescription
        case .permissions(let c):   return c.localizedDescription
        case .unknown(let e):       return e.localizedDescription
        }
    }

    var isRecoverable: Bool {
        switch self {
        case .audio(.engineNotRunning), .audio(.sessionConfiguration): return true
        case .permissions: return true
        default: return false
        }
    }
}

// MARK: - Audio errors
enum AudioErrorCode: Error, LocalizedError {
    case sessionConfiguration(underlying: Error)
    case engineStart(underlying: Error)
    case engineNotRunning
    case conversionFailed(String)
    case fileReadFailed(URL)
    case fileWriteFailed(URL)
    case bufferAllocationFailed

    var localizedDescription: String {
        switch self {
        case .sessionConfiguration(let e): return "Audio session error: \(e.localizedDescription)"
        case .engineStart(let e):          return "Engine start error: \(e.localizedDescription)"
        case .engineNotRunning:            return "Audio engine is not running"
        case .conversionFailed(let msg):   return "Conversion failed: \(msg)"
        case .fileReadFailed(let url):     return "Cannot read: \(url.lastPathComponent)"
        case .fileWriteFailed(let url):    return "Cannot write: \(url.lastPathComponent)"
        case .bufferAllocationFailed:      return "Audio buffer allocation failed"
        }
    }
}

// MARK: - Persistence errors
enum PersistenceErrorCode: Error, LocalizedError {
    case encodingFailed(Error)
    case decodingFailed(Error)
    case writeFailure(URL, Error)
    case readFailure(URL, Error)
    case notFound(UUID)
    case directoryCreationFailed(URL)

    var localizedDescription: String {
        switch self {
        case .encodingFailed(let e):        return "Encode error: \(e.localizedDescription)"
        case .decodingFailed(let e):        return "Decode error: \(e.localizedDescription)"
        case .writeFailure(let url, let e): return "Write failed [\(url.lastPathComponent)]: \(e.localizedDescription)"
        case .readFailure(let url, let e):  return "Read failed [\(url.lastPathComponent)]: \(e.localizedDescription)"
        case .notFound(let id):             return "Not found: \(id)"
        case .directoryCreationFailed(let url): return "Directory failed: \(url.path)"
        }
    }
}

// MARK: - Transcription errors
enum TranscriptionErrorCode: Error, LocalizedError {
    case unavailable
    case localeNotSupported(String)
    case jobFailed(Error)
    case timeout

    var localizedDescription: String {
        switch self {
        case .unavailable:               return "Speech recognition unavailable"
        case .localeNotSupported(let l): return "Locale not supported: \(l)"
        case .jobFailed(let e):          return "Transcription failed: \(e.localizedDescription)"
        case .timeout:                   return "Transcription timed out"
        }
    }
}

// MARK: - Stem errors
enum StemErrorCode: Error, LocalizedError {
    case modelLoadFailed
    case inferenceFailure(String)
    case unsupportedFormat

    var localizedDescription: String {
        switch self {
        case .modelLoadFailed:         return "Stem model failed to load"
        case .inferenceFailure(let m): return "Inference error: \(m)"
        case .unsupportedFormat:       return "Unsupported audio format for stem separation"
        }
    }
}

// MARK: - Export errors
enum ExportErrorCode: Error, LocalizedError {
    case sessionCreationFailed
    case exportFailed(String)
    case invalidDestination(URL)

    var localizedDescription: String {
        switch self {
        case .sessionCreationFailed:    return "Export session could not be created"
        case .exportFailed(let msg):    return "Export failed: \(msg)"
        case .invalidDestination(let u): return "Invalid destination: \(u.path)"
        }
    }
}

// MARK: - Permission errors
enum PermissionErrorCode: Error, LocalizedError {
    case microphoneDenied
    case speechRecognitionDenied

    var localizedDescription: String {
        switch self {
        case .microphoneDenied:         return "Microphone access denied. Enable in Settings."
        case .speechRecognitionDenied:  return "Speech recognition denied. Enable in Settings."
        }
    }
}
