import Foundation
import NaturalLanguage

actor SessionInsightsEngine {
    private let speechAnalyzer: SpeechAnalyzerAdapter

    init(speechAnalyzer: SpeechAnalyzerAdapter) {
        self.speechAnalyzer = speechAnalyzer
    }

    // MARK: - Auto title
    func generateTitle(from segments: [TranscriptSegmentModel]) -> String {
        let text = segments.prefix(20).map(\.text).joined(separator: " ")
        guard !text.isEmpty else { return Date().sessionTitle }

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text

        var keywords: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                              unit: .word,
                              scheme: .lexicalClass,
                              options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if tag == .noun || tag == .verb {
                keywords.append(String(text[range]).capitalized)
            }
            return keywords.count < 4
        }

        if keywords.isEmpty { return Date().sessionTitle }
        return keywords.prefix(4).joined(separator: " ")
    }

    // MARK: - Auto summary
    func generateSummary(from segments: [TranscriptSegmentModel]) -> String {
        let text = segments.map(\.text).joined(separator: " ")
        guard text.count > 100 else { return text }

        // Sentence extraction: take first 2 sentences
        var sentences: [String] = []
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            sentences.append(String(text[range]))
            return sentences.count < 2
        }
        return sentences.joined(separator: " ")
    }

    // MARK: - Tag suggestions
    func suggestTags(from segments: [TranscriptSegmentModel]) -> [String] {
        let text = segments.map(\.text).joined(separator: " ")
        guard !text.isEmpty else { return [] }

        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var tags = Set<String>()

        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                              unit: .word,
                              scheme: .nameType,
                              options: [.omitWhitespace, .joinNames]) { tag, range in
            if tag == .personalName || tag == .placeName || tag == .organizationName {
                tags.insert(String(text[range]))
            }
            return tags.count < 5
        }
        return Array(tags)
    }
}
