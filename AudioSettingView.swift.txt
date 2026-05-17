import SwiftUI
import AVFoundation

struct AudioSettingsView: View {
    @State private var selectedSampleRate = "44.1 kHz"
    @State private var hardwareLatency = "0.0 ms"
    @State private var activeInputName = "Built-in Microphone"
    
    var body: some View {
        List {
            Section(header: Text("CURRENT HARDWARE TARGET DETAILS")) {
                HStack {
                    Text("Input Source")
                    Spacer()
                    Text(activeInputName)
                        .foregroundColor(AppTheme.Color.textSecondary)
                }
                
                HStack {
                    Text("Hardware Direct Latency")
                    Spacer()
                    Text(hardwareLatency)
                        .foregroundColor(AppTheme.Color.textSecondary)
                }
            }
            
            Section(header: Text("DSP SAMPLING RATE PREFERENCE")) {
                Picker("Sample Rate Configuration", selection: $selectedSampleRate) {
                    Text("44.1 kHz (Production Audio)").tag("44.1 kHz")
                    Text("48.0 kHz (Video Sync Broadcast)").tag("48.0 kHz")
                }
                .pickerStyle(.inline)
                .onChange(of: selectedSampleRate) { _, newValue in
                    Logger.shared.info("DSP Sampling Rate updated down inside kernel matrix hook: \(newValue)")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Hardware Engine Settings")
        .onAppear(perform: queryActiveHardwareRouteData)
    }
    
    private func queryActiveHardwareRouteData() {
        let session = AVAudioSession.sharedInstance()
        activeInputName = session.currentRoute.inputs.first?.portName ?? "No physical capture unit mounted"
        hardwareLatency = String(format: "%.1f ms", session.inputLatency * 1000)
    }
}