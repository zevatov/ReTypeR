import SwiftUI

struct ConversionToast: View {
    let original: String
    let converted: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Left Status Icon/Badge - Glassy Rounded Rectangle matching system accent
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
            
            // Text Details
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Конвертация")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.accentColor)
                    
                    Spacer()
                    
                    Text("ReTypeR")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                
                HStack(spacing: 5) {
                    Text(truncateText(original, limit: 16))
                        .font(.system(size: 12, weight: .regular))
                        .strikethrough()
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color.accentColor.opacity(0.7))
                    
                    Text(truncateText(converted, limit: 16))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 320, height: 56)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow).cornerRadius(12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
    }
    
    private func truncateText(_ text: String, limit: Int) -> String {
        if text.count > limit {
            return String(text.prefix(limit)) + "..."
        }
        return text
    }
}

// SwiftUI NSVisualEffectView helper for macOS
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
