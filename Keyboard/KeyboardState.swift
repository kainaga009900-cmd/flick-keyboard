import SwiftUI
import UIKit
import KeyboardCore

enum EmojiTab: Hashable {
    case kaomoji, emoji
}

enum KeyboardMode: Equatable {
    case kana, alphabet, number, symbol, emoji(EmojiTab), settings
}

/// キーボードの状態。画面（SwiftUI）と入力欄（textDocumentProxy）をつなぐ。
@MainActor
final class KeyboardState: ObservableObject {
    @Published private(set) var reading = ""
    @Published private(set) var candidates = CandidateSet.empty
    @Published private(set) var highlighted: Int?
    @Published var mode: KeyboardMode = .kana
    @Published var cursorMode = false
    @Published var uppercase = false
    @Published var needsGlobe = false

    private weak var controller: UIInputViewController?
    private let composer: Composer
    private let learningURL: URL
    private let writer = ProxyWriter()

    init(controller: UIInputViewController) {
        self.controller = controller
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        learningURL = directory.appendingPathComponent("learning.json")
        let dictionary = Bundle.main.bundleURL.appendingPathComponent("Dictionary", isDirectory: true)
        composer = Composer(
            provider: AzooKeyProvider(dictionaryURL: dictionary, workDirectory: directory),
            learning: LearningStore.load(from: learningURL)
        )
    }

    // MARK: - キー

    func tapFlick(_ key: FlickKey, _ direction: FlickDirection) {
        guard let s = key.output(direction) else { return }
        if mode == .kana {
            apply(composer.type(s))
        } else {
            insertDirect(uppercase ? s.uppercased() : s)
        }
    }

    /// 「^^ / 小゛゜」キー：打っている時は小゛゜、打っていない時は顔文字の一覧
    func smallDakuten() {
        if composer.isComposing {
            apply(composer.toggleSmallDakuten())
        } else {
            switchMode(.emoji(.kaomoji))
        }
    }

    func backspace() { apply(composer.backspace()) }

    func space() {
        if mode == .kana {
            apply(composer.space())
        } else {
            insertDirect(" ")
        }
    }

    func enter() { apply(composer.enter()) }
    func selectCandidate(_ index: Int) { apply(composer.selectCandidate(at: index)) }
    func selectPrediction(_ index: Int) { apply(composer.selectPrediction(at: index)) }

    /// 変換を通さずにそのまま入れる（英字・数字・記号・絵文字・顔文字）
    func insertDirect(_ s: String) {
        apply(composer.flush())
        controller?.textDocumentProxy.insertText(s)
    }

    // MARK: - モードと道具

    /// 同じモードのキーをもう一度押したら、ひらがなに戻る
    func switchMode(_ newMode: KeyboardMode) {
        apply(composer.flush())
        cursorMode = false
        mode = (mode == newMode) ? .kana : newMode
    }

    func backToKana() { mode = .kana }

    func toggleCursorMode() {
        apply(composer.flush())
        cursorMode.toggle()
    }

    func moveCursor(_ offset: Int) {
        controller?.textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
    }

    func dismiss() {
        flushAndPersist()
        controller?.dismissKeyboard()
    }

    func nextKeyboard() {
        flushAndPersist()
        controller?.advanceToNextInputMode()
    }

    func forgetAll() {
        composer.forgetAll()
        persist()
    }

    func flushAndPersist() {
        apply(composer.flush())
        persist()
    }

    // MARK: - 内部

    private func persist() {
        try? composer.learning.save(to: learningURL)
    }

    private func apply(_ ops: [TextOp]) {
        if let proxy = controller?.textDocumentProxy {
            for op in ops {
                writer.apply(op, to: proxy)
            }
        }
        reading = composer.reading
        candidates = composer.candidates
        highlighted = composer.highlighted
    }
}
