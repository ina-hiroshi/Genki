import SwiftUI
import SwiftData
import UIKit

/// 家族タブ: メンバー一覧と共有リンクでの招待、プライバシー説明。
struct FamilyView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var families: [FamilyGroup]
    @Query private var reminders: [Reminder]
    @State private var entitlements = EntitlementStore.shared
    @State private var shareError: String?
    @State private var shareSheetItem: ShareSheetItem?
    @State private var isPreparingShare = false
    @State private var showDeleteConfirmation = false
    @State private var showPaywall = false
    @State private var showTransferHelp = false
    @State private var restoreMessage: String?
    @State private var notificationsEnabled = NotificationManager.shared.areAppNotificationsEnabled
    @State private var systemNotificationsAuthorized = true

    private var family: FamilyGroup? { FamilyActions.activeFamily(from: families) }

    var body: some View {
        NavigationStack {
            List {
                premiumSection

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
                        if let limit = FeatureGate.memberLimit(for: family) {
                            Text(String(format: String(localized: "family_member_limit_format"), limit))
                                .font(GenkiFont.caption())
                                .foregroundStyle(GenkiPalette.muted)
                        }
                    }
                }

                Section(String(localized: "family_invite_section")) {
                    Button {
                        if FeatureGate.canInvite(family: family) {
                            inviteFamily()
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        if isPreparingShare {
                            Label(String(localized: "family_share_preparing"), systemImage: "hourglass")
                        } else {
                            Label(String(localized: "family_share_link"), systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(isPreparingShare || family == nil)
                    .accessibilityIdentifier("genki-share-link-button")
                    if !FeatureGate.canInvite(family: family) {
                        Text(String(localized: "family_invite_locked"))
                            .font(GenkiFont.caption())
                            .foregroundStyle(GenkiPalette.muted)
                    }
                    if let shareError {
                        Text(shareError).font(GenkiFont.caption()).foregroundStyle(GenkiPalette.sos)
                    }
                    Text(String(localized: "family_invite_detail"))
                        .font(GenkiFont.caption())
                        .foregroundStyle(GenkiPalette.muted)
                }

                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "family_notifications_toggle"))
                                .font(GenkiFont.body())
                            Text(String(localized: "family_notifications_detail"))
                                .font(GenkiFont.caption())
                                .foregroundStyle(GenkiPalette.muted)
                        }
                    }
                    .tint(GenkiPalette.primary)
                    .onChange(of: notificationsEnabled) { _, enabled in
                        applyNotificationsEnabled(enabled)
                    }

                    if !systemNotificationsAuthorized {
                        Text(String(localized: "family_notifications_os_denied"))
                            .font(GenkiFont.caption())
                            .foregroundStyle(GenkiPalette.muted)
                        Button {
                            openSystemNotificationSettings()
                        } label: {
                            Label(String(localized: "family_notifications_open_settings"), systemImage: "gear")
                        }
                    }
                } header: {
                    Text(String(localized: "family_notifications_section"))
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
            .genkiTabNavigationStyle()
            .sheet(item: $shareSheetItem) { item in
                ActivityShareSheet(items: item.activityItems, onDismiss: { shareSheetItem = nil })
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showTransferHelp) {
                LicenseTransferHelpView()
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
            .task {
                await refreshNotificationSettings()
                await entitlements.refresh(in: context)
                if let family, family.shareRecordName != nil {
                    await FamilyDataSync.pushAllLocalDataBestEffort(for: family, in: context)
                    await FamilyDataSync.pullFamilyData(for: family, in: context)
                    await FamilyDataSync.pullCheckIns(for: family, in: context)
                    await FamilyDataSync.pullCompletions(for: family, in: context)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await refreshNotificationSettings() }
            }
        }
    }

    private func refreshNotificationSettings() async {
        await NotificationManager.shared.refreshAuthorizationStatus()
        notificationsEnabled = NotificationManager.shared.areAppNotificationsEnabled
        systemNotificationsAuthorized = NotificationManager.shared.isSystemAuthorized
    }

    private func applyNotificationsEnabled(_ enabled: Bool) {
        NotificationManager.shared.areAppNotificationsEnabled = enabled
        if enabled {
            for reminder in reminders {
                NotificationManager.shared.scheduleReminder(reminder)
            }
        }
    }

    private func openSystemNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    @ViewBuilder
    private var premiumSection: some View {
        Section(String(localized: "family_premium_section")) {
            if entitlements.hasFullAccess {
                Label(String(localized: "paywall_already_unlocked"), systemImage: "checkmark.seal.fill")
                    .font(GenkiFont.body())
                    .foregroundStyle(GenkiPalette.done)
            } else if entitlements.isFamilyOwner {
                Button {
                    showPaywall = true
                } label: {
                    Label(String(localized: "paywall_unlock_button"), systemImage: "lock.open.fill")
                }
                Button(String(localized: "paywall_restore")) {
                    Task { await restorePurchases() }
                }
                .font(GenkiFont.callout())
            } else {
                Text(String(format: String(localized: "paywall_participant_subtitle_format"),
                            entitlements.premiumOwnerName ?? String(localized: "family")))
                    .font(GenkiFont.caption())
                    .foregroundStyle(GenkiPalette.muted)
            }

            Button(String(localized: "paywall_transfer_help")) {
                showTransferHelp = true
            }
            .font(GenkiFont.caption())
            .foregroundStyle(GenkiPalette.muted)

            if let restoreMessage {
                Text(restoreMessage)
                    .font(GenkiFont.caption())
                    .foregroundStyle(GenkiPalette.muted)
            }
        }
    }

    private func restorePurchases() async {
        let success = await PurchaseManager.shared.restorePurchases()
        if success {
            do {
                try await entitlements.applyPurchase(to: family, in: context)
                restoreMessage = String(localized: "paywall_restore_success")
            } catch {
                restoreMessage = GenkiCloudError.friendlyMessage(for: error)
            }
        } else {
            restoreMessage = PurchaseManager.shared.lastErrorMessage
                ?? String(localized: "purchase_restore_not_found")
        }
        await entitlements.refresh(in: context)
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
                do {
                    try await FamilyDataSync.pushAllLocalData(for: family, in: context)
                } catch {
                    shareError = GenkiCloudError.friendlyMessage(for: error)
                    return
                }
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
