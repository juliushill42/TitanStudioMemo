import AVFoundation

final class AudioFormatManager {
    // MARK: - Recording format
    func recordingFormat(sampleRate: Double, channels: Int) -> AVAudioFormat {
        let sr = sampleRate > 0 ? sampleRate : 44100
        let ch = max(channels, 1)
        return AVAudioFormat(standardFormatWithSampleRate: sr, channels: AVAudioChannelCount(ch))
            ?? AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    }

    // MARK: - Export settings
    func m4aExportSettings(sampleRate: Double = 44100, bitRate: Int = 256_000) -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: bitRate,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
    }

    func wavExportSettings(sampleRate: Double = 44100) -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 24,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
    }

    // MARK: - Conversion
    func convert(sourceURL: URL, to destinationURL: URL, outputSettings: [String: Any]) async throws {
        let asset = AVURLAsset(url: sourceURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AppError.audio(.conversionFailed("Export session init failed"))
        }
        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .m4a

        await exportSession.export()
        if let error = exportSession.error {
            throw AppError.audio(.conversionFailed(error.localizedDescription))
        }
    }

    // MARK: - Duration
    func duration(of url: URL) -> TimeInterval? {
        let asset = AVURLAsset(url: url)
        let duration = asset.duration
        guard duration.isValid, !duration.isIndefinite else { return nil }
        return CMTimeGetSeconds(duration)
    }
}
