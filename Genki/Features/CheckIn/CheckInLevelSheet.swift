import SwiftUI

/// 3段階の元気度を選んでチェックインするシート。
struct CheckInLevelSheet: View {
    @Binding var selectedLevel: GenkiLevel
    @Binding var note: String
    var isUpdate: Bool
    var onSend: () -> Void
    var onCancel: () -> Void

    @State private var showNoteField = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(String(localized: "check_in_sheet_title"))
                        .font(GenkiFont.headline())
                        .foregroundStyle(GenkiPalette.text)

                    VStack(spacing: 10) {
                        ForEach(GenkiLevel.allCases.reversed()) { level in
                            GenkiLevelOptionRow(
                                level: level,
                                isSelected: selectedLevel == level
                            ) {
                                selectedLevel = level
                            }
                        }
                    }

                    DisclosureGroup(isExpanded: $showNoteField) {
                        TextField(String(localized: "check_in_note_placeholder"), text: $note, axis: .vertical)
                            .lineLimit(3...5)
                            .textFieldStyle(.genki)
                    } label: {
                        Text(String(localized: "check_in_note_toggle"))
                            .font(GenkiFont.callout())
                            .foregroundStyle(GenkiPalette.muted)
                    }

                    Button(action: onSend) {
                        Text(isUpdate
                             ? String(localized: "check_in_update_button")
                             : String(localized: "check_in_send_button"))
                    }
                    .buttonStyle(GenkiPrimaryButtonStyle(tint: selectedLevel.tint))
                }
                .padding(20)
            }
            .genkiScreenBackground()
            .navigationTitle(String(localized: "check_in_sheet_nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel"), action: onCancel)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct GenkiLevelOptionRow: View {
    var level: GenkiLevel
    var isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: level.symbolName)
                    .font(.system(size: 28))
                    .foregroundStyle(level.tint)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.label)
                        .font(GenkiFont.body().weight(.semibold))
                        .foregroundStyle(GenkiPalette.text)
                    Text(level.detail)
                        .font(GenkiFont.caption())
                        .foregroundStyle(GenkiPalette.muted)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? level.tint : GenkiPalette.border)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? level.tint.opacity(0.12) : GenkiPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? level.tint : GenkiPalette.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(level.label)
        .accessibilityHint(level.detail)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    CheckInLevelSheet(
        selectedLevel: .constant(.okay),
        note: .constant(""),
        isUpdate: false,
        onSend: {},
        onCancel: {}
    )
}
