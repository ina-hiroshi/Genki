import SwiftUI
import SwiftData

/// 家族タブ: メンバー一覧と共有リンクでの招待、プライバシー説明。
struct FamilyView: View {
    @Environment(\.modelContext) private var context
    @Query private var families: [FamilyGroup]
    @State private var isPreparingShare = false
    @State private var shareError: String?
    @State private var sharePresentation: SharePresentation?
    @State private var showDeleteConfirmation = false

    private var family: FamilyGroup? { families.first }

    var body: some View {
        NavigationStack {
            List {
                if let family {
                    Section("メンバー") {
                        ForEach(family.sortedMembers) { member in
                            HStack(spacing: 12) {
                                MemberAvatar(name: member.name, colorIndex: member.colorIndex, size: 40)
                                Text(member.name)
                                    .font(GenkiFont.body())
                                    .foregroundStyle(GenkiPalette.text)
                                if member.isMe {
                                    Text("あなた")
                                        .font(GenkiFont.caption())
                                        .foregroundStyle(GenkiPalette.muted)
                                }
                            }
                        }
                    }
                }

                Section("家族を招待") {
                    Button {
                        inviteFamily()
                    } label: {
                        Label("共有リンクを送る", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isPreparingShare || family == nil)
                    if let shareError {
                        Text(shareError).font(GenkiFont.caption()).foregroundStyle(GenkiPalette.sos)
                    }
                    Text("リンクを受け取った家族がGenkiに参加できます。招待した人だけが見られます。")
                        .font(GenkiFont.caption())
                        .foregroundStyle(GenkiPalette.muted)
                }

                Section("プライバシー") {
                    Label("共有されるのは、リマインドの完了・チェックイン・リアクションだけです。", systemImage: "lock.shield")
                        .font(GenkiFont.caption())
                    Label("位置情報は使いません。履歴はずっと無料で見られます。", systemImage: "checkmark.seal")
                        .font(GenkiFont.caption())
                }

                Section("データとアカウント") {
                    Text("Genkiにメールアドレス等のアカウント登録はありません。家族グループ・履歴は端末とiCloud（共有時）に保存されます。")
                        .font(GenkiFont.caption())
                        .foregroundStyle(GenkiPalette.muted)

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("すべてのデータを削除", systemImage: "trash")
                    }
                }
            }
            .genkiListStyle()
            .genkiScreenBackground()
            .navigationTitle(family?.name ?? "家族")
            .sheet(item: $sharePresentation) { presentation in
                CloudSharingSheet(share: presentation.share, container: presentation.container) {
                    sharePresentation = nil
                }
            }
            .confirmationDialog(
                "すべてのデータを削除しますか？",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("削除する", role: .destructive, action: deleteAllData)
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("家族グループ・リマインド・チェックイン・履歴がこの端末から削除され、最初の画面に戻ります。iCloud共有中のデータは、設定アプリのiCloudからも削除できます。")
            }
        }
    }

    private func inviteFamily() {
        guard let family else { return }
        guard FeatureFlags.cloudKitEnabled else {
            shareError = "共有（招待リンク）は、iCloudを設定した実機で利用できます。"
            return
        }
        isPreparingShare = true
        shareError = nil
        Task {
            do {
                let controller = ShareController()
                let (share, container) = try await controller.prepareShare(for: family)
                try? context.save()
                sharePresentation = SharePresentation(share: share, container: container)
            } catch {
                shareError = "共有の準備に失敗しました: \(GenkiCloudError.friendlyMessage(for: error))"
            }
            isPreparingShare = false
        }
    }

    private func deleteAllData() {
        AccountActions.deleteAllUserData(in: context)
    }
}

#Preview {
    FamilyView()
        .modelContainer(GenkiModelContainer.makePreview())
}
