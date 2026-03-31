import SwiftUI
import AppKit
import DesignSystem
import DofficeKit

// ═══════════════════════════════════════════════════════
// MARK: - Settings View
// ═══════════════════════════════════════════════════════

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss

    @ObservedObject private var tokenTracker = TokenTracker.shared
    @ObservedObject private var templateStore = AutomationTemplateStore.shared
    @State private var editingAppName: String = ""
    @State private var editingCompanyName: String = ""

    @State private var selectedSettingsTab = 0
    @State private var selectedTemplateKind: AutomationTemplateKind = .planner
    @State private var cacheSize: String = NSLocalizedString("settings.calculating", comment: "")
    @State private var showClearConfirm = false
    @State private var clearAllMode = false
    @State private var showTokenResetConfirm = false
    @State private var showTemplateResetConfirm = false
    @State private var showLanguageRestartAlert = false
    @State private var pendingLanguage: String?
    @State private var showThemeRestartAlert = false
    @State private var pendingThemeMode: String?
    @State private var showFontRestartAlert = false
    @State private var pendingFontScale: Double?

    // Custom Theme
    @State private var customAccentColor: Color = Theme.accent
    @State private var customGradientStart: Color = Color(hex: "3291ff")
    @State private var customGradientEnd: Color = Color(hex: "8e4ec6")
    @State private var customUseGradient: Bool = false
    @State private var customFontName: String = ""
    @State private var customFontSize: Double = 11.0
    @State private var showImportError = false

    // Custom Theme - Background colors
    @State private var customBgColor: Color = Color(hex: "000000")
    @State private var customBgCardColor: Color = Color(hex: "0a0a0a")
    @State private var customBgSurfaceColor: Color = Color(hex: "111111")
    @State private var customBgTertiaryColor: Color = Color(hex: "1a1a1a")
    // Custom Theme - Text colors
    @State private var customTextPrimaryColor: Color = Color(hex: "ededed")
    @State private var customTextSecondaryColor: Color = Color(hex: "a1a1a1")
    @State private var customTextDimColor: Color = Color(hex: "707070")
    @State private var customTextMutedColor: Color = Color(hex: "484848")
    // Custom Theme - Border colors
    @State private var customBorderColor: Color = Color(hex: "282828")
    @State private var customBorderStrongColor: Color = Color(hex: "3e3e3e")
    // Custom Theme - Semantic colors
    @State private var customGreenColor: Color = Color(hex: "3ecf8e")
    @State private var customRedColor: Color = Color(hex: "f14c4c")
    @State private var customYellowColor: Color = Color(hex: "f5a623")
    @State private var customPurpleColor: Color = Color(hex: "8e4ec6")
    @State private var customOrangeColor: Color = Color(hex: "f97316")
    @State private var customCyanColor: Color = Color(hex: "06b6d4")
    @State private var customPinkColor: Color = Color(hex: "e54d9e")
    // Expanded state for color groups
    @State private var showBgColors: Bool = false
    @State private var showTextColors: Bool = false
    @State private var showBorderColors: Bool = false
    @State private var showSemanticColors: Bool = false

    // Plugin
    @ObservedObject private var pluginManager = PluginManager.shared
    @State private var pluginSourceInput: String = ""
    @State private var showPluginUninstallConfirm = false
    @State private var pluginToUninstall: PluginEntry?
    @State private var showPluginScaffold = false
    @State private var scaffoldName: String = ""
    @State private var expandedPluginId: String?   // 상세 정보 토글

    private let settingsTabs: [(String, String)] = [
        ("slider.horizontal.3", NSLocalizedString("settings.general", comment: "")), ("paintbrush.fill", NSLocalizedString("settings.display", comment: "")), ("building.2.fill", NSLocalizedString("settings.office", comment: "")),
        ("bolt.fill", NSLocalizedString("settings.token", comment: "")), ("externaldrive.fill", NSLocalizedString("settings.data", comment: "")), ("doc.text.fill", NSLocalizedString("settings.template", comment: "")),
        ("puzzlepiece.fill", NSLocalizedString("settings.plugin", comment: "")),
        ("cup.and.saucer.fill", NSLocalizedString("settings.support", comment: "")), ("lock.shield.fill", NSLocalizedString("settings.security", comment: "")),
        ("keyboard.fill", NSLocalizedString("settings.shortcuts", comment: ""))
    ]

    var body: some View {
        DSModalShell {
            DSModalHeader(
                icon: "gearshape.fill",
                iconColor: Theme.textSecondary,
                title: NSLocalizedString("settings.title", comment: ""),
                onClose: { dismiss() }
            )
            .keyboardShortcut(.escape)

            // 탭 바
            ScrollView(.horizontal, showsIndicators: false) {
                DSTabBar(tabs: settingsTabs, selectedIndex: $selectedSettingsTab)
            }
            .padding(.horizontal, Theme.sp4)
            .padding(.vertical, Theme.sp2)

            Rectangle().fill(Theme.border).frame(height: 1)

            // 탭 내용
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Theme.sp4) {
                    switch selectedSettingsTab {
                    case 0: generalTab
                    case 1: displayTab
                    case 2: officeTab
                    case 3: tokenTab
                    case 4: dataTab
                    case 5: templateTab
                    case 6: pluginTab
                    case 7: supportTab
                    case 8: securityTab
                    case 9: ShortcutsSettingsTab()
                    default: generalTab
                    }
                }
                .padding(Theme.sp5)
            }
        }
        .frame(width: 580, height: 680)
        .background(Theme.bg)
        .onAppear {
            settings.ensureCoffeeSupportPreset()
            editingAppName = settings.appDisplayName
            editingCompanyName = settings.companyName
            calculateCacheSize()
            // 커스텀 테마 상태 초기화
            let ct = settings.customTheme
            if let hex = ct.accentHex, !hex.isEmpty { customAccentColor = Color(hex: hex) }
            if let hex = ct.gradientStartHex, !hex.isEmpty { customGradientStart = Color(hex: hex) }
            if let hex = ct.gradientEndHex, !hex.isEmpty { customGradientEnd = Color(hex: hex) }
            customUseGradient = ct.useGradient
            customFontName = ct.fontName ?? ""
            customFontSize = ct.fontSize ?? 11.0
            // Background
            if let hex = ct.bgHex, !hex.isEmpty { customBgColor = Color(hex: hex) }
            else { customBgColor = settings.isDarkMode ? Color(hex: "000000") : Color(hex: "fafafa") }
            if let hex = ct.bgCardHex, !hex.isEmpty { customBgCardColor = Color(hex: hex) }
            else { customBgCardColor = settings.isDarkMode ? Color(hex: "0a0a0a") : Color(hex: "ffffff") }
            if let hex = ct.bgSurfaceHex, !hex.isEmpty { customBgSurfaceColor = Color(hex: hex) }
            else { customBgSurfaceColor = settings.isDarkMode ? Color(hex: "111111") : Color(hex: "f5f5f5") }
            if let hex = ct.bgTertiaryHex, !hex.isEmpty { customBgTertiaryColor = Color(hex: hex) }
            else { customBgTertiaryColor = settings.isDarkMode ? Color(hex: "1a1a1a") : Color(hex: "ebebeb") }
            // Text
            if let hex = ct.textPrimaryHex, !hex.isEmpty { customTextPrimaryColor = Color(hex: hex) }
            else { customTextPrimaryColor = settings.isDarkMode ? Color(hex: "ededed") : Color(hex: "171717") }
            if let hex = ct.textSecondaryHex, !hex.isEmpty { customTextSecondaryColor = Color(hex: hex) }
            else { customTextSecondaryColor = settings.isDarkMode ? Color(hex: "a1a1a1") : Color(hex: "636363") }
            if let hex = ct.textDimHex, !hex.isEmpty { customTextDimColor = Color(hex: hex) }
            else { customTextDimColor = settings.isDarkMode ? Color(hex: "707070") : Color(hex: "8f8f8f") }
            if let hex = ct.textMutedHex, !hex.isEmpty { customTextMutedColor = Color(hex: hex) }
            else { customTextMutedColor = settings.isDarkMode ? Color(hex: "484848") : Color(hex: "b0b0b0") }
            // Border
            if let hex = ct.borderHex, !hex.isEmpty { customBorderColor = Color(hex: hex) }
            else { customBorderColor = settings.isDarkMode ? Color(hex: "282828") : Color(hex: "e5e5e5") }
            if let hex = ct.borderStrongHex, !hex.isEmpty { customBorderStrongColor = Color(hex: hex) }
            else { customBorderStrongColor = settings.isDarkMode ? Color(hex: "3e3e3e") : Color(hex: "d0d0d0") }
            // Semantic
            if let hex = ct.greenHex, !hex.isEmpty { customGreenColor = Color(hex: hex) }
            else { customGreenColor = settings.isDarkMode ? Color(hex: "3ecf8e") : Color(hex: "18a058") }
            if let hex = ct.redHex, !hex.isEmpty { customRedColor = Color(hex: hex) }
            else { customRedColor = settings.isDarkMode ? Color(hex: "f14c4c") : Color(hex: "e5484d") }
            if let hex = ct.yellowHex, !hex.isEmpty { customYellowColor = Color(hex: hex) }
            else { customYellowColor = settings.isDarkMode ? Color(hex: "f5a623") : Color(hex: "ca8a04") }
            if let hex = ct.purpleHex, !hex.isEmpty { customPurpleColor = Color(hex: hex) }
            else { customPurpleColor = settings.isDarkMode ? Color(hex: "8e4ec6") : Color(hex: "6e56cf") }
            if let hex = ct.orangeHex, !hex.isEmpty { customOrangeColor = Color(hex: hex) }
            else { customOrangeColor = settings.isDarkMode ? Color(hex: "f97316") : Color(hex: "e5560a") }
            if let hex = ct.cyanHex, !hex.isEmpty { customCyanColor = Color(hex: hex) }
            else { customCyanColor = settings.isDarkMode ? Color(hex: "06b6d4") : Color(hex: "0891b2") }
            if let hex = ct.pinkHex, !hex.isEmpty { customPinkColor = Color(hex: hex) }
            else { customPinkColor = settings.isDarkMode ? Color(hex: "e54d9e") : Color(hex: "d23197") }
        }
        .onChange(of: settings.isDarkMode) { dark in
            // 커스텀 hex가 없는 색상만 다크/라이트 모드 기본값으로 자동 업데이트
            let ct = settings.customTheme
            if ct.bgHex == nil || ct.bgHex!.isEmpty { customBgColor = dark ? Color(hex: "000000") : Color(hex: "fafafa") }
            if ct.bgCardHex == nil || ct.bgCardHex!.isEmpty { customBgCardColor = dark ? Color(hex: "0a0a0a") : Color(hex: "ffffff") }
            if ct.bgSurfaceHex == nil || ct.bgSurfaceHex!.isEmpty { customBgSurfaceColor = dark ? Color(hex: "111111") : Color(hex: "f5f5f5") }
            if ct.bgTertiaryHex == nil || ct.bgTertiaryHex!.isEmpty { customBgTertiaryColor = dark ? Color(hex: "1a1a1a") : Color(hex: "ebebeb") }
            if ct.textPrimaryHex == nil || ct.textPrimaryHex!.isEmpty { customTextPrimaryColor = dark ? Color(hex: "ededed") : Color(hex: "171717") }
            if ct.textSecondaryHex == nil || ct.textSecondaryHex!.isEmpty { customTextSecondaryColor = dark ? Color(hex: "a1a1a1") : Color(hex: "636363") }
            if ct.textDimHex == nil || ct.textDimHex!.isEmpty { customTextDimColor = dark ? Color(hex: "707070") : Color(hex: "8f8f8f") }
            if ct.textMutedHex == nil || ct.textMutedHex!.isEmpty { customTextMutedColor = dark ? Color(hex: "484848") : Color(hex: "b0b0b0") }
            if ct.borderHex == nil || ct.borderHex!.isEmpty { customBorderColor = dark ? Color(hex: "282828") : Color(hex: "e5e5e5") }
            if ct.borderStrongHex == nil || ct.borderStrongHex!.isEmpty { customBorderStrongColor = dark ? Color(hex: "3e3e3e") : Color(hex: "d0d0d0") }
            if ct.greenHex == nil || ct.greenHex!.isEmpty { customGreenColor = dark ? Color(hex: "3ecf8e") : Color(hex: "18a058") }
            if ct.redHex == nil || ct.redHex!.isEmpty { customRedColor = dark ? Color(hex: "f14c4c") : Color(hex: "e5484d") }
            if ct.yellowHex == nil || ct.yellowHex!.isEmpty { customYellowColor = dark ? Color(hex: "f5a623") : Color(hex: "ca8a04") }
            if ct.purpleHex == nil || ct.purpleHex!.isEmpty { customPurpleColor = dark ? Color(hex: "8e4ec6") : Color(hex: "6e56cf") }
            if ct.orangeHex == nil || ct.orangeHex!.isEmpty { customOrangeColor = dark ? Color(hex: "f97316") : Color(hex: "e5560a") }
            if ct.cyanHex == nil || ct.cyanHex!.isEmpty { customCyanColor = dark ? Color(hex: "06b6d4") : Color(hex: "0891b2") }
            if ct.pinkHex == nil || ct.pinkHex!.isEmpty { customPinkColor = dark ? Color(hex: "e54d9e") : Color(hex: "d23197") }
        }
        .alert(clearAllMode ? NSLocalizedString("theme.alert.clear.all", comment: "") : NSLocalizedString("theme.alert.clear.old", comment: ""), isPresented: $showClearConfirm) {
            Button(NSLocalizedString("delete", comment: ""), role: .destructive) {
                if clearAllMode { clearAllData() } else { clearOldCache() }
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(clearAllMode
                 ? NSLocalizedString("theme.alert.clear.all.msg", comment: "")
                 : NSLocalizedString("theme.alert.clear.old.msg", comment: ""))
        }
        .alert(NSLocalizedString("theme.alert.token.reset", comment: ""), isPresented: $showTokenResetConfirm) {
            Button(NSLocalizedString("theme.alert.token.reset.btn", comment: ""), role: .destructive) {
                tokenTracker.clearAllEntries()
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("theme.alert.token.reset.msg", comment: ""))
        }
        .alert(NSLocalizedString("theme.alert.template.reset", comment: ""), isPresented: $showTemplateResetConfirm) {
            Button(NSLocalizedString("theme.alert.template.reset.btn", comment: ""), role: .destructive) {
                templateStore.resetAll()
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("theme.alert.template.reset.msg", comment: ""))
        }
        .alert(NSLocalizedString("theme.alert.language.change", comment: ""), isPresented: $showLanguageRestartAlert) {
            Button(NSLocalizedString("settings.restart", comment: ""), role: .destructive) {
                if let lang = pendingLanguage {
                    settings.appLanguage = lang
                    restartApp()
                }
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { pendingLanguage = nil }
        } message: {
            let langName: String = {
                switch pendingLanguage {
                case "ko": return NSLocalizedString("theme.lang.korean", comment: "")
                case "en": return "English"
                case "ja": return "日本語"
                default: return NSLocalizedString("settings.language.system", comment: "")
                }
            }()
            Text(String(format: NSLocalizedString("theme.alert.language.msg", comment: ""), langName))
        }
        .alert(NSLocalizedString("settings.customtheme.import.error", comment: ""), isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(NSLocalizedString("settings.customtheme.import.error.msg", comment: ""))
        }
        .alert(NSLocalizedString("theme.alert.theme.change", comment: "테마 변경"), isPresented: $showThemeRestartAlert) {
            Button(NSLocalizedString("settings.restart", comment: ""), role: .destructive) {
                if let mode = pendingThemeMode {
                    settings.themeMode = mode
                    settings.requestRefreshIfNeeded()
                    restartApp()
                }
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { pendingThemeMode = nil }
        } message: {
            Text(NSLocalizedString("theme.alert.theme.change.msg", comment: "테마를 변경하면 앱이 재시작됩니다."))
        }
        .alert(NSLocalizedString("theme.alert.font.change", comment: "글꼴 크기 변경"), isPresented: $showFontRestartAlert) {
            Button(NSLocalizedString("settings.restart", comment: ""), role: .destructive) {
                if let scale = pendingFontScale {
                    settings.fontSizeScale = scale
                    restartApp()
                }
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { pendingFontScale = nil }
        } message: {
            Text(NSLocalizedString("theme.alert.font.change.msg", comment: "글꼴 크기를 변경하면 앱이 재시작됩니다."))
        }
    }

    private func langButton(_ label: String, code: String) -> some View {
        let isActive = settings.appLanguage == code
        return Button(action: {
            guard code != settings.appLanguage else { return }
            pendingLanguage = code
            showLanguageRestartAlert = true
        }) {
            Text(label)
                .font(Theme.mono(9, weight: isActive ? .bold : .regular))
                .foregroundColor(isActive ? .white : Theme.textSecondary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(isActive ? Theme.accent : Theme.bgSurface))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(isActive ? Theme.accent : Theme.border.opacity(0.3), lineWidth: 0.5))
        }.buttonStyle(.plain)
    }

    // MARK: - Tab Button

    private func settingsTabButton(_ title: String, icon: String, tab: Int) -> some View {
        let selected = selectedSettingsTab == tab
        return Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selectedSettingsTab = tab } }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: Theme.iconSize(12), weight: .medium))
                Text(title)
                    .font(Theme.mono(8, weight: selected ? .bold : .medium))
            }
            .foregroundColor(selected ? Theme.accent : Theme.textDim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerSmall)
                    .fill(selected ? Theme.accent.opacity(0.08) : Theme.bgSurface.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerSmall)
                    .stroke(selected ? Theme.accent.opacity(0.18) : Theme.border.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 일반 탭

    private var generalTab: some View {
        VStack(spacing: 14) {
            settingsSection(title: NSLocalizedString("theme.section.profile", comment: ""), subtitle: NSLocalizedString("theme.section.profile.subtitle", comment: "")) {
                VStack(spacing: 10) {
                    securityRow(label: NSLocalizedString("theme.label.app.name", comment: "")) {
                        TextField(NSLocalizedString("theme.label.app.name", comment: ""), text: $editingAppName)
                            .font(Theme.mono(10)).textFieldStyle(.plain)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 0.5))
                            .frame(maxWidth: 180)
                            .onSubmit { settings.appDisplayName = editingAppName; settings.requestRefreshIfNeeded() }
                    }
                    securityRow(label: NSLocalizedString("theme.label.company", comment: "")) {
                        TextField(NSLocalizedString("theme.label.company.placeholder", comment: ""), text: $editingCompanyName)
                            .font(Theme.mono(10)).textFieldStyle(.plain)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 0.5))
                            .frame(maxWidth: 180)
                            .onSubmit { settings.companyName = editingCompanyName; settings.requestRefreshIfNeeded() }
                    }
                    securityRow(label: NSLocalizedString("theme.label.secret.key", comment: "")) {
                        HStack(spacing: 6) {
                            SecureField(NSLocalizedString("theme.label.secret.key.placeholder", comment: ""), text: $secretKeyInput)
                                .font(Theme.mono(10)).textFieldStyle(.plain)
                                .padding(6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(
                                    secretKeyResult == .wrong ? Theme.red : Theme.border, lineWidth: 0.5))
                                .frame(maxWidth: 140)
                                .onSubmit { applySecretKey() }
                            Button(NSLocalizedString("theme.label.apply", comment: "")) { applySecretKey() }
                                .font(Theme.mono(9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accentBackground))
                                .buttonStyle(.plain)
                        }
                    }
                    if secretKeyResult == .success {
                        statusHint(icon: "checkmark.circle.fill", text: NSLocalizedString("theme.secret.unlocked", comment: ""), tint: Theme.green)
                    } else if secretKeyResult == .wrong {
                        statusHint(icon: "xmark.circle.fill", text: NSLocalizedString("theme.secret.invalid", comment: ""), tint: Theme.red)
                    }
                }
            }

            settingsSection(title: NSLocalizedString("theme.section.language", comment: ""), subtitle: settings.currentLanguageLabel) {
                VStack(spacing: 10) {
                    securityRow(label: NSLocalizedString("theme.label.app.language", comment: "")) {
                        HStack(spacing: 8) {
                            langButton(NSLocalizedString("theme.lang.system", comment: ""), code: "auto")
                            langButton(NSLocalizedString("theme.lang.korean", comment: ""), code: "ko")
                            langButton("English", code: "en")
                            langButton("日本語", code: "ja")
                        }
                    }
                }
            }

            settingsSection(title: NSLocalizedString("theme.section.terminal", comment: ""), subtitle: settings.rawTerminalMode ? NSLocalizedString("theme.terminal.raw", comment: "") : NSLocalizedString("theme.terminal.doffice", comment: "")) {
                VStack(spacing: 10) {
                    securityRow(label: NSLocalizedString("theme.label.raw.terminal", comment: "")) {
                        Toggle("", isOn: $settings.rawTerminalMode)
                            .toggleStyle(.switch).tint(Theme.green).labelsHidden()
                            .onChange(of: settings.rawTerminalMode) { _, _ in settings.requestRefreshIfNeeded() }
                    }
                    securityRow(label: NSLocalizedString("theme.label.auto.refresh", comment: "")) {
                        Toggle("", isOn: $settings.autoRefreshOnSettingsChange)
                            .toggleStyle(.switch).tint(Theme.accent).labelsHidden()
                    }
                    securityRow(label: NSLocalizedString("theme.label.tutorial.reset", comment: "")) {
                        Button(action: { settings.hasCompletedOnboarding = false; dismiss() }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold)).foregroundColor(Theme.textDim)
                        }.buttonStyle(.plain)
                    }
                }
            }

            settingsSection(title: NSLocalizedString("settings.performance", comment: ""), subtitle: settings.performanceMode ? NSLocalizedString("settings.performance.manual", comment: "") : (settings.autoPerformanceMode ? NSLocalizedString("settings.performance.auto", comment: "") : NSLocalizedString("settings.performance.off", comment: ""))) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(NSLocalizedString("settings.performance.mode", comment: ""), isOn: $settings.performanceMode)
                        .font(Theme.mono(10, weight: .medium))
                    Toggle(NSLocalizedString("settings.performance.auto.mode", comment: ""), isOn: $settings.autoPerformanceMode)
                        .font(Theme.mono(10, weight: .medium))
                    Text(NSLocalizedString("settings.performance.desc", comment: ""))
                        .font(Theme.mono(8)).foregroundColor(Theme.textDim)
                }
            }

            settingsSection(title: NSLocalizedString("settings.appinfo", comment: ""), subtitle: "v\(UpdateChecker.shared.currentVersion)") {
                VStack(spacing: 10) {
                    securityRow(label: NSLocalizedString("settings.appinfo.version", comment: "")) {
                        Text("v\(UpdateChecker.shared.currentVersion)")
                            .font(Theme.mono(10, weight: .bold)).foregroundColor(Theme.textPrimary)
                    }
                    HStack(spacing: 8) {
                        Button(action: {
                            if let url = URL(string: "https://github.com/jjunhaa0211/MyWorkStudio") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Text("GitHub").font(Theme.mono(9, weight: .bold))
                                .appButtonSurface(tone: .accent, compact: true)
                        }.buttonStyle(.plain)
                        Button(action: { UpdateChecker.shared.performUpdate() }) {
                            Text(NSLocalizedString("settings.appinfo.update", comment: "")).font(Theme.mono(9, weight: .bold))
                                .appButtonSurface(tone: .green, compact: true)
                        }.buttonStyle(.plain)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - 화면 탭

    private var displayTab: some View {
        VStack(spacing: 14) {
            settingsSection(title: NSLocalizedString("settings.theme", comment: ""), subtitle: NSLocalizedString("settings.theme.subtitle", comment: "")) {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        themeModeButton(title: "Light", icon: "sun.max.fill", mode: "light")
                        themeModeButton(title: "Dark", icon: "moon.fill", mode: "dark")
                        themeModeButton(title: "Custom", icon: "paintpalette.fill", mode: "custom")
                    }

                    // 플러그인 테마
                    if !PluginHost.shared.themes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "puzzlepiece.fill")
                                    .font(.system(size: Theme.iconSize(8)))
                                Text(NSLocalizedString("plugin.themes.label", comment: ""))
                                    .font(Theme.mono(8, weight: .medium))
                            }.foregroundColor(Theme.textDim)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                                ForEach(PluginHost.shared.themes) { theme in
                                    Button(action: { PluginHost.shared.applyTheme(theme) }) {
                                        VStack(spacing: 4) {
                                            Circle()
                                                .fill(Color(hex: theme.decl.accentHex))
                                                .frame(width: 16, height: 16)
                                            Text(theme.decl.name)
                                                .font(Theme.mono(7, weight: .medium))
                                                .foregroundColor(Theme.textSecondary)
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border.opacity(0.3), lineWidth: 1))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }

            settingsSection(title: NSLocalizedString("settings.backdrop", comment: ""), subtitle: currentTheme.displayName) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(quickBackgroundThemes, id: \.rawValue) { theme in
                        quickBackgroundButton(theme)
                    }
                }
            }

            settingsSection(title: NSLocalizedString("settings.fontsize", comment: ""), subtitle: fontSizeLabel) {
                VStack(spacing: 10) {
                    HStack(spacing: 6) {
                        ForEach(fontSizeOptions, id: \.value) { opt in
                            Button(action: {
                                guard !isSelectedSize(opt.value) else { return }
                                pendingFontScale = opt.value
                                showFontRestartAlert = true
                            }) {
                                VStack(spacing: 4) {
                                    Text("Aa")
                                        .font(.system(size: CGFloat(10 * opt.value), weight: .medium, design: .monospaced))
                                        .foregroundColor(isSelectedSize(opt.value) ? Theme.accent : Theme.textSecondary)
                                    Text(opt.label)
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundColor(isSelectedSize(opt.value) ? Theme.accent : Theme.textDim)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(isSelectedSize(opt.value) ? Theme.accent.opacity(0.11) : Theme.bgSurface))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelectedSize(opt.value) ? Theme.accent.opacity(0.38) : Theme.border.opacity(0.4), lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }

            // ── 커스텀 테마 (Custom 모드일 때만 표시) ──
            if settings.themeMode == "custom" {
            settingsSection(title: NSLocalizedString("settings.customtheme", comment: ""), subtitle: NSLocalizedString("settings.customtheme.subtitle", comment: "")) {
                VStack(spacing: 12) {
                    // ── 강조 색상 / 그라데이션 통합 행 ──
                    VStack(spacing: 8) {
                        HStack {
                            Text(NSLocalizedString("settings.customtheme.accent", comment: ""))
                                .font(Theme.mono(10, weight: .medium))
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            // 그라데이션 토글
                            HStack(spacing: 4) {
                                Text(NSLocalizedString("settings.customtheme.gradient", comment: ""))
                                    .font(Theme.mono(8)).foregroundColor(Theme.textDim)
                                Toggle("", isOn: $customUseGradient)
                                    .toggleStyle(.switch).controlSize(.mini)
                                    .onChange(of: customUseGradient) { newVal in
                                        var config = settings.customTheme
                                        config.useGradient = newVal
                                        if newVal {
                                            config.gradientStartHex = customGradientStart.hexString
                                            config.gradientEndHex = customGradientEnd.hexString
                                        }
                                        settings.saveCustomTheme(config)
                                    }
                            }
                        }
                        if customUseGradient {
                            // 그라데이션 모드: 그라데이션 바가 accent
                            RoundedRectangle(cornerRadius: Theme.cornerMedium)
                                .fill(LinearGradient(colors: [customGradientStart, customGradientEnd], startPoint: .leading, endPoint: .trailing))
                                .frame(height: 32)
                                .overlay(
                                    Text("● Accent Gradient")
                                        .font(Theme.mono(9, weight: .bold))
                                        .foregroundColor(customGradientStart.contrastingTextColor)
                                )
                                .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.border, lineWidth: 1))
                            HStack(spacing: 16) {
                                HStack(spacing: 6) {
                                    Text(NSLocalizedString("settings.customtheme.gradient.start", comment: ""))
                                        .font(Theme.mono(9)).foregroundColor(Theme.textSecondary)
                                    ColorPicker("", selection: $customGradientStart, supportsOpacity: false)
                                        .labelsHidden()
                                        .onChange(of: customGradientStart) { newColor in
                                            var config = settings.customTheme
                                            config.gradientStartHex = newColor.hexString
                                            settings.saveCustomTheme(config)
                                        }
                                }
                                HStack(spacing: 6) {
                                    Text(NSLocalizedString("settings.customtheme.gradient.end", comment: ""))
                                        .font(Theme.mono(9)).foregroundColor(Theme.textSecondary)
                                    ColorPicker("", selection: $customGradientEnd, supportsOpacity: false)
                                        .labelsHidden()
                                        .onChange(of: customGradientEnd) { newColor in
                                            var config = settings.customTheme
                                            config.gradientEndHex = newColor.hexString
                                            settings.saveCustomTheme(config)
                                        }
                                }
                            }
                        } else {
                            // 단색 모드: 강조 색상 피커
                            HStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(customAccentColor)
                                    .frame(width: 28, height: 18)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.border, lineWidth: 1))
                                Text("● Accent")
                                    .font(Theme.mono(9)).foregroundColor(Theme.textSecondary)
                                Spacer()
                                ColorPicker("", selection: $customAccentColor, supportsOpacity: false)
                                    .labelsHidden()
                                    .onChange(of: customAccentColor) { newColor in
                                        var config = settings.customTheme
                                        config.accentHex = newColor.hexString
                                        settings.saveCustomTheme(config)
                                    }
                                Button(action: {
                                    var config = settings.customTheme
                                    config.accentHex = nil
                                    settings.saveCustomTheme(config)
                                    customAccentColor = settings.isDarkMode ? Color(hex: "3291ff") : Color(hex: "0070f3")
                                }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 9)).foregroundColor(Theme.textDim)
                                }.buttonStyle(.plain)
                            }
                        }
                    }

                    // 배경 색상
                    DisclosureGroup(isExpanded: $showBgColors) {
                        VStack(spacing: 8) {
                            colorPickerRow(label: "배경 (bg)", color: $customBgColor,
                                savedHex: settings.customTheme.bgHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "000000") : Color(hex: "fafafa")) { hex in
                                var c = settings.customTheme; c.bgHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "카드 (bgCard)", color: $customBgCardColor,
                                savedHex: settings.customTheme.bgCardHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "0a0a0a") : Color(hex: "ffffff")) { hex in
                                var c = settings.customTheme; c.bgCardHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "서피스 (bgSurface)", color: $customBgSurfaceColor,
                                savedHex: settings.customTheme.bgSurfaceHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "111111") : Color(hex: "f5f5f5")) { hex in
                                var c = settings.customTheme; c.bgSurfaceHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "3단계 배경 (bgTertiary)", color: $customBgTertiaryColor,
                                savedHex: settings.customTheme.bgTertiaryHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "1a1a1a") : Color(hex: "ebebeb")) { hex in
                                var c = settings.customTheme; c.bgTertiaryHex = hex; settings.saveCustomTheme(c)
                            }
                        }
                        .padding(.top, 6)
                    } label: {
                        Text("배경 색상")
                            .font(Theme.mono(10, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                    }

                    // 텍스트 색상
                    DisclosureGroup(isExpanded: $showTextColors) {
                        VStack(spacing: 8) {
                            colorPickerRow(label: "기본 텍스트", color: $customTextPrimaryColor,
                                savedHex: settings.customTheme.textPrimaryHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "ededed") : Color(hex: "171717")) { hex in
                                var c = settings.customTheme; c.textPrimaryHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "보조 텍스트", color: $customTextSecondaryColor,
                                savedHex: settings.customTheme.textSecondaryHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "a1a1a1") : Color(hex: "636363")) { hex in
                                var c = settings.customTheme; c.textSecondaryHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "흐린 텍스트 (dim)", color: $customTextDimColor,
                                savedHex: settings.customTheme.textDimHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "707070") : Color(hex: "8f8f8f")) { hex in
                                var c = settings.customTheme; c.textDimHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "뮤트 텍스트 (muted)", color: $customTextMutedColor,
                                savedHex: settings.customTheme.textMutedHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "484848") : Color(hex: "b0b0b0")) { hex in
                                var c = settings.customTheme; c.textMutedHex = hex; settings.saveCustomTheme(c)
                            }
                        }
                        .padding(.top, 6)
                    } label: {
                        Text("텍스트 색상")
                            .font(Theme.mono(10, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                    }

                    // 테두리 색상
                    DisclosureGroup(isExpanded: $showBorderColors) {
                        VStack(spacing: 8) {
                            colorPickerRow(label: "기본 테두리", color: $customBorderColor,
                                savedHex: settings.customTheme.borderHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "282828") : Color(hex: "e5e5e5")) { hex in
                                var c = settings.customTheme; c.borderHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "강조 테두리", color: $customBorderStrongColor,
                                savedHex: settings.customTheme.borderStrongHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "3e3e3e") : Color(hex: "d0d0d0")) { hex in
                                var c = settings.customTheme; c.borderStrongHex = hex; settings.saveCustomTheme(c)
                            }
                        }
                        .padding(.top, 6)
                    } label: {
                        Text("테두리 색상")
                            .font(Theme.mono(10, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                    }

                    // 시맨틱 색상
                    DisclosureGroup(isExpanded: $showSemanticColors) {
                        VStack(spacing: 8) {
                            colorPickerRow(label: "초록 (green)", color: $customGreenColor,
                                savedHex: settings.customTheme.greenHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "3ecf8e") : Color(hex: "18a058")) { hex in
                                var c = settings.customTheme; c.greenHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "빨강 (red)", color: $customRedColor,
                                savedHex: settings.customTheme.redHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "f14c4c") : Color(hex: "e5484d")) { hex in
                                var c = settings.customTheme; c.redHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "노랑 (yellow)", color: $customYellowColor,
                                savedHex: settings.customTheme.yellowHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "f5a623") : Color(hex: "ca8a04")) { hex in
                                var c = settings.customTheme; c.yellowHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "보라 (purple)", color: $customPurpleColor,
                                savedHex: settings.customTheme.purpleHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "8e4ec6") : Color(hex: "6e56cf")) { hex in
                                var c = settings.customTheme; c.purpleHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "주황 (orange)", color: $customOrangeColor,
                                savedHex: settings.customTheme.orangeHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "f97316") : Color(hex: "e5560a")) { hex in
                                var c = settings.customTheme; c.orangeHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "청록 (cyan)", color: $customCyanColor,
                                savedHex: settings.customTheme.cyanHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "06b6d4") : Color(hex: "0891b2")) { hex in
                                var c = settings.customTheme; c.cyanHex = hex; settings.saveCustomTheme(c)
                            }
                            colorPickerRow(label: "분홍 (pink)", color: $customPinkColor,
                                savedHex: settings.customTheme.pinkHex,
                                defaultColor: settings.isDarkMode ? Color(hex: "e54d9e") : Color(hex: "d23197")) { hex in
                                var c = settings.customTheme; c.pinkHex = hex; settings.saveCustomTheme(c)
                            }
                        }
                        .padding(.top, 6)
                    } label: {
                        Text("시맨틱 색상")
                            .font(Theme.mono(10, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                    }

                    Rectangle().fill(Theme.border).frame(height: 1)

                    // 폰트 선택
                    HStack {
                        Text(NSLocalizedString("settings.customtheme.font", comment: ""))
                            .font(Theme.mono(10, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Picker("", selection: $customFontName) {
                            Text(NSLocalizedString("settings.customtheme.font.system", comment: ""))
                                .tag("")
                            ForEach(NSFontManager.shared.availableFontFamilies, id: \.self) { family in
                                Text(family).font(.custom(family, size: 12)).tag(family)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 200)
                        .onChange(of: customFontName) { newVal in
                            var config = settings.customTheme
                            config.fontName = newVal.isEmpty ? nil : newVal
                            settings.saveCustomTheme(config)
                        }
                    }

                    // 폰트 크기 슬라이더
                    VStack(spacing: 4) {
                        HStack {
                            Text(NSLocalizedString("settings.customtheme.fontsize", comment: ""))
                                .font(Theme.mono(10, weight: .medium))
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            Text(String(format: "%.0fpt", customFontSize))
                                .font(Theme.code(10))
                                .foregroundColor(Theme.textSecondary)
                        }
                        Slider(value: $customFontSize, in: 8...24, step: 1)
                            .onChange(of: customFontSize) { newVal in
                                var config = settings.customTheme
                                config.fontSize = newVal
                                settings.saveCustomTheme(config)
                            }
                    }

                    // 미리보기
                    RoundedRectangle(cornerRadius: Theme.cornerMedium)
                        .fill(Theme.accent.opacity(0.12))
                        .overlay(
                            VStack(spacing: 4) {
                                Text("The quick brown fox")
                                    .font(Theme.mono(11, weight: .medium))
                                    .foregroundColor(Theme.textPrimary)
                                Text(NSLocalizedString("theme.custom.preview", comment: ""))
                                    .font(Theme.mono(9))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        )
                        .frame(height: 52)
                        .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(Theme.accent.opacity(0.2), lineWidth: 1))

                    Rectangle().fill(Theme.border).frame(height: 1)

                    // Import / Export / Reset 버튼
                    HStack(spacing: 8) {
                        Button(action: { settings.exportThemeToFile() }) {
                            Label(NSLocalizedString("settings.customtheme.export", comment: ""), systemImage: "square.and.arrow.up")
                                .font(Theme.mono(9, weight: .bold))
                                .foregroundColor(Theme.cyan)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.cyan.opacity(0.1)))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.cyan.opacity(0.25), lineWidth: 1))
                        }.buttonStyle(.plain)

                        Button(action: {
                            let panel = NSOpenPanel()
                            panel.allowedContentTypes = [.json]
                            panel.allowsMultipleSelection = false
                            panel.title = NSLocalizedString("settings.customtheme.import", comment: "")
                            if panel.runModal() == .OK, let url = panel.url {
                                guard let data = try? Data(contentsOf: url),
                                      let config = try? JSONDecoder().decode(CustomThemeConfig.self, from: data) else {
                                    showImportError = true
                                    return
                                }
                                settings.saveCustomTheme(config)
                                // 상태 동기화
                                if let hex = config.accentHex, !hex.isEmpty { customAccentColor = Color(hex: hex) }
                                if let hex = config.gradientStartHex, !hex.isEmpty { customGradientStart = Color(hex: hex) }
                                if let hex = config.gradientEndHex, !hex.isEmpty { customGradientEnd = Color(hex: hex) }
                                customUseGradient = config.useGradient
                                customFontName = config.fontName ?? ""
                                customFontSize = config.fontSize ?? 11.0
                                let dark = settings.isDarkMode
                                if let hex = config.bgHex, !hex.isEmpty { customBgColor = Color(hex: hex) } else { customBgColor = dark ? Color(hex: "000000") : Color(hex: "fafafa") }
                                if let hex = config.bgCardHex, !hex.isEmpty { customBgCardColor = Color(hex: hex) } else { customBgCardColor = dark ? Color(hex: "0a0a0a") : Color(hex: "ffffff") }
                                if let hex = config.bgSurfaceHex, !hex.isEmpty { customBgSurfaceColor = Color(hex: hex) } else { customBgSurfaceColor = dark ? Color(hex: "111111") : Color(hex: "f5f5f5") }
                                if let hex = config.bgTertiaryHex, !hex.isEmpty { customBgTertiaryColor = Color(hex: hex) } else { customBgTertiaryColor = dark ? Color(hex: "1a1a1a") : Color(hex: "ebebeb") }
                                if let hex = config.textPrimaryHex, !hex.isEmpty { customTextPrimaryColor = Color(hex: hex) } else { customTextPrimaryColor = dark ? Color(hex: "ededed") : Color(hex: "171717") }
                                if let hex = config.textSecondaryHex, !hex.isEmpty { customTextSecondaryColor = Color(hex: hex) } else { customTextSecondaryColor = dark ? Color(hex: "a1a1a1") : Color(hex: "636363") }
                                if let hex = config.textDimHex, !hex.isEmpty { customTextDimColor = Color(hex: hex) } else { customTextDimColor = dark ? Color(hex: "707070") : Color(hex: "8f8f8f") }
                                if let hex = config.textMutedHex, !hex.isEmpty { customTextMutedColor = Color(hex: hex) } else { customTextMutedColor = dark ? Color(hex: "484848") : Color(hex: "b0b0b0") }
                                if let hex = config.borderHex, !hex.isEmpty { customBorderColor = Color(hex: hex) } else { customBorderColor = dark ? Color(hex: "282828") : Color(hex: "e5e5e5") }
                                if let hex = config.borderStrongHex, !hex.isEmpty { customBorderStrongColor = Color(hex: hex) } else { customBorderStrongColor = dark ? Color(hex: "3e3e3e") : Color(hex: "d0d0d0") }
                                if let hex = config.greenHex, !hex.isEmpty { customGreenColor = Color(hex: hex) } else { customGreenColor = dark ? Color(hex: "3ecf8e") : Color(hex: "18a058") }
                                if let hex = config.redHex, !hex.isEmpty { customRedColor = Color(hex: hex) } else { customRedColor = dark ? Color(hex: "f14c4c") : Color(hex: "e5484d") }
                                if let hex = config.yellowHex, !hex.isEmpty { customYellowColor = Color(hex: hex) } else { customYellowColor = dark ? Color(hex: "f5a623") : Color(hex: "ca8a04") }
                                if let hex = config.purpleHex, !hex.isEmpty { customPurpleColor = Color(hex: hex) } else { customPurpleColor = dark ? Color(hex: "8e4ec6") : Color(hex: "6e56cf") }
                                if let hex = config.orangeHex, !hex.isEmpty { customOrangeColor = Color(hex: hex) } else { customOrangeColor = dark ? Color(hex: "f97316") : Color(hex: "e5560a") }
                                if let hex = config.cyanHex, !hex.isEmpty { customCyanColor = Color(hex: hex) } else { customCyanColor = dark ? Color(hex: "06b6d4") : Color(hex: "0891b2") }
                                if let hex = config.pinkHex, !hex.isEmpty { customPinkColor = Color(hex: hex) } else { customPinkColor = dark ? Color(hex: "e54d9e") : Color(hex: "d23197") }
                            }
                        }) {
                            Label(NSLocalizedString("settings.customtheme.import", comment: ""), systemImage: "square.and.arrow.down")
                                .font(Theme.mono(9, weight: .bold))
                                .foregroundStyle(Theme.accentBackground)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent.opacity(0.1)))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accent.opacity(0.25), lineWidth: 1))
                        }.buttonStyle(.plain)

                        Spacer()

                        Button(action: {
                            settings.saveCustomTheme(.default)
                            customAccentColor = Theme.accent
                            customGradientStart = Color(hex: "3291ff")
                            customGradientEnd = Color(hex: "8e4ec6")
                            customUseGradient = false
                            customFontName = ""
                            customFontSize = 11.0
                            let dark = settings.isDarkMode
                            customBgColor = dark ? Color(hex: "000000") : Color(hex: "fafafa")
                            customBgCardColor = dark ? Color(hex: "0a0a0a") : Color(hex: "ffffff")
                            customBgSurfaceColor = dark ? Color(hex: "111111") : Color(hex: "f5f5f5")
                            customBgTertiaryColor = dark ? Color(hex: "1a1a1a") : Color(hex: "ebebeb")
                            customTextPrimaryColor = dark ? Color(hex: "ededed") : Color(hex: "171717")
                            customTextSecondaryColor = dark ? Color(hex: "a1a1a1") : Color(hex: "636363")
                            customTextDimColor = dark ? Color(hex: "707070") : Color(hex: "8f8f8f")
                            customTextMutedColor = dark ? Color(hex: "484848") : Color(hex: "b0b0b0")
                            customBorderColor = dark ? Color(hex: "282828") : Color(hex: "e5e5e5")
                            customBorderStrongColor = dark ? Color(hex: "3e3e3e") : Color(hex: "d0d0d0")
                            customGreenColor = dark ? Color(hex: "3ecf8e") : Color(hex: "18a058")
                            customRedColor = dark ? Color(hex: "f14c4c") : Color(hex: "e5484d")
                            customYellowColor = dark ? Color(hex: "f5a623") : Color(hex: "ca8a04")
                            customPurpleColor = dark ? Color(hex: "8e4ec6") : Color(hex: "6e56cf")
                            customOrangeColor = dark ? Color(hex: "f97316") : Color(hex: "e5560a")
                            customCyanColor = dark ? Color(hex: "06b6d4") : Color(hex: "0891b2")
                            customPinkColor = dark ? Color(hex: "e54d9e") : Color(hex: "d23197")
                        }) {
                            Text(NSLocalizedString("settings.customtheme.reset", comment: ""))
                                .font(Theme.mono(9, weight: .bold))
                                .foregroundColor(Theme.orange)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.orange.opacity(0.1)))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.orange.opacity(0.25), lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                }
            }
            } // end if themeMode == "custom"
        }
    }

    // MARK: - 오피스 탭

    private var officeTab: some View {
        VStack(spacing: 14) {
            settingsSection(title: NSLocalizedString("settings.layout", comment: ""), subtitle: currentOfficePreset.displayName) {
                VStack(spacing: 8) {
                    ForEach(OfficePreset.allCases) { preset in
                        officePresetButton(preset)
                    }
                }
            }

            settingsSection(title: NSLocalizedString("settings.camera", comment: ""), subtitle: settings.officeViewMode == "side" ? NSLocalizedString("settings.camera.focus", comment: "") : NSLocalizedString("settings.camera.full", comment: "")) {
                HStack(spacing: 8) {
                    officeCameraButton(title: NSLocalizedString("settings.camera.full", comment: ""), icon: "rectangle.expand.vertical", mode: "grid")
                    officeCameraButton(title: NSLocalizedString("settings.camera.focus", comment: ""), icon: "scope", mode: "side")
                }
            }
        }
    }

    // MARK: - 토큰 탭

    private var tokenTab: some View {
        let protectionReason = tokenTracker.startBlockReason(isAutomation: false)
        return VStack(spacing: 14) {
            settingsSection(title: NSLocalizedString("settings.usage", comment: ""), subtitle: NSLocalizedString("settings.usage.subtitle", comment: "")) {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        usageMetricCard(
                            title: NSLocalizedString("settings.usage.today", comment: ""),
                            value: tokenTracker.formatTokens(tokenTracker.todayTokens),
                            secondary: "$" + String(format: "%.2f", tokenTracker.todayCost),
                            tint: Theme.accent,
                            progress: tokenTracker.dailyUsagePercent
                        )
                        usageMetricCard(
                            title: NSLocalizedString("settings.usage.week", comment: ""),
                            value: tokenTracker.formatTokens(tokenTracker.weekTokens),
                            secondary: "$" + String(format: "%.2f", tokenTracker.weekCost),
                            tint: Theme.cyan,
                            progress: tokenTracker.weeklyUsagePercent
                        )
                    }

                    HStack(spacing: 12) {
                        tokenLimitField(title: NSLocalizedString("settings.token.daily.limit", comment: ""), value: $tokenTracker.dailyTokenLimit)
                        tokenLimitField(title: NSLocalizedString("settings.token.weekly.limit", comment: ""), value: $tokenTracker.weeklyTokenLimit)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if let protectionReason {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: Theme.iconSize(11), weight: .bold))
                                    .foregroundColor(Theme.orange)
                                Text(protectionReason)
                                    .font(Theme.mono(8))
                                    .foregroundColor(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: Theme.iconSize(11), weight: .bold))
                                    .foregroundColor(Theme.green)
                                Text(NSLocalizedString("settings.token.ok.desc", comment: ""))
                                    .font(Theme.mono(8))
                                    .foregroundColor(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        HStack(spacing: 10) {
                            Button(action: {
                                tokenTracker.applyRecommendedMinimumLimits()
                            }) {
                                Text(NSLocalizedString("settings.token.apply.min", comment: ""))
                                    .font(Theme.mono(9, weight: .bold))
                                    .foregroundColor(Theme.cyan)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.cyan.opacity(0.1)))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Theme.cyan.opacity(0.25), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                showTokenResetConfirm = true
                            }) {
                                Text(NSLocalizedString("settings.token.reset", comment: ""))
                                    .font(Theme.mono(9, weight: .bold))
                                    .foregroundColor(Theme.orange)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.orange.opacity(0.1)))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Theme.orange.opacity(0.25), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.bgSurface.opacity(0.85))
                    )
                }
            }

            settingsSection(title: NSLocalizedString("settings.automation", comment: ""), subtitle: NSLocalizedString("settings.automation.subtitle", comment: "")) {
                VStack(spacing: 10) {
                    settingsToggleRow(
                        title: NSLocalizedString("settings.automation.parallel", comment: ""),
                        subtitle: settings.allowParallelSubagents ? NSLocalizedString("settings.automation.allowed", comment: "") : NSLocalizedString("settings.automation.blocked", comment: ""),
                        isOn: Binding(
                            get: { settings.allowParallelSubagents },
                            set: { settings.allowParallelSubagents = $0 }
                        ),
                        tint: Theme.purple
                    )

                    settingsToggleRow(
                        title: NSLocalizedString("settings.automation.terminal.light", comment: ""),
                        subtitle: settings.terminalSidebarLightweight ? NSLocalizedString("settings.enabled", comment: "") : NSLocalizedString("settings.disabled", comment: ""),
                        isOn: Binding(
                            get: { settings.terminalSidebarLightweight },
                            set: { settings.terminalSidebarLightweight = $0 }
                        ),
                        tint: Theme.cyan
                    )

                    HStack(spacing: 10) {
                        limitStepperCard(
                            title: NSLocalizedString("settings.automation.review.max", comment: ""),
                            subtitle: NSLocalizedString("settings.automation.review.sub", comment: ""),
                            value: Binding(
                                get: { settings.reviewerMaxPasses },
                                set: { settings.reviewerMaxPasses = min(3, max(0, $0)) }
                            ),
                            range: 0...3,
                            tint: Theme.yellow
                        )
                        limitStepperCard(
                            title: "QA 최대",
                            subtitle: NSLocalizedString("settings.automation.qa.sub", comment: ""),
                            value: Binding(
                                get: { settings.qaMaxPasses },
                                set: { settings.qaMaxPasses = min(3, max(0, $0)) }
                            ),
                            range: 0...3,
                            tint: Theme.green
                        )
                    }

                    limitStepperCard(
                        title: NSLocalizedString("settings.automation.revision.max", comment: ""),
                        subtitle: NSLocalizedString("settings.automation.revision.sub", comment: ""),
                        value: Binding(
                            get: { settings.automationRevisionLimit },
                            set: { settings.automationRevisionLimit = min(5, max(1, $0)) }
                        ),
                        range: 1...5,
                        tint: Theme.accent
                    )

                    HStack(spacing: 8) {
                        Image(systemName: "person.3.sequence.fill")
                            .font(.system(size: Theme.iconSize(11), weight: .bold))
                            .foregroundColor(Theme.orange)
                        Text(NSLocalizedString("settings.automation.worker.limit", comment: ""))
                            .font(Theme.mono(8))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.orange.opacity(0.08))
                    )
                }
            }
        }
    }

    private var templateTab: some View {
        let selectedKind = selectedTemplateKind
        let templateBinding = templateStore.binding(for: selectedKind)

        return VStack(spacing: 14) {
            settingsSection(title: NSLocalizedString("settings.template.workflow", comment: ""), subtitle: selectedKind.displayName) {
                VStack(alignment: .leading, spacing: 10) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                        ForEach(AutomationTemplateKind.allCases) { kind in
                            templateKindButton(kind)
                        }
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: selectedKind.icon)
                            .font(.system(size: Theme.iconSize(11), weight: .bold))
                            .foregroundColor(Theme.cyan)
                        Text(selectedKind.summary)
                            .font(Theme.mono(8))
                            .foregroundColor(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            settingsSection(title: NSLocalizedString("settings.template.editor", comment: ""), subtitle: NSLocalizedString("settings.template.autosave", comment: "")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        statusHint(
                            icon: templateStore.isCustomized(selectedKind) ? "slider.horizontal.3" : "checkmark.circle.fill",
                            text: templateStore.isCustomized(selectedKind) ? NSLocalizedString("settings.template.custom", comment: "") : NSLocalizedString("settings.template.default", comment: ""),
                            tint: templateStore.isCustomized(selectedKind) ? Theme.orange : Theme.green
                        )
                        Spacer()
                        Button(action: {
                            templateStore.reset(selectedKind)
                        }) {
                            Text(NSLocalizedString("settings.template.reset.current", comment: ""))
                                .font(Theme.mono(9, weight: .bold))
                                .appButtonSurface(tone: .orange, compact: true)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            showTemplateResetConfirm = true
                        }) {
                            Text(NSLocalizedString("settings.template.reset.all", comment: ""))
                                .font(Theme.mono(9, weight: .bold))
                                .appButtonSurface(tone: .red, compact: true)
                        }
                        .buttonStyle(.plain)
                    }

                    TextEditor(text: templateBinding)
                        .scrollContentBackground(.hidden)
                        .font(Theme.mono(10))
                        .foregroundColor(Theme.textPrimary)
                        .frame(minHeight: 260)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.bgSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.border.opacity(0.35), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("settings.template.placeholders", comment: ""))
                            .font(Theme.mono(9, weight: .bold))
                            .foregroundColor(Theme.textDim)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                            ForEach(selectedKind.placeholderTokens, id: \.self) { token in
                                templateTokenPill(token, tint: Theme.cyan)
                            }
                        }
                    }

                    if !selectedKind.pinnedLines.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("settings.template.pinned", comment: ""))
                                .font(Theme.mono(9, weight: .bold))
                                .foregroundColor(Theme.textDim)
                            Text(NSLocalizedString("settings.template.pinned.desc", comment: ""))
                                .font(Theme.mono(8))
                                .foregroundColor(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                                ForEach(selectedKind.pinnedLines, id: \.self) { line in
                                    templateTokenPill(line, tint: Theme.purple)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 플러그인 탭

    private var pluginTab: some View {
        VStack(spacing: 14) {
            settingsSection(title: NSLocalizedString("plugin.section.add", comment: ""), subtitle: NSLocalizedString("plugin.section.add.subtitle", comment: "")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        TextField(NSLocalizedString("plugin.input.placeholder", comment: ""), text: $pluginSourceInput)
                            .font(Theme.mono(10)).textFieldStyle(.plain)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.5), lineWidth: 1))
                            .onSubmit { installPlugin() }

                        Button(action: { installPlugin() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: Theme.iconSize(11), weight: .bold))
                                Text(NSLocalizedString("plugin.btn.install", comment: ""))
                                    .font(Theme.mono(9, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(pluginManager.isInstalling ? Theme.textDim : Theme.accent))
                        }
                        .buttonStyle(.plain)
                        .disabled(pluginManager.isInstalling || pluginSourceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    // 로컬 폴더 선택 + 새 플러그인 생성
                    HStack(spacing: 8) {
                        Button(action: { pickLocalPluginFolder() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: Theme.iconSize(10), weight: .medium))
                                Text(NSLocalizedString("plugin.btn.local", comment: ""))
                                    .font(Theme.mono(9, weight: .medium))
                            }
                            .foregroundColor(Theme.cyan)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.cyan.opacity(0.08)))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.cyan.opacity(0.2), lineWidth: 1))
                        }.buttonStyle(.plain)

                        Button(action: { showPluginScaffold = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "hammer.fill")
                                    .font(.system(size: Theme.iconSize(10), weight: .medium))
                                Text(NSLocalizedString("plugin.btn.create", comment: ""))
                                    .font(Theme.mono(9, weight: .medium))
                            }
                            .foregroundColor(Theme.green)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.green.opacity(0.08)))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.green.opacity(0.2), lineWidth: 1))
                        }.buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        pluginFormatHint(icon: "mug.fill", text: NSLocalizedString("plugin.format.brew", comment: ""), example: "formula-name")
                        pluginFormatHint(icon: "arrow.triangle.branch", text: NSLocalizedString("plugin.format.tap", comment: ""), example: "user/tap/formula")
                        pluginFormatHint(icon: "link", text: NSLocalizedString("plugin.format.url", comment: ""), example: "https://…/plugin.tar.gz")
                        pluginFormatHint(icon: "folder.fill", text: NSLocalizedString("plugin.format.local", comment: ""), example: "~/my-plugins/my-plugin")
                    }

                    if pluginManager.isInstalling {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(pluginManager.installProgress)
                                .font(Theme.mono(9))
                                .foregroundColor(Theme.cyan)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.cyan.opacity(0.08)))
                    }

                    if let error = pluginManager.lastError {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: Theme.iconSize(11), weight: .bold))
                                .foregroundColor(Theme.red)
                            Text(error)
                                .font(Theme.mono(8))
                                .foregroundColor(Theme.red)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Button(action: { pluginManager.lastError = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.textDim)
                            }.buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.red.opacity(0.08)))
                    }
                }
            }

            settingsSection(
                title: NSLocalizedString("plugin.section.installed", comment: ""),
                subtitle: String(format: NSLocalizedString("plugin.section.installed.count", comment: ""),
                                 pluginManager.plugins.count,
                                 pluginManager.plugins.filter { $0.enabled }.count)
            ) {
                if pluginManager.plugins.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.system(size: Theme.iconSize(14), weight: .light))
                            .foregroundColor(Theme.textDim)
                        Text(NSLocalizedString("plugin.empty", comment: ""))
                            .font(Theme.mono(10))
                            .foregroundColor(Theme.textDim)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 8) {
                        ForEach(pluginManager.plugins) { plugin in
                            pluginRow(plugin)
                        }
                    }
                }
            }

            // 마켓플레이스
            settingsSection(
                title: NSLocalizedString("plugin.marketplace", comment: ""),
                subtitle: pluginManager.isLoadingRegistry
                    ? NSLocalizedString("plugin.marketplace.loading", comment: "")
                    : String(format: NSLocalizedString("plugin.marketplace.count", comment: ""), pluginManager.registryPlugins.count)
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Button(action: { pluginManager.fetchRegistry() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: Theme.iconSize(10), weight: .bold))
                                Text(NSLocalizedString("plugin.marketplace.refresh", comment: ""))
                                    .font(Theme.mono(9, weight: .medium))
                            }
                            .foregroundStyle(Theme.accentBackground)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent.opacity(0.08)))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accent.opacity(0.2), lineWidth: 1))
                        }.buttonStyle(.plain)
                        .disabled(pluginManager.isLoadingRegistry)

                        // 일괄 업데이트 버튼
                        if !pluginManager.updatablePlugins.isEmpty {
                            Button(action: { pluginManager.updateAllPlugins() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: Theme.iconSize(10), weight: .bold))
                                    Text(String(format: NSLocalizedString("plugin.update.count", comment: ""), pluginManager.updatablePlugins.count))
                                        .font(Theme.mono(9, weight: .medium))
                                }
                                .foregroundColor(Theme.green)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.green.opacity(0.08)))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.green.opacity(0.2), lineWidth: 1))
                            }.buttonStyle(.plain)
                        }

                        Spacer()

                        Text(NSLocalizedString("plugin.marketplace.hint", comment: ""))
                            .font(Theme.mono(7))
                            .foregroundColor(Theme.textDim)
                    }

                    // 검색바
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.textDim)
                        TextField(NSLocalizedString("plugin.search.placeholder", comment: ""), text: $pluginManager.searchQuery)
                            .font(Theme.mono(10)).textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.5), lineWidth: 1))

                    // 태그 필터
                    if !pluginManager.allRegistryTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(pluginManager.allRegistryTags.prefix(10), id: \.tag) { item in
                                    let isSelected = pluginManager.selectedTags.contains(item.tag)
                                    Button(action: {
                                        if isSelected { pluginManager.selectedTags.remove(item.tag) }
                                        else { pluginManager.selectedTags.insert(item.tag) }
                                    }) {
                                        HStack(spacing: 3) {
                                            Text("#\(item.tag)")
                                                .font(Theme.mono(8, weight: isSelected ? .bold : .regular))
                                            Text("\(item.count)")
                                                .font(Theme.mono(7))
                                                .foregroundColor(isSelected ? Theme.accent : Theme.textDim)
                                        }
                                        .foregroundColor(isSelected ? Theme.accent : Theme.textSecondary)
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(isSelected ? Theme.accent.opacity(0.12) : Theme.bgSurface)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(isSelected ? Theme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                                        )
                                    }.buttonStyle(.plain)
                                }

                                if !pluginManager.selectedTags.isEmpty {
                                    Button(action: { pluginManager.selectedTags.removeAll() }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(Theme.textDim)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if pluginManager.isLoadingRegistry {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(NSLocalizedString("plugin.marketplace.loading", comment: ""))
                                .font(Theme.mono(9)).foregroundColor(Theme.textDim)
                        }
                    }

                    if let error = pluginManager.registryError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10)).foregroundColor(Theme.orange)
                            Text(error)
                                .font(Theme.mono(8)).foregroundColor(Theme.orange)
                                .lineLimit(2)
                        }
                    }

                    let filtered = pluginManager.filteredRegistryPlugins
                    if !filtered.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(filtered) { item in
                                marketplaceRow(item)
                            }
                        }
                    } else if !pluginManager.isLoadingRegistry && pluginManager.registryError == nil {
                        HStack(spacing: 8) {
                            Image(systemName: pluginManager.searchQuery.isEmpty && pluginManager.selectedTags.isEmpty ? "tray" : "magnifyingglass")
                                .font(.system(size: Theme.iconSize(12), weight: .light))
                                .foregroundColor(Theme.textDim)
                            Text(pluginManager.searchQuery.isEmpty && pluginManager.selectedTags.isEmpty
                                 ? NSLocalizedString("plugin.marketplace.empty", comment: "")
                                 : NSLocalizedString("plugin.search.empty", comment: ""))
                                .font(Theme.mono(9)).foregroundColor(Theme.textDim)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                }
            }

            // 정보
            settingsSection(title: NSLocalizedString("plugin.section.info", comment: ""), subtitle: NSLocalizedString("plugin.section.info.subtitle", comment: "")) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: Theme.iconSize(11), weight: .bold))
                        .foregroundStyle(Theme.accentBackground)
                    Text(NSLocalizedString("plugin.info.desc", comment: ""))
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear {
            if pluginManager.registryPlugins.isEmpty && !pluginManager.isLoadingRegistry {
                pluginManager.fetchRegistry()
            }
            pluginManager.startWatchingLocalPlugins()
        }
        .onDisappear {
            pluginManager.stopWatchingAll()
        }
        .alert(NSLocalizedString("plugin.confirm.uninstall", comment: ""), isPresented: $showPluginUninstallConfirm) {
            Button(NSLocalizedString("delete", comment: ""), role: .destructive) {
                if let plugin = pluginToUninstall {
                    pluginManager.uninstall(plugin)
                    pluginToUninstall = nil
                }
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { pluginToUninstall = nil }
        } message: {
            Text(String(format: NSLocalizedString("plugin.confirm.uninstall.msg", comment: ""), pluginToUninstall?.name ?? ""))
        }
        .alert(NSLocalizedString("plugin.permission.title", comment: ""),
               isPresented: Binding(
                   get: { pluginManager.pendingPermission != nil },
                   set: { if !$0 { pluginManager.denyPermission() } }
               )) {
            Button(NSLocalizedString("plugin.permission.allow", comment: "")) {
                pluginManager.approvePermission(alwaysTrust: false)
            }
            Button(NSLocalizedString("plugin.permission.always", comment: "")) {
                pluginManager.approvePermission(alwaysTrust: true)
            }
            Button(NSLocalizedString("plugin.permission.deny", comment: ""), role: .cancel) {
                pluginManager.denyPermission()
            }
        } message: {
            if let req = pluginManager.pendingPermission {
                Text(String(format: NSLocalizedString("plugin.permission.desc", comment: ""),
                            req.pluginName, URL(fileURLWithPath: req.scriptPath).lastPathComponent))
            }
        }
        .sheet(isPresented: $showPluginScaffold) {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: Theme.iconSize(14), weight: .bold))
                        .foregroundColor(Theme.green)
                    Text(NSLocalizedString("plugin.scaffold.title", comment: ""))
                        .font(Theme.mono(13, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Button(action: { showPluginScaffold = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textDim)
                    }.buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("plugin.scaffold.name.label", comment: ""))
                        .font(Theme.mono(10, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                    TextField(NSLocalizedString("plugin.scaffold.name.placeholder", comment: ""), text: $scaffoldName)
                        .font(Theme.mono(11)).textFieldStyle(.plain)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("plugin.scaffold.desc", comment: ""))
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Spacer()
                    Button(action: { showPluginScaffold = false }) {
                        Text(NSLocalizedString("cancel", comment: ""))
                            .font(Theme.mono(10, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface))
                    }.buttonStyle(.plain)

                    Button(action: { scaffoldNewPlugin() }) {
                        Text(NSLocalizedString("plugin.scaffold.btn", comment: ""))
                            .font(Theme.mono(10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(scaffoldName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.textDim : Theme.green))
                    }
                    .buttonStyle(.plain)
                    .disabled(scaffoldName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
            .frame(width: 400)
            .background(Theme.bg)
            .dofficeSheetPresentation()
        }
    }

    private func installPlugin() {
        let source = pluginSourceInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return }
        pluginManager.install(source: source)
        pluginSourceInput = ""
    }

    private func pickLocalPluginFolder() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = NSLocalizedString("plugin.picker.message", comment: "")
        panel.prompt = NSLocalizedString("plugin.picker.prompt", comment: "")
        if panel.runModal() == .OK, let url = panel.url {
            pluginManager.install(source: url.path)
        }
        #endif
    }

    private func scaffoldNewPlugin() {
        let name = scaffoldName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = NSLocalizedString("plugin.scaffold.pick.dir", comment: "")
        panel.prompt = NSLocalizedString("plugin.scaffold.pick.prompt", comment: "")
        if panel.runModal() == .OK, let url = panel.url {
            if let pluginPath = pluginManager.scaffold(name: name, at: url.path) {
                pluginManager.install(source: pluginPath)
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: pluginPath)
            }
        }
        #endif
        scaffoldName = ""
        showPluginScaffold = false
    }

    private func pluginTypeIcon(_ type: PluginEntry.SourceType) -> String {
        switch type {
        case .brewFormula, .brewTap: return "mug.fill"
        case .rawURL: return "link.circle.fill"
        case .local: return "folder.circle.fill"
        }
    }

    private func pluginRow(_ plugin: PluginEntry) -> some View {
        let isExpanded = expandedPluginId == plugin.id
        let hasUpdate = pluginManager.hasUpdate(plugin)
        let badges = pluginManager.contributionSummary(for: plugin)
        let depIssues = pluginManager.validateDependencies(for: plugin.localPath)

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                // 확장 토글
                Button(action: { withAnimation(.easeOut(duration: 0.2)) {
                    expandedPluginId = isExpanded ? nil : plugin.id
                }}) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.textDim)
                        .frame(width: 12)
                }.buttonStyle(.plain)

                Image(systemName: pluginTypeIcon(plugin.sourceType))
                    .font(.system(size: Theme.iconSize(14), weight: .bold))
                    .foregroundColor(plugin.enabled ? Theme.accent : Theme.textDim)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(plugin.name)
                            .font(Theme.mono(10, weight: .bold))
                            .foregroundColor(plugin.enabled ? Theme.textPrimary : Theme.textDim)
                        // 업데이트 배지
                        if hasUpdate, let newVer = pluginManager.availableVersion(for: plugin) {
                            Text("v\(newVer)")
                                .font(Theme.mono(7, weight: .bold))
                                .foregroundColor(Theme.green)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.green.opacity(0.12)))
                        }
                        // 신뢰 상태
                        if pluginManager.isPluginTrusted(plugin.name) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.green.opacity(0.7))
                                .help(NSLocalizedString("plugin.permission.trusted", comment: ""))
                        }
                        // 의존성 경고
                        if !depIssues.isEmpty {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.orange)
                                .help(depIssues.map { $0.localizedMessage }.joined(separator: "\n"))
                        }
                    }
                    HStack(spacing: 6) {
                        Text("v\(plugin.version)")
                            .font(Theme.mono(8))
                            .foregroundColor(Theme.textDim)
                        Text("\u{00B7}").foregroundColor(Theme.textDim)
                        Text(plugin.source)
                            .font(Theme.mono(8))
                            .foregroundColor(Theme.textDim)
                            .lineLimit(1).truncationMode(.middle)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { plugin.enabled },
                    set: { _ in pluginManager.toggleEnabled(plugin) }
                ))
                .toggleStyle(.switch).tint(Theme.green).labelsHidden().controlSize(.mini)

                // 업데이트 버튼
                if hasUpdate {
                    Button(action: { pluginManager.updatePlugin(plugin) }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: Theme.iconSize(12), weight: .medium))
                            .foregroundColor(Theme.green)
                    }.buttonStyle(.plain)
                }

                #if os(macOS)
                // 내보내기
                Button(action: { pluginManager.exportPlugin(plugin) }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: Theme.iconSize(11), weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }.buttonStyle(.plain)
                .help(NSLocalizedString("plugin.export", comment: ""))

                // Finder에서 열기
                Button(action: { pluginManager.revealInFinder(plugin) }) {
                    Image(systemName: "folder")
                        .font(.system(size: Theme.iconSize(11), weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }.buttonStyle(.plain)

                // brew 업그레이드 (brew만)
                if plugin.sourceType == .brewFormula || plugin.sourceType == .brewTap {
                    Button(action: { pluginManager.upgrade(plugin) }) {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.system(size: Theme.iconSize(12), weight: .medium))
                            .foregroundColor(Theme.cyan)
                    }.buttonStyle(.plain)
                }
                #endif

                Button(action: {
                    pluginToUninstall = plugin
                    showPluginUninstallConfirm = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: Theme.iconSize(11), weight: .medium))
                        .foregroundColor(Theme.red.opacity(0.7))
                }.buttonStyle(.plain)
            }
            .padding(10)

            // 확장 상세 정보
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // 기여 배지
                    if !badges.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                                    HStack(spacing: 3) {
                                        Image(systemName: badge.icon)
                                            .font(.system(size: 9, weight: .medium))
                                        Text("\(badge.label) \(badge.count)")
                                            .font(Theme.mono(8, weight: .medium))
                                    }
                                    .foregroundColor(Theme.accent)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent.opacity(0.08)))
                                }
                            }
                        }
                    }

                    // 의존성 경고
                    if !depIssues.isEmpty {
                        ForEach(Array(depIssues.enumerated()), id: \.offset) { _, issue in
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9)).foregroundColor(Theme.orange)
                                Text(issue.localizedMessage)
                                    .font(Theme.mono(8)).foregroundColor(Theme.orange)
                            }
                        }
                    }

                    // 개별 확장 포인트 토글
                    extensionToggles(for: plugin)

                    // 충돌 경고
                    let conflicts = pluginManager.conflicts(for: plugin.name)
                    if !conflicts.isEmpty {
                        ForEach(Array(conflicts.enumerated()), id: \.offset) { _, conflict in
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                                    .font(.system(size: 9)).foregroundColor(Theme.red)
                                Text(conflict.localizedMessage)
                                    .font(Theme.mono(7)).foregroundColor(Theme.red)
                            }
                        }
                    }

                    // 설치 정보
                    HStack(spacing: 10) {
                        Text(String(format: NSLocalizedString("plugin.detail.installed", comment: ""), plugin.installedAt.formatted(.dateTime.year().month().day())))
                            .font(Theme.mono(7)).foregroundColor(Theme.textDim)
                        Text(String(format: NSLocalizedString("plugin.detail.type", comment: ""), plugin.sourceType.rawValue))
                            .font(Theme.mono(7)).foregroundColor(Theme.textDim)
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(plugin.enabled ? Theme.bgSurface : Theme.bgSurface.opacity(0.4)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(
            hasUpdate ? Theme.green.opacity(0.4) : (plugin.enabled ? Theme.border.opacity(0.4) : Theme.border.opacity(0.2)),
            lineWidth: hasUpdate ? 1.5 : 1
        ))
    }

    @ViewBuilder
    private func extensionToggles(for plugin: PluginEntry) -> some View {
        let baseURL = URL(fileURLWithPath: plugin.localPath)
        let manifestURL = baseURL.appendingPathComponent("plugin.json")

        if let data = try? Data(contentsOf: manifestURL),
           let manifest = try? JSONDecoder().decode(PluginManifest.self, from: data),
           let c = manifest.contributes {
            let allExtensions = collectExtensionIds(pluginName: manifest.name, contributes: c)
            if !allExtensions.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(allExtensions, id: \.id) { ext in
                        HStack(spacing: 6) {
                            Image(systemName: ext.icon)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(pluginManager.isExtensionEnabled(ext.id) ? Theme.accent : Theme.textDim)
                                .frame(width: 12)
                            Text(ext.label)
                                .font(Theme.mono(8))
                                .foregroundColor(pluginManager.isExtensionEnabled(ext.id) ? Theme.textPrimary : Theme.textDim)
                            Spacer()
                            Button(action: { pluginManager.toggleExtension(ext.id) }) {
                                Text(pluginManager.isExtensionEnabled(ext.id)
                                     ? NSLocalizedString("plugin.extension.enable", comment: "")
                                     : NSLocalizedString("plugin.extension.disable", comment: ""))
                                    .font(Theme.mono(7, weight: .medium))
                                    .foregroundColor(pluginManager.isExtensionEnabled(ext.id) ? Theme.green : Theme.textDim)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(RoundedRectangle(cornerRadius: 4).fill(
                                        pluginManager.isExtensionEnabled(ext.id) ? Theme.green.opacity(0.08) : Theme.bgSurface
                                    ))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface.opacity(0.5)))
            }
        }
    }

    private struct ExtensionInfo: Identifiable {
        let id: String
        let icon: String
        let label: String
    }

    private func collectExtensionIds(pluginName: String, contributes c: PluginManifest.PluginContributions) -> [ExtensionInfo] {
        var items: [ExtensionInfo] = []
        if let themes = c.themes {
            for t in themes {
                items.append(ExtensionInfo(id: "\(pluginName)::\(t.id)", icon: "paintpalette.fill", label: t.name))
            }
        }
        if let effects = c.effects {
            for e in effects {
                items.append(ExtensionInfo(id: "\(pluginName)::\(e.id)", icon: "sparkles", label: "\(e.type) → \(e.trigger)"))
            }
        }
        if let panels = c.panels {
            for p in panels {
                items.append(ExtensionInfo(id: "\(pluginName)::\(p.id)", icon: "rectangle.on.rectangle", label: p.title))
            }
        }
        if let commands = c.commands {
            for cmd in commands {
                items.append(ExtensionInfo(id: "\(pluginName)::\(cmd.id)", icon: "terminal", label: cmd.title))
            }
        }
        if let achievements = c.achievements {
            for a in achievements {
                items.append(ExtensionInfo(id: "\(pluginName)::\(a.id)", icon: "trophy.fill", label: a.name))
            }
        }
        return items
    }

    private func pluginFormatHint(icon: String, text: String, example: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: Theme.iconSize(9), weight: .medium))
                .foregroundColor(Theme.textDim)
                .frame(width: 14)
            Text(text)
                .font(Theme.mono(8))
                .foregroundColor(Theme.textDim)
            Text(example)
                .font(Theme.mono(8, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.bgSurface))
        }
    }

    private func marketplaceRow(_ item: RegistryPlugin) -> some View {
        let installed = pluginManager.isInstalled(item)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("v\(item.version)")
                        .font(Theme.mono(7))
                        .foregroundColor(Theme.textDim)
                    if item.characterCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 7))
                            Text("\(item.characterCount)")
                                .font(Theme.mono(7, weight: .medium))
                        }
                        .foregroundColor(Theme.purple)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Theme.purple.opacity(0.1)))
                    }
                }
                Text(item.description)
                    .font(Theme.mono(8))
                    .foregroundColor(Theme.textDim)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("by \(item.author)")
                        .font(Theme.mono(7))
                        .foregroundColor(Theme.textDim)
                    if !item.tags.isEmpty {
                        ForEach(item.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(Theme.mono(6, weight: .medium))
                                .foregroundColor(Theme.cyan)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(RoundedRectangle(cornerRadius: 3).fill(Theme.cyan.opacity(0.08)))
                        }
                    }
                }
            }

            Spacer()

            if installed {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                    Text(NSLocalizedString("plugin.marketplace.installed", comment: ""))
                        .font(Theme.mono(8, weight: .medium))
                }
                .foregroundColor(Theme.green)
            } else {
                Button(action: { pluginManager.installFromRegistry(item) }) {
                    Text(NSLocalizedString("plugin.btn.install", comment: ""))
                        .font(Theme.mono(9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accentBackground))
                }
                .buttonStyle(.plain)
                .disabled(pluginManager.isInstalling)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgSurface))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border.opacity(0.3), lineWidth: 1))
    }

    private var supportTab: some View {
        VStack(spacing: 14) {
            CoffeeSupportPopoverView(embedded: true)
        }
    }

    // MARK: - 보안 탭

    private var securityTab: some View {
        VStack(spacing: 14) {
            // 세션 잠금 + 결제일
            settingsSection(title: NSLocalizedString("settings.security.session", comment: ""), subtitle: settings.lockPIN.isEmpty ? NSLocalizedString("settings.security.lock.off", comment: "") : NSLocalizedString("settings.security.lock.on", comment: "")) {
                VStack(spacing: 10) {
                    securityRow(label: NSLocalizedString("settings.security.pin", comment: "")) {
                        SecureField(NSLocalizedString("settings.security.pin.placeholder", comment: ""), text: $settings.lockPIN)
                            .font(Theme.monoSmall).textFieldStyle(.plain)
                            .frame(width: 100).padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 0.5))
                    }
                    securityRow(label: NSLocalizedString("settings.security.autolock", comment: "")) {
                        Picker("", selection: $settings.autoLockMinutes) {
                            Text(NSLocalizedString("settings.none", comment: "")).tag(0)
                            Text(NSLocalizedString("settings.1min", comment: "")).tag(1); Text(NSLocalizedString("settings.3min", comment: "")).tag(3)
                            Text(NSLocalizedString("settings.5min", comment: "")).tag(5); Text(NSLocalizedString("settings.10min", comment: "")).tag(10)
                        }.frame(width: 120)
                    }
                    securityRow(label: NSLocalizedString("settings.security.billing", comment: "")) {
                        Picker("", selection: $settings.billingDay) {
                            Text(NSLocalizedString("settings.notset", comment: "")).tag(0)
                            ForEach(1...31, id: \.self) { day in Text(String(format: NSLocalizedString("settings.day.format", comment: ""), day)).tag(day) }
                        }.frame(width: 100)
                    }
                }
            }

            // 비용 제한
            settingsSection(title: NSLocalizedString("settings.security.cost", comment: ""), subtitle: settings.dailyCostLimit > 0 ? "$\(String(format: "%.0f", settings.dailyCostLimit))/" + NSLocalizedString("settings.day", comment: "") : NSLocalizedString("settings.unlimited", comment: "")) {
                VStack(spacing: 10) {
                    securityRow(label: NSLocalizedString("settings.security.cost.daily", comment: "")) {
                        TextField("0", value: $settings.dailyCostLimit, format: .number)
                            .font(Theme.monoSmall).textFieldStyle(.plain)
                            .frame(width: 80).padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 0.5))
                    }
                    securityRow(label: NSLocalizedString("settings.security.cost.session", comment: "")) {
                        TextField("0", value: $settings.perSessionCostLimit, format: .number)
                            .font(Theme.monoSmall).textFieldStyle(.plain)
                            .frame(width: 80).padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 0.5))
                    }
                    Toggle(NSLocalizedString("settings.security.cost.warn80", comment: ""), isOn: $settings.costWarningAt80)
                        .font(Theme.mono(10, weight: .medium))
                        .tint(Theme.accent)
                }
            }

            // 보호 기능 통합
            settingsSection(title: NSLocalizedString("settings.security.protection", comment: ""), subtitle: NSLocalizedString("settings.security.protection.subtitle", comment: "")) {
                VStack(spacing: 10) {
                    Toggle(NSLocalizedString("settings.security.danger.detect", comment: ""), isOn: Binding(
                        get: { DangerousCommandDetector.shared.enabled },
                        set: { DangerousCommandDetector.shared.enabled = $0 }
                    )).font(Theme.mono(10, weight: .medium)).tint(Theme.accent)

                    Toggle(NSLocalizedString("settings.security.sensitive.file", comment: ""), isOn: Binding(
                        get: { SensitiveFileShield.shared.enabled },
                        set: { SensitiveFileShield.shared.enabled = $0 }
                    )).font(Theme.mono(10, weight: .medium)).tint(Theme.accent)

                    Toggle(NSLocalizedString("settings.security.audit.log", comment: ""), isOn: Binding(
                        get: { AuditLog.shared.enabled },
                        set: { AuditLog.shared.enabled = $0 }
                    )).font(Theme.mono(10, weight: .medium)).tint(Theme.accent)

                    HStack(spacing: 8) {
                        Button(action: {
                            if let data = AuditLog.shared.exportJSON() {
                                let panel = NSSavePanel()
                                panel.nameFieldStringValue = "workman_audit_log.json"
                                panel.allowedContentTypes = [.json]
                                if panel.runModal() == .OK, let url = panel.url {
                                    try? data.write(to: url)
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.doc").font(.system(size: 10))
                                Text(NSLocalizedString("settings.security.log.export", comment: "")).font(Theme.mono(9, weight: .medium))
                            }
                            .foregroundStyle(Theme.accentBackground)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accent.opacity(0.08)))
                        }.buttonStyle(.plain)

                        Button(action: { AuditLog.shared.clear() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash").font(.system(size: 10))
                                Text(NSLocalizedString("settings.security.log.delete", comment: "")).font(Theme.mono(9, weight: .medium))
                            }
                            .foregroundColor(Theme.red)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.red.opacity(0.08)))
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 데이터 탭

    private var dataTab: some View {
        VStack(spacing: 14) {
            settingsSection(title: NSLocalizedString("settings.data.storage", comment: ""), subtitle: cacheSize) {
                VStack(alignment: .leading, spacing: 12) {
                    dataRow(icon: "doc.text.fill", title: NSLocalizedString("settings.data.sessions", comment: ""), detail: String(format: NSLocalizedString("settings.data.count", comment: ""), SessionStore.shared.sessionCount), tint: Theme.accent)
                    dataRow(icon: "bolt.fill", title: NSLocalizedString("settings.data.tokens", comment: ""), detail: tokenTracker.formatTokens(tokenTracker.weekTokens), tint: Theme.yellow)
                    dataRow(icon: "building.2.fill", title: NSLocalizedString("settings.data.office.layout", comment: ""), detail: "UserDefaults", tint: Theme.cyan)
                    dataRow(icon: "trophy.fill", title: NSLocalizedString("settings.data.achievements", comment: ""), detail: "UserDefaults", tint: Theme.purple)
                    dataRow(icon: "person.2.fill", title: NSLocalizedString("settings.data.characters", comment: ""), detail: "UserDefaults", tint: Theme.green)
                }
            }

            settingsSection(title: NSLocalizedString("settings.data.cache", comment: ""), subtitle: NSLocalizedString("settings.data.cache.subtitle", comment: "")) {
                VStack(spacing: 10) {
                    Button(action: {
                        clearAllMode = false
                        showClearConfirm = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "wind").font(.system(size: Theme.iconSize(11), weight: .bold))
                            Text(NSLocalizedString("settings.data.cache.old", comment: "")).font(Theme.mono(11, weight: .semibold))
                            Spacer()
                            Text(NSLocalizedString("settings.data.cache.old.desc", comment: ""))
                                .font(Theme.mono(8)).foregroundColor(Theme.textDim)
                        }
                        .foregroundColor(Theme.orange)
                        .appButtonSurface(tone: .orange)
                    }.buttonStyle(.plain)

                    Button(action: {
                        clearAllMode = true
                        showClearConfirm = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill").font(.system(size: Theme.iconSize(11), weight: .bold))
                            Text(NSLocalizedString("settings.data.delete.all", comment: "")).font(Theme.mono(11, weight: .semibold))
                            Spacer()
                            Text(NSLocalizedString("settings.data.delete.all.desc", comment: ""))
                                .font(Theme.mono(8)).foregroundColor(Theme.textDim)
                        }
                        .foregroundColor(Theme.red)
                        .appButtonSurface(tone: .red)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Data Helpers

    private func dataRow(icon: String, title: String, detail: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: Theme.iconSize(10), weight: .bold)).foregroundColor(tint)
                .frame(width: 20)
            Text(title).font(Theme.mono(10, weight: .medium)).foregroundColor(Theme.textPrimary)
            Spacer()
            Text(detail).font(Theme.mono(9)).foregroundColor(Theme.textSecondary)
        }
    }

    private func calculateCacheSize() {
        var totalBytes: Int64 = 0
        // Application Support 디렉토리
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let workmanDir = appSupport.appendingPathComponent("WorkMan")
            if let enumerator = FileManager.default.enumerator(at: workmanDir, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let url as URL in enumerator {
                    if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        totalBytes += Int64(size)
                    }
                }
            }
        }
        // UserDefaults 추정 (대략적)
        let udKeys = ["WorkManTokenHistory", "WorkManCharacters", "WorkManCharacterManualUnlocks", "WorkManAchievements"]
        for key in udKeys {
            if let data = UserDefaults.standard.data(forKey: key) {
                totalBytes += Int64(data.count)
            } else if let dict = UserDefaults.standard.dictionary(forKey: key),
                      let data = try? JSONSerialization.data(withJSONObject: dict) {
                totalBytes += Int64(data.count)
            }
        }
        if totalBytes < 1024 {
            cacheSize = "\(totalBytes) B"
        } else if totalBytes < 1024 * 1024 {
            cacheSize = String(format: "%.1f KB", Double(totalBytes) / 1024.0)
        } else {
            cacheSize = String(format: "%.1f MB", Double(totalBytes) / (1024.0 * 1024.0))
        }
    }

    private func clearOldCache() {
        // 완료된 세션 기록만 삭제 (빈 리스트로 저장)
        SessionStore.shared.save(tabs: [])
        // 토큰 이력 중 오래된 것은 TokenTracker가 자동 관리하므로 수동 리셋
        TokenTracker.shared.clearOldEntries()
        calculateCacheSize()
    }

    private func clearAllData() {
        // 세션 기록 삭제
        SessionStore.shared.save(tabs: [])
        // 토큰 데이터 삭제
        TokenTracker.shared.clearAllEntries()
        // 업적 데이터 삭제
        UserDefaults.standard.removeObject(forKey: "WorkManAchievements")
        // 캐릭터 데이터 삭제
        UserDefaults.standard.removeObject(forKey: "WorkManCharacters")
        CharacterRegistry.shared.clearManualUnlocks()
        UserDefaults.standard.removeObject(forKey: "WorkManCharacterManualUnlocks")
        // 오피스 레이아웃 삭제
        for preset in OfficePreset.allCases {
            UserDefaults.standard.removeObject(forKey: "workman.office.layout.\(preset.rawValue).v1")
        }
        // 가구 위치 초기화
        settings.resetFurniturePositions()
        calculateCacheSize()
    }

    private var settingsHeroCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.accent.opacity(0.16),
                            Theme.purple.opacity(0.14),
                            Theme.bgCard
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Theme.border.opacity(0.35), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("settings.title", comment: ""))
                            .font(Theme.mono(16, weight: .black))
                            .foregroundColor(Theme.textPrimary)
                        Text(NSLocalizedString("settings.subtitle", comment: ""))
                            .font(Theme.mono(10))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: Theme.iconSize(15), weight: .bold))
                        .foregroundStyle(Theme.accentBackground)
                        .padding(10)
                        .background(Circle().fill(Theme.accent.opacity(0.12)))
                }

                HStack(spacing: 10) {
                    heroPill(title: settings.appDisplayName, subtitle: "Workspace", tint: Theme.accent)
                    heroPill(title: settings.isDarkMode ? "Dark" : "Light", subtitle: "Theme", tint: Theme.purple)
                    heroPill(title: currentTheme.displayName, subtitle: "Backdrop", tint: Theme.cyan)
                }
            }
            .padding(18)
        }
        .frame(height: 132)
    }

    private func settingsSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.sp3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.mono(11, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(Theme.mono(9))
                    .foregroundColor(Theme.textDim)
            }
            content()
        }
        .padding(Theme.sp4)
        .background(RoundedRectangle(cornerRadius: Theme.cornerLarge).fill(Theme.bgCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerLarge).stroke(Theme.border, lineWidth: 1))
    }

    private func securityRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).font(Theme.mono(10, weight: .medium)).foregroundColor(Theme.textPrimary)
            Spacer()
            content()
        }
    }

    private func labeledField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        emphasized: Bool = false,
        onSubmit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.mono(10, weight: .bold))
                .foregroundColor(Theme.textDim)

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(Theme.mono(11, weight: emphasized ? .semibold : .regular))
                .foregroundColor(Theme.textPrimary)
                .appFieldStyle(emphasized: emphasized)
                .onSubmit { onSubmit() }
                .onChange(of: text.wrappedValue) { _, _ in onSubmit() }
        }
    }

    @ViewBuilder
    private func colorPickerRow(
        label: String,
        color: Binding<Color>,
        savedHex: String?,
        defaultColor: Color,
        onChange: @escaping (String?) -> Void
    ) -> some View {
        let isCustomized = savedHex != nil && !savedHex!.isEmpty
        HStack(spacing: 6) {
            Circle()
                .fill(isCustomized ? color.wrappedValue : Color.clear)
                .frame(width: 7, height: 7)
                .overlay(Circle().stroke(Theme.border, lineWidth: 1))
            Text(label)
                .font(Theme.mono(9))
                .foregroundColor(isCustomized ? Theme.textPrimary : Theme.textSecondary)
            if isCustomized {
                Text("custom")
                    .font(Theme.mono(7, weight: .bold))
                    .foregroundStyle(Theme.accentBackground)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Theme.accent.opacity(0.1)))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.accent.opacity(0.2), lineWidth: 1))
            }
            Spacer()
            ColorPicker("", selection: color, supportsOpacity: false)
                .labelsHidden()
                .onChange(of: color.wrappedValue) { newColor in
                    onChange(newColor.hexString)
                }
            if isCustomized {
                Button(action: {
                    color.wrappedValue = defaultColor
                    onChange(nil)
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textDim)
                }.buttonStyle(.plain)
            }
        }
    }

    private func themeModeButton(title: String, icon: String, mode: String) -> some View {
        let selected = settings.themeMode == mode
        let tint: Color = mode == "dark" ? Theme.yellow : (mode == "custom" ? Theme.purple : Theme.orange)
        return Button(action: {
            guard mode != settings.themeMode else { return }
            pendingThemeMode = mode
            showThemeRestartAlert = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: Theme.iconSize(12)))
                    .foregroundColor(selected ? tint : Theme.textDim)
                Text(title)
                    .font(Theme.mono(10, weight: selected ? .bold : .regular))
                    .foregroundColor(selected ? Theme.textPrimary : Theme.textSecondary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: Theme.iconSize(10)))
                        .foregroundColor(tint)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: Theme.cornerMedium).fill(selected ? tint.opacity(0.1) : Theme.bgSurface.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerMedium).stroke(selected ? tint.opacity(Theme.borderActiveOpacity) : Theme.border.opacity(Theme.borderLight), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private func themeButton(title: String, icon: String, isDark: Bool) -> some View {
        let selected = settings.isDarkMode == isDark
        let tint = isDark ? Theme.yellow : Theme.orange
        return Button(action: { withAnimation(.easeInOut(duration: 0.2)) { settings.isDarkMode = isDark }; settings.requestRefreshIfNeeded() }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: Theme.iconSize(14)))
                    .foregroundColor(selected ? tint : Theme.textDim)
                Text(title)
                    .font(Theme.mono(11, weight: selected ? .bold : .regular))
                    .foregroundColor(selected ? Theme.textPrimary : Theme.textSecondary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: Theme.iconSize(12)))
                        .foregroundColor(tint)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(selected ? tint.opacity(0.1) : Theme.bgSurface.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .stroke(selected ? tint.opacity(Theme.borderActiveOpacity) : Theme.border.opacity(Theme.borderLight), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    struct FontSizeOption {
        let value: Double
        let label: String
    }

    private var fontSizeOptions: [FontSizeOption] {
        [
            FontSizeOption(value: 1.2, label: "S"),
            FontSizeOption(value: 1.5, label: "M"),
            FontSizeOption(value: 1.8, label: "L"),
            FontSizeOption(value: 2.2, label: "XL"),
            FontSizeOption(value: 2.7, label: "XXL"),
        ]
    }

    private func isSelectedSize(_ v: Double) -> Bool {
        abs(settings.fontSizeScale - v) < 0.05
    }

    private var fontSizeLabel: String {
        fontSizeOptions.first(where: { isSelectedSize($0.value) })?.label ?? "\(Int(settings.fontSizeScale * 100))%"
    }

    private func restartApp() {
        SessionManager.shared.saveSessions(immediately: true)
        let appPath = Bundle.main.bundlePath
        let script = "sleep 1; open \"\(appPath)\""
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", script]
        try? task.run()
        // Give the shell process time to start before terminating
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApplication.shared.terminate(nil)
        }
    }

    private var currentTheme: BackgroundTheme {
        BackgroundTheme(rawValue: settings.backgroundTheme) ?? .auto
    }

    private var currentOfficePreset: OfficePreset {
        OfficePreset(rawValue: settings.officePreset) ?? .cozy
    }

    private var quickBackgroundThemes: [BackgroundTheme] {
        [.auto, .sunny, .goldenHour, .moonlit, .rain, .neonCity]
    }

    private func quickBackgroundButton(_ theme: BackgroundTheme) -> some View {
        let selected = currentTheme == theme
        let locked = !theme.isUnlocked
        return Button(action: {
            guard !locked else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.backgroundTheme = theme.rawValue
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: locked ? "lock.fill" : theme.icon)
                    .font(.system(size: Theme.iconSize(10), weight: .bold))
                Text(theme.displayName)
                    .font(Theme.mono(9, weight: selected ? .bold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if locked {
                    Text(theme.lockReason)
                        .font(Theme.mono(7))
                        .foregroundColor(Theme.textDim.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .foregroundColor(locked ? Theme.textDim.opacity(0.5) : (selected ? Theme.purple : Theme.textSecondary))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected && !locked ? Theme.purple.opacity(0.12) : Theme.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(locked ? Theme.border.opacity(0.15) : (selected ? Theme.purple.opacity(0.35) : Theme.border.opacity(0.3)), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func officePresetButton(_ preset: OfficePreset) -> some View {
        let selected = currentOfficePreset == preset
        let tint = Theme.cyan
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.officePreset = preset.rawValue
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: preset.icon)
                    .font(.system(size: Theme.iconSize(12), weight: .bold))
                    .foregroundColor(selected ? tint : Theme.textDim)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.displayName)
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(selected ? Theme.textPrimary : Theme.textSecondary)
                    Text(preset.subtitle)
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                        .lineLimit(2)
                }

                Spacer()

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: Theme.iconSize(12)))
                        .foregroundColor(tint)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(selected ? tint.opacity(0.1) : Theme.bgSurface.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .stroke(selected ? tint.opacity(Theme.borderActiveOpacity) : Theme.border.opacity(Theme.borderLight), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func officeCameraButton(title: String, icon: String, mode: String) -> some View {
        let selected = settings.officeViewMode == mode
        let tint = Theme.purple
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.officeViewMode = mode
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: Theme.iconSize(11), weight: .bold))
                Text(title)
                    .font(Theme.mono(10, weight: .bold))
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: Theme.iconSize(12)))
                        .foregroundColor(tint)
                }
            }
            .foregroundColor(selected ? tint : Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(selected ? tint.opacity(0.1) : Theme.bgSurface.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .stroke(selected ? tint.opacity(Theme.borderActiveOpacity) : Theme.border.opacity(Theme.borderLight), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func templateKindButton(_ kind: AutomationTemplateKind) -> some View {
        let selected = selectedTemplateKind == kind
        let tint = Theme.cyan
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTemplateKind = kind
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: kind.icon)
                    .font(.system(size: Theme.iconSize(11), weight: .bold))
                    .foregroundColor(selected ? tint : Theme.textDim)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.shortLabel)
                        .font(Theme.mono(9, weight: .bold))
                        .foregroundColor(selected ? Theme.textPrimary : Theme.textSecondary)
                    Text(kind.summary)
                        .font(Theme.mono(7))
                        .foregroundColor(Theme.textDim)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: Theme.iconSize(12)))
                        .foregroundColor(tint)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(selected ? tint.opacity(0.1) : Theme.bgSurface.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .stroke(selected ? tint.opacity(Theme.borderActiveOpacity) : Theme.border.opacity(Theme.borderLight), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func templateTokenPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(Theme.mono(8, weight: .semibold))
            .foregroundColor(tint)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(tint.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(tint.opacity(0.22), lineWidth: 1)
            )
    }

    private func heroPill(title: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(subtitle)
                .font(Theme.mono(7, weight: .bold))
                .foregroundColor(tint.opacity(0.75))
            Text(title)
                .font(Theme.mono(10, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.bgSurface.opacity(0.9))
        )
    }

    private func usageMetricCard(
        title: String,
        value: String,
        secondary: String,
        tint: Color,
        progress: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.mono(8, weight: .bold))
                .foregroundColor(Theme.textDim)
            Text(value)
                .font(Theme.mono(13, weight: .black))
                .foregroundColor(tint)
            Text(secondary)
                .font(Theme.mono(8))
                .foregroundColor(Theme.textSecondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.bgSurface)
                    Capsule()
                        .fill(tint.opacity(0.88))
                        .frame(width: max(8, geo.size.width * CGFloat(min(progress, 1.0))))
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.bgSurface.opacity(0.85))
        )
    }

    private func tokenLimitField(title: String, value: Binding<Int>) -> some View {
        let safeBinding = Binding<Int>(
            get: { value.wrappedValue },
            set: { value.wrappedValue = max(1, $0) }
        )
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.mono(9, weight: .bold))
                .foregroundColor(Theme.textDim)
            HStack(spacing: 6) {
                TextField("", value: safeBinding, format: .number)
                    .textFieldStyle(.plain)
                    .font(Theme.mono(11, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.bgSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.border.opacity(0.35), lineWidth: 1)
                    )
                Text("tokens")
                    .font(Theme.mono(8))
                    .foregroundColor(Theme.textDim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusHint(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: Theme.iconSize(10), weight: .bold))
            Text(text)
                .font(Theme.mono(9, weight: .medium))
        }
        .foregroundColor(tint)
    }

    // ── Secret Key ──
    @State private var secretKeyInput = ""
    @State private var secretKeyResult: SecretKeyResult = .none
    enum SecretKeyResult { case none, success, wrong }

    private static let normalizedSecretKey = "i dont like snatch"

    private static func normalizeSecretKey(_ value: String) -> String {
        let folded = value.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current).lowercased()
        let allowed = CharacterSet.alphanumerics.union(.whitespacesAndNewlines)
        let stripped = String(folded.unicodeScalars.filter { allowed.contains($0) })
        return stripped
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func applySecretKey() {
        let key = Self.normalizeSecretKey(secretKeyInput)
        if key == Self.normalizedSecretKey {
            _ = CharacterRegistry.shared.unlockAllCharacters()
            UserDefaults.standard.set(true, forKey: "allContentUnlocked")
            withAnimation(.easeInOut(duration: 0.3)) { secretKeyResult = .success }
            secretKeyInput = ""
        } else {
            withAnimation(.easeInOut(duration: 0.3)) { secretKeyResult = .wrong }
        }
        // 3초 후 결과 메시지 숨기기
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { secretKeyResult = .none }
        }
    }
}

enum CoffeeSupportProvider: String, CaseIterable, Identifiable {
    case kakaoBank
    case toss

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kakaoBank: return NSLocalizedString("coffee.bank.kakao", comment: "")
        case .toss: return NSLocalizedString("coffee.bank.toss", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .kakaoBank: return "building.columns.fill"
        case .toss: return "paperplane.fill"
        }
    }

    var tint: Color {
        switch self {
        case .kakaoBank: return Theme.yellow
        case .toss: return Theme.cyan
        }
    }

    var appURL: URL? {
        switch self {
        case .kakaoBank:
            return URL(string: "kakaobank://")
        case .toss:
            return URL(string: "supertoss://toss/pay")
        }
    }

    var fallbackURL: URL? {
        switch self {
        case .kakaoBank:
            return URL(string: "https://www.kakaobank.com/view/main")
        case .toss:
            return URL(string: "https://toss.im")
        }
    }

    var subtitle: String {
        switch self {
        case .kakaoBank: return NSLocalizedString("coffee.bank.kakao.subtitle", comment: "")
        case .toss: return NSLocalizedString("coffee.bank.toss.subtitle", comment: "")
        }
    }
}

struct CoffeeSupportPopoverView: View {
    @ObservedObject private var settings = AppSettings.shared
    var onRequestSettings: (() -> Void)? = nil
    var embedded: Bool = false

    @State private var feedback: Feedback?
    @State private var copied = false

    private struct Feedback {
        let icon: String
        let text: String
        let tint: Color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 헤더
            HStack(spacing: 12) {
                Text(settings.coffeeSupportDisplayTitle)
                    .font(Theme.mono(14, weight: .black))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }

            // 안내 메시지
            Text(settings.coffeeSupportMessage)
                .font(Theme.mono(9))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if settings.hasCoffeeSupportDestination {
                // 계좌 카드
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(settings.trimmedCoffeeSupportBankName.isEmpty ? NSLocalizedString("coffee.bank.kakao", comment: "") : settings.trimmedCoffeeSupportBankName)
                                .font(Theme.mono(9, weight: .semibold))
                                .foregroundColor(Theme.textDim)
                            Text(settings.trimmedCoffeeSupportAccountNumber.isEmpty ? "7777015832634" : settings.trimmedCoffeeSupportAccountNumber)
                                .font(Theme.mono(15, weight: .black))
                                .foregroundColor(Theme.textPrimary)
                        }
                        Spacer()
                        Button(action: {
                            copySupportAccount(showFeedback: true)
                            withAnimation(.easeInOut(duration: 0.2)) { copied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation { copied = false }
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc.fill")
                                    .font(.system(size: Theme.iconSize(10), weight: .bold))
                                Text(copied ? NSLocalizedString("coffee.copied", comment: "") : NSLocalizedString("coffee.copy", comment: ""))
                                    .font(Theme.mono(9, weight: .bold))
                            }
                            .foregroundColor(copied ? Theme.green : Theme.orange)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Capsule().fill((copied ? Theme.green : Theme.orange).opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.bgSurface.opacity(0.7))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.border.opacity(0.25), lineWidth: 1)
                    )
                }

                // 송금 버튼들
                VStack(spacing: 6) {
                    ForEach(CoffeeSupportProvider.allCases) { provider in
                        providerButton(provider)
                    }
                }

                // 안내
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: Theme.iconSize(9)))
                        .foregroundColor(Theme.textDim)
                    Text(NSLocalizedString("coffee.fallback.info", comment: ""))
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                // 계좌 미설정 상태
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: Theme.iconSize(11), weight: .bold))
                            .foregroundColor(Theme.orange)
                        Text(NSLocalizedString("coffee.setup.hint", comment: ""))
                            .font(Theme.mono(9))
                            .foregroundColor(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let onRequestSettings {
                        Button(action: onRequestSettings) {
                            Text(NSLocalizedString("coffee.open.settings", comment: ""))
                                .font(Theme.mono(9, weight: .bold))
                                .foregroundColor(Theme.orange)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.orange.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bgSurface.opacity(0.5)))
            }

            if let feedback {
                HStack(spacing: 6) {
                    Image(systemName: feedback.icon)
                        .font(.system(size: Theme.iconSize(10), weight: .bold))
                    Text(feedback.text)
                        .font(Theme.mono(8, weight: .medium))
                }
                .foregroundColor(feedback.tint)
                .transition(.opacity)
            }
        }
        .padding(embedded ? 0 : 16)
        .frame(maxWidth: embedded ? .infinity : 320, alignment: .leading)
        .background(embedded ? AnyShapeStyle(.clear) : AnyShapeStyle(Theme.bgCard))
        .clipShape(RoundedRectangle(cornerRadius: embedded ? 0 : 16))
        .overlay(
            RoundedRectangle(cornerRadius: embedded ? 0 : 16)
                .stroke(embedded ? .clear : Theme.border.opacity(0.35), lineWidth: embedded ? 0 : 1)
        )
        .onAppear {
            settings.ensureCoffeeSupportPreset()
        }
    }

    private func providerButton(_ provider: CoffeeSupportProvider) -> some View {
        Button(action: { openProvider(provider) }) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(provider.tint.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: provider.icon)
                        .font(.system(size: Theme.iconSize(14), weight: .bold))
                        .foregroundColor(provider.tint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(provider.title)
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text(provider.subtitle)
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer(minLength: 0)

                Text(NSLocalizedString("coffee.open", comment: ""))
                    .font(Theme.mono(8, weight: .bold))
                    .foregroundColor(provider.tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(provider.tint.opacity(0.1))
                    )
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.bgSurface.opacity(0.65))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(provider.tint.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func openProvider(_ provider: CoffeeSupportProvider) {
        guard copySupportAccount(showFeedback: false) else {
            feedback = Feedback(icon: "exclamationmark.triangle.fill", text: NSLocalizedString("coffee.account.empty", comment: ""), tint: Theme.orange)
            return
        }

        if let appURL = provider.appURL, NSWorkspace.shared.open(appURL) {
            feedback = Feedback(icon: "arrow.up.right.square.fill", text: String(format: NSLocalizedString("coffee.opened", comment: ""), provider.title), tint: provider.tint)
            return
        }

        if let fallbackURL = provider.fallbackURL, NSWorkspace.shared.open(fallbackURL) {
            feedback = Feedback(icon: "safari.fill", text: String(format: NSLocalizedString("coffee.fallback.opened", comment: ""), provider.title), tint: provider.tint)
            return
        }

        feedback = Feedback(icon: "doc.on.doc.fill", text: String(format: NSLocalizedString("coffee.copy.only", comment: ""), provider.title), tint: provider.tint)
    }

    @discardableResult
    private func copySupportAccount(showFeedback: Bool) -> Bool {
        let accountText = settings.coffeeSupportAccountDisplayText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accountText.isEmpty else { return false }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(accountText, forType: .string)

        if showFeedback {
            feedback = Feedback(icon: "doc.on.doc.fill", text: NSLocalizedString("coffee.account.copied", comment: ""), tint: Theme.orange)
        }
        return true
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Accessory View (휴게실 배치 & 가구 설정)
// ═══════════════════════════════════════════════════════

struct AccessoryView: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0  // 0=악세서리, 1=배경

    private let accessoryTabs: [(String, String)] = [("sofa.fill", NSLocalizedString("accessory.tab.furniture", comment: "")), ("photo.fill", NSLocalizedString("accessory.tab.background", comment: ""))]

    var body: some View {
        VStack(spacing: 0) {
            DSModalHeader(
                icon: "paintpalette.fill",
                iconColor: Theme.purple,
                title: NSLocalizedString("accessory.title", comment: ""),
                subtitle: NSLocalizedString("accessory.subtitle", comment: ""),
                onClose: { dismiss() }
            )

            // 탭 선택
            DSTabBar(tabs: accessoryTabs, selectedIndex: $selectedTab)
                .padding(.horizontal, Theme.sp4)
                .padding(.vertical, Theme.sp2)

            Rectangle().fill(Theme.border).frame(height: 1)

            // 탭 내용
            if selectedTab == 0 {
                accessoryTabContent
            } else {
                backgroundTabContent
            }
        }
        .padding(24)
        .background(Theme.bgCard)
    }

    private func tabButton(_ title: String, icon: String, tab: Int) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab } }) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: Theme.iconSize(10)))
                Text(title).font(Theme.mono(11, weight: selectedTab == tab ? .bold : .medium))
            }
            .foregroundColor(selectedTab == tab ? Theme.purple : Theme.textDim)
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(selectedTab == tab ? Theme.purple.opacity(0.1) : .clear)
            .cornerRadius(6)
        }.buttonStyle(.plain)
    }

    // MARK: - 악세서리 탭

    private var accessoryTabContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                // 가구 목록 (미리보기 카드 형식)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(FurnitureItem.all) { item in
                        furnitureCard(item)
                    }
                }

                // ── 가구 배치 ──
                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("accessory.placement", comment: "")).font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)

                    Button(action: { settings.isEditMode = true; dismiss() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.draw.fill").font(.system(size: Theme.iconSize(12))).foregroundColor(Theme.textOnAccent)
                            Text(NSLocalizedString("accessory.drag.hint", comment: "")).font(Theme.mono(11, weight: .bold)).foregroundColor(Theme.textOnAccent)
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill").font(.system(size: Theme.iconSize(14))).foregroundColor(Theme.textOnAccent.opacity(0.7))
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(
                            LinearGradient(colors: [Theme.purple, Theme.accent], startPoint: .leading, endPoint: .trailing)))
                    }.buttonStyle(.plain)

                    Button(action: { settings.resetFurniturePositions() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise").font(.system(size: Theme.iconSize(10))).foregroundColor(Theme.textDim)
                            Text(NSLocalizedString("accessory.reset.placement", comment: "")).font(Theme.mono(10)).foregroundColor(Theme.textSecondary)
                        }
                        .padding(.vertical, 8).padding(.horizontal, 12)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border.opacity(0.3), lineWidth: 0.5)))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 배경 탭

    private var backgroundTabContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 12) {
                HStack {
                    Text(NSLocalizedString("accessory.bg.theme", comment: "")).font(Theme.pixel).foregroundColor(Theme.textDim).tracking(1.5)
                    Spacer()
                    Text(currentTheme.displayName).font(Theme.mono(9, weight: .bold)).foregroundColor(Theme.purple)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(BackgroundTheme.allCases) { theme in
                        bgThemeButton(theme)
                    }
                }
            }
        }
    }

    // MARK: - 가구 카드 (미리보기 포함)

    private func furnitureCard(_ item: FurnitureItem) -> some View {
        let isOn = isFurnitureOn(item.id)
        let locked = !item.isUnlocked
        return Button(action: { guard !locked else { return }; withAnimation(.easeInOut(duration: 0.15)) { toggleFurniture(item.id) } }) {
            VStack(spacing: 6) {
                // 미리보기 영역
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(locked ? Theme.bgSurface.opacity(0.5) : (isOn ? Theme.purple.opacity(0.08) : Theme.bgSurface))
                        .frame(height: 50)

                    // 픽셀 아트 미리보기 (Canvas)
                    Canvas { context, size in
                        let cx = size.width / 2 - item.width / 2
                        let cy = size.height / 2 - item.height / 2 + 2
                        drawFurniturePreview(context: context, item: item, at: CGPoint(x: cx, y: cy))
                    }
                    .frame(height: 50)
                    .opacity(locked ? 0.15 : (isOn ? 1.0 : 0.4))

                    // 잠금 오버레이
                    if locked {
                        VStack(spacing: 2) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: Theme.iconSize(14)))
                                .foregroundColor(Theme.textDim)
                            Text(item.lockReason)
                                .font(Theme.mono(6, weight: .medium))
                                .foregroundColor(Theme.textDim)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                    }
                }

                // 이름 + 체크
                HStack(spacing: 3) {
                    Image(systemName: locked ? "lock.fill" : item.icon)
                        .font(.system(size: Theme.iconSize(8)))
                        .foregroundColor(locked ? Theme.textDim.opacity(0.5) : (isOn ? Theme.purple : Theme.textDim))
                    Text(item.name)
                        .font(Theme.mono(8, weight: isOn ? .bold : .medium))
                        .foregroundColor(locked ? Theme.textDim.opacity(0.5) : (isOn ? Theme.textPrimary : Theme.textDim))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: locked ? "lock.fill" : (isOn ? "checkmark.circle.fill" : "circle"))
                        .font(.system(size: Theme.iconSize(9)))
                        .foregroundColor(locked ? Theme.textDim.opacity(0.3) : (isOn ? Theme.green : Theme.textDim.opacity(0.4)))
                }
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 8)
                .stroke(locked ? Theme.border.opacity(0.1) : (isOn ? Theme.purple.opacity(0.4) : Theme.border.opacity(0.2)), lineWidth: isOn && !locked ? 1.5 : 0.5))
        }.buttonStyle(.plain)
    }

    // 미리보기 그리기 (간소화된 버전)
    private func drawFurniturePreview(context: GraphicsContext, item: FurnitureItem, at pos: CGPoint) {
        let dark = settings.isDarkMode
        let theme = resolvedAccessoryPreviewTheme(settings)
        let previewRect = CGRect(x: pos.x - 8, y: pos.y - 6, width: max(item.width + 16, 52), height: max(item.height + 12, 34))
        drawAccessoryPreviewRoom(context: context, item: item, rect: previewRect, theme: theme, dark: dark, frame: 18)
        drawAccessoryPixelFurniture(context: context, itemId: item.id, at: pos, dark: dark, frame: 18)
    }

    // MARK: - Helpers

    private var currentTheme: BackgroundTheme {
        BackgroundTheme(rawValue: settings.backgroundTheme) ?? .auto
    }

    private func isFurnitureOn(_ id: String) -> Bool {
        switch id {
        case "sofa": return settings.breakRoomShowSofa
        case "coffeeMachine": return settings.breakRoomShowCoffeeMachine
        case "plant": return settings.breakRoomShowPlant
        case "sideTable": return settings.breakRoomShowSideTable
        case "picture": return settings.breakRoomShowPicture
        case "neonSign": return settings.breakRoomShowNeonSign
        case "rug": return settings.breakRoomShowRug
        case "bookshelf": return settings.breakRoomShowBookshelf
        case "aquarium": return settings.breakRoomShowAquarium
        case "arcade": return settings.breakRoomShowArcade
        case "whiteboard": return settings.breakRoomShowWhiteboard
        case "lamp": return settings.breakRoomShowLamp
        case "cat": return settings.breakRoomShowCat
        case "tv": return settings.breakRoomShowTV
        case "fan": return settings.breakRoomShowFan
        case "calendar": return settings.breakRoomShowCalendar
        case "poster": return settings.breakRoomShowPoster
        case "trashcan": return settings.breakRoomShowTrashcan
        case "cushion": return settings.breakRoomShowCushion
        default: return false
        }
    }

    private func toggleFurniture(_ id: String) {
        switch id {
        case "sofa": settings.breakRoomShowSofa.toggle()
        case "coffeeMachine": settings.breakRoomShowCoffeeMachine.toggle()
        case "plant": settings.breakRoomShowPlant.toggle()
        case "sideTable": settings.breakRoomShowSideTable.toggle()
        case "picture": settings.breakRoomShowPicture.toggle()
        case "neonSign": settings.breakRoomShowNeonSign.toggle()
        case "rug": settings.breakRoomShowRug.toggle()
        case "bookshelf": settings.breakRoomShowBookshelf.toggle()
        case "aquarium": settings.breakRoomShowAquarium.toggle()
        case "arcade": settings.breakRoomShowArcade.toggle()
        case "whiteboard": settings.breakRoomShowWhiteboard.toggle()
        case "lamp": settings.breakRoomShowLamp.toggle()
        case "cat": settings.breakRoomShowCat.toggle()
        case "tv": settings.breakRoomShowTV.toggle()
        case "fan": settings.breakRoomShowFan.toggle()
        case "calendar": settings.breakRoomShowCalendar.toggle()
        case "poster": settings.breakRoomShowPoster.toggle()
        case "trashcan": settings.breakRoomShowTrashcan.toggle()
        case "cushion": settings.breakRoomShowCushion.toggle()
        default: break
        }
    }

    private func bgThemeButton(_ theme: BackgroundTheme) -> some View {
        let selected = settings.backgroundTheme == theme.rawValue
        let locked = !theme.isUnlocked
        return Button(action: { guard !locked else { return }; withAnimation(.easeInOut(duration: 0.15)) { settings.backgroundTheme = theme.rawValue } }) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: [Color(hex: theme.skyColors.top), Color(hex: theme.skyColors.bottom)],
                            startPoint: .top, endPoint: .bottom))
                        .frame(height: 28)
                        .opacity(locked ? 0.3 : 1.0)
                    if locked {
                        VStack(spacing: 1) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: Theme.iconSize(9)))
                                .foregroundColor(.white.opacity(0.7))
                            Text(theme.lockReason)
                                .font(Theme.mono(5, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                    } else {
                        Image(systemName: theme.icon)
                            .font(.system(size: Theme.iconSize(10)))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                Text(theme.displayName)
                    .font(Theme.mono(7, weight: selected ? .bold : .medium))
                    .foregroundColor(locked ? Theme.textDim.opacity(0.5) : (selected ? Theme.purple : Theme.textDim))
                    .lineLimit(1)
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(selected && !locked ? Theme.purple.opacity(0.1) : .clear)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(locked ? Theme.border.opacity(0.1) : (selected ? Theme.purple.opacity(0.5) : Theme.border.opacity(0.2)), lineWidth: selected && !locked ? 1.5 : 0.5)))
        }.buttonStyle(.plain)
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - Accessory Preview Backgrounds
// ═══════════════════════════════════════════════════════

private enum AccessoryPreviewBackdropKind {
    case brightOffice
    case sunsetOffice
    case nightOffice
    case weather
    case blossom
    case forest
    case neon
    case ocean
    case desert
    case volcano
}

private struct AccessoryPreviewPalette {
    let wallTop: String
    let wallBottom: String
    let trim: String
    let baseboard: String
    let floorA: String
    let floorB: String
    let floorShadow: String
    let windowFrame: String
    let windowTop: String
    let windowBottom: String
    let windowGlow: String
    let reflection: String
    let sill: String
}

private func resolvedAccessoryPreviewTheme(_ settings: AppSettings) -> BackgroundTheme {
    let selected = BackgroundTheme(rawValue: settings.backgroundTheme) ?? .auto
    guard selected == .auto else { return selected }

    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 6..<11: return .sunny
    case 11..<17: return .clearSky
    case 17..<19: return .goldenHour
    case 19..<21: return .dusk
    default: return settings.isDarkMode ? .moonlit : .sunny
    }
}

private func accessoryPreviewBackdropKind(for theme: BackgroundTheme) -> AccessoryPreviewBackdropKind {
    switch theme {
    case .sunny, .clearSky:
        return .brightOffice
    case .sunset, .goldenHour, .dusk, .autumn:
        return .sunsetOffice
    case .moonlit, .starryNight, .milkyWay, .aurora:
        return .nightOffice
    case .storm, .rain, .snow, .fog:
        return .weather
    case .cherryBlossom:
        return .blossom
    case .forest:
        return .forest
    case .neonCity:
        return .neon
    case .ocean:
        return .ocean
    case .desert:
        return .desert
    case .volcano:
        return .volcano
    case .auto:
        return .brightOffice
    }
}

private func accessoryPreviewPalette(for theme: BackgroundTheme, dark: Bool) -> AccessoryPreviewPalette {
    let baseFloor = theme.floorColors.base
    let baseDot = theme.floorColors.dot
    let kind = accessoryPreviewBackdropKind(for: theme)

    switch kind {
    case .brightOffice:
        return AccessoryPreviewPalette(
            wallTop: dark ? "C6D2DA" : "E3EDF3",
            wallBottom: dark ? "9DB1BF" : "C8D9E2",
            trim: dark ? "8E6A45" : "C59056",
            baseboard: dark ? "6E4B2F" : "A06E3D",
            floorA: baseFloor.isEmpty ? (dark ? "BB8A54" : "D9A76A") : baseFloor,
            floorB: baseDot.isEmpty ? (dark ? "A57446" : "C78F55") : baseDot,
            floorShadow: dark ? "6A4528" : "966234",
            windowFrame: dark ? "C7D5E2" : "F8FBFF",
            windowTop: "6AB0E9",
            windowBottom: "D7F0FF",
            windowGlow: dark ? "D8F3FF" : "FFFFFF",
            reflection: dark ? "6F8292" : "A9BACA",
            sill: dark ? "A97140" : "D29559"
        )
    case .sunsetOffice:
        return AccessoryPreviewPalette(
            wallTop: dark ? "DAB88D" : "F2D0A5",
            wallBottom: dark ? "B9926A" : "E7BF92",
            trim: dark ? "91603A" : "B87543",
            baseboard: dark ? "70462A" : "8E5632",
            floorA: baseFloor.isEmpty ? "B9824C" : baseFloor,
            floorB: baseDot.isEmpty ? "A16B39" : baseDot,
            floorShadow: "7A4C27",
            windowFrame: dark ? "D9B48D" : "FCE2BF",
            windowTop: "8F4A68",
            windowBottom: "F0A24A",
            windowGlow: "FFF2D0",
            reflection: dark ? "8D6B5C" : "C89A80",
            sill: dark ? "A2683A" : "D88D4D"
        )
    case .nightOffice:
        return AccessoryPreviewPalette(
            wallTop: dark ? "55627C" : "6F7E9D",
            wallBottom: dark ? "394762" : "55637E",
            trim: dark ? "8FA5C6" : "A9C0DD",
            baseboard: dark ? "283444" : "40526B",
            floorA: baseFloor.isEmpty ? (dark ? "4A5970" : "5E718C") : baseFloor,
            floorB: baseDot.isEmpty ? (dark ? "38465A" : "4A5971") : baseDot,
            floorShadow: dark ? "263243" : "3B4A5E",
            windowFrame: dark ? "CBD7EA" : "F2F7FF",
            windowTop: "0A1631",
            windowBottom: "233F6C",
            windowGlow: dark ? "D4E8FF" : "F3FAFF",
            reflection: dark ? "677A97" : "8799B6",
            sill: dark ? "4A5C75" : "6F86A4"
        )
    case .weather:
        return AccessoryPreviewPalette(
            wallTop: dark ? "ACB5BE" : "D7DEE4",
            wallBottom: dark ? "8E98A3" : "BCC8D0",
            trim: dark ? "6A7581" : "8E9BA6",
            baseboard: dark ? "59636D" : "76828C",
            floorA: baseFloor.isEmpty ? (dark ? "7B866D" : "CBD3C0") : baseFloor,
            floorB: baseDot.isEmpty ? (dark ? "687354" : "B3BEA8") : baseDot,
            floorShadow: dark ? "4E5844" : "8C947E",
            windowFrame: dark ? "D9E3EA" : "F6FAFC",
            windowTop: theme.skyColors.top,
            windowBottom: theme.skyColors.bottom,
            windowGlow: dark ? "DCE8EF" : "FFFFFF",
            reflection: dark ? "7C8A94" : "ABB8C1",
            sill: dark ? "858E95" : "A4AEB6"
        )
    case .blossom:
        return AccessoryPreviewPalette(
            wallTop: dark ? "E5C7D3" : "F7DEE7",
            wallBottom: dark ? "CBA8B4" : "EBC6D3",
            trim: dark ? "A37584" : "C68FA0",
            baseboard: dark ? "875866" : "B17384",
            floorA: baseFloor.isEmpty ? "D9CEC8" : baseFloor,
            floorB: baseDot.isEmpty ? "C7B8B2" : baseDot,
            floorShadow: "A7938E",
            windowFrame: dark ? "F0DCE5" : "FFF6FA",
            windowTop: "E8B5C4",
            windowBottom: "F6E3EE",
            windowGlow: "FFFFFF",
            reflection: dark ? "A68893" : "CCAFB8",
            sill: dark ? "C28E9F" : "E8AFC0"
        )
    case .forest:
        return AccessoryPreviewPalette(
            wallTop: dark ? "B4C6B0" : "D5E1D2",
            wallBottom: dark ? "8EA08A" : "B6C7B2",
            trim: dark ? "6B7C58" : "8AA06F",
            baseboard: dark ? "506040" : "71875A",
            floorA: baseFloor.isEmpty ? "9C7B54" : baseFloor,
            floorB: baseDot.isEmpty ? "846544" : baseDot,
            floorShadow: "654C33",
            windowFrame: dark ? "D8E6D6" : "F5FCF3",
            windowTop: "4D875A",
            windowBottom: "99C882",
            windowGlow: "EAF9E8",
            reflection: dark ? "778B74" : "A3B69F",
            sill: dark ? "7C9163" : "A4BB7E"
        )
    case .neon:
        return AccessoryPreviewPalette(
            wallTop: dark ? "483B66" : "6B5B8C",
            wallBottom: dark ? "30284A" : "43375E",
            trim: dark ? "9F7BE0" : "C09CFF",
            baseboard: dark ? "211B35" : "32284A",
            floorA: baseFloor.isEmpty ? (dark ? "1C1631" : "2D2247") : baseFloor,
            floorB: baseDot.isEmpty ? (dark ? "2D1F4F" : "45316D") : baseDot,
            floorShadow: dark ? "120E20" : "241933",
            windowFrame: dark ? "D8D0FF" : "F5F0FF",
            windowTop: "120B2A",
            windowBottom: "2E1854",
            windowGlow: "FF7BE7",
            reflection: dark ? "8A73B5" : "A28BD0",
            sill: dark ? "7B58C8" : "A57BFF"
        )
    case .ocean:
        return AccessoryPreviewPalette(
            wallTop: dark ? "B7D7E6" : "D8EEF7",
            wallBottom: dark ? "93C0D3" : "B9DDE9",
            trim: dark ? "4F7FA4" : "6AA8D2",
            baseboard: dark ? "345874" : "497898",
            floorA: baseFloor.isEmpty ? "93B4C8" : baseFloor,
            floorB: baseDot.isEmpty ? "7399AF" : baseDot,
            floorShadow: "54758B",
            windowFrame: dark ? "ECF8FF" : "FFFFFF",
            windowTop: "2B86CF",
            windowBottom: "8BE2F5",
            windowGlow: "F4FFFF",
            reflection: dark ? "6EA1B8" : "92BED0",
            sill: dark ? "5D99B1" : "86BED1"
        )
    case .desert:
        return AccessoryPreviewPalette(
            wallTop: dark ? "E4CC9E" : "F4DFB1",
            wallBottom: dark ? "C9AE7A" : "E5C78A",
            trim: dark ? "A97842" : "C88F4E",
            baseboard: dark ? "7D582F" : "9F6D38",
            floorA: baseFloor.isEmpty ? "C99B59" : baseFloor,
            floorB: baseDot.isEmpty ? "B48547" : baseDot,
            floorShadow: "916734",
            windowFrame: dark ? "F3E7C6" : "FFF7DE",
            windowTop: "E3A85D",
            windowBottom: "F3D38C",
            windowGlow: "FFF8DA",
            reflection: dark ? "A98A67" : "C9A47B",
            sill: dark ? "C18D4A" : "E5A95D"
        )
    case .volcano:
        return AccessoryPreviewPalette(
            wallTop: dark ? "7C5E5E" : "A27D7D",
            wallBottom: dark ? "583E3E" : "6D4E4E",
            trim: dark ? "A46A55" : "CC8467",
            baseboard: dark ? "3B2727" : "503636",
            floorA: baseFloor.isEmpty ? (dark ? "2C1616" : "3D2222") : baseFloor,
            floorB: baseDot.isEmpty ? (dark ? "431F1F" : "5A2C2C") : baseDot,
            floorShadow: dark ? "180C0C" : "2A1414",
            windowFrame: dark ? "E6D4D4" : "FAEAEA",
            windowTop: "3C0F15",
            windowBottom: "A52A1F",
            windowGlow: "FFC388",
            reflection: dark ? "8A6262" : "A98181",
            sill: dark ? "793A30" : "AA5344"
            )
        }
    }

    private func settingsToggleRow(title: String, subtitle: String, isOn: Binding<Bool>, tint: Color) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.mono(10, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(Theme.mono(8))
                    .foregroundColor(Theme.textDim)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerMedium)
                .fill(Theme.bgSurface.opacity(0.45))
        )
    }

    private func limitStepperCard(
        title: String,
        subtitle: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.mono(10, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text(subtitle)
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.textDim)
                }
                Spacer()
                Text("\(value.wrappedValue)회")
                    .font(Theme.mono(10, weight: .bold))
                    .foregroundColor(tint)
            }

            Stepper("", value: value, in: range)
                .labelsHidden()
                .tint(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerMedium)
                .fill(Theme.bgSurface.opacity(0.45))
        )
    }

private func drawAccessoryPreviewRoom(
    context: GraphicsContext,
    item: FurnitureItem,
    rect: CGRect,
    theme: BackgroundTheme,
    dark: Bool,
    frame: Int
) {
    let palette = accessoryPreviewPalette(for: theme, dark: dark)
    let kind = accessoryPreviewBackdropKind(for: theme)

    func px(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ hex: String, _ opacity: Double = 1) {
        context.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(Color(hex: hex).opacity(opacity)))
    }

    let floorHeight: CGFloat = item.isWallItem ? 8 : 11
    let wallHeight = rect.height - floorHeight
    let windowWidth = min(item.isWallItem ? rect.width * 0.42 : rect.width * 0.34, 22)
    let windowHeight = max(12, wallHeight - 9)
    let windowX = item.isWallItem ? rect.midX - windowWidth / 2 : rect.maxX - windowWidth - 6
    let windowY = rect.minY + 4
    let reflectionPulse = (sin(Double(frame) * 0.18) + 1) * 0.5

    px(rect.minX, rect.minY, rect.width, wallHeight, palette.wallBottom)
    px(rect.minX, rect.minY, rect.width, wallHeight * 0.48, palette.wallTop)
    px(rect.minX, rect.minY, rect.width, 1, palette.windowGlow, 0.4)
    px(rect.minX, rect.minY, 1, wallHeight, palette.windowGlow, 0.12)
    px(rect.maxX - 1, rect.minY, 1, wallHeight, palette.baseboard, 0.22)
    px(rect.minX, rect.minY + wallHeight - 3, rect.width, 3, palette.trim, 0.65)
    px(rect.minX, rect.minY + wallHeight - 1, rect.width, 1, palette.baseboard, 0.9)

    let shelfY = rect.minY + wallHeight - 9
    if !item.isWallItem {
        px(rect.minX + 4, shelfY, 9, 2, palette.baseboard, 0.55)
        px(rect.minX + 5, shelfY - 4, 2, 4, palette.reflection, 0.20)
        px(rect.minX + 8, shelfY - 3, 3, 3, palette.reflection, 0.18)
    }

    px(windowX, windowY, windowWidth, windowHeight, palette.windowFrame, 0.95)
    px(windowX + 1, windowY + 1, windowWidth - 2, windowHeight - 2, palette.windowBottom)
    px(windowX + 1, windowY + 1, windowWidth - 2, (windowHeight - 2) * 0.46, palette.windowTop)

    switch kind {
    case .brightOffice:
        px(windowX + 3, windowY + 3, 7, 2, "F9FFFF", 0.55)
        px(windowX + 9, windowY + 5, 5, 2, "F9FFFF", 0.40)
        px(windowX + 2, windowY + windowHeight - 4, windowWidth - 4, 2, "8EB27B", 0.75)
        px(windowX + 4, windowY + windowHeight - 7, 3, 3, "A1C490", 0.55)
        px(windowX + 12, windowY + windowHeight - 8, 4, 4, "8CA2B5", 0.5)
    case .sunsetOffice:
        px(windowX + 2, windowY + 2, windowWidth - 4, 1, "FFD58E", 0.40)
        px(windowX + windowWidth - 7, windowY + 3, 4, 4, "FFF0B2", 0.55)
        px(windowX + 2, windowY + windowHeight - 5, windowWidth - 4, 2, "70475A", 0.55)
        px(windowX + 4, windowY + windowHeight - 8, 5, 3, "8E5A4C", 0.35)
        px(windowX + 11, windowY + windowHeight - 7, 4, 2, "9F6A51", 0.3)
    case .nightOffice:
        px(windowX + windowWidth - 6, windowY + 3, 3, 3, "F7E89B", 0.65)
        px(windowX + 4, windowY + 4, 1, 1, "F7F8FF", 0.8)
        px(windowX + 9, windowY + 6, 1, 1, "F7F8FF", 0.55)
        px(windowX + 3, windowY + windowHeight - 5, windowWidth - 6, 2, "263247", 0.85)
        px(windowX + 4, windowY + windowHeight - 7, 2, 2, "F5D36B", 0.5)
        px(windowX + 9, windowY + windowHeight - 7, 2, 2, "8BC1FF", 0.35)
    case .weather:
        if theme == .snow {
            for i in 0..<4 {
                px(windowX + 3 + CGFloat(i * 3), windowY + 4 + CGFloat((i * 5) % 6), 1, 1, "FFFFFF", 0.7)
            }
        } else if theme == .fog {
            px(windowX + 2, windowY + 4, windowWidth - 4, 3, "F4F7FB", 0.22)
            px(windowX + 3, windowY + 8, windowWidth - 6, 2, "E7EDF2", 0.18)
        } else {
            for i in 0..<4 {
                px(windowX + 4 + CGFloat(i * 4), windowY + 3, 1, windowHeight - 6, "D9EAF4", theme == .storm ? 0.26 : 0.18)
            }
        }
        px(windowX + 2, windowY + windowHeight - 4, windowWidth - 4, 2, "75838D", 0.45)
    case .blossom:
        px(windowX + 2, windowY + windowHeight - 4, windowWidth - 4, 2, "809F73", 0.58)
        px(windowX + 3, windowY + 4, 6, 4, "F3BCD0", 0.80)
        px(windowX + 8, windowY + 3, 6, 5, "F8D4E2", 0.74)
        px(windowX + 7, windowY + 10, 1, 1, "FFFFFF", 0.55)
        px(windowX + 12, windowY + 8, 1, 1, "FFFFFF", 0.55)
    case .forest:
        px(windowX + 2, windowY + windowHeight - 4, windowWidth - 4, 2, "456A42", 0.78)
        px(windowX + 4, windowY + 4, 3, windowHeight - 8, "57764A", 0.72)
        px(windowX + 9, windowY + 5, 3, windowHeight - 9, "3E5C37", 0.78)
        px(windowX + 2, windowY + 4, 5, 4, "86AF78", 0.45)
        px(windowX + 10, windowY + 3, 6, 5, "A2CA7F", 0.36)
    case .neon:
        px(windowX + 3, windowY + windowHeight - 5, windowWidth - 6, 2, "1B1838", 0.9)
        px(windowX + 4, windowY + windowHeight - 8, 3, 3, "FF4CD2", 0.65)
        px(windowX + 10, windowY + windowHeight - 9, 4, 4, "54D7FF", 0.50)
        px(windowX + 5, windowY + 3, 1, windowHeight - 8, "FFF4FF", 0.18)
    case .ocean:
        px(windowX + 1, windowY + windowHeight - 5, windowWidth - 2, 1, "DDF6FF", 0.55)
        px(windowX + 2, windowY + windowHeight - 4, windowWidth - 4, 2, "2E8DC1", 0.60)
        px(windowX + 4, windowY + windowHeight - 7, 4, 1, "F7FFFF", 0.45)
        px(windowX + 11, windowY + windowHeight - 8, 5, 1, "B7F3FF", 0.40)
    case .desert:
        px(windowX + 2, windowY + windowHeight - 4, windowWidth - 4, 2, "D8B16B", 0.75)
        px(windowX + 5, windowY + windowHeight - 8, 6, 3, "C28A4A", 0.45)
        px(windowX + 12, windowY + windowHeight - 9, 1, 5, "63844D", 0.35)
        px(windowX + 11, windowY + windowHeight - 7, 3, 1, "86A66E", 0.30)
    case .volcano:
        px(windowX + 2, windowY + windowHeight - 4, windowWidth - 4, 2, "311315", 0.90)
        px(windowX + 7, windowY + windowHeight - 9, 5, 4, "4B1819", 0.55)
        px(windowX + 10, windowY + 4, 2, 6, "FFB261", 0.25)
        px(windowX + 11, windowY + 4, 1, 5, "FFD78A", 0.18)
    }

    px(windowX + 2, windowY + 1, 1, windowHeight - 2, palette.windowGlow, 0.16 + reflectionPulse * 0.08)
    px(windowX + windowWidth * 0.55, windowY + 1, 1, windowHeight - 2, palette.windowGlow, 0.10)
    px(windowX + 2, windowY + windowHeight - 6, windowWidth - 4, 1, palette.reflection, 0.26)
    px(windowX + 4, windowY + windowHeight - 5, 4, 2, palette.reflection, 0.20)
    px(windowX + windowWidth - 8, windowY + windowHeight - 7, 3, 3, palette.reflection, 0.12)
    px(windowX - 1, windowY + windowHeight, windowWidth + 2, 2, palette.sill, 0.95)

    let floorTop = rect.maxY - floorHeight
    px(rect.minX, floorTop, rect.width, floorHeight, palette.floorA)
    for row in stride(from: floorTop, to: rect.maxY, by: 4) {
        px(rect.minX, row, rect.width, 1, palette.floorShadow, 0.18)
    }
    if kind == .neon || kind == .ocean || kind == .weather {
        for col in stride(from: rect.minX, to: rect.maxX, by: 6) {
            px(col, floorTop, 1, floorHeight, palette.floorB, 0.22)
        }
    } else {
        for col in stride(from: rect.minX, to: rect.maxX, by: 8) {
            px(col, floorTop, 1, floorHeight, palette.floorB, 0.26)
        }
    }
    px(rect.minX, floorTop, rect.width, 1, palette.windowGlow, 0.16)
    px(rect.minX, rect.maxY - 1, rect.width, 1, palette.floorShadow, 0.34)
}

// ═══════════════════════════════════════════════════════
// MARK: - Shared Pixel Furniture Renderer
// ═══════════════════════════════════════════════════════
