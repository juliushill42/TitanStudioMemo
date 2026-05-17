import SwiftUI
import AVFoundation

// MARK: - StemViewModel
@MainActor
final class StemViewModel: ObservableObject {
    @Published var jobs: [StemJob] = []
    @Published var activeJob: StemJob?
    @Published var selectedMode: StemJobModel.StemMode = .fourStem
    @Published var error: AppError?

    private let engine: StemSeparationEngine
    private let fileStore: FileStore
    private let repository: ProjectRepository?

    init(engine: StemSeparationEngine, fileStore: FileStore, repository: ProjectRepository? = nil) {
        self.engine = engine
        self.fileStore = fileStore
        self.repository = repository
    }

    func submitJob(sourceURL: URL, sessionId: UUID? = nil) async {
        let model = StemJobModel(
            id: UUID(),
            sessionId: sessionId,
            sourceURL: sourceURL,
            status: .queued,
            mode: selectedMode,
            progress: 0,
            outputURLs: [:],
            createdAt: Date()
        )
        let job = StemJob(model: model, engine: engine)
        jobs.append(job)
        activeJob = job
        await job.run()
    }

    func clearCompleted() {
        jobs.removeAll { $0.model.status == .complete || $0.model.status == .failed }
        activeJob = nil
    }
}

// MARK: - StemImportView
struct StemImportView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm: StemViewModel
    @State private var showFilePicker: Bool = false
    @State private var importedURL: URL?
    @State private var selectedJob: StemJob?

    init() {
        _vm = StateObject(wrappedValue: StemViewModel(
            engine: AppEnvironment().stemEngine!,
            fileStore: AppEnvironment().fileStore!
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    importCard
                    if !vm.jobs.isEmpty { jobList }
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Stem Lab")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !vm.jobs.isEmpty {
                        Button("Clear") { vm.clearCompleted() }
                            .foregroundColor(AppTheme.Colors.accent)
                    }
                }
            }
            .fileImporter(isPresented: $showFilePicker,
                          allowedContentTypes: [.audio],
                          allowsMultipleSelection: false) { result in
                if let url = try? result.get().first {
                    importedURL = url
                }
            }
            .onChange(of: importedURL) { _, url in
                guard let url else { return }
                Task { await vm.submitJob(sourceURL: url) }
            }
            .sheet(item: $selectedJob) { job in
                StemJobView(job: job)
            }
        }
    }

    private var importCard: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "tuningfork")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.accent)

            Text("Stem Separation")
                .font(AppTheme.Fonts.title)
                .foregroundColor(AppTheme.Colors.primary)

            Text("Import an audio file to separate into stems.")
                .font(AppTheme.Fonts.body)
                .foregroundColor(AppTheme.Colors.secondary)
                .multilineTextAlignment(.center)

            Picker("Mode", selection: $vm.selectedMode) {
                ForEach(StemJobModel.StemMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.Colors.accent)

            Button("Import Audio") { showFilePicker = true }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.accent)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private var jobList: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Jobs")
                .font(AppTheme.Fonts.headline)
                .foregroundColor(AppTheme.Colors.primary)

            ForEach(vm.jobs) { job in
                StemJobRowView(job: job)
                    .onTapGesture { selectedJob = job }
            }
        }
    }
}

// MARK: - StemJobRowView
struct StemJobRowView: View {
    @ObservedObject var job: StemJob

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(job.model.sourceURL.lastPathComponent)
                    .font(AppTheme.Fonts.headline)
                    .foregroundColor(AppTheme.Colors.primary)
                    .lineLimit(1)
                Text(job.model.mode.rawValue)
                    .font(AppTheme.Fonts.caption)
                    .foregroundColor(AppTheme.Colors.secondary)
            }
            Spacer()
            statusView
        }
        .cardStyle()
    }

    @ViewBuilder private var statusView: some View {
        switch job.model.status {
        case .queued:
            Label("Queued", systemImage: "clock").foregroundColor(AppTheme.Colors.secondary)
        case .processing:
            ProgressView().tint(AppTheme.Colors.accent)
        case .complete:
            Label("Done", systemImage: "checkmark.circle.fill").foregroundColor(.green)
        case .failed:
            Label("Failed", systemImage: "xmark.circle.fill").foregroundColor(.red)
        }
    }
}

// MARK: - StemJobView
struct StemJobView: View {
    @ObservedObject var job: StemJob
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    jobHeader
                    if job.model.status == .processing {
                        ProgressView(value: job.model.progress)
                            .tint(AppTheme.Colors.accent)
                            .padding(.horizontal, AppTheme.Spacing.md)
                    }
                    if job.model.status == .complete {
                        stemTracks
                    }
                    if let msg = job.model.errorMessage {
                        Text(msg)
                            .font(AppTheme.Fonts.body)
                            .foregroundColor(.red)
                            .cardStyle()
                    }
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Stem Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }

    private var jobHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(job.model.sourceURL.lastPathComponent)
                .font(AppTheme.Fonts.headline)
                .foregroundColor(AppTheme.Colors.primary)
            Text(job.model.mode.rawValue)
                .font(AppTheme.Fonts.caption)
                .foregroundColor(AppTheme.Colors.secondary)
            Text(job.model.status.rawValue.capitalized)
                .font(AppTheme.Fonts.caption)
                .foregroundColor(job.model.status == .complete ? .green : AppTheme.Colors.accent)
        }
        .cardStyle()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stemTracks: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Stems")
                .font(AppTheme.Fonts.headline)
                .foregroundColor(AppTheme.Colors.primary)

            ForEach(Array(job.model.outputURLs.sorted(by: { $0.key.rawValue < $1.key.rawValue })), id: \.key) { track, url in
                StemPlayerView(track: track, url: url)
            }
        }
    }
}

// MARK: - StemPlayerView
struct StemPlayerView: View {
    let track: StemJobModel.StemTrack
    let url: URL

    @State private var player: AVAudioPlayer?
    @State private var isPlaying: Bool = false
    @State private var progress: Double = 0
    @State private var timer: Timer?

    var body: some View {
        HStack {
            Image(systemName: track.systemImage)
                .foregroundColor(AppTheme.Colors.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(track.displayName)
                    .font(AppTheme.Fonts.headline)
                    .foregroundColor(AppTheme.Colors.primary)
                ProgressView(value: progress)
                    .tint(AppTheme.Colors.accent)
            }

            Spacer()

            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .foregroundColor(AppTheme.Colors.accent)
            }

            ShareLink(item: url) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(AppTheme.Colors.secondary)
            }
        }
        .cardStyle()
        .onDisappear { stopPlayback() }
    }

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
            isPlaying = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                guard let p = player else { return }
                progress = p.currentTime / max(p.duration, 1)
                if !p.isPlaying { stopPlayback() }
            }
        } catch {
            AppLogger.error("StemPlayer: \(error)")
        }
    }

    private func stopPlayback() {
        player?.stop()
        player = nil
        isPlaying = false
        timer?.invalidate()
        timer = nil
        progress = 0
    }
}
