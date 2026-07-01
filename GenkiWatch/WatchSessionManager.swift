import Foundation
import WatchConnectivity

/// Watch 側で iPhone から家族スナップショットを受け取り、チェックイン・完了要求を送る。
final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var snapshot: FamilySnapshot = .placeholder

    override init() {
        super.init()
        #if DEBUG
        if ProcessInfo.processInfo.environment["GENKI_WATCH_SCREENSHOT"] == "1" {
            snapshot = .placeholder
            return
        }
        #endif
        refreshFromSharedStore()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func refreshFromSharedStore() {
        if let loaded = GenkiSharedStore().load() {
            snapshot = loaded
        }
    }

    /// iPhone 側にチェックインを依頼する。
    func sendCheckIn(level: GenkiLevel = .okay) {
        send(action: ["action": "checkin", "level": level.rawValue])
    }

    /// iPhone 側にリマインド完了を依頼する。
    func completeReminder(id: String) {
        send(action: ["action": "complete", "reminderID": id])
    }

    private func send(action: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.sendMessage(action, replyHandler: nil) { _ in }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        refreshFromSharedStore()
    }

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
