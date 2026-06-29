import CloudKit
import SwiftUI
import UIKit

/// 家族グループの共有 UI。既存 share があれば表示、なければ preparationHandler で Apple 公式フロー。
struct FamilyCloudSharingSheet: UIViewControllerRepresentable {
    let family: FamilyGroup
    let existingShare: CKShare?
    let container: CKContainer
    var onShared: () -> Void
    var onDismiss: () -> Void
    var onError: (Error) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let sharing: UICloudSharingController
        if let existingShare {
            sharing = UICloudSharingController(share: existingShare, container: container)
        } else {
            let controller = ShareController()
            sharing = UICloudSharingController { _, prepareCompletionHandler in
                controller.saveNewHierarchyShare(for: family, completion: prepareCompletionHandler)
            }
        }
        sharing.delegate = context.coordinator
        sharing.availablePermissions = [.allowReadWrite, .allowPrivate, .allowPublic]
        return embedInHost(sharing)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onShared: onShared, onDismiss: onDismiss, onError: onError)
    }

    private func embedInHost(_ sharing: UICloudSharingController) -> UIViewController {
        let host = UIViewController()
        host.view.backgroundColor = .systemBackground
        host.addChild(sharing)
        sharing.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(sharing.view)
        NSLayoutConstraint.activate([
            sharing.view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            sharing.view.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            sharing.view.topAnchor.constraint(equalTo: host.view.topAnchor),
            sharing.view.bottomAnchor.constraint(equalTo: host.view.bottomAnchor)
        ])
        sharing.didMove(toParent: host)
        return host
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let onShared: () -> Void
        let onDismiss: () -> Void
        let onError: (Error) -> Void

        init(onShared: @escaping () -> Void, onDismiss: @escaping () -> Void, onError: @escaping (Error) -> Void) {
            self.onShared = onShared
            self.onDismiss = onDismiss
            self.onError = onError
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            onError(error)
            onDismiss()
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            "Genki 家族グループ"
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            onShared()
            onDismiss()
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            onDismiss()
        }
    }
}

struct ShareSheetItem: Identifiable {
    let id = UUID()
    let family: FamilyGroup
    let existingShare: CKShare?
    let container: CKContainer
}
