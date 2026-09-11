import SwiftUI

/// パネルの共通の枠：左に中身、右に ⌫ と「戻る」
struct PanelChrome<Content: View>: View {
    @ObservedObject var state: KeyboardState
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: Metrics.spacing) {
                RepeatKey(systemImage: "delete.left") { state.backspace() }
                SideKey(title: "戻る", height: Metrics.keyHeight * 3 + Metrics.spacing * 2) { state.backToKana() }
            }
            .frame(width: Metrics.sideWidth)
        }
    }
}

struct SymbolPanel: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        PanelChrome(state: state) {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
                    ForEach(PanelData.symbols, id: \.self) { symbol in
                        Button { state.insertDirect(symbol) } label: {
                            Text(symbol)
                                .font(.system(size: 20))
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct EmojiPanel: View {
    @ObservedObject var state: KeyboardState
    let tab: EmojiTab

    var body: some View {
        PanelChrome(state: state) {
            VStack(spacing: 4) {
                Picker("", selection: Binding(get: { tab }, set: { state.mode = .emoji($0) })) {
                    Text("顔文字").tag(EmojiTab.kaomoji)
                    Text("絵文字").tag(EmojiTab.emoji)
                }
                .pickerStyle(.segmented)
                ScrollView {
                    if tab == .emoji {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 8), spacing: 2) {
                            ForEach(PanelData.emoji, id: \.self) { emoji in
                                Button { state.insertDirect(emoji) } label: {
                                    Text(emoji)
                                        .font(.system(size: 26))
                                        .frame(maxWidth: .infinity, minHeight: 36)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                            ForEach(PanelData.kaomoji, id: \.self) { kaomoji in
                                Button { state.insertDirect(kaomoji) } label: {
                                    Text(kaomoji)
                                        .font(.system(size: 14))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                        .frame(maxWidth: .infinity, minHeight: 36)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// ⚙：覚えた言葉を全部忘れる（押すと確認する：設計書 4章）
struct SettingsPanel: View {
    @ObservedObject var state: KeyboardState
    @State private var confirming = false
    @State private var done = false

    var body: some View {
        PanelChrome(state: state) {
            VStack(spacing: 12) {
                if done {
                    Text("覚えた言葉を全部忘れました")
                } else if confirming {
                    Text("本当に全部忘れますか？")
                    HStack(spacing: 12) {
                        Button("忘れる", role: .destructive) {
                            state.forgetAll()
                            done = true
                        }
                        Button("やめる") { confirming = false }
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("覚えた言葉を全部忘れる") { confirming = true }
                        .buttonStyle(.bordered)
                }
            }
        }
    }
}
