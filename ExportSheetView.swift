import SwiftUI

struct ExportSheetView: View {
    @Environment(\.dismiss) var dismiss
    let sessionId: UUID
    @ObservedObject var exportService: ExportService
    
    @State private var selectedFormat: ExportFormat = .wav
    @State private var includeBounces = true
    @State private var isExporting = false
    @State private var shareSheetItem: URL? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("EXPORT FORMAT")
                        .font(.caption)
                        .bold()
                        .foregroundColor(AppTheme.Color.textSecondary)
                    
                    Picker("Format", selection: $selectedFormat) {
                        Text("WAV (Uncompressed)").tag(ExportFormat.wav)
                        Text("M4A (Compressed)").tag(ExportFormat.m4a)
                    }
                    .pickerStyle(.segmented)
                }
                
                Toggle(isOn: $includeBounces) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Consolidate Track Matrix")
                            .font(.body)
                            .foregroundColor(AppTheme.Color.textPrimary)
                        Text("Bounces all layered clips down into a single coherent audio file.")
                            .font(.caption)
                            .foregroundColor(AppTheme.Color.textSecondary)
                    }
                }
                .tint(AppTheme.Color.accent)
                .padding()
                .background(AppTheme.Color.surface)
                .cornerRadius(8)
                
                Spacer()
                
                if isExporting {
                    ProgressView("Bouncing and rendering master file...")
                        .tint(AppTheme.Color.accent)
                        .foregroundColor(AppTheme.Color.textPrimary)
                } else {
                    Button(action: triggerExportAssembly) {
                        Text("Compile and Export Asset")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(AppTheme.Color.accent)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(AppTheme.Layout.paddingStandard)
            .background(AppTheme.Color.background.ignoresSafeArea())
            .navigationTitle("Export Pipeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $shareSheetItem) { url in
                ActivityViewController(activityItems: [url])
            }
        }
    }
    
    private func triggerExportAssembly() {
        isExporting = true
        exportService.compileProjectAsset(sessionId: sessionId, format: selectedFormat, flatten: includeBounces) { result in
            DispatchQueue.main.async {
                isExporting = false
                switch result {
                case .success(let exportURL):
                    self.shareSheetItem = exportURL
                case .failure(let error):
                    Logger.shared.error("Export thread collapse: \(error.localizedDescription)")
                }
            }
        }
    }
}

// Deep structural mapping system for UIActivityViewController wrapper
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}