import SwiftUI

@main
struct StudioMemoApp: App {
    @StateObject private var env = AppEnvironment()

    init() {
        AppTheme.apply()
    }

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environmentObject(env)
                .onAppear {
                    Task { await env.bootstrap() }
                }
        }
    }
}
