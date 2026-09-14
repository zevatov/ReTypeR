import SwiftUI
import AppKit
import KeyboardShortcuts

/// Compact popover shown from the menu-bar status item: enable toggle,
/// hotkey recorder, layout pickers and the recent history.
/// Styled according to SingAR design language with ReTypeR red brand accents.
struct MenuBarView: View {
    @ObservedObject private var prefs = PreferencesManager.shared
    @ObservedObject private var stats = StatisticsManager.shared
    @ObservedObject private var permissions = PermissionsManager.shared

    @State private var installedLayouts: [KeyboardLayoutInfo] = []
    @State private var isHistoryExpanded = false
    @State private var copiedIndex: Int?

    // Status Dot Color & Subtitle
    private var statusDotColor: Color {
        if !prefs.isAppEnabled {
            return Color.red
        } else if !permissions.isAccessibilityGranted {
            return Color.brandAmber
        } else {
            return Color.brandGreen
        }
    }

    private var statusSubtitle: String {
        if !prefs.isAppEnabled {
            return "На паузе"
        } else if !permissions.isAccessibilityGranted {
            return "Требуются разрешения"
        } else {
            return "Работает"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header: Status glyph + App name + Play/Pause & Power buttons
            HStack(spacing: 10) {
                // Keyboard icon with status dot
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(prefs.isAppEnabled ? Color.brandAccent.opacity(0.15) : Color.secondary.opacity(0.1))
                            .frame(width: 32, height: 32)
                        Image(systemName: prefs.isAppEnabled ? "keyboard" : "keyboard.badge.ellipsis")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(prefs.isAppEnabled ? Color.brandAccent : Color.secondary)
                    }

                    // Always-visible status dot
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 9, height: 9)
                        .overlay(
                            Circle()
                                .stroke(Color(red: 0.12, green: 0.12, blue: 0.15), lineWidth: 1.5)
                        )
                        .offset(x: 1, y: 1)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("ReTypeR")
                            .font(.system(size: 14, weight: .bold))
                        Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3.1")")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Text(statusSubtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Top-Right Control Buttons (Play/Pause + Power)
                HStack(spacing: 6) {
                    // Play / Pause Button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            prefs.isAppEnabled.toggle()
                        }
                    } label: {
                        Image(systemName: prefs.isAppEnabled ? "pause.fill" : "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(prefs.isAppEnabled ? Color.secondary : Color.brandGreen)
                            .frame(width: 26, height: 26)
                            .background(prefs.isAppEnabled ? Color.brandCard : Color.brandGreen.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(prefs.isAppEnabled ? "Поставить на паузу (не реагировать на хоткей)" : "Возобновить работу")

                    // Power / Quit Button
                    Button {
                        NSApp.terminate(nil)
                    } label: {
                        Image(systemName: "power")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.secondary)
                            .frame(width: 26, height: 26)
                            .background(Color.brandCard)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Выйти из ReTypeR")
                }
            }

            Divider()

            // Interactive Hotkeys & Layouts Configuration
            VStack(spacing: 8) {
                // Hotkey row
                HStack {
                    Label("Хоткей", systemImage: "keyboard")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .convertText)
                }
                .fixedSize(horizontal: false, vertical: true)

                Divider()

                // Layout Switcher A ↔ B
                HStack {
                    Label("Раскладки", systemImage: "globe")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()

                    Menu {
                        ForEach(installedLayouts) { layout in
                            Button(layout.localizedName) {
                                prefs.primaryLayoutID = layout.id
                                prefs.updateMapping()
                            }
                        }
                    } label: {
                        Text(layoutShortName(prefs.primaryLayoutID))
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(5)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 10))
                        .foregroundColor(prefs.primaryLayoutID == prefs.secondaryLayoutID ? .orange : .secondary)

                    Menu {
                        ForEach(installedLayouts) { layout in
                            Button(layout.localizedName) {
                                prefs.secondaryLayoutID = layout.id
                                prefs.updateMapping()
                            }
                        }
                    } label: {
                        Text(layoutShortName(prefs.secondaryLayoutID))
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(5)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            .padding(10)
            .background(Color.brandCard)
            .cornerRadius(8)

            // Collapsible History View
            if isHistoryExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Недавние записи")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Нажмите для копирования")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.7))
                    }

                    let entries = Array(stats.history.prefix(8))
                    if entries.isEmpty {
                        Text("История пуста")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    } else {
                        ScrollView {
                            VStack(spacing: 5) {
                                ForEach(Array(entries.enumerated()), id: \.element.id) { index, record in
                                    Button {
                                        copyToClipboard(record.converted, at: index)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack {
                                                Text(formatTime(record.timestamp))
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                                if copiedIndex == index {
                                                    Text("Скопировано!")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(Color.brandGreen)
                                                } else {
                                                    Text(record.original)
                                                        .font(.system(size: 9))
                                                        .foregroundColor(.secondary.opacity(0.6))
                                                        .lineLimit(1)
                                                }
                                            }

                                            Text(record.converted)
                                                .font(.system(size: 11))
                                                .foregroundColor(.primary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                        }
                                        .padding(6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(copiedIndex == index ? Color.brandGreen.opacity(0.12) : Color.brandCard)
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .frame(minHeight: 90, maxHeight: 170)
                    }
                }
                .transition(.opacity)
            }

            Divider()

            // Footer action buttons (2 buttons 50/50 width)
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isHistoryExpanded.toggle()
                    }
                } label: {
                    Label(isHistoryExpanded ? "Скрыть" : "История", systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(6)
                .background(Color.primary.opacity(isHistoryExpanded ? 0.08 : 0.04))
                .cornerRadius(6)

                Button {
                    DispatchQueue.main.async {
                        NSApp.sendAction(#selector(NSPopover.performClose(_:)), to: nil, from: nil)
                        WindowManager.shared.showSettings()
                    }
                } label: {
                    Label("Настройки", systemImage: "gearshape")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(6)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(6)
            }
        }
        .padding(14)
        .frame(width: 290)
        .onAppear {
            LayoutMapper.shared.refreshAvailableLayouts()
            installedLayouts = LayoutMapper.shared.getInstalledLayouts()
            permissions.checkAccessibility()
        }
    }

    // MARK: - Helpers

    private func copyToClipboard(_ text: String, at index: Int) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation {
            copiedIndex = index
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedIndex == index {
                withAnimation {
                    copiedIndex = nil
                }
            }
        }
    }

    private func layoutShortName(_ id: String) -> String {
        let fullName = installedLayouts.first(where: { $0.id == id })?.localizedName ?? "…"
        if fullName.contains("Russian") || fullName.contains("Русская") { return "Русская" }
        if fullName.contains("U.S.") || fullName.contains("English") || fullName.contains("США") { return "English" }
        return fullName
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
