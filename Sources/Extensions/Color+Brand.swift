import SwiftUI

extension Color {
    // Exact colors from logo: #ff3131 (red) and #ff914d (orange)
    static let brandStart = Color(red: 255/255, green: 49/255, blue: 49/255) // #ff3131
    static let brandEnd = Color(red: 255/255, green: 145/255, blue: 77/255)  // #ff914d
    
    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [.brandStart, .brandEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var brandGradientHorizontal: LinearGradient {
        LinearGradient(
            colors: [.brandStart, .brandEnd],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
