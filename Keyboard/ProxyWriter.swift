import UIKit
import KeyboardCore

/// Composer が出した TextOp を入力欄に反映する。
/// 変換中の文字は下線つきの仮の文字（marked text）として出し、確定したら普通の文字にする。
final class ProxyWriter {
    private var hasMarkedText = false

    func apply(_ op: TextOp, to proxy: UITextDocumentProxy) {
        switch op {
        case .setComposing(let text):
            if text.isEmpty {
                if hasMarkedText {
                    proxy.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
                    proxy.unmarkText()
                }
                hasMarkedText = false
            } else {
                proxy.setMarkedText(text, selectedRange: NSRange(location: (text as NSString).length, length: 0))
                hasMarkedText = true
            }
        case .commit(let text):
            if hasMarkedText {
                proxy.setMarkedText(text, selectedRange: NSRange(location: (text as NSString).length, length: 0))
                proxy.unmarkText()
                hasMarkedText = false
            } else {
                proxy.insertText(text)
            }
        case .deleteBackward(let count):
            for _ in 0..<count {
                proxy.deleteBackward()
            }
        }
    }

    /// 入力欄の中身が外から変わったときに呼ぶ。仮の文字（marked text）はもうないものとして扱う。
    func reset() {
        hasMarkedText = false
    }
}
