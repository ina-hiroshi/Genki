import Foundation
import SwiftData
import WatchConnectivity

/// iPhone 側の WatchConnectivity。Watch へ家族スナップショットを送り、
/// Watch からの「元気だよ」依頼を受けてチェックインを記録する。
final class PhoneSessionManager: NSObject, WCSessionDelegate {
    static let shared = PhoneSessionManager()

    private var container: ModelContainer?

    func configure(container: ModelContainer) {
        self.container = container
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    /// 最新スナップショットを Watch に同期する。
    func send(snapshot: FamilySnapshot) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? WCSession.default.updateApplicationContext(["snapshot": data])
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard message["action"] as? String == "checkin" else { return }
        Task { @MainActor in
            guard let context = container?.mainContext,
                  let me = FamilyActions.currentMember(in: context) else { return }
            let levelValue = message["level"] as? Int ?? GenkiLevel.okay.rawValue
            let level = GenkiLevel(rawValue: levelValue) ?? .okay
            FamilyActions.checkIn(member: me, level: level, in: context)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
