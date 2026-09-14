import SwiftUI

/// Brand palette for ReTypeR:
/// Signature fiery red gradient (matching the app icon/avatar) paired with
/// SingAR dark luxury carbon graphite neutrals and semantic status accents.
extension Color {
    // MARK: - ReTypeR Signature Red Palette (from Avatar)
    
    /// Crimson red start for avatar gradient
    static let brandRedStart = Color(red: 1.0, green: 0.20, blue: 0.18)
    /// Coral-red end for avatar gradient
    static let brandRedEnd = Color(red: 1.0, green: 0.46, blue: 0.28)
    /// Primary vibrant red accent for buttons, icons, badges, borders
    static let brandAccent = Color(red: 1.0, green: 0.28, blue: 0.22)
    /// Secondary warm violet accent
    static let brandViolet = Color(red: 0.72, green: 0.32, blue: 0.95)
    
    // MARK: - SingAR Dark Luxury Neutrals
    
    /// Background gradient start: carbon obsidian
    static let brandStart = Color(red: 0.07, green: 0.07, blue: 0.09)
    /// Background gradient end: deep graphite
    static let brandEnd = Color(red: 0.14, green: 0.14, blue: 0.18)
    
    /// Subtle card backgrounds
    static let brandCard = Color.primary.opacity(0.04)
    static let brandCardHover = Color.primary.opacity(0.08)
    static let brandBorder = Color.primary.opacity(0.08)
    
    // MARK: - Semantic Status Accents
    
    /// Emerald green (ready / active / copied feedback)
    static let brandGreen = Color(red: 0.20, green: 0.85, blue: 0.50)
    /// Amber (warning / missing permissions)
    static let brandAmber = Color(red: 1.0, green: 0.68, blue: 0.20)
}

extension LinearGradient {
    /// ReTypeR signature fiery red gradient (from the app icon)
    static let brandRed = LinearGradient(
        colors: [.brandRedStart, .brandRedEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

