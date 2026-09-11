import Foundation

/// 入力欄への指示
public enum TextOp: Equatable, Sendable {
    /// 変換中の文字を表示する（空文字なら変換中の表示を消す）
    case setComposing(String)
    /// 確定して入力する
    case commit(String)
    /// カーソルの前を n 文字消す
    case deleteBackward(Int)
}

/// 読みから候補を作るもの（アプリでは azooKey、テストでは偽物）
public protocol CandidateProvider: AnyObject {
    func candidates(for reading: String) -> CandidateSet
    /// 変換をやめたときに呼ぶ
    func reset()
}

/// 打つ→変換→確定の流れと「覚え方のルール」（設計書 3〜5章）
public final class Composer {
    /// 確定してからこの秒数以内に ⌫ したら、その確定は数えない
    public static let undoWindow: TimeInterval = 5

    public private(set) var reading = ""
    public private(set) var candidates = CandidateSet.empty
    /// 空白キーで選んでいる変換の段の位置
    public private(set) var highlighted: Int?
    public private(set) var learning: LearningStore
    public private(set) var learningRevision = 0

    private let provider: CandidateProvider
    private let now: () -> Date
    /// まだ回数に入れていない直前の確定
    private var pending: (reading: String, text: String, at: Date)?

    public init(provider: CandidateProvider, learning: LearningStore = LearningStore(), now: @escaping () -> Date = { Date() }) {
        self.provider = provider
        self.learning = learning
        self.now = now
    }

    public var isComposing: Bool { !reading.isEmpty }

    // MARK: - 操作

    public func type(_ s: String) -> [TextOp] {
        var ops: [TextOp] = []
        if let index = highlighted {
            ops = selectCandidate(at: index)
        }
        settlePending(isBackspace: false)
        reading += s
        highlighted = nil
        refresh()
        return ops + [.setComposing(reading)]
    }

    public func toggleSmallDakuten() -> [TextOp] {
        guard let last = reading.last, let next = Kana.cycle(last) else { return [] }
        settlePending(isBackspace: false)
        reading.removeLast()
        reading.append(next)
        highlighted = nil
        refresh()
        return [.setComposing(reading)]
    }

    public func backspace() -> [TextOp] {
        if reading.isEmpty {
            settlePending(isBackspace: true)
            return [.deleteBackward(1)]
        }
        if highlighted != nil {
            highlighted = nil
            return [.setComposing(reading)]
        }
        reading.removeLast()
        refresh()
        if reading.isEmpty {
            provider.reset()
        }
        return [.setComposing(reading)]
    }

    public func space() -> [TextOp] {
        if reading.isEmpty {
            settlePending(isBackspace: false)
            return [.commit("　")]
        }
        guard !candidates.main.isEmpty else { return [] }
        let next = ((highlighted ?? -1) + 1) % candidates.main.count
        highlighted = next
        return [.setComposing(candidates.main[next].text)]
    }

    public func enter() -> [TextOp] {
        if reading.isEmpty {
            settlePending(isBackspace: false)
            return [.commit("\n")]
        }
        if let index = highlighted {
            return selectCandidate(at: index)
        }
        let text = reading
        finishComposition()
        return [.commit(text)]
    }

    public func selectCandidate(at index: Int) -> [TextOp] {
        guard candidates.main.indices.contains(index) else { return [] }
        let item = candidates.main[index]
        settlePending(isBackspace: false)
        pending = (item.reading, item.text, now())
        reading = String(reading.dropFirst(item.reading.count))
        highlighted = nil
        if reading.isEmpty {
            finishComposition()
            return [.commit(item.text)]
        }
        refresh()
        return [.commit(item.text), .setComposing(reading)]
    }

    public func selectPrediction(at index: Int) -> [TextOp] {
        guard candidates.predictions.indices.contains(index) else { return [] }
        let item = candidates.predictions[index]
        settlePending(isBackspace: false)
        finishComposition()
        return [.commit(item.text)]
    }

    /// キーボードを閉じる・モードを変えるときに呼ぶ。打ちかけの読みはひらがなのまま確定する。
    public func flush() -> [TextOp] {
        settlePending(isBackspace: false)
        guard !reading.isEmpty else { return [] }
        let text = reading
        finishComposition()
        return [.commit(text)]
    }

    /// 入力欄の中身が外から変わったとき（別の欄に移った・送信で空になった）に呼ぶ。
    /// 入力欄には何も書かず、打ちかけの状態だけを捨てる。直前の確定は（⌫ ではないので）回数に入れる。
    public func abandon() {
        settlePending(isBackspace: false)
        guard !reading.isEmpty else { return }
        finishComposition()
    }

    public func forgetAll() {
        learning.reset()
        pending = nil
        learningRevision += 1
    }

    // MARK: - 内部

    /// 直前の確定を回数に入れるか決める。「確定後の最初の操作が ⌫、しかも undoWindow 秒以内」なら入れない。
    private func settlePending(isBackspace: Bool) {
        guard let p = pending else { return }
        pending = nil
        if isBackspace && now().timeIntervalSince(p.at) <= Self.undoWindow { return }
        learning.record(reading: p.reading, text: p.text, at: p.at)
        learningRevision += 1
    }

    private func finishComposition() {
        reading = ""
        highlighted = nil
        candidates = .empty
        provider.reset()
    }

    private func refresh() {
        guard !reading.isEmpty else {
            candidates = .empty
            return
        }
        let raw = provider.candidates(for: reading)
        let main = CandidateFilter.promote(
            CandidateFilter.conversion(raw.main, typed: reading),
            typed: reading,
            learned: learning.learnedTexts(for: reading)
        )
        candidates = CandidateSet(
            main: main,
            predictions: CandidateFilter.prediction(raw.predictions, typed: reading, excluding: main)
        )
    }
}
