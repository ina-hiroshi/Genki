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
    static let introPages: [OnboardingIntroPage] = [
        OnboardingIntroPage(
            icon: "sun.max.fill",
            title: "Genkiへようこそ",
            subtitle: "家族がつながる、家族が安心する",
            detail: "離れて暮らす家族みんなで、毎日の「元気」を共有できるアプリです。"
        ),
        OnboardingIntroPage(
            icon: "checklist",
            title: "リマインドで見守る",
            subtitle: "服薬・散歩・水分など",
            detail: "大切なことを登録して、家族で完了を確認。忘れがちなことも、やさしくサポートします。"
        ),
        OnboardingIntroPage(
            icon: "sun.max",
            title: "元気だよチェックイン",
            subtitle: "毎朝の安心の合図",
            detail: "「元気だよ」を送るだけ。目覚ましと連携すれば、起きたら自動で家族に届きます。"
        ),
        OnboardingIntroPage(
            icon: "face.smiling",
            title: "リアクションでつながる",
            subtitle: "スタンプで気持ちを返す",
            detail: "完了やチェックインにリアクション。小さな「ありがとう」が、家族の絆になります。"
        )
    ]
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
                    Text("家族をつくろう")
                        .font(GenkiFont.largeTitle())
                        .foregroundStyle(GenkiPalette.text)
                    Text("あなたの家族の名前と、あなた自身の情報を入力してください。")
                        .font(GenkiFont.callout())
                        .foregroundStyle(GenkiPalette.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 12)

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

                Text("作成後、「家族」タブから共有リンクで招待できます。データの削除もいつでも可能です。")
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
                    .accessibilityLabel("色 \(index + 1)")
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
        familyName: .constant("わたしの家族"),
        myName: .constant(""),
        colorIndex: .constant(0)
    )
    .genkiScreenBackground()
}
