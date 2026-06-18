import Foundation
import CloudKit
import SwiftUI

/// 家族グループの CKShare 発行・受諾を扱う。共有リンクで家族を招待する。
final class ShareController {
    private let manager: CloudKitManager

    init(manager: CloudKitManager = .shared) {
        self.manager = manager
    }

    /// 家族グループ用の CKShare を作成し、共有用のレコードを返す。
    /// UICloudSharingController に渡してリンク/メッセージで招待する。
    func makeShare(for family: FamilyGroup) async throws -> (CKShare, CKContainer) {
        try await manager.ensureCustomZone()

        let rootID = CKRecord.ID(recordName: family.id.uuidString, zoneID: manager.zoneID)
        let root = CKRecord(recordType: "FamilyGroup", recordID: rootID)
        root["name"] = family.name as CKRecordValue
        let savedRoot = try await manager.save(root)

        let share = CKShare(rootRecord: savedRoot)
        share[CKShare.SystemFieldKey.title] = "\(family.name)（Genki）" as CKRecordValue
        share.publicPermission = .none // 招待された人だけが参加できる
        let savedShare = try await manager.save(share)

        guard let ckShare = savedShare as? CKShare else {
            throw NSError(domain: "Genki.Share", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "CKShare の生成に失敗しました。"])
        }
        family.shareRecordName = savedRoot.recordID.recordName
        return (ckShare, manager.container)
    }

    /// 受け取った共有メタデータを受諾して家族に参加する。
    func accept(_ metadata: CKShare.Metadata) async throws {
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
    }
}
