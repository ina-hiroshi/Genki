import SwiftUI
import SwiftData

/// 機能紹介1ページ分のデータ。
struct OnboardingIntroPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let detail: String
}

enum OnboardingContent {
    static var introPages: [OnboardingIntroPage] {
        [
            OnboardingIntroPage(
                icon: "sun.max.fill",
                title: String(localized: "onboarding_welcome_title"),
                subtitle: String(localized: "onboarding_welcome_subtitle"),
                detail: String(localized: "onboarding_welcome_detail")
            ),
            OnboardingIntroPage(
                icon: "checklist",
                title: String(localized: "onboarding_reminders_title"),
                subtitle: String(localized: "onboarding_reminders_subtitle"),
                detail: String(localized: "onboarding_reminders_detail")
            ),
            OnboardingIntroPage(
                icon: "sun.max",
                title: String(localized: "onboarding_checkin_title"),
                subtitle: String(localized: "onboarding_checkin_subtitle"),
                detail: String(localized: "onboarding_checkin_detail")
            ),
            OnboardingIntroPage(
                icon: "face.smiling",
                title: String(localized: "onboarding_reactions_title"),
                subtitle: String(localized: "onboarding_reactions_subtitle"),
                detail: String(localized: "onboarding_reactions_detail")
            )
        ]
    }
}

/// 1機能ずつ紹介する全画面ページ。
struct OnboardingIntroPageView: View {
    let page: OnboardingIntroPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 72))
                .foregroundStyle(GenkiPalette.primary)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text(page.title)
                    .font(GenkiFont.largeTitle())
                    .foregroundStyle(GenkiPalette.text)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(GenkiFont.title())
                    .foregroundStyle(GenkiPalette.primary)
                    .multilineTextAlignment(.center)
            }

            Text(page.detail)
                .font(GenkiFont.body())
                .foregroundStyle(GenkiPalette.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
    }
}

/// 家族・本人の設定フォーム（紹介の最終ページ）。
struct OnboardingSetupView: View {
    @Binding var familyName: String
    @Binding var myName: String
    @Binding var colorIndex: Int

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(String(localized: "onboarding_create_family"))
                        .font(GenkiFont.largeTitle())
                        .foregroundStyle(GenkiPalette.text)
                    Text(String(localized: "onboarding_setup_detail"))
                        .font(GenkiFont.callout())
                        .foregroundStyle(GenkiPalette.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 20) {
                    field(title: String(localized: "field_family_name")) {
                        TextField(String(localized: "default_family_name"), text: $familyName)
                            .textFieldStyle(.genki)
                    }
                    field(title: String(localized: "field_your_name")) {
                        TextField(String(localized: "name_placeholder_mother"), text: $myName)
                            .textFieldStyle(.genki)
                    }
                    field(title: String(localized: "field_your_color")) {
                        colorPicker
                    }
                }
                .genkiCard()

                Text(String(localized: "onboarding_after_create"))
                    .font(GenkiFont.caption())
                    .foregroundStyle(GenkiPalette.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
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
                    .accessibilityLabel(String(format: String(localized: "color_a11y_format"), index + 1))
                    .accessibilityAddTraits(colorIndex == index ? .isSelected : [])
            }
        }
    }
}

#Preview("Intro") {
    OnboardingIntroPageView(page: OnboardingContent.introPages[0])
        .genkiScreenBackground()
}

#Preview("Setup") {
    OnboardingSetupView(
        familyName: .constant(String(localized: "default_family_name")),
        myName: .constant(""),
        colorIndex: .constant(0)
    )
    .genkiScreenBackground()
}
