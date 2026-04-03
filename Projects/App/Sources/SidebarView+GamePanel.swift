import SwiftUI
import AppKit
import DesignSystem
import DofficeKit

extension SidebarView {
    var gamePanel: some View {
        sidebarPanel(title: "Level", icon: "sparkles", tint: Theme.yellow) {
            VStack(spacing: 8) {
                XPBarView(xp: AchievementManager.shared.totalXP)
                AchievementsView()
            }
        }
    }

    var breakRoomFurnitureOnCount: Int {
        let s = AppSettings.shared
        return [s.breakRoomShowSofa, s.breakRoomShowCoffeeMachine, s.breakRoomShowPlant, s.breakRoomShowSideTable,
                s.breakRoomShowPicture, s.breakRoomShowNeonSign, s.breakRoomShowRug,
                s.breakRoomShowBookshelf, s.breakRoomShowAquarium, s.breakRoomShowArcade, s.breakRoomShowWhiteboard,
                s.breakRoomShowLamp, s.breakRoomShowCat, s.breakRoomShowTV, s.breakRoomShowFan,
                s.breakRoomShowCalendar, s.breakRoomShowPoster, s.breakRoomShowTrashcan, s.breakRoomShowCushion].filter { $0 }.count
    }
}
