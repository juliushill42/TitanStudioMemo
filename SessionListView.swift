import SwiftUI

// MARK: - SessionStore
@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [SessionModel] = []
    @Published var isLoading: Bool = false
    @Published var error: AppError?

    private let repository: ProjectRepository

    init(repository: ProjectRepository) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        await repository.loadAllSessions()
        sessions = repository.sessions
        isLoading = false
    }

    func delete(_ session: SessionModel) async {
        do {
            try await repository.deleteSession(session.id)
            sessions.removeAll { $0.id == session.id }
        } catch let e as AppError {
            error = e
        }
    }

    func update(_ session: SessionModel) async {
        do {
            try await repository.updateSession(session)
            if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[idx] = session
            }
        } catch let e as AppError {
            error = e
        }
    }
}

// MARK: - SessionListView
struct SessionListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var store: SessionStore
    @State private var searchText: String = ""
    @State private var sortOrder: SortOrder = .updatedDesc

    enum SortOrder: String, CaseIterable {
        case updatedDesc = "Newest"
        case updatedAsc  = "Oldest"
        case durationDesc = "Longest"
        case title = "A–Z"
    }

    init() {
        _store = StateObject(wrappedValue: SessionStore(repository: AppEnvironment().projectRepository!))
    }

    private var filtered: [SessionModel] {
        let q = searchText.lowercased()
        let list = q.isEmpty ? store.sessions : store.sessions.filter {
            $0.title.lowercased().contains(q) || $0.notes.lowercased().contains(q)
        }
        switch sortOrder {
        case .updatedDesc:  return list.sorted { $0.updatedAt > $1.updatedAt }
        case .updatedAsc:   return list.sorted { $0.updatedAt < $1.updatedAt }
        case .durationDesc: return list.sorted { $0.durationSeconds > $1.durationSeconds }
        case .title:        return list.sorted { $0.title < $1.title }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtered.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Sessions")
            .searchable(text: $searchText, prompt: "Search sessions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Button(order.rawValue) { sortOrder = order }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(AppTheme.Colors.accent)
                    }
                }
            }
        }
        .task { await store.load() }
        .environmentObject(store)
    }

    private var sessionList: some View {
        List {
            ForEach(filtered) { session in
                NavigationLink(destination: SessionDetailView(session: session)) {
                    SessionRowView(session: session)
                }
                .listRowBackground(AppTheme.Colors.surface)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await store.delete(session) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 56))
                .foregroundColor(AppTheme.Colors.secondary)
            Text("No sessions yet")
                .font(AppTheme.Fonts.title)
                .foregroundColor(AppTheme.Colors.primary)
            Text("Start a new recording from the Home tab.")
                .font(AppTheme.Fonts.body)
                .foregroundColor(AppTheme.Colors.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppTheme.Spacing.xl)
    }
}

// MARK: - SessionRowView
struct SessionRowView: View {
    let session: SessionModel

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: session.mode.systemImage)
                .font(.title3)
                .foregroundColor(AppTheme.Colors.accent)
                .frame(width: 36, height: 36)
                .background(AppTheme.Colors.accent.opacity(0.12))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(AppTheme.Fonts.headline)
                    .foregroundColor(AppTheme.Colors.primary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(session.updatedAt.relativeDisplay)
                    Text("·")
                    Text(session.durationSeconds.mmss)
                    Text("·")
                    Text("\(session.clipCount) clip\(session.clipCount == 1 ? "" : "s")")
                }
                .font(AppTheme.Fonts.caption)
                .foregroundColor(AppTheme.Colors.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - SessionDetailView
struct SessionDetailView: View {
    let session: SessionModel
    @EnvironmentObject private var env: AppEnvironment
    @State private var clips: [ClipModel] = []
    @State private var markers: [MarkerModel] = []
    @State private var segments: [TranscriptSegmentModel] = []
    @State private var showEditor: Bool = false
    @State private var showCapture: Bool = false
    @State private var showExport: Bool = false
    @State private var showTimeline: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // Notes card
                if !session.notes.isEmpty {
                    Text(session.notes)
                        .font(AppTheme.Fonts.body)
                        .foregroundColor(AppTheme.Colors.secondary)
                        .cardStyle()
                }

                // Stats
                statsRow

                // Actions
                actionGrid

                // Clips
                if !clips.isEmpty {
                    clipSection
                }

                // Transcript preview
                if !segments.isEmpty {
                    transcriptPreview
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { showEditor = true }
                    .foregroundColor(AppTheme.Colors.accent)
            }
        }
        .sheet(isPresented: $showEditor) {
            SessionEditorView(session: session)
        }
        .sheet(isPresented: $showCapture) {
            CaptureView(session: session)
        }
        .sheet(isPresented: $showExport) {
            ExportSheetView(session: session, clips: clips)
        }
        .sheet(isPresented: $showTimeline) {
            TimelineView(session: session, clips: clips, markers: markers, segments: segments)
        }
        .task { await loadContent() }
    }

    private func loadContent() async {
        clips    = (try? await env.projectRepository.loadClips(for: session.id)) ?? []
        markers  = (try? await env.projectRepository.loadMarkers(for: session.id)) ?? []
        segments = await env.projectRepository.loadTranscript(for: session.id)
    }

    private var statsRow: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            StatBadge(icon: "clock", label: "Duration", value: session.durationSeconds.mmss)
            StatBadge(icon: "waveform", label: "Clips", value: "\(session.clipCount)")
            StatBadge(icon: "text.bubble", label: "Words", value: "\(segments.reduce(0) { $0 + $1.text.split(separator: " ").count })")
        }
    }

    private var actionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
            ActionButton(title: "Record", icon: "record.circle") { showCapture = true }
            ActionButton(title: "Timeline", icon: "timeline.selection") { showTimeline = true }
            ActionButton(title: "Export", icon: "square.and.arrow.up") { showExport = true }
            ActionButton(title: "Transcript", icon: "text.quote") { }
        }
    }

    private var clipSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Clips (\(clips.count))")
                .font(AppTheme.Fonts.headline)
                .foregroundColor(AppTheme.Colors.primary)
            ForEach(clips) { clip in
                HStack {
                    Image(systemName: "waveform").foregroundColor(AppTheme.Colors.accent)
                    Text("Clip \(clip.trackId + 1)").font(AppTheme.Fonts.body).foregroundColor(AppTheme.Colors.primary)
                    Spacer()
                    Text(clip.duration.mmss).font(AppTheme.Fonts.caption).foregroundColor(AppTheme.Colors.secondary)
                }
                .cardStyle()
            }
        }
    }

    private var transcriptPreview: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Transcript")
                .font(AppTheme.Fonts.headline)
                .foregroundColor(AppTheme.Colors.primary)
            Text(segments.prefix(5).map(\.text).joined(separator: " "))
                .font(AppTheme.Fonts.body)
                .foregroundColor(AppTheme.Colors.secondary)
                .lineLimit(4)
                .cardStyle()
        }
    }
}

private struct StatBadge: View {
    let icon: String; let label: String; let value: String
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(AppTheme.Colors.accent)
            Text(value).font(AppTheme.Fonts.headline).foregroundColor(AppTheme.Colors.primary)
            Text(label).font(AppTheme.Fonts.caption).foregroundColor(AppTheme.Colors.secondary)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

private struct ActionButton: View {
    let title: String; let icon: String; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title2).foregroundColor(AppTheme.Colors.accent)
                Text(title).font(AppTheme.Fonts.caption).foregroundColor(AppTheme.Colors.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(AppTheme.Spacing.md)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SessionEditorView
struct SessionEditorView: View {
    let session: SessionModel
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var notes: String
    @State private var tags: String
    @State private var mode: SessionMode
    @State private var isSaving: Bool = false

    init(session: SessionModel) {
        self.session = session
        _title = State(initialValue: session.title)
        _notes = State(initialValue: session.notes)
        _tags  = State(initialValue: session.tags.joined(separator: ", "))
        _mode  = State(initialValue: session.mode)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Info") {
                    TextField("Title", text: $title)
                    Picker("Mode", selection: $mode) {
                        ForEach(SessionMode.allCases) { m in Text(m.rawValue).tag(m) }
                    }
                }
                Section("Notes") {
                    TextEditor(text: $notes).frame(minHeight: 80)
                }
                Section("Tags (comma separated)") {
                    TextField("e.g. verse, chorus, idea", text: $tags)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        var updated = session
        updated.title = title.isEmpty ? Date().sessionTitle : title
        updated.notes = notes
        updated.tags  = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        updated.mode  = mode
        try? await env.projectRepository.updateSession(updated)
        dismiss()
    }
}
