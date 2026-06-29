import CloudKit
import SwiftUI
import UIKit

/// UICloudSharingController を SwiftUI から表示する。share は事前に CloudKit へ保存済みであること。
struct CloudSharingSheet: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    var onDismiss: () -> Void
    var onError: ((Error) -> Void)?

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let sharing = UICloudSharingController(share: share, container: container)
        sharing.delegate = context.coordinator
        sharing.availablePermissions = [.allowReadWrite, .allowPrivate, .allowPublic]
        return sharing
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss, onError: onError)
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let onDismiss: () -> Void
        let onError: ((Error) -> Void)?

        init(onDismiss: @escaping () -> Void, onError: ((Error) -> Void)?) {
            self.onDismiss = onDismiss
            self.onError = onError
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            onError?(error)
            onDismiss()
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            "Genki 家族グループ"
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            onDismiss()
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            onDismiss()
        }
    }
}

struct ShareSheetItem: Identifiable {
    let id = UUID()
    let share: CKShare
    let container: CKContainer
}
