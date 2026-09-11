import CoreGraphics

/// キーボードの大きさ（高さは常に同じ：設計書 2章）
enum Metrics {
    static let padding: CGFloat = 6
    static let spacing: CGFloat = 6
    /// 道具の段 / 候補の 2段（38 + 4 + 24）
    static let topAreaHeight: CGFloat = 66
    static let keyHeight: CGFloat = 48
    /// 左右の列の幅
    static let sideWidth: CGFloat = 56
    static var keyAreaHeight: CGFloat { keyHeight * 4 + spacing * 3 }
    static var totalHeight: CGFloat { padding * 2 + topAreaHeight + spacing + keyAreaHeight }
}
