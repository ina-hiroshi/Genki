import SwiftUI

/// Genki のタイポグラフィ。iOS ネイティブの SF Pro Rounded を全面採用。
/// Dynamic Type に追従するため固定サイズではなく TextStyle ベース。
enum GenkiFont {
    static func largeTitle() -> Font { .system(.largeTitle, design: .rounded).weight(.bold) }
    static func title() -> Font { .system(.title2, design: .rounded).weight(.semibold) }
    static func headline() -> Font { .system(.headline, design: .rounded).weight(.semibold) }
    static func body() -> Font { .system(.body, design: .rounded) }
    static func callout() -> Font { .system(.callout, design: .rounded) }
    static func caption() -> Font { .system(.caption, design: .rounded) }
}

extension View {
    /// 画面全体に丸ゴシックを適用するための簡易モディファイア。
    func genkiRoundedFont() -> some View {
        fontDesign(.rounded)
    }
}
