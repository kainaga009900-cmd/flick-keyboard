/// かなの変換に使う小さな道具
public enum Kana {
    /// カタカナをひらがなにする。ァ（U+30A1）〜ヶ（U+30F6）だけを変え、ほかの文字はそのまま。
    public static func toHiragana(_ s: String) -> String {
        var scalars = String.UnicodeScalarView()
        for u in s.unicodeScalars {
            if (0x30A1...0x30F6).contains(u.value), let hiragana = Unicode.Scalar(u.value - 0x60) {
                scalars.append(hiragana)
            } else {
                scalars.append(u)
            }
        }
        return String(scalars)
    }

    /// 小゛゜キーで順番に切り替わる文字のならび（小→゛→゜→元に戻る）
    private static let cycles: [[Character]] = [
        ["あ", "ぁ"], ["い", "ぃ"], ["う", "ぅ", "ゔ"], ["え", "ぇ"], ["お", "ぉ"],
        ["か", "が"], ["き", "ぎ"], ["く", "ぐ"], ["け", "げ"], ["こ", "ご"],
        ["さ", "ざ"], ["し", "じ"], ["す", "ず"], ["せ", "ぜ"], ["そ", "ぞ"],
        ["た", "だ"], ["ち", "ぢ"], ["つ", "っ", "づ"], ["て", "で"], ["と", "ど"],
        ["は", "ば", "ぱ"], ["ひ", "び", "ぴ"], ["ふ", "ぶ", "ぷ"], ["へ", "べ", "ぺ"], ["ほ", "ぼ", "ぽ"],
        ["や", "ゃ"], ["ゆ", "ゅ"], ["よ", "ょ"], ["わ", "ゎ"],
    ]

    /// 小゛゜キーを押したときの次の文字。切り替えられない文字なら nil。
    public static func cycle(_ c: Character) -> Character? {
        for group in cycles {
            if let i = group.firstIndex(of: c) {
                return group[(i + 1) % group.count]
            }
        }
        return nil
    }
}
