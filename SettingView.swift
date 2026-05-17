import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var environment: AppEnvironment
    
    var body: some View {
        Form {
            Section(header: Text("HARDWARE SETUP BRIDGE")) {
                NavigationLink(destination: AudioSettingsView()) {
                    HStack {
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(AppTheme.Color.accent)
                        Text("Audio Hardware Engine Configuration")
                    }
                }
            }
            
            Section(header: Text("SATELLITE ACCELERATION LAYER")) {
                NavigationLink(destination: PurchaseView()) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                        Text("Manage Pro Processing Packages")
                    }
                }
            }
            
            Section(header: Text("METADATA STORAGE & DIAGNOSTICS")) {
                HStack {
                    Text("Database Integrity")
                    Spacer()
                    Text("Sovereign Node Stable")
                        .foregroundColor(AppTheme.Color.success)
                        .bold()
                }
                
                Button(action: {
                    environment.initializeSubsystems()
                }) {
                    Text("Force Hardware Subsystem Sync")
                        .foregroundColor(AppTheme.Color.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .background(AppTheme.Color.background.ignoresSafeArea())
        .navigationTitle("System Architecture Control")
    }
}