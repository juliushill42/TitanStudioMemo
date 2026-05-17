import SwiftUI
import AVFoundation

struct StemPlayerView: View {
    @ObservedObject var viewModel: StemViewModel
    let job: StemJobModel
    
    @State private var stemVolumes: [String: Float] = [:]
    @State private var isPlaying = false
    @State private var playbackProgress: Double = 0.0
    
    var body: some View {
        VStack(spacing: 24) {
            // Master Transport Monitor
            VStack(spacing: 12) {
                Text(job.sourceURL.lastPathComponent)
                    .font(.headline)
                    .foregroundColor(AppTheme.Color.textPrimary)
                    .lineLimit(1)
                
                Slider(value: $playbackProgress, in: 0...1) { editing in
                    if !editing { viewModel.seekPlayback(to: playbackProgress) }
                }
                .tint(AppTheme.Color.accent)
                
                HStack(spacing: 32) {
                    Button(action: { viewModel.skipPlayback(by: -10) }) {
                        Image(systemName: "gobackward.10")
                            .font(.title2)
                            .foregroundColor(AppTheme.Color.textPrimary)
                    }
                    
                    Button(action: {
                        isPlaying.toggle()
                        if isPlaying { viewModel.startStemPlayback(for: job) } else { viewModel.pauseStemPlayback() }
                    }) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(AppTheme.Color.accent)
                    }
                    
                    Button(action: { viewModel.skipPlayback(by: 10) }) {
                        Image(systemName: "goforward.10")
                            .font(.title2)
                            .foregroundColor(AppTheme.Color.textPrimary)
                    }
                }
            }
            .padding()
            .background(AppTheme.Color.surface)
            .cornerRadius(AppTheme.Layout.cornerRadius)
            
            // Console Mixing Rails
            VStack(alignment: .leading, spacing: 16) {
                Text("STEM CONSOLE")
                    .font(.caption)
                    .bold()
                    .foregroundColor(AppTheme.Color.textSecondary)
                
                ForEach(job.outputURLs.keys.sorted(), id: \.self) { stemKey in
                    let currentVolume = Binding<Float>(
                        get: { stemVolumes[stemKey] ?? 1.0 },
                        set: { newValue in
                            stemVolumes[stemKey] = newValue
                            viewModel.setVolumeForStem(stemKey, volume: newValue)
                        }
                    )
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text(stemKey.uppercased())
                                .font(.caption)
                                .bold()
                                .foregroundColor(AppTheme.Color.textPrimary)
                            Spacer()
                            Text("\(Int(currentVolume.wrappedValue * 100))%")
                                .font(.caption2)
                                .foregroundColor(AppTheme.Color.textSecondary)
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: currentVolume.wrappedValue == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.caption)
                                .foregroundColor(AppTheme.Color.textSecondary)
                            
                            Slider(value: currentVolume, in: 0...1)
                                .tint(AppTheme.Color.accent)
                        }
                    }
                    .padding()
                    .background(AppTheme.Color.surfaceElevated)
                    .cornerRadius(8)
                }
            }
            
            Spacer()
        }
        .padding(AppTheme.Layout.paddingStandard)
        .background(AppTheme.Color.background.ignoresSafeArea())
        .navigationTitle("Stem Multi-Track Mixer")
        .onDisappear {
            viewModel.stopStemPlayback()
        }
    }
}