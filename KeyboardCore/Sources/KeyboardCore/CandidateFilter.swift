/// 候補 1つ
public struct CandidateItem: Equatable, Sendable {
    /// 画面に出して、確定したら入力される文字
    public let text: String
    /// この候補が受け持つ読み（ひらがな）。打った読みの頭の部分だけのこともある。
    public let reading: String

    public init(text: String, reading: String) {
        self.text = text
        self.reading = reading
    }
}

/// 変換の段と予測の段に出す候補
public struct CandidateSet: Equatable, Sendable {
    public var main: [CandidateItem]
    public var predictions: [CandidateItem]

    public init(main: [CandidateItem], predictions: [CandidateItem]) {
        self.main = main
        self.predictions = predictions
    }

    public static let empty = CandidateSet(main: [], predictions: [])
}

/// 設計書 3章「候補の出し方」
public enum CandidateFilter {
    /// 変換の段：読みが「打った読み全体」か「打った読みの頭の部分」と同じものだけ残す。
    /// 読みが違うもの（打ち間違いの補正）は捨てる。同じ読み・同じ文字の重複は最初のものだけ残す。
    public static func conversion(_ items: [CandidateItem], typed: String) -> [CandidateItem] {
        var seen = Set<String>()
        var result: [CandidateItem] = []
        for item in items where !item.reading.isEmpty && typed.hasPrefix(item.reading) {
            if seen.insert(item.reading + "\t" + item.text).inserted {
                result.append(item)
            }
        }
        return result
    }

    /// 予測の段：読みが打った読みで始まるものだけ残す。変換の段にある文字と同じものは出さない。
    public static func prediction(_ items: [CandidateItem], typed: String, excluding main: [CandidateItem]) -> [CandidateItem] {
        let mainTexts = Set(main.map(\.text))
        var seen = Set<String>()
        var result: [CandidateItem] = []
        for item in items where item.reading.hasPrefix(typed) && !mainTexts.contains(item.text) {
            if seen.insert(item.text).inserted {
                result.append(item)
            }
        }
        return result
    }

    /// 覚えた言葉（learned の順）を先頭に出す。読み全体と同じ候補だけが対象。
    public static func promote(_ items: [CandidateItem], typed: String, learned: [String]) -> [CandidateItem] {
        var front: [CandidateItem] = []
        for text in learned {
            if let item = items.first(where: { $0.text == text && $0.reading == typed }) {
                front.append(item)
            }
        }
        return front + items.filter { !front.contains($0) }
    }
}
