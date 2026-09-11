import SwiftUI

struct KeyboardView: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        VStack(spacing: Metrics.spacing) {
            TopArea(state: state)
                .frame(height: Metrics.topAreaHeight)
            content
                .frame(height: Metrics.keyAreaHeight)
        }
        .padding(Metrics.padding)
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.totalHeight)
        .background(Color(uiColor: .systemGray5))
    }

    @ViewBuilder private var content: some View {
        switch state.mode {
        case .kana, .alphabet, .number:
            KeyGrid(state: state)
        case .symbol, .emoji, .settings:
            // Task 8 で専用の画面に置き換える。それまではキーを出しておく。
            KeyGrid(state: state)
        }
    }
}
