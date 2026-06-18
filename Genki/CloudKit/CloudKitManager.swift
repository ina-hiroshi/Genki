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

    let logger = Logger(subsystem: "com.itoguchi.Genki", category: "CloudKit")

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
    /// 戻り値は recordID をキーにした保存済みレコード。個別レコードの失敗も握りつぶさず throw する。
    @discardableResult
    func saveRecords(_ records: [CKRecord],
                     in database: CKDatabase? = nil,
                     savePolicy: CKModifyRecordsOperation.RecordSavePolicy = .allKeys) async throws -> [CKRecord.ID: CKRecord] {
        let db = database ?? privateDB
        let op = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        op.savePolicy = savePolicy
        op.isAtomic = true
        op.qualityOfService = .userInitiated

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[CKRecord.ID: CKRecord], Error>) in
            var savedRecords: [CKRecord.ID: CKRecord] = [:]
            var perRecordError: Error?
            op.perRecordSaveBlock = { recordID, result in
                switch result {
                case .success(let record):
                    savedRecords[recordID] = record
                case .failure(let error):
                    self.logger.error("saveRecords perRecord failed \(recordID.recordName, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    if perRecordError == nil { perRecordError = error }
                }
            }
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    // 操作全体は成功でも、個別レコードが失敗していれば throw する。
                    if let perRecordError {
                        cont.resume(throwing: perRecordError)
                    } else {
                        cont.resume(returning: savedRecords)
                    }
                case .failure(let error):
                    self.logger.error("saveRecords operation failed: \(error.localizedDescription, privacy: .public)")
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

    /// レコードが無い場合は nil（unknownItem はエラーにしない）。
    func fetchRecordIfExists(with id: CKRecord.ID, in database: CKDatabase? = nil) async -> CKRecord? {
        do {
            return try await fetchRecord(with: id, in: database)
        } catch {
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                return nil
            }
            logger.error("fetchRecordIfExists error: \(error.localizedDescription)")
            return nil
        }
    }

    /// 既存の root レコードに紐づく CKShare を取得する。無ければ nil。
    func fetchShareIfExists(forRootRecordName recordName: String) async -> CKShare? {
        let rootID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        guard let root = await fetchRecordIfExists(with: rootID, in: privateDB) else {
            return nil
        }
        guard let shareReference = root.share else { return nil }
        guard let shareRecord = await fetchRecordIfExists(with: shareReference.recordID, in: privateDB) else {
            return nil
        }
        return shareRecord as? CKShare
    }
}
