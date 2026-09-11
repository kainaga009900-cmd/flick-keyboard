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
        case .symbol:
            SymbolPanel(state: state)
        case .emoji(let tab):
            EmojiPanel(state: state, tab: tab)
        case .settings:
            SettingsPanel(state: state)
        }
    }
}
