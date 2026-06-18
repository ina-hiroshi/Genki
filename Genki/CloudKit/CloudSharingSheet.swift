import CloudKit
import SwiftUI
import UIKit

/// UICloudSharingController を SwiftUI の sheet 内で正しく表示するラッパー。
struct CloudSharingSheet: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let sharing = UICloudSharingController(share: share, container: container)
        sharing.delegate = context.coordinator
        sharing.availablePermissions = [.allowReadWrite, .allowPrivate]

        // sheet 内で UICloudSharingController 単体だと背景が真っ黒になることがあるため、
        // システム背景色を持つ親 VC に embed する。
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

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

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
