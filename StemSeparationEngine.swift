import Foundation
import AVFoundation
import CoreML
import Accelerate

actor StemSeparationEngine {
    private let fileStore: FileStore

    init(fileStore: FileStore) {
        self.fileStore = fileStore
    }

    // MARK: - Run separation job
    func separate(job: StemJobModel) async throws -> StemJobModel {
        var updatedJob = job
        updatedJob.status = .processing

        // 1. Load source audio into float buffers
        let buffers = try loadAudioBuffers(from: job.sourceURL)

        // 2. Run separation (stub: ships with on-device model when integrated)
        let stems = try await runSeparation(buffers: buffers, mode: job.mode)

        // 3. Write stem files
        var outputURLs: [StemJobModel.StemTrack: URL] = [:]
        let stemDir = fileStore.stemDirectory(for: job.sessionId ?? UUID())
        for (track, buffer) in stems {
            let url = stemDir.appendingPathComponent("\(job.id.uuidString)_\(track.rawValue).caf")
            try writeBuffer(buffer, to: url, sourceFormat: buffers.format)
            outputURLs[track] = url
        }

        updatedJob.outputURLs = outputURLs
        updatedJob.status = .complete
        updatedJob.completedAt = Date()
        updatedJob.progress = 1.0
        return updatedJob
    }

    // MARK: - Audio loading
    private struct AudioBuffers {
        let left: [Float]
        let right: [Float]
        let format: AVAudioFormat
        let sampleRate: Double
    }

    private func loadAudioBuffers(from url: URL) throws -> AudioBuffers {
        guard let file = try? AVAudioFile(forReading: url) else {
            throw AppError.audio(.fileReadFailed(url))
        }
        let frameCount = AVAudioFrameCount(file.length)
        let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: file.fileFormat.sampleRate, channels: 2)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: stereoFormat, frameCapacity: frameCount) else {
            throw AppError.audio(.bufferAllocationFailed)
        }
        try file.read(into: buffer)

        let ch = buffer.floatChannelData
        let left  = ch.map { Array(UnsafeBufferPointer(start: $0[0], count: Int(buffer.frameLength))) } ?? []
        let right = buffer.format.channelCount > 1
            ? Array(UnsafeBufferPointer(start: ch![1], count: Int(buffer.frameLength)))
            : left
        return AudioBuffers(left: left, right: right, format: stereoFormat, sampleRate: file.fileFormat.sampleRate)
    }

    // MARK: - Separation (model integration point)
    /// Phase 4: Replace with actual CoreML model inference.
    /// Stub implementation produces energy-split stems for integration testing.
    private func runSeparation(
        buffers: AudioBuffers,
        mode: StemJobModel.StemMode
    ) async throws -> [StemJobModel.StemTrack: AVAudioPCMBuffer] {
        let tracks = tracksForMode(mode)
        var result: [StemJobModel.StemTrack: AVAudioPCMBuffer] = [:]
        let frameCount = AVAudioFrameCount(buffers.left.count)

        for track in tracks {
            guard let buf = AVAudioPCMBuffer(pcmFormat: buffers.format, frameCapacity: frameCount) else {
                throw AppError.audio(.bufferAllocationFailed)
            }
            buf.frameLength = frameCount
            let scale: Float = 1.0 / Float(tracks.count)
            var scaledL = buffers.left.map  { $0 * scale }
            var scaledR = buffers.right.map { $0 * scale }
            vDSP_vclr(buf.floatChannelData![0], 1, vDSP_Length(frameCount))
            vDSP_vclr(buf.floatChannelData![1], 1, vDSP_Length(frameCount))
            cblas_scopy(Int32(frameCount), &scaledL, 1, buf.floatChannelData![0], 1)
            cblas_scopy(Int32(frameCount), &scaledR, 1, buf.floatChannelData![1], 1)
            result[track] = buf
        }
        return result
    }

    private func tracksForMode(_ mode: StemJobModel.StemMode) -> [StemJobModel.StemTrack] {
        switch mode {
        case .twoStem:  return [.vocals, .accompaniment]
        case .fourStem: return [.vocals, .drums, .bass, .other]
        case .fiveStem: return [.vocals, .drums, .bass, .piano, .other]
        }
    }

    // MARK: - Buffer write
    private func writeBuffer(_ buffer: AVAudioPCMBuffer, to url: URL, sourceFormat: AVAudioFormat) throws {
        guard let file = try? AVAudioFile(forWriting: url,
                                           settings: sourceFormat.settings,
                                           commonFormat: .pcmFormatFloat32,
                                           interleaved: false) else {
            throw AppError.audio(.fileWriteFailed(url))
        }
        try file.write(from: buffer)
    }
}
