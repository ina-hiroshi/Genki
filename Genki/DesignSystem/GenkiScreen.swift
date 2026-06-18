import SwiftUI

extension View {
    /// Genki 標準の画面背景を適用する。
    func genkiScreenBackground() -> some View {
        background(GenkiPalette.background.ignoresSafeArea())
    }

    /// List / Form のシステム背景を隠し、Genki の背景色に統一する。
    func genkiListStyle() -> some View {
        scrollContentBackground(.hidden)
            .background(GenkiPalette.background)
    }
}
