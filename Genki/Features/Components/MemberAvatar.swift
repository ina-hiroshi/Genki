import SwiftUI

/// メンバーのアバター。頭文字＋固有色の細いリング。任意でチェックイン済みドット。
struct MemberAvatar: View {
    var name: String
    var colorIndex: Int
    var checkedIn: Bool = false
    var genkiLevel: GenkiLevel? = nil
    var size: CGFloat = 56

    private var initial: String {
        String(name.prefix(1))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(GenkiPalette.memberColor(for: colorIndex).opacity(0.18))
                .overlay(
                    Circle().stroke(GenkiPalette.memberColor(for: colorIndex), lineWidth: 2)
                )
                .frame(width: size, height: size)
                .overlay(
                    Text(initial)
                        .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                        .foregroundStyle(GenkiPalette.text)
                )

            if checkedIn {
                statusBadge
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if let genkiLevel {
            Image(systemName: genkiLevel.symbolName)
                .font(.system(size: size * 0.28))
                .foregroundStyle(genkiLevel.tint)
                .background(Circle().fill(.background).padding(-2))
                .accessibilityHidden(true)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: size * 0.3))
                .foregroundStyle(GenkiPalette.done)
                .background(Circle().fill(.background))
                .accessibilityHidden(true)
        }
    }

    private var accessibilityText: String {
        if checkedIn, let genkiLevel {
            return String(
                format: String(localized: "member_checked_in_level_a11y_format"),
                name,
                genkiLevel.label
            )
        }
        if checkedIn {
            return String(format: String(localized: "member_checked_in_a11y_format"), name)
        }
        return String(format: String(localized: "member_not_checked_in_a11y_format"), name)
    }
}

#Preview {
    HStack {
        MemberAvatar(name: "お母さん", colorIndex: 0, checkedIn: true, genkiLevel: .great)
        MemberAvatar(name: "お父さん", colorIndex: 1, checkedIn: false)
        MemberAvatar(name: "さくら", colorIndex: 2, checkedIn: true, genkiLevel: .rough)
    }
    .padding()
}
