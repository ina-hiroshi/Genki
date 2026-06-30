import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 16進文字列から Color を生成するための初期化子。App / Widget / Watch で共有。
public extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b, a: Double
        switch cleaned.count {
        case 8: // RRGGBBAA
            r = Double((value & 0xFF00_0000) >> 24) / 255
            g = Double((value & 0x00FF_0000) >> 16) / 255
            b = Double((value & 0x0000_FF00) >> 8) / 255
            a = Double(value & 0x0000_00FF) / 255
        default: // RRGGBB
            r = Double((value & 0xFF0000) >> 16) / 255
            g = Double((value & 0x00FF00) >> 8) / 255
            b = Double(value & 0x0000FF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(genkiHex: String) {
        let cleaned = genkiHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b, a: CGFloat
        switch cleaned.count {
        case 8:
            r = CGFloat((value & 0xFF00_0000) >> 24) / 255
            g = CGFloat((value & 0x00FF_0000) >> 16) / 255
            b = CGFloat((value & 0x0000_FF00) >> 8) / 255
            a = CGFloat(value & 0x0000_00FF) / 255
        default:
            r = CGFloat((value & 0xFF0000) >> 16) / 255
            g = CGFloat((value & 0x00FF00) >> 8) / 255
            b = CGFloat(value & 0x0000FF) / 255
            a = 1
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }

    static func genkiAdaptive(light: String, dark: String) -> UIColor {
        UIColor { traits in
            UIColor(genkiHex: traits.userInterfaceStyle == .dark ? dark : light)
        }
    }
}
#endif

/// Genki のデザイントークン（UIテーマ: シンプル・洗練 × あたたかい元気）。
public enum GenkiPalette {
    /// 元気のオレンジ（主役アクセント）。ライト/ダーク共通。
    public static let primary = Color(hex: "FF7A45")
    public static let primaryDeep = Color(hex: "FF6A35")
    public static let primaryLight = Color(hex: "FF8A5B")

    /// 画面背景（warm off-white / 深い紫がかったダーク）。
    public static var background: Color { adaptive(light: "FFFAF5", dark: "1C1726") }
    /// カード・入力欄の面。
    public static var surface: Color { adaptive(light: "FFFFFF", dark: "2A2336") }
    /// 本文テキスト。
    public static var text: Color { adaptive(light: "2B2233", dark: "F5F0FA") }
    /// 補助テキスト。
    public static var muted: Color { adaptive(light: "6B6478", dark: "A89FB5") }
    /// 区切り線・枠線。
    public static var border: Color { adaptive(light: "E8E0F0", dark: "3D3350") }
    /// 未選択チップ等の薄い背景。
    public static var chipBackground: Color { adaptive(light: "F0EBE6", dark: "3A3248") }

    public static let done = Color(hex: "2FBF71")
    public static let sos = Color(hex: "FF5A5F")
    /// 元気度「ちょっとつらい」用（SOS 赤とは別の落ち着いたトーン）。
    public static let genkiRough = Color(hex: "E8A04A")

    /// メンバーカラー（淡め・控えめに使う）。
    public static let memberColors: [Color] = [
        Color(hex: "2DD4BF"),
        Color(hex: "38BDF8"),
        Color(hex: "FB7185"),
        Color(hex: "34D399"),
        Color(hex: "A78BFA"),
        Color(hex: "FBBF24")
    ]

    public static func memberColor(for index: Int) -> Color {
        memberColors[((index % memberColors.count) + memberColors.count) % memberColors.count]
    }

    private static func adaptive(light: String, dark: String) -> Color {
        #if canImport(UIKit)
        Color(UIColor.genkiAdaptive(light: light, dark: dark))
        #else
        Color(hex: light)
        #endif
    }
}
