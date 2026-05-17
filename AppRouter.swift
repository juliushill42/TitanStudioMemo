import SwiftUI

struct AppRouter: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var selectedTab: Tab = .home

    enum Tab: Hashable {
        case home, sessions, stemLab, settings
    }

    var body: some View {
        Group {
            if env.isBootstrapping {
                SplashView()
            } else if !env.permissionsGranted {
                PermissionsGateView()
            } else {
                mainTabView
            }
        }
        .animation(.easeInOut(duration: 0.3), value: env.isBootstrapping)
        .animation(.easeInOut(duration: 0.3), value: env.permissionsGranted)
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "waveform") }
                .tag(Tab.home)

            SessionListView()
                .tabItem { Label("Sessions", systemImage: "list.bullet.rectangle") }
                .tag(Tab.sessions)

            StemImportView()
                .tabItem { Label("Stem Lab", systemImage: "tuningfork") }
                .tag(Tab.stemLab)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(Tab.settings)
        }
        .accentColor(AppTheme.Colors.accent)
    }
}

// MARK: - Splash
private struct SplashView: View {
    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(AppTheme.Colors.accent)
                Text("StudioMemo")
                    .font(AppTheme.Fonts.display)
                    .foregroundColor(AppTheme.Colors.primary)
                ProgressView()
                    .tint(AppTheme.Colors.accent)
            }
        }
    }
}
