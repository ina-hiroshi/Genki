import Foundation
import SwiftData

/// SwiftData の ModelContainer を構築する。
///
/// ローカル（オフラインファースト）の保存を担う。家族間の同期・共有は
/// `CloudKitManager`（CKShare ベース）が別レイヤーで担当する設計のため、
/// ここでは SwiftData の自動 CloudKit ミラーリングは使わない。
enum GenkiModelContainer {
    static let schema = Schema([
        FamilyGroup.self,
        Member.self,
        Reminder.self,
        CompletionLog.self,
        CheckIn.self,
        Reaction.self
    ])

    /// 本番用の永続コンテナ。
    static func makeShared() -> ModelContainer {
        let storeURL = persistentStoreURL()
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // スキーマ変更などで既存ストアが読めない場合は削除して再作成。
            removePersistentStore(at: storeURL)
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("ModelContainer の作成に失敗: \(error)")
            }
        }
    }

    private static func persistentStoreURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Genki.store")
    }

    private static func removePersistentStore(at url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            try? fm.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }

    /// プレビュー / テスト用のインメモリコンテナ。
    @MainActor
    static func makePreview(seeded: Bool = true) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            if seeded {
                SampleData.seed(into: container.mainContext)
            }
            return container
        } catch {
            fatalError("プレビュー用 ModelContainer の作成に失敗: \(error)")
        }
    }
}
