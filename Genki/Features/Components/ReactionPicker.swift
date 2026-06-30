import SwiftUI

/// リアクション（スタンプ）を選ぶ小さなバー。ブランド調の SF Symbol を使う。
struct ReactionPicker: View {
    var onSelect: (ReactionKind) -> Void

    var body: some View {
        HStack(spacing: 14) {
            ForEach(ReactionKind.allCases) { kind in
                Button {
                    onSelect(kind)
                } label: {
                    Image(systemName: kind.symbolName)
                        .font(.system(size: 20))
                        .foregroundStyle(GenkiPalette.primary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(GenkiPalette.primary.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(kind.accessibilityLabel)
            }
        }
    }
}

/// 付いたリアクションを並べて表示する。
struct ReactionRow: View {
    var reactions: [Reaction]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(reactions) { reaction in
                Image(systemName: reaction.kind.symbolName)
                    .font(.system(size: 13))
                    .foregroundStyle(GenkiPalette.primary)
                    .accessibilityLabel(String(format: String(localized: "reaction_from_a11y_format"), reaction.authorName, reaction.kind.accessibilityLabel))
            }
        }
    }
}

#Preview {
    ReactionPicker { _ in }
        .padding()
}
