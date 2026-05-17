import SwiftUI
import UIKit

enum AppTheme {
    enum Colors {
        static let background    = Color("Background",     bundle: nil)
        static let surface       = Color("Surface",        bundle: nil)
        static let primary       = Color("PrimaryText",    bundle: nil)
        static let secondary     = Color("SecondaryText",  bundle: nil)
        static let accent        = Color("Accent",         bundle: nil)
        static let destructive   = Color("Destructive",    bundle: nil)
        static let waveformFill  = Color("WaveformFill",   bundle: nil)
        static let markerDefault = Color("MarkerDefault",  bundle: nil)

        // Fallback pure-Swift colors used before xcassets load
        static let accentFallback     = Color(red: 0.96, green: 0.42, blue: 0.21)
        static let backgroundFallback = Color(red: 0.07, green: 0.07, blue: 0.09)
    }

    enum Fonts {
        static let display    = Font.custom("Georgia-Bold", size: 28)
        static let title      = Font.custom("Georgia", size: 20)
        static let headline   = Font.system(size: 16, weight: .semibold, design: .rounded)
        static let body       = Font.system(size: 15, weight: .regular, design: .default)
        static let caption    = Font.system(size: 12, weight: .regular, design: .monospaced)
        static let mono       = Font.system(size: 13, weight: .medium, design: .monospaced)
    }

    enum Spacing {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 24
        static let xl: CGFloat  = 40
        static let xxl: CGFloat = 64
    }

    enum Radius {
        static let sm: CGFloat  = 6
        static let md: CGFloat  = 12
        static let lg: CGFloat  = 20
        static let pill: CGFloat = 999
    }

    enum Animation {
        static let standard  = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let spring    = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.7)
        static let fast      = SwiftUI.Animation.easeOut(duration: 0.15)
    }

    /// One-time UIKit global appearance config
    static func apply() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "Background") ?? .black
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(named: "Background") ?? .black
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(named: "PrimaryText") ?? .white,
            .font: UIFont(name: "Georgia-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }
}

// MARK: - View Modifiers
extension View {
    func cardStyle() -> some View {
        self
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.Radius.md)
    }

    func accentBorder() -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                .stroke(AppTheme.Colors.accent, lineWidth: 1.5)
        )
    }
}
