import SwiftUI
import SwiftData

/// 家族グループの作成（または参加案内）。
struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    @State private var familyName = "わたしの家族"
    @State private var myName = ""
    @State private var colorIndex = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header

                    VStack(alignment: .leading, spacing: 20) {
                        field(title: "家族の名前") {
                            TextField("わたしの家族", text: $familyName)
                                .textFieldStyle(.genki)
                        }
                        field(title: "あなたの名前") {
                            TextField("例: お母さん / さくら", text: $myName)
                                .textFieldStyle(.genki)
                        }
                        field(title: "あなたの色") {
                            colorPicker
                        }
                    }
                    .genkiCard()

                    Button("家族をはじめる", action: createFamily)
                        .buttonStyle(.genkiPrimary)
                        .disabled(myName.trimmingCharacters(in: .whitespaces).isEmpty)

                    Text("家族の招待は、作成後に「家族」タブの共有リンクから送れます。")
                        .font(GenkiFont.caption())
                        .foregroundStyle(GenkiPalette.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            }
            .genkiScreenBackground()
            .navigationTitle("Genki")
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 56))
                .foregroundStyle(GenkiPalette.primary)
            Text("家族がつながる、家族が安心する")
                .font(GenkiFont.title())
                .foregroundStyle(GenkiPalette.text)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private func field<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(GenkiFont.headline())
                .foregroundStyle(GenkiPalette.text)
            content()
        }
    }

    private var colorPicker: some View {
        HStack(spacing: 12) {
            ForEach(GenkiPalette.memberColors.indices, id: \.self) { index in
                Circle()
                    .fill(GenkiPalette.memberColors[index])
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle().stroke(GenkiPalette.text, lineWidth: colorIndex == index ? 3 : 0)
                    )
                    .onTapGesture { colorIndex = index }
                    .accessibilityLabel("色 \(index + 1)")
                    .accessibilityAddTraits(colorIndex == index ? .isSelected : [])
            }
        }
    }

    private func createFamily() {
        let family = FamilyGroup(name: familyName.isEmpty ? "わたしの家族" : familyName)
        context.insert(family)

        let me = Member(name: myName.trimmingCharacters(in: .whitespaces), colorIndex: colorIndex, isMe: true)
        me.family = family
        context.insert(me)
        try? context.save()

        CurrentUser.myMemberID = me.id
        CurrentUser.myName = me.name
        CurrentUser.isOnboarded = true

        FamilyActions.rebuildSnapshot(in: context)

        Task {
            await NotificationManager.shared.requestAuthorization()
            await CloudKitBootstrap.activateIfNeeded()
        }
    }
}

#Preview {
    OnboardingView()
        .modelContainer(GenkiModelContainer.makePreview(seeded: false))
}
