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

    /// カスタムゾーンを削除して作り直す（失敗した hierarchy share の残骸を消す）。
    func resetCustomZone() async throws {
        try await requireAvailableAccount()
        let op = CKModifyRecordZonesOperation(recordZonesToSave: nil, recordZoneIDsToDelete: [zoneID])
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
        try await ensureCustomZone()
        logger.info("resetCustomZone completed")
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

    /// ゾーン全体共有用 CKShare を保存する（root との同時保存は不要）。
    func saveZoneShare(_ share: CKShare) async throws -> CKShare {
        let saved = try await privateDB.save(share)
        guard let ckShare = saved as? CKShare else {
            throw GenkiCloudError.shareNotFound
        }
        return ckShare
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

    /// 以前の hierarchy share（Share-UUID）の残骸を削除する。
    func removeHierarchyShareArtifacts(forRootRecordName recordName: String) async throws {
        let rootID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        guard let root = await fetchRecordIfExists(with: rootID, in: privateDB) else { return }

        var idsToDelete: [CKRecord.ID] = []
        if let shareReference = root.share {
            idsToDelete.append(shareReference.recordID)
        }
        idsToDelete.append(rootID)
        try await deleteRecords(withIDs: idsToDelete, in: privateDB)
        logger.info("removeHierarchyShareArtifacts removed \(idsToDelete.count) records")
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
