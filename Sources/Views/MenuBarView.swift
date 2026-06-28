import SwiftUI

struct MenuBarView: View {
    @ObservedObject var prefs = PreferencesManager.shared
    @ObservedObject var stats = StatisticsManager.shared
    @ObservedObject var permissions = PermissionsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.title2)
                    .foregroundStyle(Color.brandGradient)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("ReTypeR")
                        .font(.headline)
                    Text("Активен (⌃⇧Space)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(permissions.isAccessibilityGranted ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // Warnings (if any)
            if !permissions.isAccessibilityGranted {
                Button(action: {
                    WindowManager.shared.showOnboarding()
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Предоставить доступ")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            // Layout info
            VStack(alignment: .leading, spacing: 4) {
                Text("Режим перевода:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(getLayoutName(id: prefs.primaryLayoutID))
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.left.and.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(getLayoutName(id: prefs.secondaryLayoutID))
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
            }
            
            Divider()
            
            // Stats quick view
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Конверсий")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(stats.totalConversions)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Символов")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(stats.totalCharactersConverted)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
            }
            
            Divider()
            
            // Action Buttons
            VStack(spacing: 6) {
                Button(action: {
                    WindowManager.shared.showSettings()
                }) {
                    HStack {
                        Image(systemName: "gearshape")
                        Text("Настройки...")
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(6)
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack {
                        Image(systemName: "power")
                        Text("Выйти")
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(6)
            }
        }
        .padding(16)
        .frame(width: 250)
        .background(.ultraThinMaterial)
    }
    
    private func getLayoutName(id: String) -> String {
        let layouts = LayoutMapper.shared.getInstalledLayouts()
        if let layout = layouts.first(where: { $0.id == id }) {
            return layout.localizedName
        }
        // Fallback to name extraction from bundle ID
        return id.components(separatedBy: ".").last ?? id
    }
}
