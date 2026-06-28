import SwiftUI

struct OnboardingView: View {
    @ObservedObject var permissions = PermissionsManager.shared
    @State private var checkTimer: Timer? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon / Logo Area
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.brandStart.opacity(0.15), Color.brandEnd.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "keyboard.badge.ellipsis")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .foregroundStyle(Color.brandGradient)
            }
            .padding(.top, 10)
            
            Text("Требуется Универсальный доступ")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("ReTypeR необходим доступ к функциям Универсального доступа (Accessibility) для считывания и автоматического перевода выделенного вами текста.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            if permissions.isAccessibilityGranted {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Доступ успешно предоставлен!")
                        .fontWeight(.semibold)
                }
                .padding(.bottom, 20)
            } else {
                Button(action: {
                    permissions.requestAccessibility()
                }) {
                    Text("Открыть Системные настройки")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.brandGradientHorizontal)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .shadow(color: Color.brandStart.opacity(0.3), radius: 5, x: 0, y: 2)
                .padding(.bottom, 20)
            }
        }
        .padding(24)
        .frame(width: 420, height: 320)
        .onAppear {
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }
    
    private func startPolling() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            PermissionsManager.shared.checkAccessibility()
            if PermissionsManager.shared.isAccessibilityGranted {
                // If granted, auto close window in main thread
                DispatchQueue.main.async {
                    WindowManager.shared.closeOnboarding()
                }
            }
        }
    }
    
    private func stopPolling() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
}
