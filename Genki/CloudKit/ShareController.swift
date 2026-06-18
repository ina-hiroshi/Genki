import Foundation
import CloudKit
import SwiftData

/// 家族グループの CKShare 発行・受諾を扱う。共有リンクで家族を招待する。
final class ShareController {
    private let manager: CloudKitManager

    init(manager: CloudKitManager = .shared) {
        self.manager = manager
    }

    /// 家族グループ用の CKShare を取得または作成する。
    func prepareShare(for family: FamilyGroup) async throws -> (CKShare, CKContainer) {
        try await manager.requireAvailableAccount()
        try await manager.ensureCustomZone()

        if let recordName = family.shareRecordName {
            if let existing = try await manager.fetchShare(forRootRecordName: recordName) {
                return (existing, manager.container)
            }
            if let repaired = try await repairShare(for: family, rootRecordName: recordName) {
                return (repaired, manager.container)
            }
        }

        let rootID = CKRecord.ID(recordName: family.id.uuidString, zoneID: manager.zoneID)
        let root = CKRecord(recordType: CloudKitManager.familyGroupRecordType, recordID: rootID)
        root["name"] = family.name as CKRecordValue

        let share = CKShare(rootRecord: root)
        share[CKShare.SystemFieldKey.title] = "\(family.name)（Genki）" as CKRecordValue
        share.publicPermission = .none

        let saved = try await manager.saveRecords([root, share], in: manager.privateDB, savePolicy: .allKeys)
        guard let ckShare = saved.first(where: { $0 is CKShare }) as? CKShare else {
            if let fetched = try await manager.fetchShare(forRootRecordName: root.recordID.recordName) {
                family.shareRecordName = root.recordID.recordName
                family.cloudKitRootZoneOwnerName = manager.zoneID.ownerName
                return (fetched, manager.container)
            }
            throw GenkiCloudError.shareNotFound
        }

        family.shareRecordName = root.recordID.recordName
        family.cloudKitRootZoneOwnerName = manager.zoneID.ownerName
        return (ckShare, manager.container)
    }

    /// root は存在するが CKShare が欠けている場合に修復する。
    private func repairShare(for family: FamilyGroup, rootRecordName: String) async throws -> CKShare? {
        let rootID = CKRecord.ID(recordName: rootRecordName, zoneID: manager.zoneID)
        do {
            let root = try await manager.fetchRecord(with: rootID, in: manager.privateDB)
            if root.share != nil,
               let share = try await manager.fetchShare(forRootRecordName: rootRecordName) {
                return share
            }
            let share = CKShare(rootRecord: root)
            share[CKShare.SystemFieldKey.title] = "\(family.name)（Genki）" as CKRecordValue
            share.publicPermission = .none
            let saved = try await manager.saveRecords([share], in: manager.privateDB, savePolicy: .allKeys)
            return saved.first as? CKShare
        } catch {
            family.shareRecordName = nil
            return nil
        }
    }

    /// 受け取った共有メタデータを受諾し、参加オンボーディング用の状態を保存する。
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

        let root = try await manager.fetchRecord(with: metadata.rootRecordID, in: manager.sharedDB)
        let familyName = root["name"] as? String ?? "家族"
        ShareAcceptanceStore.storePendingJoin(
            rootRecordName: metadata.rootRecordID.recordName,
            familyName: familyName,
            zoneOwnerName: metadata.rootRecordID.zoneID.ownerName
        )
    }

    /// 参加オンボーディング完了時に、共有ゾーンの家族をローカル SwiftData に取り込む。
    @MainActor
    func completeJoin(name: String,
                      colorIndex: Int,
                      rootRecordName: String,
                      familyName: String,
                      zoneOwnerName: String,
                      in context: ModelContext) throws {
        let familyID = UUID(uuidString: rootRecordName) ?? UUID()
        let family = FamilyGroup(id: familyID, name: familyName)
        family.shareRecordName = rootRecordName
        family.cloudKitRootZoneOwnerName = zoneOwnerName
        context.insert(family)

        let me = Member(name: name, colorIndex: colorIndex, isMe: true)
        me.family = family
        context.insert(me)
        try context.save()

        CurrentUser.myMemberID = me.id
        CurrentUser.myName = me.name
        CurrentUser.isOnboarded = true
        ShareAcceptanceStore.clear()
        FamilyActions.rebuildSnapshot(in: context)
    }
}
