import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject var prefs = PreferencesManager.shared
    @ObservedObject var launch = LaunchManager.shared
    @ObservedObject var stats = StatisticsManager.shared
    
    @State private var installedLayouts: [KeyboardLayoutInfo] = []
    @State private var isHistoryExpanded = false
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    // Header (About App with Logo)
                    HStack(spacing: 16) {
                        if let nsImage = NSImage(named: "AppIcon") ?? NSImage(contentsOfFile: Bundle.main.path(forResource: "AppIcon", ofType: "png") ?? "") {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 56, height: 56)
                                .cornerRadius(12)
                                .shadow(color: Color.accentColor.opacity(0.15), radius: 4, x: 0, y: 2)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.accentColor)
                                    .frame(width: 56, height: 56)
                                Image(systemName: "keyboard")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ReTypeR")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Версия \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.2")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Social Links
                        HStack(spacing: 12) {
                            Link(destination: URL(string: "https://t.me/your_telegram_channel")!) {
                                VStack(spacing: 4) {
                                    Image("telegram")
                                        .renderingMode(.template)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(Color(red: 38/255, green: 165/255, blue: 228/255))
                                    Text("Telegram")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Link(destination: URL(string: "https://github.com/your_github_repo")!) {
                                VStack(spacing: 4) {
                                    Image("github")
                                        .renderingMode(.template)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(.primary) // white in dark mode, black in light mode
                                    Text("GitHub")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                    
                    Divider()
                    
                    // Section 1: Hotkeys
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Горячие клавиши")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        
                        HStack {
                            Text("Сочетание для конвертации:")
                                .font(.body) // Unified font size
                            Spacer()
                            KeyboardShortcuts.Recorder(for: .convertText)
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.02))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )
                    }
                    
                    // Section 2: Layouts
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Раскладки клавиатуры")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Основная раскладка (A):")
                                    .font(.body) // Unified font size
                                Spacer()
                                Picker("", selection: $prefs.primaryLayoutID) {
                                    if installedLayouts.isEmpty {
                                        Text("Загрузка...").tag(prefs.primaryLayoutID)
                                    } else {
                                        ForEach(installedLayouts) { layout in
                                            Text(layout.localizedName).tag(layout.id)
                                        }
                                    }
                                }
                                .labelsHidden()
                                .fixedSize()
                            }
                            .onChange(of: prefs.primaryLayoutID) { _, _ in
                                prefs.updateMapping()
                            }
                            
                            HStack {
                                Text("Вторичная раскладка (B):")
                                    .font(.body) // Unified font size
                                Spacer()
                                Picker("", selection: $prefs.secondaryLayoutID) {
                                    if installedLayouts.isEmpty {
                                        Text("Загрузка...").tag(prefs.secondaryLayoutID)
                                    } else {
                                        ForEach(installedLayouts) { layout in
                                            Text(layout.localizedName).tag(layout.id)
                                        }
                                    }
                                }
                                .labelsHidden()
                                .fixedSize()
                            }
                            .onChange(of: prefs.secondaryLayoutID) { _, _ in
                                prefs.updateMapping()
                            }
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.02))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )
                    }
                    
                    // Section 3: System & Notifications
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Система и Уведомления")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Запуск при старте системы", isOn: Binding(
                                get: { launch.isLaunchAtLoginEnabled },
                                set: { launch.setLaunchAtLogin($0) }
                            ))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Умное распознавание раскладки", isOn: $prefs.isSmartRecognitionEnabled)
                                Text("Конвертирует только слова с опечатками раскладки, оставляя правильный текст без изменений.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 18)
                            }
                            
                            Toggle("Показывать уведомления (Toast)", isOn: $prefs.isToastEnabled)
                            
                            Toggle("Выделять весь текст (Cmd+A) перед конвертацией", isOn: $prefs.autoSelectAllText)
                            
                            Toggle("Переключать язык системы после конвертации", isOn: $prefs.switchLayoutAfterConversion)
                            
                            Toggle("Сохранять историю конвертаций", isOn: $prefs.isHistoryEnabled)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.02))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )
                    }
                    
                    // Section 4: Statistics & History
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Статистика и История")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            // 2x2 grid for stats and action buttons
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                                // Cell 1: Conversions
                                VStack(spacing: 4) {
                                    Image(systemName: "arrow.left.arrow.right.circle")
                                        .font(.title3)
                                        .foregroundColor(.accentColor)
                                    Text("Конвертации")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    Text("\(stats.totalConversions)")
                                        .font(.body)
                                        .fontWeight(.bold)
                                }
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(Color.primary.opacity(0.03))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.primary.opacity(0.02), lineWidth: 1)
                                )
                                
                                // Cell 2: Characters
                                VStack(spacing: 4) {
                                    Image(systemName: "character.textbox")
                                        .font(.title3)
                                        .foregroundColor(.accentColor)
                                    Text("Символы")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    Text("\(stats.totalCharactersConverted)")
                                        .font(.body)
                                        .fontWeight(.bold)
                                }
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(Color.primary.opacity(0.03))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.primary.opacity(0.02), lineWidth: 1)
                                )
                                
                                // Cell 3: History Toggle Button
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        isHistoryExpanded.toggle()
                                    }
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.title3)
                                            .foregroundColor(isHistoryExpanded ? .accentColor : .secondary)
                                        Text("История")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.center)
                                        Text(isHistoryExpanded ? "Скрыть" : "Показать")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .background(Color.primary.opacity(isHistoryExpanded ? 0.08 : 0.03))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isHistoryExpanded ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.02), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                // Cell 4: Reset Button
                                Button(action: {
                                    confirmReset()
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "trash")
                                            .font(.title3)
                                            .foregroundColor(.red)
                                        Text("Сбросить")
                                            .font(.body)
                                            .foregroundColor(.red)
                                            .multilineTextAlignment(.center)
                                        Text(" ") // Spacer to keep heights equal
                                            .font(.system(size: 9))
                                    }
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .background(Color.red.opacity(0.06))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.red.opacity(0.15), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(stats.totalConversions == 0 && stats.totalCharactersConverted == 0)
                            }
                            
                            if isHistoryExpanded {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("История последних запросов:")
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    
                                    if !prefs.isHistoryEnabled {
                                        Text("История отключена в настройках")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .italic()
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .padding(.vertical, 12)
                                    } else if stats.history.isEmpty {
                                        Text("История пуста")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .italic()
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .padding(.vertical, 12)
                                    } else {
                                        ScrollView {
                                            VStack(spacing: 6) {
                                                ForEach(stats.history) { record in
                                                    HStack {
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(record.original)
                                                                .font(.system(size: 10))
                                                                .foregroundColor(.secondary)
                                                                .lineLimit(1)
                                                            Text(record.converted)
                                                                .font(.system(size: 11, weight: .semibold))
                                                                .foregroundColor(.primary)
                                                                .lineLimit(1)
                                                        }
                                                        Spacer()
                                                        Text(formatTime(record.timestamp))
                                                            .font(.system(size: 8))
                                                            .foregroundColor(.secondary.opacity(0.6))
                                                    }
                                                    .padding(6)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .background(Color.primary.opacity(0.02))
                                                    .cornerRadius(6)
                                                }
                                            }
                                        }
                                        .frame(maxHeight: 150)
                                    }
                                }
                                .padding(.top, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.02))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )
                    }
                    
                    // Bottom Anchor for ScrollViewReader
                    Color.clear
                        .frame(height: 1)
                        .id("bottom_anchor")
                }
                .padding(16)
            }
            .frame(width: 440, height: 500)
            .onAppear {
                LayoutMapper.shared.refreshAvailableLayouts()
                self.installedLayouts = LayoutMapper.shared.getInstalledLayouts()
            }
            .onChange(of: isHistoryExpanded) { _, newValue in
                if newValue {
                    // Let SwiftUI rendering complete before scrolling
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("bottom_anchor", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    private func confirmReset() {
        let alert = NSAlert()
        alert.messageText = "Сброс статистики"
        alert.informativeText = "Вы действительно хотите очистить историю и статистику?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Сбросить")
        alert.addButton(withTitle: "Отмена")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            stats.reset()
            isHistoryExpanded = false
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
