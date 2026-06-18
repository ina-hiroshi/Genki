import Foundation
import WatchConnectivity

/// Watch 側で iPhone から家族スナップショットを受け取り、チェックイン要求を送る。
final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var snapshot: FamilySnapshot = .placeholder

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    /// iPhone 側に「元気だよ」を依頼する。
    func sendCheckIn() {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.sendMessage(["action": "checkin"], replyHandler: nil) { _ in }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        applySnapshot(from: applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        applySnapshot(from: userInfo)
    }

    private func applySnapshot(from payload: [String: Any]) {
        guard let data = payload["snapshot"] as? Data,
              let decoded = try? JSONDecoder().decode(FamilySnapshot.self, from: data) else { return }
        DispatchQueue.main.async { self.snapshot = decoded }
    }
}
