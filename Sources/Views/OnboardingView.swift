import SwiftUI
import AppKit

/// First-run onboarding: guides the user through granting Accessibility
/// permission.
/// Styled according to SingAR design language with ReTypeR red brand accents.
struct OnboardingView: View {
    @ObservedObject private var permissions = PermissionsManager.shared

    var body: some View {
        VStack(spacing: 20) {
            // Header: 50x50 Brand Icon + Title + Subtitle
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(LinearGradient.brandRed)
                        .frame(width: 50, height: 50)
                        .shadow(color: Color.brandAccent.opacity(0.35), radius: 8, x: 0, y: 4)

                    Image(systemName: "keyboard")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("Добро пожаловать в ReTypeR")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("Для работы умной смены раскладки требуется системное разрешение:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Permissions Card (SingAR style)
            VStack(spacing: 12) {
                permissionItem(
                    title: "Универсальный доступ",
                    subtitle: "Для чтения и автоматической замены выделенного текста",
                    icon: "accessibility",
                    isGranted: permissions.isAccessibilityGranted,
                    isRequired: true,
                    onRequest: {
                        permissions.requestAccessibility()
                    },
                    onOpenSettings: {
                        permissions.openAccessibilitySettings()
                    }
                )
            }
            .padding(14)
            .background(Color.brandCard)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.brandBorder, lineWidth: 1)
            )

            // Status message
            if permissions.isAccessibilityGranted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.brandGreen)
                    Text("Основное разрешение выдано! Вы готовы к работе.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.brandGreen)
                }
                .transition(.opacity)
            } else {
                Text("После выдачи разрешения нажмите «Проверить снова».")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Footer Action Buttons
            HStack(spacing: 12) {
                if !permissions.isAccessibilityGranted {
                    Button("Проверить снова") {
                        permissions.checkAccessibility()
                    }
                    .buttonStyle(.bordered)
                }

                Button(action: {
                    WindowManager.shared.closeOnboarding()
                }) {
                    Text(permissions.isAccessibilityGranted ? "Начать использование" : "Закрыть")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandAccent)
                .controlSize(.large)
            }
        }
        .padding(20)
        .frame(width: 440, height: 280)
        .onAppear {
            permissions.checkAccessibility()
        }
    }

    private func permissionItem(
        title: String,
        subtitle: String,
        icon: String,
        isGranted: Bool,
        isRequired: Bool,
        onRequest: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isGranted ? Color.brandGreen.opacity(0.15) : (isRequired ? Color.brandAmber.opacity(0.15) : Color.primary.opacity(0.06)))
                    .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isGranted ? Color.brandGreen : (isRequired ? Color.brandAmber : Color.secondary))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                    if isRequired {
                        Text("Обязательно")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color.brandAmber)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.brandAmber.opacity(0.12))
                            .cornerRadius(4)
                    } else {
                        Text("Опционально")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if isGranted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.brandGreen)
                    Text("Готово")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.brandGreen)
                }
            } else {
                Button("Разрешить") {
                    onRequest()
                }
                .buttonStyle(.borderedProminent)
                .tint(isRequired ? Color.brandAccent : Color.secondary)
                .controlSize(.small)
            }
        }
    }
}
