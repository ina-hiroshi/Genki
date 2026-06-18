import Foundation
import CloudKit

/// 共有リンク受諾後、参加オンボーディングが完了するまでの状態。
enum ShareAcceptanceStore {
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: GenkiConstants.appGroupID) ?? .standard
    }

    private static let rootRecordNameKey = "genki.pendingShare.rootRecordName"
    private static let familyNameKey = "genki.pendingShare.familyName"
    private static let zoneOwnerNameKey = "genki.pendingShare.zoneOwnerName"

    static var hasPendingJoin: Bool {
        pendingRootRecordName != nil
    }

    static var pendingRootRecordName: String? {
        get { defaults.string(forKey: rootRecordNameKey) }
        set { defaults.set(newValue, forKey: rootRecordNameKey) }
    }

    static var pendingFamilyName: String? {
        get { defaults.string(forKey: familyNameKey) }
        set { defaults.set(newValue, forKey: familyNameKey) }
    }

    static var pendingZoneOwnerName: String? {
        get { defaults.string(forKey: zoneOwnerNameKey) }
        set { defaults.set(newValue, forKey: zoneOwnerNameKey) }
    }

    static func storePendingJoin(rootRecordName: String, familyName: String, zoneOwnerName: String) {
        pendingRootRecordName = rootRecordName
        pendingFamilyName = familyName
        pendingZoneOwnerName = zoneOwnerName
    }

    static func clear() {
        pendingRootRecordName = nil
        pendingFamilyName = nil
        pendingZoneOwnerName = nil
    }
}
