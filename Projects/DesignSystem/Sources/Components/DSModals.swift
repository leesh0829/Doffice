import SwiftUI

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 통합 모달 시스템 (DSModal)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
// 모든 시트/모달이 동일한 구조를 따름:
// DSModalShell > DSModalHeader > Content > DSModalFooter
// 헤더: 아이콘 + 타이틀 + 서브타이틀 + 닫기 버튼
// 바디: ScrollView + 섹션들
// 푸터: 좌측 보조 액션 + 우측 주요 액션

/// 모달 전체 컨테이너
public struct DSModalShell<Content: View>: View {
    public let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Theme.bg)
    }
}

/// 통합 모달 헤더
public struct DSModalHeader<Trailing: View>: View {
    public let icon: String
    public let iconColor: Color
    public let title: String
    public var subtitle: String = ""
    public let trailing: Trailing?
    public var onClose: (() -> Void)? = nil

    public init(icon: String, iconColor: Color, title: String, subtitle: String = "", trailing: Trailing, onClose: (() -> Void)? = nil) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.onClose = onClose
    }

    public var body: some View {
        HStack(spacing: Theme.sp3) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(Theme.accentBg(iconColor))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: Theme.iconSize(14), weight: .medium))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.mono(13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Theme.mono(10))
                        .foregroundColor(Theme.textDim)
                }
            }

            Spacer()

            if let trailing { trailing }

            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.textDim)
                        .frame(width: 24, height: 24)
                        .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.bgSurface))
                        .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall).stroke(Theme.border, lineWidth: 1).allowsHitTesting(false))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.sp5)
        .padding(.vertical, Theme.sp4)
        .background(Theme.bgCard)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }
}

// Convenience init without trailing view
public extension DSModalHeader where Trailing == EmptyView {
    init(icon: String, iconColor: Color, title: String, subtitle: String = "", onClose: (() -> Void)? = nil) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.trailing = nil
        self.onClose = onClose
    }
}

/// 모달 푸터 (액션 바)
public struct DSModalFooter<Leading: View, Trailing: View>: View {
    public let leading: Leading
    public let trailing: Trailing

    public init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: Theme.sp2) {
            leading
            Spacer()
            trailing
        }
        .padding(.horizontal, Theme.sp5)
        .padding(.vertical, Theme.sp3)
        .background(Theme.bgCard)
        .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 1) }
    }
}

/// 모달 내부 섹션 (통합 settingsSection 대체)
public struct DSSection<Content: View>: View {
    public let title: String
    public var subtitle: String = ""
    public let content: Content

    public init(title: String, subtitle: String = "", @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.sp3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.mono(11, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Theme.mono(9))
                        .foregroundColor(Theme.textDim)
                }
            }
            content
        }
        .padding(Theme.sp4)
        .background(RoundedRectangle(cornerRadius: Theme.cornerLarge).fill(Theme.bgCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerLarge).stroke(Theme.border, lineWidth: 1))
    }
}

public extension View {
    @ViewBuilder
    func dofficeSheetPresentation() -> some View {
        if #available(macOS 15.0, *) {
            self
                .presentationSizing(.fitted)
                .presentationBackground(Theme.bg)
        } else {
            self
                .presentationBackground(Theme.bg)
        }
    }
}
