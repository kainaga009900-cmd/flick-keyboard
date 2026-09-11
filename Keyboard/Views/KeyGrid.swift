import SwiftUI
import KeyboardCore

/// 左の列（記号・123・あA・☺/🌐）＋ 真ん中のフリックのキー ＋ 右の列（⌫・空白・改行）
struct KeyGrid: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            VStack(spacing: Metrics.spacing) {
                SideKey(title: "記号", active: state.mode == .symbol) { state.switchMode(.symbol) }
                SideKey(title: "123", active: state.mode == .number) { state.switchMode(.number) }
                SideKey(title: state.mode == .alphabet ? "あいう" : "あA", active: state.mode == .alphabet) {
                    state.switchMode(.alphabet)
                }
                if state.needsGlobe {
                    SideKey(systemImage: "globe") { state.nextKeyboard() }
                } else {
                    SideKey(systemImage: "face.smiling") { state.switchMode(.emoji(.emoji)) }
                }
            }
            .frame(width: Metrics.sideWidth)

            VStack(spacing: Metrics.spacing) {
                centerRows
            }

            VStack(spacing: Metrics.spacing) {
                RepeatKey(systemImage: "delete.left") { state.backspace() }
                SideKey(title: state.reading.isEmpty ? "空白" : "次候補") { state.space() }
                SideKey(title: state.reading.isEmpty ? "改行" : "確定", height: Metrics.keyHeight * 2 + Metrics.spacing) {
                    state.enter()
                }
            }
            .frame(width: Metrics.sideWidth)
        }
    }

    @ViewBuilder private var centerRows: some View {
        switch state.mode {
        case .alphabet:
            ForEach(0..<3, id: \.self) { r in row(FlickLayouts.alphabet[r]) }
            HStack(spacing: Metrics.spacing) {
                SideKey(title: "a/A", active: state.uppercase) { state.uppercase.toggle() }
                FlickKeyView(key: FlickLayouts.alphabetQuote) { state.tapFlick(FlickLayouts.alphabetQuote, $0) }
                FlickKeyView(key: FlickLayouts.alphabetPunct) { state.tapFlick(FlickLayouts.alphabetPunct, $0) }
            }
            .frame(height: Metrics.keyHeight)
        case .number:
            ForEach(0..<4, id: \.self) { r in row(FlickLayouts.number[r]) }
        default:
            ForEach(0..<3, id: \.self) { r in row(FlickLayouts.kana[r]) }
            HStack(spacing: Metrics.spacing) {
                SideKey(title: state.reading.isEmpty ? "^^" : "小゛゜") { state.smallDakuten() }
                FlickKeyView(key: FlickLayouts.wa) { state.tapFlick(FlickLayouts.wa, $0) }
                FlickKeyView(key: FlickLayouts.punctuation) { state.tapFlick(FlickLayouts.punctuation, $0) }
            }
            .frame(height: Metrics.keyHeight)
        }
    }

    private func row(_ keys: [FlickKey]) -> some View {
        HStack(spacing: Metrics.spacing) {
            ForEach(keys, id: \.label) { key in
                FlickKeyView(key: key, uppercase: state.mode == .alphabet && state.uppercase) {
                    state.tapFlick(key, $0)
                }
            }
        }
        .frame(height: Metrics.keyHeight)
    }
}
