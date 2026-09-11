import SwiftUI
import KeyboardCore

/// フリック入力のキー。押している間は、選んでいる方向の文字を大きく出す。
struct FlickKeyView: View {
    let key: FlickKey
    var uppercase = false
    let onInput: (FlickDirection) -> Void
    @State private var direction: FlickDirection?

    var body: some View {
        let shown = direction.flatMap { key.output($0) } ?? key.label
        Text(uppercase ? shown.uppercased() : shown)
            .font(.system(size: direction == nil ? 20 : 26))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(direction == nil ? Color(uiColor: .systemBackground) : Color(uiColor: .systemGray3))
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        direction = Flick.direction(dx: Double(value.translation.width), dy: Double(value.translation.height))
                    }
                    .onEnded { value in
                        let final = Flick.direction(dx: Double(value.translation.width), dy: Double(value.translation.height))
                        direction = nil
                        onInput(final)
                    }
            )
    }
}

/// 左右の列のキー（記号・123・あA・空白・改行など）
struct SideKey: View {
    var title: String? = nil
    var systemImage: String? = nil
    var active = false
    var height: CGFloat = Metrics.keyHeight
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                } else {
                    Text(title ?? "").font(.system(size: 15))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(active ? Color.accentColor.opacity(0.3) : Color(uiColor: .systemGray4))
            )
        }
        .buttonStyle(.plain)
    }
}

/// 押しっぱなしで繰り返すボタン（⌫ とカーソルの ← →）
struct RepeatButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @State private var timer: Timer?

    var body: some View {
        label()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { action() }
            .onLongPressGesture(minimumDuration: 0.4, perform: {
                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                    action()
                }
            }, onPressingChanged: { pressing in
                if !pressing {
                    timer?.invalidate()
                    timer = nil
                }
            })
    }
}

/// ⌫ キー
struct RepeatKey: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        RepeatButton(action: action) {
            Image(systemName: systemImage)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.keyHeight)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(uiColor: .systemGray4)))
    }
}
