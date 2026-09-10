/// フリックの方向
public enum FlickDirection: CaseIterable, Sendable {
    case center, left, up, right, down
}

/// フリック入力のキー 1つ
public struct FlickKey: Equatable, Sendable {
    /// キーに書く文字
    public let label: String
    /// center, left, up, right, down の順の文字。nil はその方向に文字がない
    public let chars: [String?]

    public init(_ label: String, _ chars: [String?]) {
        self.label = label
        self.chars = chars
    }

    public func output(_ direction: FlickDirection) -> String? {
        let index: Int
        switch direction {
        case .center: index = 0
        case .left: index = 1
        case .up: index = 2
        case .right: index = 3
        case .down: index = 4
        }
        return index < chars.count ? chars[index] : nil
    }
}

public enum Flick {
    /// 指の動いた量から方向を決める。threshold（pt）より動いていなければ center。
    public static func direction(dx: Double, dy: Double, threshold: Double = 20) -> FlickDirection {
        if (dx * dx + dy * dy).squareRoot() < threshold { return .center }
        if abs(dx) > abs(dy) { return dx < 0 ? .left : .right }
        return dy < 0 ? .up : .down
    }
}

/// 各モードのキーの並び（今使っている Simeji と同じ位置）
public enum FlickLayouts {
    public static let kana: [[FlickKey]] = [
        [kana("あ", "あいうえお"), kana("か", "かきくけこ"), kana("さ", "さしすせそ")],
        [kana("た", "たちつてと"), kana("な", "なにぬねの"), kana("は", "はひふへほ")],
        [kana("ま", "まみむめも"), FlickKey("や", ["や", "「", "ゆ", "」", "よ"]), kana("ら", "らりるれろ")],
    ]
    public static let wa = FlickKey("わ", ["わ", "を", "ん", "ー", nil])
    public static let punctuation = FlickKey("、。?!", ["、", "。", "？", "！", "…"])

    public static let alphabet: [[FlickKey]] = [
        [FlickKey("@#/&_", ["@", "#", "/", "&", "_"]), letters("ABC", "abc"), letters("DEF", "def")],
        [letters("GHI", "ghi"), letters("JKL", "jkl"), letters("MNO", "mno")],
        [letters("PQRS", "pqrs"), letters("TUV", "tuv"), letters("WXYZ", "wxyz")],
    ]
    public static let alphabetQuote = FlickKey("'\"()", ["'", "\"", "(", ")", nil])
    public static let alphabetPunct = FlickKey(".,?!", [".", ",", "?", "!", nil])

    public static let number: [[FlickKey]] = [
        ["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["-", "0", "."],
    ].map { row in row.map { FlickKey($0, [$0, nil, nil, nil, nil]) } }

    private static func kana(_ label: String, _ chars: String) -> FlickKey {
        FlickKey(label, chars.map { String($0) })
    }

    private static func letters(_ label: String, _ chars: String) -> FlickKey {
        var list: [String?] = chars.map { String($0) }
        while list.count < 5 { list.append(nil) }
        return FlickKey(label, list)
    }
}
