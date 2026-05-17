import SwiftUI
import AVFoundation

// MARK: - TimelineView
struct TimelineView: View {
    let session: SessionModel
    let clips: [ClipModel]
    let markers: [MarkerModel]
    let segments: [TranscriptSegmentModel]

    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var playbackState = PlaybackState()
    @State private var zoom: CGFloat = 1.0
    @State private var scrollOffset: CGFloat = 0
    @State private var showMarkerSheet: Bool = false

    private var totalDuration: TimeInterval {
        clips.map(\.endTime).max() ?? 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Zoom control
                HStack {
                    Image(systemName: "minus.magnifyingglass")
                        .foregroundColor(AppTheme.Colors.secondary)
                    Slider(value: $zoom, in: 0.5...4.0)
                        .tint(AppTheme.Colors.accent)
                    Image(systemName: "plus.magnifyingglass")
                        .foregroundColor(AppTheme.Colors.secondary)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)

                // Timeline scroll area
                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        // Time ruler
                        TimeRulerView(duration: totalDuration, zoom: zoom)
                            .frame(height: 24)
                            .frame(width: timelineWidth)

                        // Clip tracks
                        VStack(spacing: 2) {
                            ForEach(clips) { clip in
                                ClipView(clip: clip, zoom: zoom, totalDuration: totalDuration)
                                    .frame(height: 56)
                            }
                        }
                        .offset(y: 24)

                        // Marker rail
                        MarkerView(markers: markers, zoom: zoom, totalDuration: totalDuration)
                            .offset(y: 24 + CGFloat(clips.count) * 58)
                            .frame(height: 24)

                        // Transcript rail
                        if !segments.isEmpty {
                            TranscriptRailView(segments: segments, zoom: zoom, totalDuration: totalDuration)
                                .offset(y: 24 + CGFloat(clips.count) * 58 + 28)
                                .frame(height: 32)
                        }

                        // Playhead
                        Rectangle()
                            .fill(AppTheme.Colors.accent)
                            .frame(width: 2)
                            .offset(x: playheadX)
                            .animation(.linear(duration: 0.05), value: playbackState.currentTime)
                    }
                    .frame(width: timelineWidth, height: timelineHeight)
                }
                .background(AppTheme.Colors.background)

                Divider()

                // Transport bar
                TransportBar(state: playbackState, totalDuration: totalDuration)
                    .padding(AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showMarkerSheet = true
                    } label: {
                        Image(systemName: "flag.badge.ellipsis").foregroundColor(AppTheme.Colors.accent)
                    }
                }
            }
            .sheet(isPresented: $showMarkerSheet) {
                AddMarkerSheet(session: session)
            }
        }
    }

    private var timelineWidth: CGFloat { max(UIScreen.main.bounds.width, CGFloat(totalDuration) * 100 * zoom) }
    private var timelineHeight: CGFloat { 24 + CGFloat(clips.count) * 58 + 60 }
    private var playheadX: CGFloat { CGFloat(playbackState.currentTime) * 100 * zoom }
}

// MARK: - PlaybackState
@MainActor
final class PlaybackState: ObservableObject {
    @Published var currentTime: TimeInterval = 0
    @Published var isPlaying: Bool = false
    @Published var isLooping: Bool = false
}

// MARK: - TimeRulerView
private struct TimeRulerView: View {
    let duration: TimeInterval
    let zoom: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let tickInterval: TimeInterval = zoom < 1 ? 10 : zoom < 2 ? 5 : 1
            var t = 0.0
            while t <= duration {
                let x = CGFloat(t) * 100 * zoom
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }, with: .color(AppTheme.Colors.secondary.opacity(0.4)), lineWidth: 1)

                let label = t.mmss
                ctx.draw(Text(label).font(.system(size: 9, design: .monospaced)).foregroundColor(AppTheme.Colors.secondary),
                         at: CGPoint(x: x + 2, y: size.height / 2))
                t += tickInterval
            }
        }
        .background(AppTheme.Colors.surface)
    }
}

// MARK: - ClipView
struct ClipView: View {
    let clip: ClipModel
    let zoom: CGFloat
    let totalDuration: TimeInterval

    @State private var waveform: [Float] = []

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(clip.isMuted ? AppTheme.Colors.secondary.opacity(0.2) : AppTheme.Colors.accent.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(AppTheme.Colors.accent.opacity(clip.isMuted ? 0.2 : 0.6), lineWidth: 1)
                )

            if !waveform.isEmpty {
                WaveformView(samples: waveform)
                    .foregroundColor(AppTheme.Colors.accent.opacity(0.7))
                    .padding(.horizontal, 4)
            }

            Text("Clip \(clip.trackId + 1)")
                .font(AppTheme.Fonts.caption)
                .foregroundColor(AppTheme.Colors.primary)
                .padding(.leading, 6)
        }
        .frame(width: clipWidth, height: 56)
        .offset(x: clipOffset)
    }

    private var clipWidth: CGFloat  { max(4, CGFloat(clip.duration) * 100 * zoom) }
    private var clipOffset: CGFloat { CGFloat(clip.startTime) * 100 * zoom }
}

// MARK: - WaveformView
struct WaveformView: View {
    let samples: [Float]
    var foregroundColor: Color = AppTheme.Colors.waveformFill

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                guard !samples.isEmpty else { return }
                let w = size.width / CGFloat(samples.count)
                for (i, sample) in samples.enumerated() {
                    let x = CGFloat(i) * w
                    let h = CGFloat(sample) * size.height
                    let y = (size.height - h) / 2
                    let rect = CGRect(x: x, y: y, width: max(1, w - 0.5), height: h)
                    ctx.fill(Path(rect), with: .color(foregroundColor))
                }
            }
        }
    }
}

// MARK: - MarkerView
struct MarkerView: View {
    let markers: [MarkerModel]
    let zoom: CGFloat
    let totalDuration: TimeInterval

    var body: some View {
        GeometryReader { geo in
            ForEach(markers) { marker in
                let x = CGFloat(marker.timestamp) * 100 * zoom
                VStack(spacing: 0) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 10))
                        .foregroundColor(markerColor(marker.color))
                    Text(marker.label)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.primary)
                        .lineLimit(1)
                }
                .offset(x: x - 8)
            }
        }
    }

    private func markerColor(_ c: MarkerModel.MarkerColor) -> Color {
        switch c {
        case .orange: return .orange
        case .red:    return .red
        case .green:  return .green
        case .blue:   return .blue
        case .purple: return .purple
        case .yellow: return .yellow
        }
    }
}

// MARK: - TranscriptRailView
struct TranscriptRailView: View {
    let segments: [TranscriptSegmentModel]
    let zoom: CGFloat
    let totalDuration: TimeInterval

    var body: some View {
        GeometryReader { _ in
            ForEach(segments) { seg in
                let x = CGFloat(seg.startTime) * 100 * zoom
                let w = max(20, CGFloat(seg.duration) * 100 * zoom)
                Text(seg.text)
                    .font(.system(size: 9))
                    .foregroundColor(AppTheme.Colors.secondary)
                    .lineLimit(1)
                    .frame(width: w, alignment: .leading)
                    .offset(x: x)
            }
        }
    }
}

// MARK: - TransportBar
private struct TransportBar: View {
    @ObservedObject var state: PlaybackState
    let totalDuration: TimeInterval

    var body: some View {
        VStack(spacing: 8) {
            Slider(value: Binding(
                get: { state.currentTime },
                set: { state.currentTime = $0 }
            ), in: 0...max(1, totalDuration))
            .tint(AppTheme.Colors.accent)

            HStack {
                Text(state.currentTime.mmss)
                    .font(AppTheme.Fonts.mono)
                    .foregroundColor(AppTheme.Colors.secondary)
                Spacer()
                Button {
                    state.currentTime = 0
                } label: {
                    Image(systemName: "backward.end.fill").foregroundColor(AppTheme.Colors.primary)
                }
                Button {
                    state.isPlaying.toggle()
                } label: {
                    Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.Colors.accent)
                }
                Button {
                    state.isLooping.toggle()
                } label: {
                    Image(systemName: "repeat")
                        .foregroundColor(state.isLooping ? AppTheme.Colors.accent : AppTheme.Colors.secondary)
                }
                Spacer()
                Text(totalDuration.mmss)
                    .font(AppTheme.Fonts.mono)
                    .foregroundColor(AppTheme.Colors.secondary)
            }
        }
    }
}

// MARK: - AddMarkerSheet
private struct AddMarkerSheet: View {
    let session: SessionModel
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var label: String = ""
    @State private var color: MarkerModel.MarkerColor = .orange
    @State private var timestamp: TimeInterval = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Label") {
                    TextField("e.g. Verse 1", text: $label)
                }
                Section("Color") {
                    Picker("Color", selection: $color) {
                        ForEach(MarkerModel.MarkerColor.allCases, id: \.self) { c in
                            Text(c.rawValue.capitalized).tag(c)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Timestamp (seconds)") {
                    TextField("0.0", value: $timestamp, format: .number)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Marker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            let marker = MarkerModel(
                                id: UUID(),
                                sessionId: session.id,
                                label: label.isEmpty ? "Marker" : label,
                                timestamp: timestamp,
                                color: color
                            )
                            try? await env.projectRepository.addMarker(marker)
                            dismiss()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
