import AVFoundation
import Foundation

final class AudioFileService {
    private let fileStore: FileStore
    private let formatManager: AudioFormatManager

    init(fileStore: FileStore, formatManager: AudioFormatManager) {
        self.fileStore = fileStore
        self.formatManager = formatManager
    }

    // MARK: - New recording URL
    func newRecordingURL(sessionId: UUID, clipId: UUID) -> URL {
        fileStore.audioDirectory(for: sessionId)
            .appendingPathComponent("\(clipId.uuidString).caf")
    }

    // MARK: - Export
    func exportClip(at sourceURL: URL, format: ExportFormat, sessionId: UUID, clipId: UUID) async throws -> URL {
        let ext = format.fileExtension
        let destURL = fileStore.exportDirectory(for: sessionId)
            .appendingPathComponent("\(clipId.uuidString).\(ext)")

        switch format {
        case .m4a:
            let settings = formatManager.m4aExportSettings()
            try await formatManager.convert(sourceURL: sourceURL, to: destURL, outputSettings: settings)
        case .wav:
            try await convertToWAV(source: sourceURL, destination: destURL)
        case .caf:
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
        }
        return destURL
    }

    private func convertToWAV(source: URL, destination: URL) async throws {
        guard let sourceFile = try? AVAudioFile(forReading: source) else {
            throw AppError.audio(.conversionFailed("Cannot open source file"))
        }
        let settings = formatManager.wavExportSettings(sampleRate: sourceFile.fileFormat.sampleRate)
        guard let destFile = try? AVAudioFile(forWriting: destination,
                                               settings: settings,
                                               commonFormat: .pcmFormatInt32,
                                               interleaved: true) else {
            throw AppError.audio(.conversionFailed("Cannot create destination file"))
        }
        let frameCapacity: AVAudioFrameCount = 4096
        guard let buffer = AVAudioPCMBuffer(pcmFormat: sourceFile.processingFormat,
                                            frameCapacity: frameCapacity) else {
            throw AppError.audio(.conversionFailed("Buffer alloc failed"))
        }
        while sourceFile.framePosition < sourceFile.length {
            try sourceFile.read(into: buffer)
            try destFile.write(from: buffer)
        }
    }

    // MARK: - Duration
    func duration(of url: URL) -> TimeInterval { formatManager.duration(of: url) ?? 0 }

    // MARK: - Waveform samples
    func waveformSamples(for url: URL, sampleCount: Int) async throws -> [Float] {
        try await Task.detached(priority: .userInitiated) {
            guard let file = try? AVAudioFile(forReading: url) else { return [] }
            let frameCount = AVAudioFrameCount(file.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else { return [] }
            try file.read(into: buffer)
            guard let data = buffer.floatChannelData?[0] else { return [] }
            let total = Int(buffer.frameLength)
            let stride = max(total / sampleCount, 1)
            var samples: [Float] = []
            samples.reserveCapacity(sampleCount)
            var i = 0
            while i < total {
                let end = min(i + stride, total)
                var peak: Float = 0
                for j in i..<end { peak = max(peak, abs(data[j])) }
                samples.append(peak)
                i += stride
            }
            return samples
        }.value
    }

    // MARK: - Delete
    func deleteClip(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case m4a, wav, caf
    var id: String { rawValue }
    var fileExtension: String { rawValue }
    var displayName: String {
        switch self {
        case .m4a: return "AAC / M4A"
        case .wav: return "WAV (24-bit)"
        case .caf: return "CAF (Lossless)"
        }
    }
}
