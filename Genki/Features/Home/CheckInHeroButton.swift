import SwiftUI
import SwiftData

/// ホーム上部の主役: 毎日の体調チェックイン。
struct CheckInHeroButton: View {
    @Environment(\.modelContext) private var context
    @State private var justChecked = false
    @State private var showSheet = false
    @State private var selectedLevel: GenkiLevel = .okay
    @State private var note = ""

    private var me: Member? { FamilyActions.currentMember(in: context) }
    private var todaysCheckIn: CheckIn? { me?.todaysCheckIn() }
    private var done: Bool { todaysCheckIn != nil }

    var body: some View {
        Button {
            prepareSheet()
            showSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: heroSymbol)
                    .font(.system(size: 24))
                    .foregroundStyle(heroTint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(heroTitle)
                        .font(GenkiFont.title())
                    if let level = todaysCheckIn?.genkiLevel {
                        Text(level.label)
                            .font(GenkiFont.caption())
                            .opacity(0.9)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(GenkiPrimaryButtonStyle(tint: heroTint))
        .accessibilityHint(done ? String(localized: "check_in_hint_done") : String(localized: "check_in_hint_tap"))
        .scaleEffect(justChecked ? 1.03 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: justChecked)
        .sheet(isPresented: $showSheet) {
            CheckInLevelSheet(
                selectedLevel: $selectedLevel,
                note: $note,
                isUpdate: done,
                onSend: sendCheckIn,
                onCancel: { showSheet = false }
            )
        }
    }

    private var heroSymbol: String {
        if let level = todaysCheckIn?.genkiLevel {
            return level.symbolName
        }
        return "sun.max.fill"
    }

    private var heroTint: Color {
        todaysCheckIn?.genkiLevel.tint ?? GenkiPalette.primary
    }

    private var heroTitle: String {
        done ? String(localized: "check_in_done") : String(localized: "check_in_send")
    }

    private func prepareSheet() {
        if let existing = todaysCheckIn {
            selectedLevel = existing.genkiLevel
            note = existing.note ?? ""
        } else {
            selectedLevel = .okay
            note = ""
        }
    }

    private func sendCheckIn() {
        guard let me else { return }
        FamilyActions.checkIn(member: me, level: selectedLevel, note: note, in: context)
        showSheet = false
        justChecked = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { justChecked = false }
    }
}

private extension Optional where Wrapped == GenkiLevel {
    var tint: Color {
        switch self {
        case .some(let level): level.tint
        case .none: GenkiPalette.primary
        }
    }
}

#Preview {
    CheckInHeroButton()
        .padding()
        .modelContainer(GenkiModelContainer.makePreview())
}
