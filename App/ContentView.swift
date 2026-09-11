import SwiftUI
import UIKit

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("使えるようにする") {
                    Text("1. iPhone の「設定」アプリを開く")
                    Text("2. 一般 → キーボード → キーボード")
                    Text("3. 「新しいキーボードを追加」→「変換キーボード」を選ぶ")
                    Text("4. 文字を打つ画面で 🌐 を長押しして「変換キーボード」を選ぶ")
                    Button("「設定」アプリを開く") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                Section("安心して使えます") {
                    Text("フルアクセスは必要ありません。打った文字をインターネットに送ることはありません。")
                    Text("覚えた言葉を消したいときは、キーボードの ⚙ から「覚えた言葉を全部忘れる」を押してください。")
                }
                Section {
                    NavigationLink("ライセンス") {
                        LicensesView()
                    }
                }
            }
            .navigationTitle("変換キーボード")
        }
    }
}
