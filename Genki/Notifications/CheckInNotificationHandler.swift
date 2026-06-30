import Foundation
import SwiftData

/// チェックイン通知アクションからの送信を処理する。
@MainActor
enum CheckInNotificationHandler {
    static func perform(level: GenkiLevel, fromAlarm: Bool = true) {
        let container = GenkiModelContainer.makeShared()
        let context = container.mainContext
        guard let me = FamilyActions.currentMember(in: context) else { return }
        guard !me.hasCheckedIn() else { return }
        FamilyActions.checkIn(member: me, level: level, in: context, fromAlarm: fromAlarm)
    }
}
