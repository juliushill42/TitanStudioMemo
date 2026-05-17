import SwiftUI

// MARK: - CaptureView
struct CaptureView: View {
    let session: SessionModel
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm: CaptureViewModel
    @Environment(\.dismiss) private var dismiss

    init(session: SessionModel) {
        self.session = session
        // ViewModel is constructed after env is available via onAppear injection
        _vm = StateObject(wrappedValue: CaptureViewModel(
            session: session,
            engine: AppEnvironment().audioEngine!,
            fileService: AppEnvironment().audioFileService!,
            repository: AppEnvironment().projectRepository!
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.lg) {
                sessionHeader
                LevelMeterView(level: vm.meterLevel)
                    .frame(height: 48)
                    .padding(.horizontal, AppTheme.Spacing.md)
                timerDisplay
                RecordButton(state: vm.recordingState) {
                    Task { await handleRecordTap() }
                }
                .padding(.vertical, AppTheme.Spacing.xl)
                clipList
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle(session.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        Task {
                            if vm.recordingState == .recording { await vm.stopRecording() }
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    InputPicker()
                }
            }
            .alert("Error", isPresented: .constant(vm.error != nil), presenting: vm.error) { _ in
                Button("OK") {}
            } message: { err in
                Text(err.localizedDescription)
            }
        }
        .task { await vm.loadClips() }
    }

    // MARK: - Header
    private var sessionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.mode.rawValue.uppercased())
                    .font(AppTheme.Fonts.caption)
                    .foregroundColor(AppTheme.Colors.accent)
                Text(session.title)
                    .font(AppTheme.Fonts.headline)
                    .foregroundColor(AppTheme.Colors.primary)
            }
            Spacer()
            Text("\(vm.clips.count) clips")
                .font(AppTheme.Fonts.caption)
                .foregroundColor(AppTheme.Colors.secondary)
        }
    }

    // MARK: - Timer
    private var timerDisplay: some View {
        Text(vm.elapsedTime.hhmmss)
            .font(.system(size: 56, weight: .thin, design: .monospaced))
            .foregroundColor(vm.recordingState == .recording ? AppTheme.Colors.accent : AppTheme.Colors.primary)
            .animation(.easeInOut(duration: 0.2), value: vm.recordingState)
            .contentTransition(.numericText())
    }

    // MARK: - Clip list
    private var clipList: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.Spacing.sm) {
                ForEach(vm.clips) { clip in
                    ClipRowView(clip: clip) {
                        Task { await vm.deleteClip(clip) }
                    }
                }
            }
        }
    }

    // MARK: - Record tap handler
    private func handleRecordTap() async {
        switch vm.recordingState {
        case .idle, .stopped:
            await vm.startRecording()
        case .recording:
            await vm.stopRecording()
        case .paused:
            vm.resumeRecording()
        }
    }
}

// MARK: - ClipRowView
private struct ClipRowView: View {
    let clip: ClipModel
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "waveform")
                .foregroundColor(AppTheme.Colors.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Clip \(clip.trackId + 1)")
                    .font(AppTheme.Fonts.headline)
                    .foregroundColor(AppTheme.Colors.primary)
                Text(clip.duration.mmss)
                    .font(AppTheme.Fonts.caption)
                    .foregroundColor(AppTheme.Colors.secondary)
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(AppTheme.Colors.destructive)
            }
        }
        .cardStyle()
    }
}

// MARK: - RecordButton
struct RecordButton: View {
    let state: CaptureViewModel.RecordingState
    let action: () -> Void

    @State private var isPulsing: Bool = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(AppTheme.Colors.accent.opacity(0.3), lineWidth: 4)
                    .frame(width: 96, height: 96)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
                    .animation(state == .recording ? .easeOut(duration: 0.8).repeatForever(autoreverses: false) : .default,
                               value: isPulsing)

                Circle()
                    .fill(state == .recording ? AppTheme.Colors.accent : AppTheme.Colors.surface)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Group {
                            switch state {
                            case .idle, .stopped:
                                Circle().fill(AppTheme.Colors.accent).frame(width: 32, height: 32)
                            case .recording:
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.white)
                                    .frame(width: 28, height: 28)
                            case .paused:
                                Image(systemName: "play.fill")
                                    .foregroundColor(AppTheme.Colors.accent)
                                    .font(.title2)
                            }
                        }
                    )
            }
        }
        .buttonStyle(.plain)
        .onChange(of: state) { _, new in
            isPulsing = new == .recording
        }
        .onAppear { isPulsing = state == .recording }
    }
}

// MARK: - LevelMeterView
struct LevelMeterView: View {
    let level: Float  // dBFS, -160...0

    private var normalizedLevel: CGFloat {
        let clamped = max(-60, min(0, Double(level)))
        return CGFloat((clamped + 60) / 60)
    }

    private var meterColor: Color {
        if normalizedLevel > 0.85 { return .red }
        if normalizedLevel > 0.65 { return .yellow }
        return AppTheme.Colors.accent
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppTheme.Colors.surface)
                RoundedRectangle(cornerRadius: 4)
                    .fill(meterColor)
                    .frame(width: geo.size.width * normalizedLevel)
                    .animation(.linear(duration: 0.05), value: normalizedLevel)
            }
        }
    }
}

// MARK: - InputPicker
struct InputPicker: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var showPicker: Bool = false

    var body: some View {
        Button {
            showPicker.toggle()
        } label: {
            Image(systemName: "mic.badge.ellipsis")
                .foregroundColor(AppTheme.Colors.accent)
        }
        .confirmationDialog("Select Input", isPresented: $showPicker, titleVisibility: .visible) {
            ForEach(env.audioRouter.availableSources, id: \.uid) { source in
                Button(source.portName) {
                    try? env.audioRouter.select(source: source)
                }
            }
            Button("Default") { try? env.audioRouter.selectDefault() }
            Button("Cancel", role: .cancel) {}
        }
    }
}
