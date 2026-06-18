import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// App Group 経由で FamilySnapshot を読み書きする共有ストア。
/// アプリが書き込み、ウィジェット / Watch が読み取る。
public struct GenkiSharedStore {
    private let defaults: UserDefaults?

    public init(appGroupID: String = GenkiConstants.appGroupID) {
        self.defaults = UserDefaults(suiteName: appGroupID)
    }

    /// 最新のスナップショットを保存し、ウィジェットのタイムラインを更新する。
    public func save(_ snapshot: FamilySnapshot) {
        guard let defaults else { return }
        do {
            let data = try JSONEncoder().encode(snapshot)
            defaults.set(data, forKey: GenkiConstants.snapshotDefaultsKey)
            reloadWidgets()
        } catch {
            // 失敗してもアプリ本体の動作は継続する（ウィジェットが古くなるだけ）。
            #if DEBUG
            print("GenkiSharedStore save error: \(error)")
            #endif
        }
    }

    /// 保存済みスナップショットを読み込む。無ければ nil。
    public func load() -> FamilySnapshot? {
        guard let defaults,
              let data = defaults.data(forKey: GenkiConstants.snapshotDefaultsKey) else {
            return nil
        }
        return try? JSONDecoder().decode(FamilySnapshot.self, from: data)
    }

    private func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
