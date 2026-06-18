import SwiftUI

/// メンバーのアバター。頭文字＋固有色の細いリング。任意でチェックイン済みドット。
struct MemberAvatar: View {
    var name: String
    var colorIndex: Int
    var checkedIn: Bool = false
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
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: size * 0.3))
                    .foregroundStyle(GenkiPalette.done)
                    .background(Circle().fill(.background))
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(checkedIn ? "\(name)、今日チェックイン済み" : "\(name)、未チェックイン")
    }
}

#Preview {
    HStack {
        MemberAvatar(name: "お母さん", colorIndex: 0, checkedIn: true)
        MemberAvatar(name: "お父さん", colorIndex: 1, checkedIn: false)
        MemberAvatar(name: "さくら", colorIndex: 2, checkedIn: true)
    }
    .padding()
}
