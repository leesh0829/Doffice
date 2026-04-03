import SwiftUI
import AppKit
import DesignSystem
import DofficeKit

extension SidebarView {
    func batchRestart() {
        for id in selectedTabIds {
            if let tab = manager.tabs.first(where: { $0.id == id }) {
                tab.stop()
                tab.start()
            }
        }
        selectedTabIds.removeAll()
        isMultiSelectMode = false
    }

    func batchStop() {
        for id in selectedTabIds {
            if let tab = manager.tabs.first(where: { $0.id == id }) {
                tab.forceStop()
            }
        }
        selectedTabIds.removeAll()
        isMultiSelectMode = false
    }

    func batchClose() {
        for id in selectedTabIds {
            manager.removeTab(id)
        }
        selectedTabIds.removeAll()
        isMultiSelectMode = false
    }

    var managementButtons: some View {
        VStack(spacing: 6) {
            utilityButton(title: NSLocalizedString("sidebar.characters", comment: ""), icon: "person.2.fill", countText: "\(CharacterRegistry.shared.hiredCharacters.count)/\(CharacterRegistry.shared.allCharacters.count)", tone: .accent) { showCharacterSheet = true }
            utilityButton(title: NSLocalizedString("sidebar.accessories", comment: ""), icon: "sofa.fill", countText: "\(breakRoomFurnitureOnCount)/20", tone: .purple) { showAccessorySheet = true }
            utilityButton(title: NSLocalizedString("sidebar.reports", comment: ""), icon: "doc.text.fill", countText: "\(manager.availableReportCount)", tone: .cyan) { showReportSheet = true }
            utilityButton(title: NSLocalizedString("sidebar.achievements", comment: ""), icon: "trophy.fill", countText: "\(AchievementManager.shared.unlockedCount)/\(AchievementManager.shared.achievements.count)", tone: .yellow) { showAchievementSheet = true }
        }
        .padding(.horizontal, 10).padding(.bottom, 6)
        .sheet(isPresented: $showCharacterSheet) {
            CharacterCollectionView()
                .frame(minWidth: 940, idealWidth: 1040, minHeight: 760, idealHeight: 840)
                .dofficeSheetPresentation()
        }
        .sheet(isPresented: $showAccessorySheet) { AccessoryView().frame(minWidth: 480, minHeight: 560).dofficeSheetPresentation() }
        .sheet(isPresented: $showReportSheet) { ReportCenterView().frame(minWidth: 760, minHeight: 620).dofficeSheetPresentation() }
        .sheet(isPresented: $showAchievementSheet) { AchievementCollectionView().frame(minWidth: 880, idealWidth: 960, minHeight: 680, idealHeight: 740).dofficeSheetPresentation() }
    }

    var lightweightManagementButtons: some View {
        VStack(spacing: 6) {
            lightweightButton(title: NSLocalizedString("sidebar.characters", comment: ""), icon: "person.2.fill") { showCharacterSheet = true }
            lightweightButton(title: NSLocalizedString("sidebar.accessories", comment: ""), icon: "sofa.fill") { showAccessorySheet = true }
            lightweightButton(title: NSLocalizedString("sidebar.reports", comment: ""), icon: "doc.text.fill") { showReportSheet = true }
            lightweightButton(title: NSLocalizedString("sidebar.achievements", comment: ""), icon: "trophy.fill") { showAchievementSheet = true }
        }
        .padding(.horizontal, 10).padding(.bottom, 6)
        .sheet(isPresented: $showCharacterSheet) {
            CharacterCollectionView()
                .frame(minWidth: 940, idealWidth: 1040, minHeight: 760, idealHeight: 840)
                .dofficeSheetPresentation()
        }
        .sheet(isPresented: $showAccessorySheet) { AccessoryView().frame(minWidth: 480, minHeight: 560).dofficeSheetPresentation() }
        .sheet(isPresented: $showReportSheet) { ReportCenterView().frame(minWidth: 760, minHeight: 620).dofficeSheetPresentation() }
        .sheet(isPresented: $showAchievementSheet) { AchievementCollectionView().frame(minWidth: 880, idealWidth: 960, minHeight: 680, idealHeight: 740).dofficeSheetPresentation() }
    }

    func lightweightButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: Theme.chromeIconSize(12), weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                Text(title).font(Theme.chrome(11, weight: .medium))
                Spacer()
                Text(NSLocalizedString("action.open", comment: ""))
                    .font(Theme.chrome(8, weight: .bold))
                    .foregroundColor(Theme.textDim)
            }
            .foregroundColor(Theme.textSecondary)
            .padding(.vertical, 9).padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bgSurface.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }
}
