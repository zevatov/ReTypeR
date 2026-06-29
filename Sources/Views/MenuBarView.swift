import SwiftUI

struct MenuBarView: View {
    @ObservedObject var prefs = PreferencesManager.shared
    @ObservedObject var stats = StatisticsManager.shared
    @ObservedObject var permissions = PermissionsManager.shared
    
    @State private var isHistoryExpanded = false
    @State private var installedLayouts: [KeyboardLayoutInfo] = []
    
    var popoverHeight: CGFloat {
        var h: CGFloat = 175 // Base height with margins (prevents squishing)
        if prefs.isAppEnabled && !permissions.isAccessibilityGranted {
            h += 42
        }
        if isHistoryExpanded {
            h += 120
        }
        return h
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                KeyboardStatusIcon(statusColor: statusColor)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("ReTypeR")
                        .font(.headline)
                    
                    HStack(spacing: 4) {
                        Text(prefs.isAppEnabled ? "Активен" : "Приостановлено")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if prefs.isAppEnabled {
                            Button(action: {
                                WindowManager.shared.showSettings()
                            }) {
                                Text("⌃⇧Space")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .help("Настройки горячих клавиш")
                        }
                    }
                }
                
                Spacer()
                
                // Toggle Switch in the Header
                Toggle("", isOn: $prefs.isAppEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
            }
            
            Divider()
            
            // Warnings (Accessibility access)
            if prefs.isAppEnabled && !permissions.isAccessibilityGranted {
                Button(action: {
                    WindowManager.shared.showOnboarding()
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("Предоставить доступ")
                            .font(.caption)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            // Layout Info & Selector (Quick switch)
            HStack {
                Text("Режим:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 2) {
                    Menu {
                        ForEach(installedLayouts, id: \.id) { layout in
                            Button(layout.localizedName) {
                                prefs.primaryLayoutID = layout.id
                                prefs.updateMapping()
                            }
                        }
                    } label: {
                        Text(getLayoutName(id: prefs.primaryLayoutID))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor) // Matches system accent color
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    
                    Image(systemName: "arrow.left.and.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Menu {
                        ForEach(installedLayouts, id: \.id) { layout in
                            Button(layout.localizedName) {
                                prefs.secondaryLayoutID = layout.id
                                prefs.updateMapping()
                            }
                        }
                    } label: {
                        Text(getLayoutName(id: prefs.secondaryLayoutID))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor) // Matches system accent color
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            
            Divider()
            
            // Stats & History Row
            HStack(spacing: 8) {
                // Conversions
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(stats.totalConversions)")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .help("Конвертации")
                
                Spacer()
                
                // Characters
                HStack(spacing: 4) {
                    Image(systemName: "character")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(stats.totalCharactersConverted)")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .help("Символы")
                
                Spacer()
                
                // History Expand Button
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        isHistoryExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10))
                        Text("История")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(isHistoryExpanded ? .accentColor : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(isHistoryExpanded ? 0.08 : 0.03))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            
            // Expanded History List
            if isHistoryExpanded {
                VStack(spacing: 0) {
                    if !prefs.isHistoryEnabled {
                        Text("История отключена")
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
                            VStack(spacing: 5) {
                                ForEach(stats.history.prefix(15)) { record in
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(record.original)
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                        Text(record.converted)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                    }
                                    .padding(.vertical, 3)
                                    .padding(.horizontal, 5)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.primary.opacity(0.02))
                                    .cornerRadius(4)
                                }
                            }
                        }
                        .frame(maxHeight: 100)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Divider()
            
            // Action Buttons
            HStack(spacing: 6) {
                Button(action: {
                    WindowManager.shared.showSettings()
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "gearshape")
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.vertical, 6)
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
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .background(Color.red)
                .cornerRadius(6)
            }
        }
        .padding(12)
        .frame(width: 250, height: popoverHeight)
        .background(.ultraThinMaterial)
        .onAppear {
            LayoutMapper.shared.refreshAvailableLayouts()
            self.installedLayouts = LayoutMapper.shared.getInstalledLayouts()
            
            // Let the popover know its initial content size
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                appDelegate.popover.contentSize = NSSize(width: 250, height: popoverHeight)
            }
        }
        .onChange(of: popoverHeight) { _, newHeight in
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                appDelegate.popover.contentSize = NSSize(width: 250, height: newHeight)
            }
        }
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

struct KeyboardStatusIcon: View {
    let statusColor: Color
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: "keyboard")
                .font(.title3)
                .foregroundColor(.white) // Force to white matching menu bar
            
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .overlay(
                    Circle()
                        .stroke(Color(NSColor.windowBackgroundColor), lineWidth: 1)
                )
                .offset(x: 2, y: 2)
        }
        .frame(width: 20, height: 16)
    }
}
