import Foundation
import CloudKit
import os

/// 家族間の同期・共有を担う CloudKit レイヤー。
final class CloudKitManager {
    static let shared = CloudKitManager()

    static let familyGroupRecordType = "FamilyGroup"
    static let checkInRecordType = "CheckIn"
    static let completionRecordType = "CompletionLog"
    static let zoneName = "GenkiSharedZone"
    /// 1.0.16 以前の hierarchy share 残骸が残る旧ゾーン。
    private static let legacyZoneName = "GenkiFamilyZone"

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

    /// カスタムゾーンを削除して作り直す。
    func resetCustomZone() async throws {
        try await requireAvailableAccount()
        await deleteZone(withID: zoneID)
        try await ensureCustomZone()
        logger.info("resetCustomZone completed")
    }

    /// 旧ゾーン（GenkiFamilyZone）を削除する。失敗しても続行。
    func deleteLegacyZoneIfNeeded() async {
        let legacyID = CKRecordZone.ID(zoneName: Self.legacyZoneName, ownerName: CKCurrentUserDefaultName)
        await deleteZone(withID: legacyID)
    }

    private func deleteZone(withID id: CKRecordZone.ID) async {
        let op = CKModifyRecordZonesOperation(recordZonesToSave: nil, recordZoneIDsToDelete: [id])
        op.qualityOfService = .userInitiated
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            op.modifyRecordZonesResultBlock = { result in
                if case .failure(let error) = result {
                    self.logger.error("deleteZone \(id.zoneName, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
                cont.resume()
            }
            privateDB.add(op)
        }
    }

    /// レコードを atomic に保存する。
    @discardableResult
    func saveRecords(_ records: [CKRecord],
                     in database: CKDatabase? = nil,
                     savePolicy: CKModifyRecordsOperation.RecordSavePolicy = .allKeys) async throws -> [CKRecord.ID: CKRecord] {
        let db = database ?? privateDB
        let result = try await db.modifyRecords(
            saving: records,
            deleting: [],
            savePolicy: savePolicy,
            atomically: records.count > 1
        )

        var savedRecords: [CKRecord.ID: CKRecord] = [:]
        var firstError: Error?
        for (recordID, recordResult) in result.saveResults {
            switch recordResult {
            case .success(let record):
                savedRecords[recordID] = record
            case .failure(let error):
                logger.error("saveRecords failed \(recordID.recordName, privacy: .public): \(error.localizedDescription, privacy: .public)")
                if firstError == nil { firstError = error }
            }
        }
        if let firstError { throw firstError }
        return savedRecords
    }

    /// ゾーン全体共有用 CKShare を保存する。
    func saveZoneShare(_ share: CKShare) async throws -> CKShare {
        let result = try await privateDB.modifyRecords(
            saving: [share],
            deleting: [],
            savePolicy: .allKeys,
            atomically: true
        )
        switch result.saveResults[share.recordID] {
        case .success(let record):
            guard let ckShare = record as? CKShare else { throw GenkiCloudError.shareNotFound }
            return ckShare
        case .failure(let error):
            throw error
        case .none:
            throw GenkiCloudError.shareNotFound
        }
    }

    func fetchRecord(with id: CKRecord.ID, in database: CKDatabase? = nil) async throws -> CKRecord {
        let db = database ?? privateDB
        return try await db.record(for: id)
    }

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

    func deleteRecords(withIDs ids: [CKRecord.ID], in database: CKDatabase? = nil) async throws {
        guard !ids.isEmpty else { return }
        let db = database ?? privateDB
        _ = try await db.modifyRecords(saving: [], deleting: ids, savePolicy: .changedKeys, atomically: true)
    }

    /// ゾーン全体共有（zone-wide share）を取得する。
    func fetchZoneShareIfExists() async -> CKShare? {
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        guard let record = await fetchRecordIfExists(with: shareID, in: privateDB) else { return nil }
        return record as? CKShare
    }

    /// 共有ゾーン内の FamilyGroup ルートレコード名を取得する（参加者側）。
    func fetchFamilyGroupRootRecordName(in zoneID: CKRecordZone.ID, database: CKDatabase) async -> String? {
        let query = CKQuery(recordType: Self.familyGroupRecordType, predicate: NSPredicate(value: true))
        let op = CKQueryOperation(query: query)
        op.zoneID = zoneID
        op.resultsLimit = 1

        return await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            var found: String?
            op.recordMatchedBlock = { (recordID: CKRecord.ID, result: Result<CKRecord, Error>) in
                if case .success = result {
                    found = recordID.recordName
                }
            }
            op.queryResultBlock = { _ in
                cont.resume(returning: found)
            }
            database.add(op)
        }
    }
}
