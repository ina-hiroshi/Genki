import UIKit
import CloudKit

/// SwiftUI ライフサイクルで CloudKit 共有受諾を受け取る SceneDelegate。
/// CKShare 受諾は UIWindowSceneDelegate 経由でのみ届く。
final class GenkiSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            CloudKitShareAcceptanceHandler.accept(metadata)
        }
    }

    func windowScene(_ windowScene: UIWindowScene,
                     userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        CloudKitShareAcceptanceHandler.accept(cloudKitShareMetadata)
    }
}
