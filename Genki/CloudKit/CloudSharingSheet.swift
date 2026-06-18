import CloudKit
import SwiftUI
import UIKit

/// CloudKit 共有リンクを Messages 等で送るための UI（Apple 推奨の preparationHandler 方式）。
struct CloudSharingSheet: UIViewControllerRepresentable {
    let family: FamilyGroup
    var onSaved: () -> Void
    var onError: (String) -> Void
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController { _, completionHandler in
            Task {
                do {
                    let shareController = ShareController()
                    let (share, container) = try await shareController.prepareShare(for: family)
                    await MainActor.run { onSaved() }
                    completionHandler(share, container, nil)
                } catch {
                    let message = GenkiCloudError.friendlyMessage(for: error)
                    await MainActor.run { onError(message) }
                    completionHandler(nil, nil, error)
                }
            }
        }
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            onDismiss()
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            "Genki 家族グループ"
        }

        func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
            nil
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            onDismiss()
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            onDismiss()
        }
    }
}
