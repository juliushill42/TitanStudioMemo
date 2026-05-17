import SwiftUI

struct StemJobView: View {
    @ObservedObject var viewModel: StemViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            List(viewModel.activeJobs) { job in
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(job.sourceURL.lastPathComponent)
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(AppTheme.Color.textPrimary)
                            .lineLimit(1)
                        
                        Text("Mode: \(job.mode) Stems")
                            .font(.caption)
                            .foregroundColor(AppTheme.Color.textSecondary)
                        
                        // Status Indicator Matrix
                        switch job.status {
                        case .queued:
                            Text("Queued in processing thread...")
                                .font(.caption2)
                                .foregroundColor(AppTheme.Color.textSecondary)
                        case .processing:
                            ProgressView(value: job.progress) {
                                Text("Separating tracks... \(Int(job.progress * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.Color.accent)
                            }
                            .progressViewStyle(.linear)
                            .tint(AppTheme.Color.accent)
                        case .completed:
                            Text("Execution Complete")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(AppTheme.Color.success)
                        case .failed:
                            Text("Job Collapsed")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(AppTheme.Color.error)
                        }
                    }
                    
                    Spacer()
                    
                    if job.status == .completed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.Color.success)
                    } else if job.status == .processing {
                        ProgressView()
                            .tint(AppTheme.Color.accent)
                    }
                }
                .padding(.vertical, 8)
                .listRowBackground(AppTheme.Color.surface)
            }
            .listStyle(.plain)
        }
        .background(AppTheme.Color.background.ignoresSafeArea())
        .navigationTitle("Active AI Pipelines")
    }
}