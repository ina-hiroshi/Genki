import SwiftUI

/// 主役アクション用のボタン（元気のオレンジ）。大きく押しやすく、控えめなスプリングで反応。
struct GenkiPrimaryButtonStyle: ButtonStyle {
    var tint: Color = GenkiPalette.primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GenkiFont.headline())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// 控えめなセカンダリボタン。
struct GenkiQuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GenkiFont.callout().weight(.medium))
            .foregroundStyle(GenkiPalette.primary)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(GenkiPalette.primary.opacity(0.12))
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == GenkiPrimaryButtonStyle {
    static var genkiPrimary: GenkiPrimaryButtonStyle { GenkiPrimaryButtonStyle() }
}

extension ButtonStyle where Self == GenkiQuietButtonStyle {
    static var genkiQuiet: GenkiQuietButtonStyle { GenkiQuietButtonStyle() }
}
