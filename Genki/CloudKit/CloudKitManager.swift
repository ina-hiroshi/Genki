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

    /// CKShare を .allKeys で単独保存する（zone-wide / hierarchy 共通）。
    func saveShareRecord(_ share: CKShare) async throws -> CKShare {
        let saved = try await saveRecords([share], savePolicy: .allKeys)
        guard let ckShare = saved[share.recordID] as? CKShare else {
            throw GenkiCloudError.shareNotFound
        }
        return ckShare
    }

    /// レコードを atomic に保存する。
    @discardableResult
    func saveRecords(_ records: [CKRecord],
                     in database: CKDatabase? = nil,
                     savePolicy: CKModifyRecordsOperation.RecordSavePolicy = .allKeys) async throws -> [CKRecord.ID: CKRecord] {
        let db = database ?? privateDB
        do {
            let result = try await db.modifyRecords(
                saving: records,
                deleting: [],
                savePolicy: savePolicy,
                atomically: records.count > 1
            )
            return try Self.collectSaveResults(result.saveResults, logger: logger)
        } catch let error as CKError where error.code == .partialFailure {
            throw Self.errorFromPartialFailure(error, logger: logger)
        }
    }

    private static func collectSaveResults(_ saveResults: [CKRecord.ID: Result<CKRecord, Error>],
                                           logger: Logger) throws -> [CKRecord.ID: CKRecord] {
        var savedRecords: [CKRecord.ID: CKRecord] = [:]
        var failures: [(CKRecord.ID, Error)] = []
        for (recordID, recordResult) in saveResults {
            switch recordResult {
            case .success(let record):
                savedRecords[recordID] = record
            case .failure(let error):
                logger.error("saveRecords failed \(recordID.recordName, privacy: .public): \(error.localizedDescription, privacy: .public)")
                failures.append((recordID, error))
            }
        }
        if !failures.isEmpty {
            throw combinedSaveError(failures: failures)
        }
        return savedRecords
    }

    private static func errorFromPartialFailure(_ error: CKError, logger: Logger) -> Error {
        if let partial = error.partialErrorsByItemID {
            var failures: [(CKRecord.ID, Error)] = []
            for (itemID, itemError) in partial {
                if let recordID = itemID as? CKRecord.ID {
                    logger.error("partial failure \(recordID.recordName, privacy: .public): \(itemError.localizedDescription, privacy: .public)")
                    failures.append((recordID, itemError))
                }
            }
            if !failures.isEmpty {
                return combinedSaveError(failures: failures)
            }
        }
        return error
    }

    private static func combinedSaveError(failures: [(CKRecord.ID, Error)]) -> Error {
        guard failures.count == 1 else {
            let lines = failures.map { id, error in
                "\(id.recordName): \(error.localizedDescription)"
            }
            return NSError(
                domain: CKErrorDomain,
                code: CKError.Code.serverRejectedRequest.rawValue,
                userInfo: [
                    NSLocalizedDescriptionKey: "Atomic failure\n" + lines.joined(separator: "\n"),
                    CKPartialErrorsByItemIDKey: Dictionary(uniqueKeysWithValues: failures.map { ($0.0, $0.1 as NSError) })
                ]
            )
        }
        return failures[0].1
    }

    /// ゾーン全体共有用 CKShare を保存する。
    func saveZoneShare(_ share: CKShare) async throws -> CKShare {
        try await saveShareRecord(share)
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

    /// hierarchy share（root 単位）を取得する。
    func fetchHierarchyShare(forRootRecordName recordName: String, zoneID: CKRecordZone.ID) async -> CKShare? {
        let rootID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        guard let root = await fetchRecordIfExists(with: rootID, in: privateDB) else { return nil }
        guard let shareReference = root.share else { return nil }
        guard let shareRecord = await fetchRecordIfExists(with: shareReference.recordID, in: privateDB) else { return nil }
        return shareRecord as? CKShare
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
