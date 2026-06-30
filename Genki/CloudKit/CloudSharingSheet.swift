import SwiftUI
import UIKit

/// iOS 標準の共有シート（メッセージ・メール・AirDrop 等）で CKShare リンクを送る。
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onDismiss()
        }
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootView = scene.windows.first(where: \.isKeyWindow)?.rootViewController?.view {
            controller.popoverPresentationController?.sourceView = rootView
            controller.popoverPresentationController?.sourceRect = CGRect(
                x: rootView.bounds.midX,
                y: rootView.bounds.midY,
                width: 0,
                height: 0
            )
            controller.popoverPresentationController?.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ShareSheetItem: Identifiable {
    let id = UUID()
    let url: URL
    let message: String

    var activityItems: [Any] { [message, url] }
}
