import SwiftUI

/// ライト/ダーク両方で背景・文字色が揃うテキストフィールド。
struct GenkiTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(GenkiFont.body())
            .foregroundStyle(GenkiPalette.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(GenkiPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(GenkiPalette.border, lineWidth: 1)
            )
    }
}

extension TextFieldStyle where Self == GenkiTextFieldStyle {
    static var genki: GenkiTextFieldStyle { GenkiTextFieldStyle() }
}
