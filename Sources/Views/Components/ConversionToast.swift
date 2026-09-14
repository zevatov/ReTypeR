import SwiftUI
import AppKit

/// Blurred material background used by toasts.
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.appearance = NSAppearance(named: .darkAqua)
    }
}

/// Toast showing the conversion result: original text on top, converted below.
/// Styled according to SingAR dark luxury aesthetic with ReTypeR red accent.
struct ConversionToast: View {
    let original: String
    let converted: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.brandAccent.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.brandAccent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(original)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                Text(converted)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(width: 320, height: 56)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.10).opacity(0.85))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Simple single-line informational toast with SingAR styling.
struct InfoToast: View {
    let message: String

    private var isSuccess: Bool {
        message.contains("Скопировано")
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isSuccess ? Color.brandGreen.opacity(0.18) : Color.brandAccent.opacity(0.18))
                    .frame(width: 30, height: 30)
                Image(systemName: isSuccess ? "checkmark" : "info")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isSuccess ? Color.brandGreen : Color.brandAccent)
            }

            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(width: 320, height: 56)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.10).opacity(0.85))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
