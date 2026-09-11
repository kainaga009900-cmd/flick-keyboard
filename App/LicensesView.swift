import SwiftUI

/// 使っている部品のライセンス（App/Licenses.txt）を表示する
struct LicensesView: View {
    private let text: String = {
        guard let url = Bundle.main.url(forResource: "Licenses", withExtension: "txt"),
              let body = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return body
    }()

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .padding()
        }
        .navigationTitle("ライセンス")
    }
}
