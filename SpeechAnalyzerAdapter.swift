import Speech
import AVFoundation

actor SpeechAnalyzerAdapter {
    private var recognizer: SFSpeechRecognizer?
    private var currentTask: SFSpeechRecognitionTask?

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale.current)
        recognizer?.defaultTaskHint = .dictation
    }

    // MARK: - Transcribe file
    func transcribeFile(url: URL, locale: Locale = .current) async throws -> [TranscriptSegmentModel] {
        guard Permissions.speechGranted else {
            throw AppError.transcription(.unavailable)
        }

        let rec = SFSpeechRecognizer(locale: locale)
        guard let rec, rec.isAvailable else {
            throw AppError.transcription(.localeNotSupported(locale.identifier))
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = false
        request.addsPunctuation = true

        return try await withCheckedThrowingContinuation { cont in
            currentTask = rec.recognitionTask(with: request) { result, error in
                if let error {
                    cont.resume(throwing: AppError.transcription(.jobFailed(error)))
                    return
                }
                guard let result, result.isFinal else { return }
                let segments = result.bestTranscription.segments.map { seg -> TranscriptSegmentModel in
                    TranscriptSegmentModel(
                        id: UUID(),
                        sessionId: UUID(),  // caller sets
                        clipId: UUID(),     // caller sets
                        text: seg.substring,
                        startTime: seg.timestamp,
                        endTime: seg.timestamp + seg.duration,
                        confidence: seg.confidence
                    )
                }
                cont.resume(returning: segments)
            }
        }
    }

    // MARK: - Live recognition (streaming)
    func startLiveRecognition(
        audioEngine: AVAudioEngine,
        onPartial: @escaping (String) -> Void,
        onFinal: @escaping ([TranscriptSegmentModel]) -> Void
    ) throws -> SFSpeechAudioBufferRecognitionRequest {
        guard let rec = recognizer, rec.isAvailable else {
            throw AppError.transcription(.unavailable)
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true

        currentTask = rec.recognitionTask(with: request) { result, error in
            guard let result else { return }
            if result.isFinal {
                let segments = result.bestTranscription.segments.map { seg in
                    TranscriptSegmentModel(
                        id: UUID(),
                        sessionId: UUID(),
                        clipId: UUID(),
                        text: seg.substring,
                        startTime: seg.timestamp,
                        endTime: seg.timestamp + seg.duration,
                        confidence: seg.confidence
                    )
                }
                onFinal(segments)
            } else {
                onPartial(result.bestTranscription.formattedString)
            }
        }
        return request
    }

    func cancelCurrentTask() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Language support
    var supportedLocales: [Locale] {
        SFSpeechRecognizer.supportedLocales().map { $0 }
    }
}
