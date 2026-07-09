import Foundation
import CloudKit
import SwiftData
import os

/// 家族グループの CKShare 発行・受諾を扱う。
final class ShareController {
    private let manager: CloudKitManager
    private let logger = Logger(subsystem: "com.itoguchi.Genki", category: "ShareController")

    init(manager: CloudKitManager = .shared) {
        self.manager = manager
    }

    /// ゾーン全体共有を作成または再利用する。
    func prepareShare(for family: FamilyGroup) async throws -> (CKShare, CKContainer) {
        try await manager.requireAvailableAccount()
        await manager.deleteLegacyZoneIfNeeded()
        try await manager.ensureCustomZone()

        let rootRecordName = family.id.uuidString
        logger.info("prepareShare root=\(rootRecordName, privacy: .public) container=\(self.manager.container.containerIdentifier ?? "?", privacy: .public)")

        if let existing = await manager.fetchZoneShareIfExists() {
            try await ensureFamilyGroupRoot(family: family, rootRecordName: rootRecordName)
            logger.info("prepareShare reuse zone share url=\(existing.url?.absoluteString ?? "nil", privacy: .public)")
            stampShareMetadata(on: family, rootRecordName: rootRecordName)
            return (existing, manager.container)
        }

        // 空ゾーンに share のみ先保存（Apple zone-wide パターン）。
        try await manager.resetCustomZone()

        let share = CKShare(recordZoneID: manager.zoneID)
        share[CKShare.SystemFieldKey.title] = "\(family.name)（Genki）" as CKRecordValue
        share.publicPermission = .readWrite

        let savedShare = try await manager.saveShareRecord(share)
        logger.info("prepareShare saved zone share name=\(savedShare.recordID.recordName, privacy: .public)")

        try await ensureFamilyGroupRoot(family: family, rootRecordName: rootRecordName)

        stampShareMetadata(on: family, rootRecordName: rootRecordName)
        return (savedShare, manager.container)
    }

    private func ensureFamilyGroupRoot(family: FamilyGroup, rootRecordName: String) async throws {
        let rootID = CKRecord.ID(recordName: rootRecordName, zoneID: manager.zoneID)
        if await manager.fetchRecordIfExists(with: rootID, in: manager.privateDB) != nil { return }

        let root = CKRecord(recordType: CloudKitManager.familyGroupRecordType, recordID: rootID)
        root["name"] = family.name as CKRecordValue
        if let premium = family.premiumUnlockedAt {
            root["premiumUnlockedAt"] = premium as CKRecordValue
        }
        _ = try await manager.saveRecords([root], savePolicy: .allKeys)
    }

    private func stampShareMetadata(on family: FamilyGroup, rootRecordName: String) {
        family.shareRecordName = rootRecordName
        family.cloudKitZoneName = manager.zoneID.zoneName
        family.cloudKitRootZoneOwnerName = manager.zoneID.ownerName
    }

    func accept(_ metadata: CKShare.Metadata) async throws {
        try await manager.requireAvailableAccount()

        let op = CKAcceptSharesOperation(shareMetadatas: [metadata])
        op.qualityOfService = .userInitiated
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            op.acceptSharesResultBlock = { result in
                switch result {
                case .success: cont.resume()
                case .failure(let error): cont.resume(throwing: error)
                }
            }
            manager.container.add(op)
        }

        let zoneOwnerName = metadata.ownerIdentity.userRecordID?.recordName ?? CKCurrentUserDefaultName
        let zoneID = CKRecordZone.ID(zoneName: metadata.share.recordID.zoneID.zoneName, ownerName: zoneOwnerName)

        if let rootRecordID = metadata.hierarchicalRootRecordID {
            guard let root = await manager.fetchRecordIfExists(with: rootRecordID, in: manager.sharedDB) else {
                throw GenkiCloudError.shareNotFound
            }
            let familyName = root["name"] as? String ?? String(localized: "family")
            ShareAcceptanceStore.storePendingJoin(
                rootRecordName: rootRecordID.recordName,
                familyName: familyName,
                zoneOwnerName: zoneOwnerName
            )
            return
        }

        guard let rootRecordName = await manager.fetchFamilyGroupRootRecordName(in: zoneID, database: manager.sharedDB),
              let root = await manager.fetchRecordIfExists(
                with: CKRecord.ID(recordName: rootRecordName, zoneID: zoneID),
                in: manager.sharedDB
              ) else {
            throw GenkiCloudError.shareNotFound
        }
        let familyName = root["name"] as? String ?? String(localized: "family")
        ShareAcceptanceStore.storePendingJoin(
            rootRecordName: rootRecordName,
            familyName: familyName,
            zoneOwnerName: zoneOwnerName
        )
    }

    @MainActor
    func completeJoin(name: String,
                      colorIndex: Int,
                      rootRecordName: String,
                      familyName: String,
                      zoneOwnerName: String,
                      in context: ModelContext) throws {
        let familyID = UUID(uuidString: rootRecordName) ?? UUID()
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let existingFamilies = (try? context.fetch(FetchDescriptor<FamilyGroup>())) ?? []

        let family: FamilyGroup
        if let existing = existingFamilies.first(where: { $0.id == familyID }) {
            family = existing
        } else {
            family = FamilyGroup(id: familyID, name: familyName)
            context.insert(family)
        }

        family.name = familyName
        family.shareRecordName = rootRecordName
        family.cloudKitZoneName = CloudKitManager.zoneName
        family.cloudKitRootZoneOwnerName = zoneOwnerName

        for other in existingFamilies where other.id != familyID {
            context.delete(other)
        }

        let me: Member
        if let existingMe = (family.members ?? []).first(where: { $0.isMe }) {
            me = existingMe
            me.name = trimmedName
            me.colorIndex = colorIndex
        } else {
            for member in family.members ?? [] {
                member.isMe = false
            }
            me = Member(name: trimmedName, colorIndex: colorIndex, isMe: true)
            me.family = family
            context.insert(me)
        }

        try context.save()

        CurrentUser.myMemberID = me.id
        CurrentUser.myName = me.name
        CurrentUser.isOnboarded = true
        TrialManager.startTrialIfNeeded()
        ShareAcceptanceStore.clear()
        PendingJoinState.shared.refreshFromStore()
        FamilyActions.rebuildSnapshot(in: context)
        Task { @MainActor in
            do {
                try await FamilyDataSync.pushMember(me, family: family)
            } catch {
                NSLog("Genki pushMember after join error: \(error.localizedDescription)")
            }
            await FamilyDataSync.pullFamilyData(for: family, in: context)
            await PremiumSync.refreshPremium(from: family, in: context)
            await EntitlementStore.shared.refresh(in: context)
        }
    }
}
