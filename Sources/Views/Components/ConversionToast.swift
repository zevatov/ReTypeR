import SwiftUI

struct ConversionToast: View {
    let original: String
    let converted: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Left Status Icon/Badge
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.brandStart.opacity(0.2), Color.brandEnd.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 42, height: 42)
                
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.brandGradient)
            }
            
            // Text Details
            VStack(alignment: .leading, spacing: 4) {
                Text("Текст сконвертирован")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    Text(truncateText(original, limit: 15))
                        .font(.subheadline)
                        .strikethrough()
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.brandStart)
                    
                    Text(truncateText(converted, limit: 15))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 340, height: 80)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow).cornerRadius(16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LinearGradient(
                    colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 5)
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
