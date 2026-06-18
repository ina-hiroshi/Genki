import SwiftUI
import SwiftData

/// 初回起動: 機能紹介（スワイプ）→ 家族セットアップ。
struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    @State private var page = 0
    @State private var familyName = "わたしの家族"
    @State private var myName = ""
    @State private var colorIndex = 0

    private var setupPageIndex: Int { OnboardingContent.introPages.count }
    private var isSetupPage: Bool { page == setupPageIndex }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(OnboardingContent.introPages.enumerated()), id: \.offset) { index, introPage in
                    OnboardingIntroPageView(page: introPage)
                        .tag(index)
                }

                OnboardingSetupView(
                    familyName: $familyName,
                    myName: $myName,
                    colorIndex: $colorIndex
                )
                .tag(setupPageIndex)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: page)

            bottomBar
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .genkiScreenBackground()
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if isSetupPage {
                Button("家族をはじめる", action: createFamily)
                    .buttonStyle(.genkiPrimary)
                    .disabled(myName.trimmingCharacters(in: .whitespaces).isEmpty)
            } else {
                Button(page == setupPageIndex - 1 ? "設定へ" : "次へ") {
                    withAnimation { page += 1 }
                }
                .buttonStyle(.genkiPrimary)

                if page < setupPageIndex - 1 {
                    Button("スキップ") {
                        withAnimation { page = setupPageIndex }
                    }
                    .font(GenkiFont.callout())
                    .foregroundStyle(GenkiPalette.muted)
                }
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
