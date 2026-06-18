import SwiftUI

/// シンプル・洗練テーマのカード。重い2重シャドウは使わず、淡い背景＋極薄シャドウで軽く表現。
struct GenkiCard: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(GenkiPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(GenkiPalette.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func genkiCard(padding: CGFloat = 16) -> some View {
        modifier(GenkiCard(padding: padding))
    }
}
