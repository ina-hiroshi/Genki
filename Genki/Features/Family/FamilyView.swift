import SwiftUI
import SwiftData

/// 家族タブ: メンバー一覧と共有リンクでの招待、プライバシー説明。
struct FamilyView: View {
    @Environment(\.modelContext) private var context
    @Query private var families: [FamilyGroup]
    @State private var shareError: String?
    @State private var shareSheetItem: ShareSheetItem?
    @State private var isPreparingShare = false
    @State private var showDeleteConfirmation = false

    private var family: FamilyGroup? { families.first }

    var body: some View {
        NavigationStack {
            List {
                if let family {
                    Section(String(localized: "family_members_section")) {
                        ForEach(family.sortedMembers) { member in
                            HStack(spacing: 12) {
                                MemberAvatar(name: member.name, colorIndex: member.colorIndex, size: 40)
                                Text(member.name)
                                    .font(GenkiFont.body())
                                    .foregroundStyle(GenkiPalette.text)
                                if member.isMe {
                                    Text(String(localized: "family_you"))
                                        .font(GenkiFont.caption())
                                        .foregroundStyle(GenkiPalette.muted)
                                }
                            }
                        }
                    }
                }

                Section(String(localized: "family_invite_section")) {
                    Button {
                        inviteFamily()
                    } label: {
                        if isPreparingShare {
                            Label(String(localized: "family_share_preparing"), systemImage: "hourglass")
                        } else {
                            Label(String(localized: "family_share_link"), systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(isPreparingShare || family == nil)
                    if let shareError {
                        Text(shareError).font(GenkiFont.caption()).foregroundStyle(GenkiPalette.sos)
                    }
                    Text(String(localized: "family_invite_detail"))
                        .font(GenkiFont.caption())
                        .foregroundStyle(GenkiPalette.muted)
                }

                Section(String(localized: "family_privacy_section")) {
                    Label(String(localized: "family_privacy_shared"), systemImage: "lock.shield")
                        .font(GenkiFont.caption())
                    Label(String(localized: "family_privacy_location"), systemImage: "checkmark.seal")
                        .font(GenkiFont.caption())
                }

                Section(String(localized: "family_data_section")) {
                    Text(String(localized: "family_no_account"))
                        .font(GenkiFont.caption())
                        .foregroundStyle(GenkiPalette.muted)

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label(String(localized: "family_delete_all"), systemImage: "trash")
                    }
                }
            }
            .genkiListStyle()
            .genkiScreenBackground()
            .navigationTitle(family?.name ?? String(localized: "family"))
            .sheet(item: $shareSheetItem) { item in
                ActivityShareSheet(items: item.activityItems, onDismiss: { shareSheetItem = nil })
            }
            .confirmationDialog(
                String(localized: "family_delete_confirm_title"),
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(String(localized: "family_delete_confirm_button"), role: .destructive, action: deleteAllData)
                Button(String(localized: "cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "family_delete_confirm_message"))
            }
        }
    }

    private func inviteFamily() {
        guard let family else { return }
        guard FeatureFlags.cloudKitEnabled else {
            shareError = String(localized: "family_share_error_simulator")
            return
        }
        shareError = nil
        isPreparingShare = true
        Task {
            defer { isPreparingShare = false }
            do {
                let controller = ShareController()
                let (share, _) = try await controller.prepareShare(for: family)
                try? context.save()
                guard let url = share.url else {
                    shareError = String(localized: "family_share_no_url")
                    return
                }
                let message = String(format: String(localized: "family_share_message_format"), family.name)
                shareSheetItem = ShareSheetItem(url: url, message: message)
            } catch {
                let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
                let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
                shareError = String(
                    format: String(localized: "family_share_error_format"),
                    version, build, GenkiCloudError.friendlyMessage(for: error)
                )
            }
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
