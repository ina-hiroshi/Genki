import CloudKit
import os

/// CloudKit 共有受諾の共通処理（SceneDelegate / AppDelegate から呼ぶ）。
enum CloudKitShareAcceptanceHandler {
    private static let logger = Logger(subsystem: "com.itoguchi.Genki", category: "ShareAcceptance")

    static func accept(_ metadata: CKShare.Metadata) {
        Task { @MainActor in
            do {
                try await ShareController().accept(metadata)
                PendingJoinState.shared.refreshFromStore()
                logger.info("share accepted root=\(metadata.hierarchicalRootRecordID?.recordName ?? "zone-wide", privacy: .public)")
            } catch {
                logger.error("share accept error: \(error.localizedDescription, privacy: .public)")
                NSLog("Genki share accept error: \(error.localizedDescription)")
            }
        }
    }
}
