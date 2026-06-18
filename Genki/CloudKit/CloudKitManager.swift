import Foundation
import CloudKit
import os

/// 家族間の同期・共有を担う CloudKit レイヤー。
///
/// 設計方針（プラン Step 1 で検証）:
/// - 家族 = 別々の iCloud アカウント間の共有のため、SwiftData / CloudKit の
///   自動ミラーリング（同一ユーザー端末間のみ）ではなく **CKShare + カスタム共有ゾーン** を使う。
/// - 端末ローカルは SwiftData が保持し、ここは「共有ゾーンへの読み書き」と「差分フェッチ」を担当する。
///
/// 注意: 実際の同期動作確認には有償 Apple Developer アカウントでの iCloud コンテナ設定と
/// 2台（別アカウント）の実機が必要。ここでは API を正しく組み上げ、ビルド可能な形にする。
final class CloudKitManager {
    static let shared = CloudKitManager()

    private let containerID: String

    /// CKContainer の生成は遅延させる。iCloud エンタイトルメント未設定のビルドでは
    /// `CKContainer(identifier:)` がトラップするため、`.shared` を参照しただけでは生成しない。
    lazy var container: CKContainer = CKContainer(identifier: containerID)
    lazy var privateDB: CKDatabase = container.privateCloudDatabase
    lazy var sharedDB: CKDatabase = container.sharedCloudDatabase

    /// 家族データを格納するカスタムゾーン。
    let zoneID = CKRecordZone.ID(zoneName: "GenkiFamilyZone", ownerName: CKCurrentUserDefaultName)

    private let logger = Logger(subsystem: "com.itoguchi.Genki", category: "CloudKit")

    private init(containerID: String = GenkiConstants.iCloudContainerID) {
        self.containerID = containerID
    }

    // MARK: - アカウント状態

    /// iCloud にサインインしているか確認する。
    func accountStatus() async -> CKAccountStatus {
        do {
            return try await container.accountStatus()
        } catch {
            logger.error("accountStatus error: \(error.localizedDescription)")
            return .couldNotDetermine
        }
    }

    // MARK: - ゾーン

    /// カスタムゾーンが無ければ作成する（共有の前提）。
    func ensureCustomZone() async throws {
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

    // MARK: - レコード保存 / 取得

    /// レコードを共有ゾーン（private DB 内）に保存する。
    @discardableResult
    func save(_ record: CKRecord, in database: CKDatabase? = nil) async throws -> CKRecord {
        let db = database ?? privateDB
        return try await db.save(record)
    }

    /// 指定タイプのレコードをゾーンから取得する。
    func fetchRecords(ofType type: String, in database: CKDatabase? = nil) async throws -> [CKRecord] {
        let db = database ?? privateDB
        let query = CKQuery(recordType: type, predicate: NSPredicate(value: true))
        let (matchResults, _) = try await db.records(matching: query, inZoneWith: zoneID)
        return matchResults.compactMap { _, result in try? result.get() }
    }

    // MARK: - Step 1 スパイク（共有 + 同期の最小検証）

    /// CKShare まわりが正しく組めているかをローカルで素振りするための検証関数。
    /// 実機・別アカウントでの完全な検証は別途必要だが、ビルド時に API 整合性を担保する。
    func runShareSpike() async -> Result<String, Error> {
        guard FeatureFlags.cloudKitEnabled else {
            return .success("CloudKit は無効（未署名/シミュレータ）。実機の署名ビルドで検証してください。")
        }
        do {
            let status = await accountStatus()
            guard status == .available else {
                return .success("iCloud 未サインイン（status=\(status.rawValue)）。実機で要確認。")
            }
            try await ensureCustomZone()
            let root = CKRecord(recordType: "FamilyGroup",
                                recordID: CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID))
            root["name"] = "Spike Family" as CKRecordValue
            let saved = try await save(root)
            let share = CKShare(rootRecord: saved)
            share[CKShare.SystemFieldKey.title] = "Genki 家族グループ" as CKRecordValue
            _ = try await save(share)
            return .success("共有ゾーン作成・ルートレコード保存・CKShare 生成に成功。")
        } catch {
            logger.error("share spike error: \(error.localizedDescription)")
            return .failure(error)
        }
    }
}
