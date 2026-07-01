import Foundation
import SwiftData
import WatchConnectivity

/// iPhone 側の WatchConnectivity。Watch へ家族スナップショットを送り、
/// Watch からのチェックイン・リマインド完了を受けて記録する。
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
        Task { @MainActor in handle(message) }
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            handle(message)
            replyHandler(["ok": true])
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    @MainActor
    private func handle(_ message: [String: Any]) {
        guard let context = container?.mainContext,
              let me = FamilyActions.currentMember(in: context) else { return }

        switch message["action"] as? String {
        case "checkin":
            let levelValue = message["level"] as? Int ?? GenkiLevel.okay.rawValue
            let level = GenkiLevel(rawValue: levelValue) ?? .okay
            FamilyActions.checkIn(member: me, level: level, in: context)
        case "complete":
            guard let rawID = message["reminderID"] as? String,
                  let reminderID = UUID(uuidString: rawID) else { return }
            let descriptor = FetchDescriptor<Reminder>()
            let reminders = (try? context.fetch(descriptor)) ?? []
            guard let reminder = reminders.first(where: { $0.id == reminderID }),
                  reminder.owner?.id == me.id,
                  !reminder.isCompleted() else { return }
            FamilyActions.complete(reminder: reminder, by: me, in: context)
        default:
            break
        }
    }
}
