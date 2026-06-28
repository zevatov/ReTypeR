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
                    Text(prefs.isAppEnabled ? "Активен (⌃⇧Space)" : "Приостановлено")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            .padding(.bottom, 2)
            
            Divider()
            
            // Warnings (if any)
            if prefs.isAppEnabled && !permissions.isAccessibilityGranted {
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
            
            // Toggle for Enabler/Disabler
            Toggle(isOn: $prefs.isAppEnabled) {
                Text(prefs.isAppEnabled ? "Работает" : "Приостановлено")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .toggleStyle(.switch)
            
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
            
            // History Section
            VStack(alignment: .leading, spacing: 6) {
                Text("История конвертаций:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !prefs.isHistoryEnabled {
                    Text("История отключена в настройках")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else if stats.history.isEmpty {
                    Text("История пуста")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(stats.history) { record in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(record.original)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    Text(record.converted)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.03))
                                .cornerRadius(4)
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
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
            
            // Redesigned Action Buttons (HStack)
            HStack(spacing: 8) {
                Button(action: {
                    WindowManager.shared.showSettings()
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "gearshape")
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(6)
                
                Button(action: {
                    (NSApplication.shared.delegate as? AppDelegate)?.confirmExit()
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "power")
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .background(Color.red)
                .cornerRadius(6)
            }
        }
        .padding(16)
        .frame(width: 250, height: 420)
        .background(.ultraThinMaterial)
    }
    
    private var statusColor: Color {
        if !prefs.isAppEnabled { return .red }
        return permissions.isAccessibilityGranted ? .green : .orange
    }
    
    private func getLayoutName(id: String) -> String {
        let layouts = LayoutMapper.shared.getInstalledLayouts()
        if let layout = layouts.first(where: { $0.id == id }) {
            return layout.localizedName
        }
        return id.components(separatedBy: ".").last ?? id
    }
}
