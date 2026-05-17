import SwiftUI

// MARK: - TranscriptViewModel
@MainActor
final class TranscriptViewModel: ObservableObject {
    @Published private(set) var segments: [TranscriptSegmentModel] = []
    @Published private(set) var jobs: [TranscriptJob] = []
    @Published private(set) var displayModel: TranscriptDisplayModel?
    @Published var searchText: String = ""
    @Published var selectedSegment: TranscriptSegmentModel?

    private let session: SessionModel
    private let repository: ProjectRepository
    private let speechAnalyzer: SpeechAnalyzerAdapter
    private let insightsEngine: SessionInsightsEngine

    init(session: SessionModel, repository: ProjectRepository,
         speechAnalyzer: SpeechAnalyzerAdapter, insightsEngine: SessionInsightsEngine) {
        self.session = session
        self.repository = repository
        self.speechAnalyzer = speechAnalyzer
        self.insightsEngine = insightsEngine
    }

    func load() async {
        segments = await repository.loadTranscript(for: session.id)
        displayModel = TranscriptDisplayModel(segments: segments)
    }

    func runTranscription(clips: [ClipModel]) async {
        for clip in clips {
            let jobModel = TranscriptJobModel(
                id: UUID(),
                sessionId: session.id,
                clipId: clip.id,
                status: .queued,
                locale: Locale.current.identifier,
                createdAt: Date()
            )
            let job = TranscriptJob(model: jobModel, adapter: speechAnalyzer, repository: repository)
            jobs.append(job)
            await job.run(clipURL: clip.fileURL)

            if case .success(let segs) = job.state {
                segments.append(contentsOf: segs)
            }
        }
        segments.sort { $0.startTime < $1.startTime }
        displayModel = TranscriptDisplayModel(segments: segments)
    }

    var filteredSegments: [TranscriptSegmentModel] {
        let q = searchText.lowercased()
        guard !q.isEmpty else { return segments }
        return segments.filter { $0.text.lowercased().contains(q) }
    }

    var wordCount: Int { displayModel?.wordCount ?? 0 }
    var fullText: String { displayModel?.fullText ?? "" }
}

// MARK: - TranscriptView
struct TranscriptView: View {
    let session: SessionModel
    let clips: [ClipModel]

    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm: TranscriptViewModel

    init(session: SessionModel, clips: [ClipModel]) {
        self.session = session
        self.clips = clips
        _vm = StateObject(wrappedValue: TranscriptViewModel(
            session: session,
            repository: AppEnvironment().projectRepository!,
            speechAnalyzer: AppEnvironment().speechAnalyzer!,
            insightsEngine: AppEnvironment().insightsEngine!
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if vm.segments.isEmpty {
                    emptyState
                } else {
                    searchBar
                    transcriptList
                    statsBar
                }
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !clips.isEmpty {
                        Button("Transcribe") {
                            Task { await vm.runTranscription(clips: clips) }
                        }
                        .foregroundColor(AppTheme.Colors.accent)
                    }
                }
            }
        }
        .task { await vm.load() }
    }

    // MARK: - Empty state
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble")
                .font(.system(size: 56))
                .foregroundColor(AppTheme.Colors.secondary)
            Text("No transcript yet")
                .font(AppTheme.Fonts.title)
                .foregroundColor(AppTheme.Colors.primary)
            Text("Tap "Transcribe" to analyze your clips.")
                .font(AppTheme.Fonts.body)
                .foregroundColor(AppTheme.Colors.secondary)
                .multilineTextAlignment(.center)
            if !clips.isEmpty {
                Button("Transcribe Now") {
                    Task { await vm.runTranscription(clips: clips) }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.accent)
            }
        }
        .padding(AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Search
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(AppTheme.Colors.secondary)
            TextField("Search transcript", text: $vm.searchText)
                .font(AppTheme.Fonts.body)
                .foregroundColor(AppTheme.Colors.primary)
        }
        .padding(AppTheme.Spacing.sm)
        .background(AppTheme.Colors.surface)
        .cornerRadius(AppTheme.Radius.sm)
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    // MARK: - Segment list
    private var transcriptList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                ForEach(vm.filteredSegments) { seg in
                    TranscriptSegmentRow(seg: seg, isSelected: vm.selectedSegment?.id == seg.id)
                        .onTapGesture { vm.selectedSegment = seg }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }

    // MARK: - Stats bar
    private var statsBar: some View {
        HStack {
            Label("\(vm.wordCount) words", systemImage: "textformat.abc")
            Spacer()
            Label("\(vm.segments.count) segments", systemImage: "list.number")
        }
        .font(AppTheme.Fonts.caption)
        .foregroundColor(AppTheme.Colors.secondary)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.surface)
    }
}

private struct TranscriptSegmentRow: View {
    let seg: TranscriptSegmentModel
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(seg.startTime.mmss)
                    .font(AppTheme.Fonts.mono)
                    .foregroundColor(AppTheme.Colors.accent)
                Spacer()
                Text(String(format: "%.0f%%", seg.confidence * 100))
                    .font(AppTheme.Fonts.caption)
                    .foregroundColor(AppTheme.Colors.secondary)
            }
            Text(seg.text)
                .font(AppTheme.Fonts.body)
                .foregroundColor(AppTheme.Colors.primary)
        }
        .padding(AppTheme.Spacing.sm)
        .background(isSelected ? AppTheme.Colors.accent.opacity(0.1) : AppTheme.Colors.surface)
        .cornerRadius(AppTheme.Radius.sm)
        .overlay(
            isSelected ? RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                .stroke(AppTheme.Colors.accent, lineWidth: 1.5) : nil
        )
        .animation(AppTheme.Animation.fast, value: isSelected)
    }
}
