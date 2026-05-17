import SwiftUI

// MARK: - ViewModel
@MainActor
final class HomeViewModel: ObservableObject {
    @Published var recentSessions: [SessionModel] = []
    @Published var isCapturing: Bool = false
    @Published var error: AppError?

    private let repository: ProjectRepository

    init(repository: ProjectRepository) {
        self.repository = repository
    }

    func load() async {
        await repository.loadAllSessions()
        recentSessions = Array(repository.sessions.prefix(5))
    }

    func newSession(mode: SessionMode) async -> SessionModel? {
        do {
            let s = try await repository.createSession(mode: mode)
            recentSessions.insert(s, at: 0)
            if recentSessions.count > 5 { recentSessions.removeLast() }
            return s
        } catch {
            self.error = .unknown(error)
            return nil
        }
    }
}

// MARK: - View
struct HomeView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm: HomeViewModel = HomeViewModel(repository: AppEnvironment().projectRepository!)
    @State private var captureSession: SessionModel?
    @State private var showCapture: Bool = false
    @State private var showModeSheet: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    heroSection
                    if !vm.recentSessions.isEmpty { recentSection }
                    quickStartSection
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("StudioMemo")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SessionListView()) {
                        Image(systemName: "list.bullet")
                            .foregroundColor(AppTheme.Colors.accent)
                    }
                }
            }
            .sheet(isPresented: $showCapture) {
                if let session = captureSession {
                    CaptureView(session: session)
                }
            }
            .sheet(isPresented: $showModeSheet) {
                ModePickerSheet { mode in
                    showModeSheet = false
                    Task {
                        if let s = await vm.newSession(mode: mode) {
                            captureSession = s
                            showCapture = true
                        }
                    }
                }
            }
        }
        .task { await vm.load() }
        .environmentObject(vm)
    }

    // MARK: - Hero
    private var heroSection: some View {
        Button {
            showModeSheet = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("New Recording")
                        .font(AppTheme.Fonts.title)
                        .foregroundColor(.white)
                    Text("Tap to start capturing")
                        .font(AppTheme.Fonts.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: "record.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
            }
            .padding(AppTheme.Spacing.lg)
            .background(
                LinearGradient(
                    colors: [AppTheme.Colors.accent, AppTheme.Colors.accent.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(AppTheme.Radius.lg)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Recent")
                .font(AppTheme.Fonts.headline)
                .foregroundColor(AppTheme.Colors.primary)

            ForEach(vm.recentSessions) { session in
                NavigationLink(destination: SessionDetailView(session: session)) {
                    SessionRowView(session: session)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Quick start
    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Quick Start")
                .font(AppTheme.Fonts.headline)
                .foregroundColor(AppTheme.Colors.primary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                ForEach(SessionMode.allCases) { mode in
                    Button {
                        Task {
                            if let s = await vm.newSession(mode: mode) {
                                captureSession = s
                                showCapture = true
                            }
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: mode.systemImage)
                                .font(.title2)
                                .foregroundColor(AppTheme.Colors.accent)
                            Text(mode.rawValue)
                                .font(AppTheme.Fonts.caption)
                                .foregroundColor(AppTheme.Colors.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.Spacing.md)
                        .cardStyle()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Mode picker sheet
private struct ModePickerSheet: View {
    let onSelect: (SessionMode) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(SessionMode.allCases) { mode in
                Button {
                    onSelect(mode)
                } label: {
                    Label(mode.rawValue, systemImage: mode.systemImage)
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .navigationTitle("Choose Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
