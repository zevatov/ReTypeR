import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject var prefs = PreferencesManager.shared
    @ObservedObject var launch = LaunchManager.shared
    @ObservedObject var stats = StatisticsManager.shared
    
    @State private var installedLayouts: [KeyboardLayoutInfo] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header (About App with Logo)
                HStack(spacing: 16) {
                    // Logo Image Loader
                    if let nsImage = NSImage(named: "AppIcon") ?? NSImage(contentsOfFile: Bundle.main.path(forResource: "AppIcon", ofType: "png") ?? "") {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .cornerRadius(12)
                            .shadow(color: Color.brandEnd.opacity(0.2), radius: 6, x: 0, y: 3)
                    } else {
                        // Fallback Symbol
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.brandGradient)
                                .frame(width: 64, height: 64)
                            Image(systemName: "keyboard.badge.ellipsis")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ReTypeR")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Версия 1.0.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Social Links
                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Link(destination: URL(string: "https://t.me/your_telegram_channel")!) {
                                Image(systemName: "paperplane.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(Color.brandStart)
                            }
                            .buttonStyle(.plain)
                            Text("Telegram")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(spacing: 4) {
                            Link(destination: URL(string: "https://github.com/your_github_repo")!) {
                                Image(systemName: "globe.americas.fill")
                                    .font(.title)
                                    .foregroundStyle(Color.primary)
                            }
                            .buttonStyle(.plain)
                            Text("GitHub")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 8)
                
                Divider()
                
                // Section 1: Hotkeys
                VStack(alignment: .leading, spacing: 10) {
                    Text("Горячие клавиши")
                        .font(.headline)
                        .foregroundColor(.brandStart)
                    
                    HStack {
                        Text("Сочетание для конвертации:")
                            .font(.subheadline)
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
                VStack(alignment: .leading, spacing: 10) {
                    Text("Раскладки клавиатуры")
                        .font(.headline)
                        .foregroundColor(.brandStart)
                    
                    VStack(spacing: 12) {
                        Picker("Основная раскладка (A):", selection: $prefs.primaryLayoutID) {
                            if installedLayouts.isEmpty {
                                Text("Загрузка...").tag(prefs.primaryLayoutID)
                            } else {
                                ForEach(installedLayouts) { layout in
                                    Text(layout.localizedName).tag(layout.id)
                                }
                            }
                        }
                        .onChange(of: prefs.primaryLayoutID) { _ in
                            prefs.updateMapping()
                        }
                        
                        Picker("Вторичная раскладка (B):", selection: $prefs.secondaryLayoutID) {
                            if installedLayouts.isEmpty {
                                Text("Загрузка...").tag(prefs.secondaryLayoutID)
                            } else {
                                ForEach(installedLayouts) { layout in
                                    Text(layout.localizedName).tag(layout.id)
                                }
                            }
                        }
                        .onChange(of: prefs.secondaryLayoutID) { _ in
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
                VStack(alignment: .leading, spacing: 10) {
                    Text("Система и Уведомления")
                        .font(.headline)
                        .foregroundColor(.brandStart)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Запускать ReTypeR при старте системы", isOn: Binding(
                            get: { launch.isLaunchAtLoginEnabled },
                            set: { launch.setLaunchAtLogin($0) }
                        ))
                        
                        Toggle("Показывать всплывающее уведомление (Toast)", isOn: $prefs.isToastEnabled)
                        
                        Toggle("Автоматически выделять весь текст (Cmd+A) при конвертации", isOn: $prefs.autoSelectAllText)
                        
                        Toggle("Переключать раскладку ввода после конвертации", isOn: $prefs.switchLayoutAfterConversion)
                        
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
                
                // Section 4: Statistics
                VStack(alignment: .leading, spacing: 10) {
                    Text("Статистика")
                        .font(.headline)
                        .foregroundColor(.brandStart)
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            // Conversions
                            HStack {
                                Image(systemName: "arrow.left.arrow.right.circle")
                                    .foregroundColor(.brandStart)
                                Text("Конверсий:")
                                Spacer()
                                Text("\(stats.totalConversions)")
                                    .fontWeight(.bold)
                            }
                            .padding(10)
                            .background(Color.primary.opacity(0.03))
                            .cornerRadius(6)
                            
                            // Characters
                            HStack {
                                Image(systemName: "character.cursor.ibound")
                                    .foregroundColor(.brandEnd)
                                Text("Символов:")
                                Spacer()
                                Text("\(stats.totalCharactersConverted)")
                                    .fontWeight(.bold)
                            }
                            .padding(10)
                            .background(Color.primary.opacity(0.03))
                            .cornerRadius(6)
                        }
                        
                        Button(action: {
                            stats.reset()
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Сбросить статистику")
                            }
                            .foregroundColor(.red)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(stats.totalConversions == 0 && stats.totalCharactersConverted == 0)
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.02))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
                }
            }
            .padding(16)
        }
        .frame(width: 440, height: 500)
        .onAppear {
            LayoutMapper.shared.refreshAvailableLayouts()
            self.installedLayouts = LayoutMapper.shared.getInstalledLayouts()
        }
    }
}
