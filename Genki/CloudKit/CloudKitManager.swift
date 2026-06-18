import Foundation
import CloudKit
import os

/// 家族間の同期・共有を担う CloudKit レイヤー。
final class CloudKitManager {
    static let shared = CloudKitManager()

    static let familyGroupRecordType = "FamilyGroup"
    static let checkInRecordType = "CheckIn"
    static let completionRecordType = "CompletionLog"
    static let zoneName = "GenkiFamilyZone"

    private let containerID: String

    lazy var container: CKContainer = CKContainer(identifier: containerID)
    lazy var privateDB: CKDatabase = container.privateCloudDatabase
    lazy var sharedDB: CKDatabase = container.sharedCloudDatabase

    let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)

    private let logger = Logger(subsystem: "com.itoguchi.Genki", category: "CloudKit")

    private init(containerID: String = GenkiConstants.iCloudContainerID) {
        self.containerID = containerID
    }

    func accountStatus() async -> CKAccountStatus {
        do {
            return try await container.accountStatus()
        } catch {
            logger.error("accountStatus error: \(error.localizedDescription)")
            return .couldNotDetermine
        }
    }

    func requireAvailableAccount() async throws {
        let status = await accountStatus()
        guard status == .available else {
            throw GenkiCloudError.iCloudUnavailable
        }
    }

    func ensureCustomZone() async throws {
        try await requireAvailableAccount()
        let zone = CKRecordZone(zoneID: zoneID)
        let op = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
        op.qualityOfService = .userInitiated
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            op.modifyRecordZonesResultBlock = { result in
                switch result {
                case .success: cont.resume()
                case .failure(let error): cont.resume(throwing: error)
                }
            }
            privateDB.add(op)
        }
    }

    /// レコードを atomic に保存する。新規作成時は .allKeys を使う。
    @discardableResult
    func saveRecords(_ records: [CKRecord],
                     in database: CKDatabase? = nil,
                     savePolicy: CKModifyRecordsOperation.RecordSavePolicy = .allKeys) async throws -> [CKRecord] {
        let db = database ?? privateDB
        let op = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        op.savePolicy = savePolicy
        op.isAtomic = true
        op.qualityOfService = .userInitiated

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[CKRecord], Error>) in
            var savedRecords: [CKRecord] = []
            op.perRecordSaveBlock = { _, result in
                if case .success(let record) = result {
                    savedRecords.append(record)
                }
            }
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    cont.resume(returning: savedRecords)
                case .failure(let error):
                    cont.resume(throwing: error)
                }
            }
            db.add(op)
        }
    }

    func fetchRecord(with id: CKRecord.ID, in database: CKDatabase? = nil) async throws -> CKRecord {
        let db = database ?? privateDB
        return try await db.record(for: id)
    }

    /// 既存の root レコードに紐づく CKShare を取得する。
    func fetchShare(forRootRecordName recordName: String) async throws -> CKShare? {
        let rootID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        let root = try await fetchRecord(with: rootID, in: privateDB)
        guard let shareReference = root.share else { return nil }
        let shareRecord = try await fetchRecord(with: shareReference.recordID, in: privateDB)
        return shareRecord as? CKShare
    }
}
