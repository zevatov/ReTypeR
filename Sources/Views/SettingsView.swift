import SwiftUI
import AppKit
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject var prefs = PreferencesManager.shared
    @ObservedObject var launch = LaunchManager.shared
    @ObservedObject var stats = StatisticsManager.shared
    @ObservedObject var permissions = PermissionsManager.shared
    @ObservedObject private var updateChecker = UpdateChecker.shared

    @State private var installedLayouts: [KeyboardLayoutInfo] = []
    @State private var isHistoryExpanded = false
    @State private var isClearLogConfirmationShown = false
    @State private var isResetStatsConfirmationShown = false
    @State private var copiedIndex: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header (App identity + links)
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient.brandRed)
                            .frame(width: 44, height: 44)
                            .shadow(color: Color.brandAccent.opacity(0.3), radius: 6, x: 0, y: 3)
                        Image(systemName: "keyboard")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("ReTypeR")
                            .font(.system(size: 18, weight: .bold))
                        HStack(spacing: 6) {
                            Text("Умная смена раскладки клавиатуры • Версия \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3.5")")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            if case .updateAvailable(let version, _) = updateChecker.status {
                                Button(action: {
                                    updateChecker.openUpdateTarget()
                                }) {
                                    HStack(spacing: 3) {
                                        Circle()
                                            .fill(Color.orange)
                                            .frame(width: 6, height: 6)
                                        Text("Доступна \(version)")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.orange)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.12))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Link(destination: URL(string: "https://t.me/+rchqdp7ARSw2Njdi") ?? URL(string: "https://telegram.org")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(red: 0.2, green: 0.65, blue: 0.95))
                                Text("Telegram")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Link(destination: URL(string: "https://github.com/zevatov/ReTypeR")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "curlybraces")
                                    .font(.system(size: 11))
                                Text("GitHub")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Section 0: System Permissions Alert (SingAR amber card)
                if !permissions.isAccessibilityGranted {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color.brandAmber)
                            Text("Требуются системные разрешения macOS")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                        }

                        VStack(spacing: 8) {
                            permissionRow(
                                title: "Универсальный доступ (чтение и замена текста)",
                                isGranted: permissions.isAccessibilityGranted,
                                icon: "accessibility",
                                onRequest: { permissions.requestAccessibility() },
                                onOpenSettings: { permissions.openAccessibilitySettings() }
                            )
                        }
                        .padding(12)
                        .background(Color.brandCard)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.brandAmber.opacity(0.4), lineWidth: 1)
                        )
                    }
                }

                // Section 1: Hotkeys & Shortcuts
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "keyboard")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.brandAccent)
                        Text("Горячие клавиши")
                            .font(.system(size: 13, weight: .semibold))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Сочетание для конвертации:")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Конвертирует выделенный текст между раскладками")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            KeyboardShortcuts.Recorder(for: .convertText)
                        }
                    }
                    .padding(14)
                    .background(Color.brandCard)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.brandBorder, lineWidth: 1)
                    )
                }

                // Section 2: Keyboard Layouts
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "globe")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.brandAccent)
                        Text("Раскладки клавиатуры")
                            .font(.system(size: 13, weight: .semibold))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Основная раскладка (A):")
                                    .font(.system(size: 12, weight: .medium))
                                Text("По умолчанию Русская")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
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

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Вторичная раскладка (B):")
                                    .font(.system(size: 12, weight: .medium))
                                Text("По умолчанию English")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
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

                        if prefs.primaryLayoutID == prefs.secondaryLayoutID, !installedLayouts.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 11))
                                Text("Основная и вторичная раскладки совпадают — выберите разные раскладки.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(14)
                    .background(Color.brandCard)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.brandBorder, lineWidth: 1)
                    )
                }

                // Section 3: Conversion & System Parameters
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.brandAccent)
                        Text("Параметры конвертации и системы")
                            .font(.system(size: 13, weight: .semibold))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Toggle("Умное распознавание раскладки", isOn: $prefs.isSmartRecognitionEnabled)
                                .toggleStyle(.checkbox)
                                .font(.system(size: 12))
                            Text("Конвертирует только слова с опечатками раскладки на основе частотного словаря, сохраняя правильные слова.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .padding(.leading, 18)
                        }

                        Divider()

                        Toggle("Запускать ReTypeR при входе в систему", isOn: Binding(
                            get: { launch.isLaunchAtLoginEnabled },
                            set: { launch.setLaunchAtLogin($0) }
                        ))
                        .toggleStyle(.checkbox)
                        .font(.system(size: 12))

                        Divider()

                        Toggle("Показывать всплывающие уведомления (Toast)", isOn: $prefs.isToastEnabled)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 12))

                        Divider()

                        Toggle("Выделять весь текст (⌘A) перед конвертацией", isOn: $prefs.autoSelectAllText)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 12))

                        Divider()

                        Toggle("Переключать раскладку системы после конвертации", isOn: $prefs.switchLayoutAfterConversion)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 12))

                        Divider()

                        Toggle("Сохранять историю последних конвертаций", isOn: $prefs.isHistoryEnabled)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 12))
                    }
                    .padding(14)
                    .background(Color.brandCard)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.brandBorder, lineWidth: 1)
                    )
                }

                // Section 4: Statistics & History
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.brandAccent)
                        Text("Статистика и История")
                            .font(.system(size: 13, weight: .semibold))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        // 3-Metric Tile Row (SingAR style)
                        HStack(spacing: 8) {
                            metricTile(title: "Конвертации", value: "\(stats.totalConversions)", icon: "arrow.left.arrow.right.circle")
                            metricTile(title: "Символы", value: "\(stats.totalCharactersConverted)", icon: "character.textbox")
                            metricTile(title: "Записей", value: "\(stats.history.count)", icon: "clock.arrow.circlepath")
                        }

                        Divider()

                        // Action Buttons: History Toggle / Data Folder / Reset
                        HStack(spacing: 8) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    isHistoryExpanded.toggle()
                                }
                            }) {
                                Label(isHistoryExpanded ? "Скрыть историю" : "Показать историю", systemImage: "clock.arrow.circlepath")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.bordered)

                            Button(action: {
                                let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                                let dir = appSupport.appendingPathComponent("ReTypeR")
                                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                                NSWorkspace.shared.open(dir)
                            }) {
                                Label("Папка данных", systemImage: "folder")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.bordered)

                            Spacer()

                            Button(action: {
                                isResetStatsConfirmationShown = true
                            }) {
                                Label("Сбросить", systemImage: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.bordered)
                            .disabled(stats.totalConversions == 0 && stats.totalCharactersConverted == 0)
                        }

                        // Collapsible History view inside Settings
                        if isHistoryExpanded {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("История последних конвертаций:")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("Нажмите для копирования")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary.opacity(0.7))
                                }

                                if !prefs.isHistoryEnabled {
                                    Text("История отключена в настройках")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 12)
                                } else if stats.history.isEmpty {
                                    Text("История пуста")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 12)
                                } else {
                                    ScrollView {
                                        VStack(spacing: 5) {
                                            ForEach(Array(stats.history.enumerated()), id: \.element.id) { index, record in
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
                                    .frame(minHeight: 100, maxHeight: 180)
                                }
                            }
                            .padding(.top, 4)
                            .transition(.opacity)
                        }
                    }
                    .padding(14)
                    .background(Color.brandCard)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.brandBorder, lineWidth: 1)
                    )
                }

                // Section 5: Privacy & Diagnostics
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.brandAccent)
                        Text("Приватность и Журнал")
                            .font(.system(size: 13, weight: .semibold))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Toggle("Вести журнал конвертаций", isOn: $prefs.isConversionLogEnabled)
                                .toggleStyle(.checkbox)
                                .font(.system(size: 12))
                            Text("Журнал хранится локально в ~/Library/Application Support/ReTypeR/conversion_log.jsonl. Выключен по умолчанию.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .padding(.leading, 18)
                        }

                        HStack {
                            Button(action: {
                                isClearLogConfirmationShown = true
                            }) {
                                Label("Очистить журнал", systemImage: "trash")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.bordered)

                            Button(action: {
                                let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                                    .appendingPathComponent("ReTypeR/conversion_log.jsonl")
                                if FileManager.default.fileExists(atPath: url.path) {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                Label("Открыть conversion_log.jsonl", systemImage: "doc.text")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(14)
                    .background(Color.brandCard)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.brandBorder, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .frame(minWidth: 540, minHeight: 620)
        .confirmationDialog(
            "Очистить журнал конвертаций?",
            isPresented: $isClearLogConfirmationShown,
            titleVisibility: .visible
        ) {
            Button("Очистить журнал", role: .destructive) {
                ConversionLogger.shared.clearLog()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Файл журнала conversion_log.jsonl будет удалён без возможности восстановления.")
        }
        .confirmationDialog(
            "Сброс статистики и истории?",
            isPresented: $isResetStatsConfirmationShown,
            titleVisibility: .visible
        ) {
            Button("Сбросить", role: .destructive) {
                stats.reset()
                isHistoryExpanded = false
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Вы действительно хотите очистить историю конвертаций и счётчики символов?")
        }
        .onAppear {
            LayoutMapper.shared.refreshAvailableLayouts()
            installedLayouts = LayoutMapper.shared.getInstalledLayouts()
            permissions.checkAccessibility()
            updateChecker.checkForUpdates()
        }
    }

    // MARK: - Components

    private func metricTile(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color.brandAccent)
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(8)
    }

    private func permissionRow(
        title: String,
        isGranted: Bool,
        icon: String,
        onRequest: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(isGranted ? Color.brandGreen : Color.brandAmber)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.primary)

            Spacer()

            if isGranted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.brandGreen)
                    Text("Разрешено")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.brandGreen)
                }
            } else {
                HStack(spacing: 6) {
                    Button("Разрешить") {
                        onRequest()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brandAccent)
                    .controlSize(.small)

                    Button("Настройки macOS") {
                        onOpenSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

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

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
