import Foundation

/// SOS の連絡チェーン。応答が無ければ次の家族へ順に通知を広げる。
///
/// MVP ではローカル通知で表現し、実機では CloudKit プッシュで各家族端末に届く。
/// Critical Alerts 承認後は、おやすみモード/消音も突破する。
final class EscalationManager {
    static let shared = EscalationManager()

    /// 各段階の間隔（秒）。応答が無ければ次の連絡先へ。
    var stageInterval: TimeInterval = 120

    private var pendingTimers: [Timer] = []
    private(set) var isActive = false

    private init() {}

    /// 連絡チェーン（名前の配列。先頭から順に通知）を開始する。
    func start(fromMemberName: String, chain: [String]) {
        cancel()
        isActive = true

        // 最初の連絡先には即時通知。
        NotificationManager.shared.sendSOS(fromMemberName: fromMemberName)

        // 2番目以降は段階的に。
        for (index, _) in chain.enumerated() where index > 0 {
            let delay = stageInterval * Double(index)
            let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                guard let self, self.isActive else { return }
                NotificationManager.shared.sendSOS(fromMemberName: fromMemberName)
            }
            pendingTimers.append(timer)
        }
    }

    /// 誰かが応答したら以降のエスカレーションを止める。
    func acknowledge() {
        cancel()
    }

    func cancel() {
        isActive = false
        pendingTimers.forEach { $0.invalidate() }
        pendingTimers.removeAll()
    }
}
