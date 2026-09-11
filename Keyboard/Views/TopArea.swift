import SwiftUI
import KeyboardCore

/// 上の段：打っていない時は道具、打っている時は候補の 2段（同じ高さ）
struct TopArea: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        if state.reading.isEmpty {
            Toolbar(state: state)
        } else {
            CandidateBar(state: state)
        }
    }
}

struct Toolbar: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        HStack {
            if state.cursorMode {
                RepeatButton(action: { state.moveCursor(-1) }) {
                    Image(systemName: "arrow.left").font(.title2)
                }
                Button("完了") { state.toggleCursorMode() }
                    .frame(maxWidth: .infinity)
                RepeatButton(action: { state.moveCursor(1) }) {
                    Image(systemName: "arrow.right").font(.title2)
                }
            } else {
                tool("gearshape", label: "設定") { state.switchMode(.settings) }
                tool("arrow.left.and.right", label: "カーソル移動") { state.toggleCursorMode() }
                tool("face.smiling", label: "顔文字・絵文字") { state.switchMode(.emoji(.kaomoji)) }
                tool("chevron.down", label: "閉じる") { state.dismiss() }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private func tool(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }
}

/// 太い段＝読みどおりの変換、細い段＝予測（設計書 3章）
struct CandidateBar: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        VStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(state.candidates.main.enumerated()), id: \.offset) { index, item in
                        Button { state.selectCandidate(index) } label: {
                            Text(item.text)
                                .font(.system(size: 18))
                                .padding(.horizontal, 12)
                                .frame(height: 38)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(index == state.highlighted ? Color.accentColor.opacity(0.25) : Color(uiColor: .systemBackground))
                                )
                        }
                    }
                }
            }
            .frame(height: 38)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(state.candidates.predictions.enumerated()), id: \.offset) { index, item in
                        Button { state.selectPrediction(index) } label: {
                            Text(item.text)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .frame(height: 24)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 0.5, dash: [3]))
                                        .foregroundStyle(.secondary)
                                )
                        }
                    }
                }
            }
            .frame(height: 24)
        }
        .buttonStyle(.plain)
    }
}
