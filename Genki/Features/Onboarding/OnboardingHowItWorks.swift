import SwiftUI

/// オンボーディングで表示する、Genki の基本的な使い方。
struct OnboardingHowItWorks: View {
    private struct Step: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    private let steps: [Step] = [
        Step(icon: "checklist",
             title: "リマインドを登録",
             detail: "服薬・散歩など、家族で見守りたいことを「リマインダー」タブから追加します。"),
        Step(icon: "checkmark.circle",
             title: "完了をタップ",
             detail: "ホームから「完了」を押すと、家族に通知が届きます。"),
        Step(icon: "sun.max",
             title: "元気だよを送る",
             detail: "毎朝のチェックインで、離れていても安心を共有できます。"),
        Step(icon: "face.smiling",
             title: "リアクションで応援",
             detail: "家族の完了やチェックインに、スタンプで気持ちを返せます。")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Genkiの使い方")
                .font(GenkiFont.headline())
                .foregroundStyle(GenkiPalette.text)

            ForEach(steps) { step in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: step.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(GenkiPalette.primary)
                        .frame(width: 28, alignment: .center)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(GenkiFont.callout().weight(.semibold))
                            .foregroundStyle(GenkiPalette.text)
                        Text(step.detail)
                            .font(GenkiFont.caption())
                            .foregroundStyle(GenkiPalette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .genkiCard()
    }
}

#Preview {
    OnboardingHowItWorks()
        .padding()
        .genkiScreenBackground()
}
