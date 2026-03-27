import SwiftUI
import DesignSystem

struct CatalogRootView: View {
    @State private var selectedSection: CatalogSection? = .colors
    @StateObject private var settings = AppSettings.shared

    enum CatalogSection: String, CaseIterable, Identifiable, Hashable {
        case colors = "Colors"
        case typography = "Typography"
        case spacing = "Spacing"
        case badges = "Badges"
        case buttons = "Buttons"
        case fields = "Fields"
        case modals = "Modals"
        case lists = "Lists"
        case cards = "Cards"
        case navigation = "Navigation"
        case indicators = "Indicators"
        case toasts = "Toasts"
        case callouts = "Callouts"
        case skeleton = "Skeleton"
        case accordion = "Accordion"
        case keyboard = "Keyboard"
        case avatar = "Avatar"
        case toggle = "Toggle"
        case tooltip = "Tooltip"
        case divider = "Divider"
        case badgeCount = "Badge Count"
        case segmented = "Segmented"
        case search = "Search"
        case codeBlock = "Code Block"
        case timeline = "Timeline"
        case colorPicker = "Color Picker"
        case ring = "Ring"
        case diff = "Diff"
        case splitPane = "Split Pane"
        case shortcutRecorder = "Shortcut Rec."
        case syntax = "Syntax"
        case chart = "Chart"
        case commandPalette = "Cmd Palette"
        case contextMenu = "Context Menu"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .colors: return "paintpalette.fill"
            case .typography: return "textformat"
            case .spacing: return "ruler"
            case .badges: return "seal.fill"
            case .buttons: return "rectangle.fill"
            case .fields: return "character.cursor.ibeam"
            case .modals: return "rectangle.stack.fill"
            case .lists: return "list.bullet"
            case .cards: return "rectangle.on.rectangle"
            case .navigation: return "arrow.triangle.branch"
            case .indicators: return "circle.dotted"
            case .toasts: return "bell.badge.fill"
            case .callouts: return "exclamationmark.bubble.fill"
            case .skeleton: return "rectangle.dashed"
            case .accordion: return "rectangle.expand.vertical"
            case .keyboard: return "keyboard"
            case .avatar: return "person.crop.circle.fill"
            case .toggle: return "switch.2"
            case .tooltip: return "text.bubble"
            case .divider: return "minus"
            case .badgeCount: return "app.badge.fill"
            case .segmented: return "rectangle.split.3x1"
            case .search: return "magnifyingglass"
            case .codeBlock: return "chevron.left.forwardslash.chevron.right"
            case .timeline: return "clock.arrow.circlepath"
            case .colorPicker: return "eyedropper"
            case .ring: return "circle.circle"
            case .diff: return "plus.forwardslash.minus"
            case .splitPane: return "rectangle.split.2x1"
            case .shortcutRecorder: return "record.circle"
            case .syntax: return "paintbrush.pointed.fill"
            case .chart: return "chart.bar.fill"
            case .commandPalette: return "command"
            case .contextMenu: return "cursorarrow.and.square.on.square.dashed"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(CatalogSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
            .toolbar {
                ToolbarItem {
                    Button(action: { settings.isDarkMode.toggle() }) {
                        Image(systemName: settings.isDarkMode ? "sun.max.fill" : "moon.fill")
                    }
                }
            }
        } detail: {
            ScrollView {
                detailContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
            }
            .background(Theme.bg)
        }
        .background(Theme.bg)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSection {
        case .colors: ColorsCatalog()
        case .typography: TypographyCatalog()
        case .spacing: SpacingCatalog()
        case .badges: BadgesCatalog()
        case .buttons: ButtonsCatalog()
        case .fields: FieldsCatalog()
        case .modals: ModalsCatalog()
        case .lists: ListsCatalog()
        case .cards: CardsCatalog()
        case .navigation: NavigationCatalog()
        case .indicators: IndicatorsCatalog()
        case .toasts: ToastCatalog()
        case .callouts: CalloutCatalog()
        case .skeleton: SkeletonCatalog()
        case .accordion: AccordionCatalog()
        case .keyboard: KeyboardCatalog()
        case .avatar: AvatarCatalog()
        case .toggle: ToggleCatalog()
        case .tooltip: TooltipCatalog()
        case .divider: DividerCatalog()
        case .badgeCount: BadgeCountCatalog()
        case .segmented: SegmentedCatalog()
        case .search: SearchCatalog()
        case .codeBlock: CodeBlockCatalog()
        case .timeline: TimelineCatalog()
        case .colorPicker: ColorPickerCatalog()
        case .ring: RingCatalog()
        case .diff: DiffCatalog()
        case .splitPane: SplitPaneCatalog()
        case .shortcutRecorder: ShortcutRecorderCatalog()
        case .syntax: SyntaxCatalog()
        case .chart: ChartCatalog()
        case .commandPalette: CommandPaletteCatalog()
        case .contextMenu: ContextMenuCatalog()
        case .none:
            Text("Select a section")
                .font(Theme.mono(14))
                .foregroundColor(Theme.textDim)
        }
    }
}
