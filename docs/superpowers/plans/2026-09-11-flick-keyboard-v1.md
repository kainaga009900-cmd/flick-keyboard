# 押し間違えないフリックキーボード 第1版 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 読みが違う候補を出さず、3回選んだ言葉だけを覚える日本語フリックキーボード（iPhone）の第1版を作り、TestFlight で本人の iPhone に届け、App Store に申請する。

**Architecture:** 入力ロジック（フリック配列・候補のふるい分け・覚え方・入力の流れ）は画面から切り離した Swift パッケージ `KeyboardCore` にまとめ、GitHub Actions の Linux 環境で自動テストする。iPhone アプリは XcodeGen の設定ファイルから作り、キーボード拡張が azooKey の変換エンジン（辞書は Apache-2.0 の azooKey_dictionary_storage）と `KeyboardCore` を使う。組み立てと TestFlight へのアップロードは GitHub Actions の macOS 環境で行う（手元に Mac はない）。

**Tech Stack:** Swift 5 言語モード / SwiftUI / UIKit（UIInputViewController）/ AzooKeyKanaKanjiConverter 0.11.x / XcodeGen / GitHub Actions（ubuntu-latest, macos-26）/ XCTest

**Spec:** `docs/superpowers/specs/2026-09-11-henkan-keyboard-design.md`

## Global Constraints

- 作業する PC は Windows。**手元に Swift も Mac もない**。テストとビルドはすべて GitHub Actions で走らせ、結果は `scripts/ci-wait.sh` で待って確かめる。
- 対応 OS は **iOS 17.0 以上**、**iPhone のみ・縦向きのみ**（`TARGETED_DEVICE_FAMILY: "1"`）。
- Swift は **Swift 5 言語モード**（アプリは `SWIFT_VERSION: "5.0"`、`KeyboardCore` は `swift-tools-version: 5.10`）。
- 変換エンジン：`https://github.com/azooKey/AzooKeyKanaKanjiConverter` を `minorVersion: 0.11.2`（= upToNextMinor）で使う。product は **`KanaKanjiConverterModule`（辞書なし版）**。
- 辞書：`azooKey/azooKey_dictionary_storage` のコミット `832fbb0d3039dfaa4b2183956f3d96f6b07eec4d`（Apache-2.0。エンジン v0.11.2 が使っているもの）の `Dictionary/` をキーボードに入れる。**絵文字辞書（azooKey_emoji_dictionary_storage）はライセンス表記がないので入れない**。
- エンジンの設定（設計書 3.3）：`typoCorrectionMode: .disabled` / `requireJapanesePrediction: .manualMix` / `requireEnglishPrediction: .disabled` / `learningType: .nothing` / `zenzaiMode: .off`。
- キーボードは **フルアクセスを求めない**（`RequestsOpenAccess: false`）。ネットには一切つながない。App Group は使わない。
- 覚え方（設計書 4 章）：**3回**選んだら先頭へ。確定後の最初の操作が ⌫ で **5秒以内**なら数えない。最大 **5,000組**、超えたら一番長く使っていない組から消す。
- キーボードの高さは常に **294pt**（上の段 66pt ＝ 変換の段 38pt ＋ すき間 4pt ＋ 予測の段 24pt）。
- Bundle ID：アプリ `io.github.kainaga009900-cmd.flickkeyboard`、キーボード `io.github.kainaga009900-cmd.flickkeyboard.keyboard`。表示名は仮に「変換キーボード」。
- GitHub：**公開**リポジトリ `kainaga009900-cmd/flick-keyboard`。コミットのメールアドレスは GitHub の noreply を使う（本物のアドレスを公開しない）。
- 鍵（App Store Connect API キーなど）は **GitHub Secrets にだけ**置く。リポジトリ・チャット・メモに書かない。鍵の入力はご本人が行う。
- すべてのコミットメッセージの最後に `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>` を付ける（下のコマンドでは 2つ目の `-m` で付けている）。
- 画面の文言は日本語。ユーザーは技術者ではないので、ご本人に操作をお願いするときは 1ステップずつ、何のボタンかを説明する。
- ご本人への確認や Apple のサイトでの操作が要るステップ（Task 1 の Step 1、Task 9、Task 10、Task 11）は、サブエージェントではなくメインのセッションで行う。

## File Structure

```
変換アプリ/
├─ .gitignore
├─ project.yml                          XcodeGen の設定（アプリとキーボードの 2ターゲット）
├─ KeyboardCore/                        画面と切り離した入力ロジック（Linux でテストできる）
│  ├─ Package.swift
│  ├─ Sources/KeyboardCore/
│  │  ├─ Kana.swift                     カタカナ→ひらがな、小゛゜の切り替え
│  │  ├─ FlickLayout.swift              フリックの方向と各キーの文字
│  │  ├─ CandidateFilter.swift          候補のふるい分けと、覚えた言葉の先頭移動
│  │  ├─ LearningStore.swift            「3回で覚える」の記録と保存
│  │  └─ Composer.swift                 打つ→変換→確定の流れ（TextOp を出す）
│  └─ Tests/KeyboardCoreTests/          上の 5ファイルそれぞれのテスト
├─ App/                                 設定アプリ（使い方とライセンス）
│  ├─ FlickKeyboardApp.swift
│  ├─ ContentView.swift
│  ├─ LicensesView.swift
│  ├─ Licenses.txt                      scripts/make-licenses.sh で作る
│  └─ Assets.xcassets/                  アプリのアイコン
├─ Keyboard/                            キーボード本体
│  ├─ KeyboardViewController.swift
│  ├─ KeyboardState.swift               画面と入力欄をつなぐ状態
│  ├─ AzooKeyProvider.swift             azooKey を KeyboardCore.CandidateProvider にする（azooKey を import するのはここだけ）
│  ├─ ProxyWriter.swift                 TextOp を入力欄に反映する
│  ├─ Metrics.swift                     高さ・幅
│  ├─ PanelData.swift                   記号・絵文字・顔文字の一覧
│  └─ Views/
│     ├─ KeyboardView.swift             全体の並び
│     ├─ TopArea.swift                  道具の段 / 候補の 2段
│     ├─ KeyGrid.swift                  左の列・フリックのキー・右の列
│     ├─ Keys.swift                     FlickKeyView / SideKey / RepeatButton / RepeatKey
│     └─ Panels.swift                   記号・顔文字/絵文字・⚙ の画面
├─ Support/                             XcodeGen が作る Info.plist の置き場（git には入れない）
├─ Vendor/azooKey_dictionary_storage/   辞書（scripts/fetch-dictionary.sh で取ってくる。git には入れない）
├─ ci/ExportOptions.plist               TestFlight へのアップロード設定
├─ scripts/
│  ├─ ci-wait.sh                        プッシュ後の GitHub Actions の結果を待つ
│  ├─ fetch-dictionary.sh               辞書を決まったコミットで取ってくる
│  ├─ make-licenses.sh                  Licenses.txt を作る
│  ├─ make-icon.ps1                     仮のアプリアイコンを作る
│  └─ make-screenshots.ps1              App Store 用にスクショの大きさをそろえる
├─ PRIVACY.md / SUPPORT.md              App Store に載せるプライバシーポリシーとサポート
└─ .github/workflows/
   ├─ core-tests.yml                    KeyboardCore のテスト（ubuntu-latest）
   └─ ios.yml                           iPhone アプリの組み立てと TestFlight へのアップロード（macos-26）
```

---

### Task 1: リポジトリの準備と KeyboardCore の土台（Kana）

**Files:**
- Create: `.gitignore`, `scripts/ci-wait.sh`, `.github/workflows/core-tests.yml`
- Create: `KeyboardCore/Package.swift`, `KeyboardCore/Sources/KeyboardCore/Kana.swift`
- Test: `KeyboardCore/Tests/KeyboardCoreTests/KanaTests.swift`

**Interfaces:**
- Produces: `Kana.toHiragana(_ s: String) -> String`、`Kana.cycle(_ c: Character) -> Character?`、`scripts/ci-wait.sh <workflow-file>`

- [ ] **Step 1: ご本人に公開リポジトリを作ってよいか確認する**

チャットで次のように聞き、はっきり「はい」をもらうまで先に進まない。

> GitHub に「flick-keyboard」という名前の**公開**リポジトリを作り、これから作るプログラムをそこに置いていきます（誰でも中身を見られます。メールアドレスは見えないようにします）。進めてよいですか？

- [ ] **Step 2: コミットのメールアドレスを noreply に変え、これまでの 3コミットも付け替える**

Bash（作業フォルダ `C:\Users\81906\変換アプリ`）で実行：

```bash
cd "/c/Users/81906/変換アプリ"
id=$(gh api user --jq .id)
login=$(gh api user --jq .login)
git config user.name "$login"
git config user.email "${id}+${login}@users.noreply.github.com"
git rebase --root --exec "git commit --amend --no-edit --reset-author"
git log --format='%h %ae %s'
```

Expected: 3行とも `...+kainaga009900-cmd@users.noreply.github.com` になっている。

- [ ] **Step 3: `.gitignore` を作る**

```gitignore
# XcodeGen が作るもの
*.xcodeproj/
Support/
# 組み立てで出るもの
.build/
.swiftpm/
DerivedData/
build/
*.xcarchive
# 辞書（scripts/fetch-dictionary.sh で取ってくる）
Vendor/
# 鍵は絶対に入れない
private_keys/
*.p8
```

- [ ] **Step 4: `scripts/ci-wait.sh` を作る**

```bash
#!/usr/bin/env bash
# 使い方: bash scripts/ci-wait.sh core-tests.yml
# いまの HEAD で動いたワークフローを見つけて、終わるまで待つ。失敗したらログの最後を表示して exit 1。
set -euo pipefail
WF="$1"
SHA=$(git rev-parse HEAD)
ID=""
for _ in $(seq 1 60); do
  ID=$(gh run list --workflow "$WF" --commit "$SHA" --limit 1 --json databaseId --jq '.[0].databaseId // empty')
  [ -n "$ID" ] && break
done
if [ -z "$ID" ]; then
  echo "ワークフロー $WF がまだ始まっていません。少し待ってからもう一度実行してください。"
  exit 2
fi
if gh run watch "$ID" --exit-status --interval 10 > /dev/null; then
  echo "PASS: $WF ($ID)"
else
  gh run view "$ID" --log-failed | tail -80
  echo "FAIL: $WF ($ID)"
  exit 1
fi
```

- [ ] **Step 5: `.github/workflows/core-tests.yml` を作る**

```yaml
name: core-tests
on:
  push:
    paths:
      - "KeyboardCore/**"
      - ".github/workflows/core-tests.yml"
  pull_request:
    paths:
      - "KeyboardCore/**"
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Test KeyboardCore
        run: swift test --package-path KeyboardCore
```

- [ ] **Step 6: `KeyboardCore/Package.swift` を作る**

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "KeyboardCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "KeyboardCore", targets: ["KeyboardCore"]),
    ],
    targets: [
        .target(name: "KeyboardCore"),
        .testTarget(name: "KeyboardCoreTests", dependencies: ["KeyboardCore"]),
    ]
)
```

- [ ] **Step 7: 失敗するテストを書く** — `KeyboardCore/Tests/KeyboardCoreTests/KanaTests.swift`

```swift
import XCTest
@testable import KeyboardCore

final class KanaTests: XCTestCase {
    func testKatakanaBecomesHiragana() {
        XCTAssertEqual(Kana.toHiragana("カイギ"), "かいぎ")
        XCTAssertEqual(Kana.toHiragana("ヴァイオリン"), "ゔぁいおりん")
    }

    func testOtherCharactersStayTheSame() {
        XCTAssertEqual(Kana.toHiragana("ラーメン!"), "らーめん!")
        XCTAssertEqual(Kana.toHiragana("会議"), "会議")
    }

    func testCycleGoesSmallThenDakutenThenHandakuten() {
        XCTAssertEqual(Kana.cycle("は"), "ば")
        XCTAssertEqual(Kana.cycle("ば"), "ぱ")
        XCTAssertEqual(Kana.cycle("ぱ"), "は")
        XCTAssertEqual(Kana.cycle("つ"), "っ")
        XCTAssertEqual(Kana.cycle("っ"), "づ")
        XCTAssertEqual(Kana.cycle("づ"), "つ")
        XCTAssertEqual(Kana.cycle("う"), "ぅ")
        XCTAssertEqual(Kana.cycle("ぅ"), "ゔ")
        XCTAssertEqual(Kana.cycle("や"), "ゃ")
    }

    func testCycleReturnsNilWhenThereIsNoVariant() {
        XCTAssertNil(Kana.cycle("ん"))
        XCTAssertNil(Kana.cycle("a"))
    }
}
```

- [ ] **Step 8: 公開リポジトリを作ってプッシュし、テストが失敗するのを確かめる**

```bash
cd "/c/Users/81906/変換アプリ"
git add .gitignore scripts/ci-wait.sh .github/workflows/core-tests.yml KeyboardCore
git commit -m "test: Kana のテストを追加" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
gh repo create flick-keyboard --public --source . --remote origin --push
bash scripts/ci-wait.sh core-tests.yml
```

Expected: `FAIL`（`cannot find 'Kana' in scope`）。

- [ ] **Step 9: 実装する** — `KeyboardCore/Sources/KeyboardCore/Kana.swift`

```swift
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
```

- [ ] **Step 10: プッシュしてテストが通るのを確かめる**

```bash
git add KeyboardCore/Sources/KeyboardCore/Kana.swift
git commit -m "feat: カタカナ→ひらがなと小゛゜の切り替えを追加" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push
bash scripts/ci-wait.sh core-tests.yml
```

Expected: `PASS`

---

### Task 2: フリック配列（FlickLayout）

**Files:**
- Create: `KeyboardCore/Sources/KeyboardCore/FlickLayout.swift`
- Test: `KeyboardCore/Tests/KeyboardCoreTests/FlickLayoutTests.swift`

**Interfaces:**
- Produces:
  - `enum FlickDirection { case center, left, up, right, down }`
  - `struct FlickKey { let label: String; let chars: [String?]; init(_ label: String, _ chars: [String?]); func output(_ d: FlickDirection) -> String? }`（`chars` は center, left, up, right, down の順）
  - `enum Flick { static func direction(dx: Double, dy: Double, threshold: Double = 20) -> FlickDirection }`
  - `enum FlickLayouts { static let kana: [[FlickKey]]（3行×3）; static let wa: FlickKey; static let punctuation: FlickKey; static let alphabet: [[FlickKey]]（3行×3）; static let alphabetQuote: FlickKey; static let alphabetPunct: FlickKey; static let number: [[FlickKey]]（4行×3） }`

- [ ] **Step 1: 失敗するテストを書く** — `KeyboardCore/Tests/KeyboardCoreTests/FlickLayoutTests.swift`

```swift
import XCTest
@testable import KeyboardCore

final class FlickLayoutTests: XCTestCase {
    func testKanaDirections() {
        let a = FlickLayouts.kana[0][0]
        XCTAssertEqual(a.label, "あ")
        XCTAssertEqual(a.output(.center), "あ")
        XCTAssertEqual(a.output(.left), "い")
        XCTAssertEqual(a.output(.up), "う")
        XCTAssertEqual(a.output(.right), "え")
        XCTAssertEqual(a.output(.down), "お")
        let ya = FlickLayouts.kana[2][1]
        XCTAssertEqual(ya.output(.left), "「")
        XCTAssertEqual(ya.output(.up), "ゆ")
        XCTAssertEqual(ya.output(.right), "」")
        XCTAssertEqual(ya.output(.down), "よ")
    }

    func testWaAndPunctuation() {
        XCTAssertEqual(FlickLayouts.wa.output(.left), "を")
        XCTAssertEqual(FlickLayouts.wa.output(.up), "ん")
        XCTAssertEqual(FlickLayouts.wa.output(.right), "ー")
        XCTAssertNil(FlickLayouts.wa.output(.down))
        XCTAssertEqual(FlickLayouts.punctuation.output(.center), "、")
        XCTAssertEqual(FlickLayouts.punctuation.output(.left), "。")
        XCTAssertEqual(FlickLayouts.punctuation.output(.up), "？")
        XCTAssertEqual(FlickLayouts.punctuation.output(.right), "！")
    }

    func testAlphabetAndNumber() {
        XCTAssertEqual(FlickLayouts.alphabet[0][1].output(.center), "a")
        XCTAssertNil(FlickLayouts.alphabet[0][1].output(.right))
        XCTAssertEqual(FlickLayouts.alphabet[2][0].output(.right), "s")
        XCTAssertEqual(FlickLayouts.alphabetQuote.output(.up), "(")
        XCTAssertEqual(FlickLayouts.alphabetPunct.output(.right), "!")
        XCTAssertEqual(FlickLayouts.number.count, 4)
        XCTAssertEqual(FlickLayouts.number[3][1].output(.center), "0")
        XCTAssertNil(FlickLayouts.number[0][0].output(.left))
    }

    func testDirectionFromFingerMovement() {
        XCTAssertEqual(Flick.direction(dx: 5, dy: 5), .center)
        XCTAssertEqual(Flick.direction(dx: -30, dy: 4), .left)
        XCTAssertEqual(Flick.direction(dx: 30, dy: -4), .right)
        XCTAssertEqual(Flick.direction(dx: 3, dy: -40), .up)
        XCTAssertEqual(Flick.direction(dx: -3, dy: 40), .down)
    }
}
```

- [ ] **Step 2: プッシュして失敗を確かめる**

```bash
git add KeyboardCore/Tests/KeyboardCoreTests/FlickLayoutTests.swift
git commit -m "test: フリック配列のテストを追加" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push
bash scripts/ci-wait.sh core-tests.yml
```

Expected: `FAIL`（`cannot find 'FlickLayouts' in scope`）

- [ ] **Step 3: 実装する** — `KeyboardCore/Sources/KeyboardCore/FlickLayout.swift`

```swift
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
```

- [ ] **Step 4: プッシュして通るのを確かめる**

```bash
git add KeyboardCore/Sources/KeyboardCore/FlickLayout.swift
git commit -m "feat: フリックの方向とキー配列を追加" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push
bash scripts/ci-wait.sh core-tests.yml
```

Expected: `PASS`

---

### Task 3: 候補のふるい分け（CandidateFilter）

**Files:**
- Create: `KeyboardCore/Sources/KeyboardCore/CandidateFilter.swift`
- Test: `KeyboardCore/Tests/KeyboardCoreTests/CandidateFilterTests.swift`

**Interfaces:**
- Produces:
  - `struct CandidateItem: Equatable { let text: String; let reading: String; init(text:reading:) }`（`reading` はその候補が受け持つ読み、ひらがな）
  - `struct CandidateSet: Equatable { var main: [CandidateItem]; var predictions: [CandidateItem]; init(main:predictions:); static let empty }`
  - `enum CandidateFilter { static func conversion(_:typed:) -> [CandidateItem]; static func prediction(_:typed:excluding:) -> [CandidateItem]; static func promote(_:typed:learned:) -> [CandidateItem] }`

- [ ] **Step 1: 失敗するテストを書く** — `KeyboardCore/Tests/KeyboardCoreTests/CandidateFilterTests.swift`

```swift
import XCTest
@testable import KeyboardCore

final class CandidateFilterTests: XCTestCase {
    private func c(_ text: String, _ reading: String) -> CandidateItem {
        CandidateItem(text: text, reading: reading)
    }

    func testConversionKeepsOnlyReadingsThatMatchWhatWasTyped() {
        // 開始（かいし）は打ち間違い補正の候補なので出さない。貝（かい）は頭の部分なので出す。
        let raw = [c("会議", "かいぎ"), c("開始", "かいし"), c("回議", "かいぎ"), c("貝", "かい")]
        XCTAssertEqual(
            CandidateFilter.conversion(raw, typed: "かいぎ"),
            [c("会議", "かいぎ"), c("回議", "かいぎ"), c("貝", "かい")]
        )
    }

    func testConversionRemovesDuplicatesAndEmptyReadings() {
        let raw = [c("会議", "かいぎ"), c("会議", "かいぎ"), c("？", "")]
        XCTAssertEqual(CandidateFilter.conversion(raw, typed: "かいぎ"), [c("会議", "かいぎ")])
    }

    func testPredictionKeepsOnlyWordsThatStartWithWhatWasTyped() {
        let main = [c("会議", "かいぎ")]
        let raw = [c("会議室", "かいぎしつ"), c("会議", "かいぎ"), c("階段", "かいだん"), c("会議室", "かいぎしつ")]
        XCTAssertEqual(
            CandidateFilter.prediction(raw, typed: "かいぎ", excluding: main),
            [c("会議室", "かいぎしつ")]
        )
    }

    func testPromoteMovesLearnedWordsToTheFrontInLearnedOrder() {
        let items = [c("会議", "かいぎ"), c("懐疑", "かいぎ"), c("回議", "かいぎ")]
        XCTAssertEqual(
            CandidateFilter.promote(items, typed: "かいぎ", learned: ["回議", "懐疑"]).map(\.text),
            ["回議", "懐疑", "会議"]
        )
    }

    func testPromoteIgnoresCandidatesForOnlyPartOfTheReading() {
        let items = [c("会議", "かいぎ"), c("貝", "かい")]
        XCTAssertEqual(
            CandidateFilter.promote(items, typed: "かいぎ", learned: ["貝"]).map(\.text),
            ["会議", "貝"]
        )
    }
}
```

- [ ] **Step 2: プッシュして失敗を確かめる**

```bash
git add KeyboardCore/Tests/KeyboardCoreTests/CandidateFilterTests.swift
git commit -m "test: 候補のふるい分けのテストを追加" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push
bash scripts/ci-wait.sh core-tests.yml
```

Expected: `FAIL`（`cannot find 'CandidateItem' in scope`）

- [ ] **Step 3: 実装する** — `KeyboardCore/Sources/KeyboardCore/CandidateFilter.swift`

```swift
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
```

- [ ] **Step 4: プッシュして通るのを確かめる**

```bash
git add KeyboardCore/Sources/KeyboardCore/CandidateFilter.swift
git commit -m "feat: 読みが違う候補を捨てるふるい分けを追加" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push
bash scripts/ci-wait.sh core-tests.yml
```

Expected: `PASS`

---

### Task 4: 覚え方の記録（LearningStore）

**Files:**
- Create: `KeyboardCore/Sources/KeyboardCore/LearningStore.swift`
- Test: `KeyboardCore/Tests/KeyboardCoreTests/LearningStoreTests.swift`

**Interfaces:**
- Produces:
  - `struct LearningStore: Codable, Equatable`
  - `static let threshold = 3`、`static let capacity = 5000`
  - `private(set) var entries: [String: Entry]`（`Entry { count: Int; lastUsed: Date }`）
  - `mutating func record(reading: String, text: String, at: Date)`
  - `func learnedTexts(for reading: String) -> [String]`（3回以上。回数の多い順、同じなら最近の順）
  - `func count(reading: String, text: String) -> Int`
  - `mutating func reset()`
  - `func save(to url: URL) throws`、`static func load(from url: URL) -> LearningStore`（読めなければ空）

- [ ] **Step 1: 失敗するテストを書く** — `KeyboardCore/Tests/KeyboardCoreTests/LearningStoreTests.swift`

```swift
import Foundation
import XCTest
@testable import KeyboardCore

final class LearningStoreTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    func testTwoTimesIsNotEnough() {
        var store = LearningStore()
        store.record(reading: "かいぎ", text: "回議", at: t0)
        store.record(reading: "かいぎ", text: "回議", at: t0.addingTimeInterval(1))
        XCTAssertEqual(store.learnedTexts(for: "かいぎ"), [])
        XCTAssertEqual(store.count(reading: "かいぎ", text: "回議"), 2)
    }

    func testThreeTimesIsLearnedOnlyForThatReading() {
        var store = LearningStore()
        for i in 0..<3 {
            store.record(reading: "かいぎ", text: "回議", at: t0.addingTimeInterval(Double(i)))
        }
        XCTAssertEqual(store.learnedTexts(for: "かいぎ"), ["回議"])
        XCTAssertEqual(store.learnedTexts(for: "かい"), [])
    }

    func testMoreUsesComeFirstThenMoreRecent() {
        var store = LearningStore()
        for i in 0..<4 { store.record(reading: "かいぎ", text: "懐疑", at: t0.addingTimeInterval(Double(i))) }
        for i in 0..<3 { store.record(reading: "かいぎ", text: "回議", at: t0.addingTimeInterval(Double(10 + i))) }
        for i in 0..<3 { store.record(reading: "かいぎ", text: "会議", at: t0.addingTimeInterval(Double(20 + i))) }
        XCTAssertEqual(store.learnedTexts(for: "かいぎ"), ["懐疑", "会議", "回議"])
    }

    func testLeastRecentlyUsedIsRemovedOverCapacity() {
        var store = LearningStore()
        for i in 0...LearningStore.capacity {
            store.record(reading: "よみ\(i)", text: "語\(i)", at: t0.addingTimeInterval(Double(i)))
        }
        XCTAssertEqual(store.entries.count, LearningStore.capacity)
        XCTAssertEqual(store.count(reading: "よみ0", text: "語0"), 0)
        XCTAssertEqual(store.count(reading: "よみ1", text: "語1"), 1)
    }

    func testResetForgetsEverything() {
        var store = LearningStore()
        store.record(reading: "かいぎ", text: "回議", at: t0)
        store.reset()
        XCTAssertTrue(store.entries.isEmpty)
    }

    func testSaveAndLoadRoundTrip() throws {
        var store = LearningStore()
        store.record(reading: "かいぎ", text: "回議", at: t0)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        try store.save(to: url)
        XCTAssertEqual(LearningStore.load(from: url), store)
    }

    func testLoadingAMissingFileGivesAnEmptyStore() {
        let url = URL(fileURLWithPath: "/no/such/dir/learning.json")
        XCTAssertEqual(LearningStore.load(from: url), LearningStore())
    }
}
```

- [ ] **Step 2: プッシュして失敗を確かめる**

```bash
git add KeyboardCore/Tests/KeyboardCoreTests/LearningStoreTests.swift
git commit -m "test: 覚え方の記録のテストを追加" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push
bash scripts/ci-wait.sh core-tests.yml
```

Expected: `FAIL`（`cannot find 'LearningStore' in scope`）

- [ ] **Step 3: 実装する** — `KeyboardCore/Sources/KeyboardCore/LearningStore.swift`

```swift
import Foundation

/// 「読み」と「選んだ言葉」の組ごとに、何回選んだかを記録する（設計書 4章）
public struct LearningStore: Codable, Equatable {
    public struct Entry: Codable, Equatable {
        public var count: Int
        public var lastUsed: Date
    }

    /// この回数以上選んだ言葉を先頭に出す
    public static let threshold = 3
    /// 覚えておく組の最大数
    public static let capacity = 5000

    public private(set) var entries: [String: Entry] = [:]

    public init() {}

    private static func key(_ reading: String, _ text: String) -> String {
        reading + "\t" + text
    }

    public mutating func record(reading: String, text: String, at date: Date) {
        let key = Self.key(reading, text)
        var entry = entries[key] ?? Entry(count: 0, lastUsed: date)
        entry.count += 1
        entry.lastUsed = date
        entries[key] = entry
        if entries.count > Self.capacity,
           let oldest = entries.min(by: { $0.value.lastUsed < $1.value.lastUsed })?.key {
            entries.removeValue(forKey: oldest)
        }
    }

    /// threshold 回以上選んだ言葉。回数の多い順、同じ回数なら最近使った順。
    public func learnedTexts(for reading: String) -> [String] {
        let prefix = reading + "\t"
        return entries
            .filter { $0.key.hasPrefix(prefix) && $0.value.count >= Self.threshold }
            .sorted { ($0.value.count, $0.value.lastUsed) > ($1.value.count, $1.value.lastUsed) }
            .map { String($0.key.dropFirst(prefix.count)) }
    }

    public func count(reading: String, text: String) -> Int {
        entries[Self.key(reading, text)]?.count ?? 0
    }

    public mutating func reset() {
        entries.removeAll()
    }

    public func save(to url: URL) throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: url, options: .atomic)
    }

    /// 保存したファイルを読む。ファイルがない・壊れているときは空で始める。
    public static func load(from url: URL) -> LearningStore {
        guard let data = try? Data(contentsOf: url),
              let store = try? JSONDecoder().decode(LearningStore.self, from: data) else {
            return LearningStore()
        }
        return store
    }
}
```

- [ ] **Step 4: プッシュして通るのを確かめる**

```bash
git add KeyboardCore/Sources/KeyboardCore/LearningStore.swift
git commit -m "feat: 3回選んだ言葉だけを覚える記録を追加" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push
bash scripts/ci-wait.sh core-tests.yml
```

Expected: `PASS`

---

### Task 5: 打つ→変換→確定の流れ（Composer）

**Files:**
- Create: `KeyboardCore/Sources/KeyboardCore/Composer.swift`
- Test: `KeyboardCore/Tests/KeyboardCoreTests/ComposerTests.swift`

**Interfaces:**
- Consumes: `Kana.cycle`（Task 1）、`CandidateItem` / `CandidateSet` / `CandidateFilter`（Task 3）、`LearningStore`（Task 4）
- Produces:
  - `enum TextOp: Equatable { case setComposing(String); case commit(String); case deleteBackward(Int) }`
  - `protocol CandidateProvider: AnyObject { func candidates(for reading: String) -> CandidateSet; func reset() }`
  - `final class Composer`
    - `init(provider: CandidateProvider, learning: LearningStore = LearningStore(), now: @escaping () -> Date = { Date() })`
    - `static let undoWindow: TimeInterval = 5`
    - 読み取り：`reading: String`、`candidates: CandidateSet`、`highlighted: Int?`、`learning: LearningStore`、`isComposing: Bool`
    - 操作（どれも `[TextOp]` を返す）：`type(_:)`、`toggleSmallDakuten()`、`backspace()`、`space()`、`enter()`、`selectCandidate(at:)`、`selectPrediction(at:)`、`flush()`
    - `forgetAll()`

- [ ] **Step 1: 失敗するテストを書く** — `KeyboardCore/Tests/KeyboardCoreTests/ComposerTests.swift`

```swift
import Foundation
import XCTest
@testable import KeyboardCore

final class FakeProvider: CandidateProvider {
    var table: [String: CandidateSet] = [:]
    var resetCount = 0
    func candidates(for reading: String) -> CandidateSet { table[reading] ?? .empty }
    func reset() { resetCount += 1 }
}

final class TestClock {
    var now = Date(timeIntervalSince1970: 1_000_000)
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

final class ComposerTests: XCTestCase {
    private var provider: FakeProvider!
    private var clock: TestClock!
    private var composer: Composer!

    private func c(_ text: String, _ reading: String) -> CandidateItem {
        CandidateItem(text: text, reading: reading)
    }

    override func setUp() {
        super.setUp()
        provider = FakeProvider()
        provider.table["かいぎ"] = CandidateSet(
            main: [c("会議", "かいぎ"), c("開始", "かいし"), c("懐疑", "かいぎ"), c("回議", "かいぎ")],
            predictions: [c("会議室", "かいぎしつ"), c("階段", "かいだん")]
        )
        provider.table["あしたかいぎ"] = CandidateSet(
            main: [c("明日会議", "あしたかいぎ"), c("明日", "あした")],
            predictions: []
        )
        let clock = TestClock()
        self.clock = clock
        composer = Composer(provider: provider, now: { clock.now })
    }

    /// 「かいぎ」と打って、変換の段の index 番目を選ぶ（はじめは 0:会議 1:懐疑 2:回議）
    private func choose(_ index: Int) {
        _ = composer.type("かいぎ")
        _ = composer.selectCandidate(at: index)
    }

    func testTypingShowsReadingAndFilteredCandidates() {
        XCTAssertEqual(composer.type("かいぎ"), [.setComposing("かいぎ")])
        XCTAssertEqual(composer.candidates.main.map(\.text), ["会議", "懐疑", "回議"])
        XCTAssertEqual(composer.candidates.predictions.map(\.text), ["会議室"])
    }

    func testSelectingAWholeCandidateCommitsAndEndsComposition() {
        _ = composer.type("かいぎ")
        XCTAssertEqual(composer.selectCandidate(at: 2), [.commit("回議")])
        XCTAssertEqual(composer.reading, "")
        XCTAssertEqual(composer.candidates, .empty)
        XCTAssertEqual(provider.resetCount, 1)
    }

    func testSelectingTheFirstClauseKeepsTheRest() {
        _ = composer.type("あしたかいぎ")
        XCTAssertEqual(composer.selectCandidate(at: 1), [.commit("明日"), .setComposing("かいぎ")])
        XCTAssertEqual(composer.reading, "かいぎ")
        XCTAssertEqual(composer.candidates.main.first?.text, "会議")
    }

    func testThreeChoicesMoveTheWordToTheFront() {
        for _ in 0..<3 { choose(2); clock.advance(10) }
        _ = composer.flush()
        _ = composer.type("かいぎ")
        XCTAssertEqual(composer.candidates.main.first?.text, "回議")
    }

    func testTwoChoicesAreNotEnough() {
        for _ in 0..<2 { choose(2); clock.advance(10) }
        _ = composer.flush()
        _ = composer.type("かいぎ")
        XCTAssertEqual(composer.candidates.main.first?.text, "会議")
    }

    func testBackspaceWithinFiveSecondsIsNotCounted() {
        for _ in 0..<3 {
            choose(2)
            clock.advance(2)
            XCTAssertEqual(composer.backspace(), [.deleteBackward(1)])
            clock.advance(10)
        }
        XCTAssertEqual(composer.learning.count(reading: "かいぎ", text: "回議"), 0)
    }

    func testBackspaceAfterFiveSecondsIsCounted() {
        choose(2)
        clock.advance(6)
        _ = composer.backspace()
        XCTAssertEqual(composer.learning.count(reading: "かいぎ", text: "回議"), 1)
    }

    func testBackspaceAfterAnotherActionIsCounted() {
        choose(2)
        clock.advance(1)
        _ = composer.type("あ")
        _ = composer.backspace()
        _ = composer.backspace()
        XCTAssertEqual(composer.learning.count(reading: "かいぎ", text: "回議"), 1)
    }

    func testSpaceCyclesCandidatesAndEnterConfirmsTheHighlightedOne() {
        _ = composer.type("かいぎ")
        XCTAssertEqual(composer.space(), [.setComposing("会議")])
        XCTAssertEqual(composer.space(), [.setComposing("懐疑")])
        XCTAssertEqual(composer.enter(), [.commit("懐疑")])
        _ = composer.flush()
        XCTAssertEqual(composer.learning.count(reading: "かいぎ", text: "懐疑"), 1)
    }

    func testTypingAfterSpaceCommitsTheHighlightedCandidate() {
        _ = composer.type("かいぎ")
        _ = composer.space()
        _ = composer.space()
        XCTAssertEqual(composer.type("の"), [.commit("懐疑"), .setComposing("の")])
        XCTAssertEqual(composer.learning.count(reading: "かいぎ", text: "懐疑"), 1)
    }

    func testEnterWithoutChoosingCommitsHiraganaAndLearnsNothing() {
        _ = composer.type("かいぎ")
        XCTAssertEqual(composer.enter(), [.commit("かいぎ")])
        _ = composer.flush()
        XCTAssertTrue(composer.learning.entries.isEmpty)
    }

    func testSpaceAndEnterWhenNotComposing() {
        XCTAssertEqual(composer.space(), [.commit("　")])
        XCTAssertEqual(composer.enter(), [.commit("\n")])
    }

    func testBackspaceWhileHighlightedGoesBackToTheReading() {
        _ = composer.type("かいぎ")
        _ = composer.space()
        XCTAssertEqual(composer.backspace(), [.setComposing("かいぎ")])
        XCTAssertNil(composer.highlighted)
    }

    func testBackspaceToEmptyEndsComposition() {
        _ = composer.type("か")
        XCTAssertEqual(composer.backspace(), [.setComposing("")])
        XCTAssertEqual(composer.reading, "")
        XCTAssertEqual(provider.resetCount, 1)
    }

    func testSmallDakutenChangesTheLastCharacter() {
        _ = composer.type("は")
        XCTAssertEqual(composer.toggleSmallDakuten(), [.setComposing("ば")])
        XCTAssertEqual(composer.toggleSmallDakuten(), [.setComposing("ぱ")])
    }

    func testSmallDakutenDoesNothingWhenNotComposing() {
        XCTAssertEqual(composer.toggleSmallDakuten(), [])
    }

    func testPredictionCommitsWithoutLearning() {
        _ = composer.type("かいぎ")
        XCTAssertEqual(composer.selectPrediction(at: 0), [.commit("会議室")])
        _ = composer.flush()
        XCTAssertTrue(composer.learning.entries.isEmpty)
        XCTAssertEqual(composer.reading, "")
    }

    func testForgetAllClearsLearning() {
        for _ in 0..<3 { choose(2); clock.advance(10) }
        _ = composer.flush()
        composer.forgetAll()
        XCTAssertTrue(composer.learning.entries.isEmpty)
    }

    func testFlushCommitsTheUnfinishedReading() {
        _ = composer.type("かい")
        XCTAssertEqual(composer.flush(), [.commit("かい")])
        XCTAssertEqual(composer.reading, "")
    }
}
```

- [ ] **Step 2: プッシュして失敗を確かめる**

```bash
git add KeyboardCore/Tests/KeyboardCoreTests/ComposerTests.swift
git commit -m "test: 入力の流れのテストを追加" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push
bash scripts/ci-wait.sh core-tests.yml
```

Expected: `FAIL`（`cannot find type 'CandidateProvider' in scope`）

- [ ] **Step 3: 実装する** — `KeyboardCore/Sources/KeyboardCore/Composer.swift`

```swift
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

    public func forgetAll() {
        learning.reset()
        pending = nil
    }

    // MARK: - 内部

    /// 直前の確定を回数に入れるか決める。「確定後の最初の操作が ⌫、しかも undoWindow 秒以内」なら入れない。
    private func settlePending(isBackspace: Bool) {
        guard let p = pending else { return }
        pending = nil
        if isBackspace && now().timeIntervalSince(p.at) <= Self.undoWindow { return }
        learning.record(reading: p.reading, text: p.text, at: p.at)
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
```

- [ ] **Step 4: プッシュして通るのを確かめる**

```bash
git add KeyboardCore/Sources/KeyboardCore/Composer.swift
git commit -m "feat: 打つ→変換→確定の流れと覚え方のルールを追加" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push
bash scripts/ci-wait.sh core-tests.yml
```

Expected: `PASS`（テスト 5ファイル分すべて）

---

### Task 6: Xcode プロジェクトと設定アプリ（組み立てを CI で確かめる）

**Files:**
- Create: `project.yml`, `scripts/fetch-dictionary.sh`, `scripts/make-licenses.sh`, `scripts/make-icon.ps1`
- Create: `App/FlickKeyboardApp.swift`, `App/ContentView.swift`, `App/LicensesView.swift`, `App/Licenses.txt`（スクリプトで作る）
- Create: `App/Assets.xcassets/Contents.json`, `App/Assets.xcassets/AppIcon.appiconset/Contents.json`, `App/Assets.xcassets/AppIcon.appiconset/icon-1024.png`（スクリプトで作る）
- Create: `Keyboard/KeyboardViewController.swift`（仮。Task 7 で置き換える）
- Create: `.github/workflows/ios.yml`（build ジョブのみ。upload は Task 9）

**Interfaces:**
- Consumes: `KeyboardCore` パッケージ（Task 1〜5）
- Produces: ターゲット `FlickKeyboard`（アプリ）と `KeyboardExtension`（キーボード、モジュール名 `KeyboardExtension`）。キーボードのバンドルに `Dictionary/` フォルダが入る。

- [ ] **Step 1: `scripts/fetch-dictionary.sh` を作る**

```bash
#!/usr/bin/env bash
# azooKey の辞書（Apache-2.0）を、エンジン v0.11.2 と同じコミットで Vendor/ に取ってくる。
set -euo pipefail
SHA=832fbb0d3039dfaa4b2183956f3d96f6b07eec4d
DEST=Vendor/azooKey_dictionary_storage
if [ -d "$DEST/Dictionary" ]; then
  echo "辞書はもうあります: $DEST"
  exit 0
fi
rm -rf "$DEST"
mkdir -p "$DEST"
git -C "$DEST" init -q
git -C "$DEST" remote add origin https://github.com/azooKey/azooKey_dictionary_storage
git -C "$DEST" fetch -q --depth 1 origin "$SHA"
git -C "$DEST" checkout -q FETCH_HEAD
test -d "$DEST/Dictionary"
echo "辞書を取ってきました: $DEST"
```

- [ ] **Step 2: `project.yml` を作る**

```yaml
name: FlickKeyboard
options:
  deploymentTarget:
    iOS: "17.0"
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "5.0"
    MARKETING_VERSION: "1.0"
    CURRENT_PROJECT_VERSION: "${BUILD_NUMBER}"
    DEVELOPMENT_TEAM: "${APPLE_TEAM_ID}"
    CODE_SIGN_STYLE: Automatic
    TARGETED_DEVICE_FAMILY: "1"
packages:
  AzooKeyKanaKanjiConverter:
    url: https://github.com/azooKey/AzooKeyKanaKanjiConverter
    minorVersion: 0.11.2
  KeyboardCore:
    path: KeyboardCore
targets:
  FlickKeyboard:
    type: application
    platform: iOS
    sources:
      - path: App
    info:
      path: Support/App-Info.plist
      properties:
        CFBundleDisplayName: 変換キーボード
        LSRequiresIPhoneOS: true
        UILaunchScreen: {}
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
        ITSAppUsesNonExemptEncryption: false
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: io.github.kainaga009900-cmd.flickkeyboard
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    dependencies:
      - target: KeyboardExtension
  KeyboardExtension:
    type: app-extension
    platform: iOS
    sources:
      - path: Keyboard
      - path: Vendor/azooKey_dictionary_storage/Dictionary
        type: folder
        buildPhase: resources
    info:
      path: Support/Keyboard-Info.plist
      properties:
        CFBundleDisplayName: 変換キーボード
        NSExtension:
          NSExtensionPointIdentifier: com.apple.keyboard-service
          NSExtensionPrincipalClass: "$(PRODUCT_MODULE_NAME).KeyboardViewController"
          NSExtensionAttributes:
            IsASCIICapable: false
            PrefersRightToLeft: false
            PrimaryLanguage: ja-JP
            RequestsOpenAccess: false
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: io.github.kainaga009900-cmd.flickkeyboard.keyboard
        APPLICATION_EXTENSION_API_ONLY: YES
    dependencies:
      - package: AzooKeyKanaKanjiConverter
        product: KanaKanjiConverterModule
      - package: KeyboardCore
        product: KeyboardCore
schemes:
  FlickKeyboard:
    build:
      targets:
        FlickKeyboard: all
    archive:
      config: Release
```

- [ ] **Step 3: 設定アプリを作る** — `App/FlickKeyboardApp.swift`

```swift
import SwiftUI

@main
struct FlickKeyboardApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

`App/ContentView.swift`

```swift
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
```

`App/LicensesView.swift`

```swift
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
```

- [ ] **Step 4: `scripts/make-licenses.sh` を作って `App/Licenses.txt` を作る**

```bash
#!/usr/bin/env bash
# アプリに組み込む部品のライセンス全文を App/Licenses.txt にまとめる。
# 部品: 変換エンジン、辞書、エンジンが使う Apple / 外部のライブラリ（絵文字辞書は組み込まない）
set -euo pipefail
OUT=App/Licenses.txt
{
  echo "このアプリは次のオープンソースソフトウェアを使っています。"
  echo
} > "$OUT"
for spec in \
  "AzooKeyKanaKanjiConverter|azooKey/AzooKeyKanaKanjiConverter" \
  "azooKey_dictionary_storage|azooKey/azooKey_dictionary_storage" \
  "swift-algorithms|apple/swift-algorithms" \
  "swift-collections|apple/swift-collections" \
  "swift-numerics|apple/swift-numerics" \
  "swift-tokenizers|ensan-hcl/swift-tokenizers" \
  "Jinja|johnmai-dev/Jinja"; do
  name=${spec%%|*}
  repo=${spec##*|}
  {
    echo "=================================================="
    echo "$name  https://github.com/$repo"
    echo "=================================================="
    gh api "repos/$repo/license" --jq '.content' | base64 -d
    echo
  } >> "$OUT"
done
echo "作りました: $OUT"
```

実行して中身を確かめる：

```bash
bash scripts/make-licenses.sh
grep -c "==========" App/Licenses.txt
```

Expected: `14`（7部品 × 区切り線 2本）

- [ ] **Step 5: 仮のアイコンを作る** — `scripts/make-icon.ps1`

```powershell
# 1024x1024 の仮アイコン（緑の背景に白い「変」）を作る。App Store の決まりで透明（アルファ）なしの PNG にする。
param([string]$Out = "App/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
$bmp = New-Object System.Drawing.Bitmap 1024, 1024, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::FromArgb(29, 158, 117))
$font = New-Object System.Drawing.Font("Yu Gothic UI", 560, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$format = New-Object System.Drawing.StringFormat
$format.Alignment = [System.Drawing.StringAlignment]::Center
$format.LineAlignment = [System.Drawing.StringAlignment]::Center
$rect = New-Object System.Drawing.RectangleF 0, 0, 1024, 1024
$g.DrawString("変", $font, [System.Drawing.Brushes]::White, $rect, $format)
$bmp.Save((Resolve-Path -LiteralPath (Split-Path $Out)).Path + "\" + (Split-Path $Out -Leaf), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output "作りました: $Out"
```

PowerShell で実行し、アルファなし（PNG の色タイプ = 2）を確かめる：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/make-icon.ps1
[IO.File]::ReadAllBytes("App/Assets.xcassets/AppIcon.appiconset/icon-1024.png")[25]
```

Expected: `2`

- [ ] **Step 6: アセットカタログの JSON を作る**

`App/Assets.xcassets/Contents.json`

```json
{
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`App/Assets.xcassets/AppIcon.appiconset/Contents.json`

```json
{
  "images" : [
    { "filename" : "icon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 7: 仮のキーボードを作る** — `Keyboard/KeyboardViewController.swift`（Task 7 で丸ごと置き換える）

```swift
import UIKit

/// 組み立ての確認用。Task 7 で本物に置き換える。
final class KeyboardViewController: UIInputViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let button = UIButton(type: .system)
        button.setTitle("次のキーボード", for: .normal)
        button.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            view.heightAnchor.constraint(equalToConstant: 294),
        ])
    }
}
```

- [ ] **Step 8: `.github/workflows/ios.yml` を作る（build ジョブ）**

```yaml
name: ios
on:
  push:
    branches: [main]
    paths:
      - "App/**"
      - "Keyboard/**"
      - "KeyboardCore/**"
      - "project.yml"
      - "ci/**"
      - "scripts/fetch-dictionary.sh"
      - ".github/workflows/ios.yml"
  pull_request:
  workflow_dispatch:
env:
  BUILD_NUMBER: ${{ github.run_number }}
jobs:
  build:
    runs-on: macos-26
    steps:
      - uses: actions/checkout@v4
      - name: Cache dictionary
        uses: actions/cache@v4
        with:
          path: Vendor/azooKey_dictionary_storage
          key: dictionary-832fbb0d3039dfaa4b2183956f3d96f6b07eec4d
      - name: Fetch dictionary
        run: bash scripts/fetch-dictionary.sh
      - name: Install XcodeGen
        run: brew install xcodegen
      - name: Generate project
        run: xcodegen generate
      - name: Build (no signing)
        run: |
          xcodebuild build \
            -project FlickKeyboard.xcodeproj \
            -scheme FlickKeyboard \
            -sdk iphoneos \
            -configuration Release \
            -destination 'generic/platform=iOS' \
            CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 9: プッシュして組み立てが通るのを確かめる**

```bash
git add project.yml scripts App Keyboard .github/workflows/ios.yml
git commit -m "feat: Xcode プロジェクトと設定アプリ、iOS の組み立てを追加" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push
bash scripts/ci-wait.sh ios.yml
```

Expected: `PASS`（初回はエンジンと辞書のダウンロードで 10〜20分かかる）

---

### Task 7: キーボード本体（打つ・変換・2段の候補）

**Files:**
- Create: `Keyboard/Metrics.swift`, `Keyboard/ProxyWriter.swift`, `Keyboard/AzooKeyProvider.swift`, `Keyboard/KeyboardState.swift`
- Create: `Keyboard/Views/KeyboardView.swift`, `Keyboard/Views/TopArea.swift`, `Keyboard/Views/KeyGrid.swift`, `Keyboard/Views/Keys.swift`
- Modify（丸ごと置き換え）: `Keyboard/KeyboardViewController.swift`

**Interfaces:**
- Consumes: `Composer` / `TextOp` / `CandidateProvider` / `CandidateSet` / `CandidateItem` / `LearningStore` / `FlickKey` / `FlickDirection` / `Flick` / `FlickLayouts` / `Kana`（Task 1〜5）
- Produces（Task 8 が使う）:
  - `enum KeyboardMode: Equatable { case kana, alphabet, number, symbol, emoji(EmojiTab), settings }`、`enum EmojiTab: Hashable { case kaomoji, emoji }`
  - `KeyboardState`（`@MainActor ObservableObject`）：`mode`（`@Published var`）、`insertDirect(_:)`、`backspace()`、`backToKana()`、`switchMode(_:)`、`forgetAll()`
  - `Metrics.keyHeight` / `Metrics.spacing` / `Metrics.sideWidth`
  - `SideKey(title:systemImage:active:height:action:)`、`RepeatKey(systemImage:action:)`
  - `KeyboardView` の `content` の `case .symbol, .emoji, .settings:`（Task 8 で置き換える）

- [ ] **Step 1: `Keyboard/Metrics.swift`**

```swift
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
```

- [ ] **Step 2: `Keyboard/ProxyWriter.swift`**

```swift
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
}
```

- [ ] **Step 3: `Keyboard/AzooKeyProvider.swift`（azooKey を import するのはこのファイルだけ）**

```swift
import Foundation
import KanaKanjiConverterModule
import KeyboardCore

/// azooKey の変換エンジンを KeyboardCore.CandidateProvider として使う。
/// 設定は設計書 3.3：打ち間違い補正なし・予測は分けて受け取る・エンジン側では覚えない。
final class AzooKeyProvider: KeyboardCore.CandidateProvider {
    private let converter: KanaKanjiConverter
    private let options: ConvertRequestOptions

    init(dictionaryURL: URL, workDirectory: URL) {
        converter = KanaKanjiConverter(dictionaryURL: dictionaryURL, preloadDictionary: false)
        options = ConvertRequestOptions(
            N_best: 10,
            requireJapanesePrediction: .manualMix,
            requireEnglishPrediction: .disabled,
            keyboardLanguage: .ja_JP,
            learningType: .nothing,
            memoryDirectoryURL: workDirectory,
            sharedContainerURL: workDirectory,
            textReplacer: .empty,
            specialCandidateProviders: [],
            zenzaiMode: .off,
            typoCorrectionMode: .disabled,
            metadata: .init(versionString: "FlickKeyboard 1.0")
        )
    }

    func candidates(for reading: String) -> KeyboardCore.CandidateSet {
        var composing = ComposingText()
        composing.insertAtCursorPosition(reading, inputStyle: .direct)
        let result = converter.requestCandidates(composing, options: options)
        return KeyboardCore.CandidateSet(
            main: result.mainResults.map(Self.item),
            predictions: result.predictionResults.map(Self.item)
        )
    }

    func reset() {
        converter.stopComposition()
    }

    private static func item(_ candidate: Candidate) -> KeyboardCore.CandidateItem {
        KeyboardCore.CandidateItem(
            text: candidate.text,
            reading: KeyboardCore.Kana.toHiragana(candidate.data.map(\.ruby).joined())
        )
    }
}
```

- [ ] **Step 4: `Keyboard/KeyboardState.swift`**

```swift
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
```

- [ ] **Step 5: `Keyboard/Views/Keys.swift`**

```swift
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
```

- [ ] **Step 6: `Keyboard/Views/TopArea.swift`**

```swift
import SwiftUI
import KeyboardCore

/// 上の段：打っていない時は道具、打っている時は候補の 2段（同じ高さ）
struct TopArea: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        if state.reading.isEmpty {
            Toolbar(state: state)
        } else {
            CandidateBar(state: state)
        }
    }
}

struct Toolbar: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        HStack {
            if state.cursorMode {
                RepeatButton(action: { state.moveCursor(-1) }) {
                    Image(systemName: "arrow.left").font(.title2)
                }
                Button("完了") { state.toggleCursorMode() }
                    .frame(maxWidth: .infinity)
                RepeatButton(action: { state.moveCursor(1) }) {
                    Image(systemName: "arrow.right").font(.title2)
                }
            } else {
                tool("gearshape", label: "設定") { state.switchMode(.settings) }
                tool("arrow.left.and.right", label: "カーソル移動") { state.toggleCursorMode() }
                tool("face.smiling", label: "顔文字・絵文字") { state.switchMode(.emoji(.kaomoji)) }
                tool("chevron.down", label: "閉じる") { state.dismiss() }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private func tool(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }
}

/// 太い段＝読みどおりの変換、細い段＝予測（設計書 3章）
struct CandidateBar: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        VStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(state.candidates.main.enumerated()), id: \.offset) { index, item in
                        Button { state.selectCandidate(index) } label: {
                            Text(item.text)
                                .font(.system(size: 18))
                                .padding(.horizontal, 12)
                                .frame(height: 38)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(index == state.highlighted ? Color.accentColor.opacity(0.25) : Color(uiColor: .systemBackground))
                                )
                        }
                    }
                }
            }
            .frame(height: 38)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(state.candidates.predictions.enumerated()), id: \.offset) { index, item in
                        Button { state.selectPrediction(index) } label: {
                            Text(item.text)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .frame(height: 24)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 0.5, dash: [3]))
                                        .foregroundStyle(.secondary)
                                )
                        }
                    }
                }
            }
            .frame(height: 24)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 7: `Keyboard/Views/KeyGrid.swift`**

```swift
import SwiftUI
import KeyboardCore

/// 左の列（記号・123・あA・☺/🌐）＋ 真ん中のフリックのキー ＋ 右の列（⌫・空白・改行）
struct KeyGrid: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            VStack(spacing: Metrics.spacing) {
                SideKey(title: "記号", active: state.mode == .symbol) { state.switchMode(.symbol) }
                SideKey(title: "123", active: state.mode == .number) { state.switchMode(.number) }
                SideKey(title: state.mode == .alphabet ? "あいう" : "あA", active: state.mode == .alphabet) {
                    state.switchMode(.alphabet)
                }
                if state.needsGlobe {
                    SideKey(systemImage: "globe") { state.nextKeyboard() }
                } else {
                    SideKey(systemImage: "face.smiling") { state.switchMode(.emoji(.emoji)) }
                }
            }
            .frame(width: Metrics.sideWidth)

            VStack(spacing: Metrics.spacing) {
                centerRows
            }

            VStack(spacing: Metrics.spacing) {
                RepeatKey(systemImage: "delete.left") { state.backspace() }
                SideKey(title: state.reading.isEmpty ? "空白" : "次候補") { state.space() }
                SideKey(title: state.reading.isEmpty ? "改行" : "確定", height: Metrics.keyHeight * 2 + Metrics.spacing) {
                    state.enter()
                }
            }
            .frame(width: Metrics.sideWidth)
        }
    }

    @ViewBuilder private var centerRows: some View {
        switch state.mode {
        case .alphabet:
            ForEach(0..<3, id: \.self) { r in row(FlickLayouts.alphabet[r]) }
            HStack(spacing: Metrics.spacing) {
                SideKey(title: "a/A", active: state.uppercase) { state.uppercase.toggle() }
                FlickKeyView(key: FlickLayouts.alphabetQuote) { state.tapFlick(FlickLayouts.alphabetQuote, $0) }
                FlickKeyView(key: FlickLayouts.alphabetPunct) { state.tapFlick(FlickLayouts.alphabetPunct, $0) }
            }
            .frame(height: Metrics.keyHeight)
        case .number:
            ForEach(0..<4, id: \.self) { r in row(FlickLayouts.number[r]) }
        default:
            ForEach(0..<3, id: \.self) { r in row(FlickLayouts.kana[r]) }
            HStack(spacing: Metrics.spacing) {
                SideKey(title: state.reading.isEmpty ? "^^" : "小゛゜") { state.smallDakuten() }
                FlickKeyView(key: FlickLayouts.wa) { state.tapFlick(FlickLayouts.wa, $0) }
                FlickKeyView(key: FlickLayouts.punctuation) { state.tapFlick(FlickLayouts.punctuation, $0) }
            }
            .frame(height: Metrics.keyHeight)
        }
    }

    private func row(_ keys: [FlickKey]) -> some View {
        HStack(spacing: Metrics.spacing) {
            ForEach(keys, id: \.label) { key in
                FlickKeyView(key: key, uppercase: state.mode == .alphabet && state.uppercase) {
                    state.tapFlick(key, $0)
                }
            }
        }
        .frame(height: Metrics.keyHeight)
    }
}
```

- [ ] **Step 8: `Keyboard/Views/KeyboardView.swift`**

```swift
import SwiftUI

struct KeyboardView: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        VStack(spacing: Metrics.spacing) {
            TopArea(state: state)
                .frame(height: Metrics.topAreaHeight)
            content
                .frame(height: Metrics.keyAreaHeight)
        }
        .padding(Metrics.padding)
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.totalHeight)
        .background(Color(uiColor: .systemGray5))
    }

    @ViewBuilder private var content: some View {
        switch state.mode {
        case .kana, .alphabet, .number:
            KeyGrid(state: state)
        case .symbol, .emoji, .settings:
            // Task 8 で専用の画面に置き換える。それまではキーを出しておく。
            KeyGrid(state: state)
        }
    }
}
```

- [ ] **Step 9: `Keyboard/KeyboardViewController.swift` を丸ごと置き換える**

```swift
import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
    private var state: KeyboardState?

    override func viewDidLoad() {
        super.viewDidLoad()
        let state = KeyboardState(controller: self)
        self.state = state

        let host = UIHostingController(rootView: KeyboardView(state: state))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)

        // 高さは常に同じ（設計書 2章）
        let height = view.heightAnchor.constraint(equalToConstant: Metrics.totalHeight)
        height.priority = UILayoutPriority(999)
        height.isActive = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        state?.needsGlobe = needsInputModeSwitchKey
    }

    override func viewWillDisappear(_ animated: Bool) {
        state?.flushAndPersist()
        super.viewWillDisappear(animated)
    }
}
```

- [ ] **Step 10: プッシュして組み立てが通るのを確かめる**

```bash
git add Keyboard
git commit -m "feat: キーボード本体（フリック入力・変換と予測の2段・覚え方）を追加" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push
bash scripts/ci-wait.sh ios.yml
```

Expected: `PASS`。失敗したら `gh run view --log-failed` のエラー行（ファイル名:行番号）を見て直し、もう一度プッシュする。

---

### Task 8: 記号・顔文字/絵文字・⚙（全部忘れる）の画面

**Files:**
- Create: `Keyboard/PanelData.swift`, `Keyboard/Views/Panels.swift`
- Modify: `Keyboard/Views/KeyboardView.swift`（`content` の `case .symbol, .emoji, .settings:` の部分）

**Interfaces:**
- Consumes: `KeyboardState.insertDirect(_:)` / `backspace()` / `backToKana()` / `forgetAll()` / `mode`、`SideKey`、`RepeatKey`、`Metrics`（Task 7）
- Produces: `SymbolPanel(state:)`、`EmojiPanel(state:tab:)`、`SettingsPanel(state:)`

- [ ] **Step 1: `Keyboard/PanelData.swift`**

```swift
/// 記号・絵文字・顔文字の一覧（どれも重複なし。ForEach の id に使うため）
enum PanelData {
    static let symbols: [String] = [
        "！", "？", "、", "。", "・", "ー", "〜", "…", "「", "」", "『", "』", "（", "）", "【", "】",
        "＠", "＃", "＄", "％", "＆", "＊", "＋", "－", "＝", "／", "＼", "：", "；", "＜", "＞", "｜",
        "♪", "☆", "★", "○", "●", "◎", "△", "▲", "□", "■", "♡", "♥", "→", "←", "↑", "↓",
        "※", "〒", "℃", "¥",
    ]

    static let emoji: [String] = [
        "😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "😊", "😇", "🙂", "😉", "😍", "🥰", "😘", "😋",
        "😛", "😜", "🤪", "😎", "🤩", "🥳", "😏", "😒", "😞", "😔", "😟", "😕", "🙁", "😣", "😖", "😫",
        "😩", "🥺", "😢", "😭", "😤", "😠", "😡", "🤯", "😳", "😱", "😨", "😰", "😥", "😓", "🤗", "🤔",
        "🤭", "🤫", "😶", "😐", "😑", "😬", "🙄", "😯", "😴", "🤤", "😪", "😵", "🤐", "🥴", "🤢", "🤧",
        "😷", "🤒", "🤕", "👍", "👎", "👏", "🙌", "🙏", "💪", "👋", "✌️", "🤞", "👌", "🤝", "❤️", "🧡",
        "💛", "💚", "💙", "💜", "🖤", "🤍", "💔", "💕", "💖", "💗", "💓", "💞", "🎉", "🎂", "🎁", "✨",
        "⭐", "🌟", "🔥", "💯", "💤", "💦", "☀️", "🌙", "⛅", "☔", "🌸", "🍀", "🍁", "🍺", "🍻", "☕",
        "🍰", "🍜", "🍣", "🐶", "🐱", "🐻", "🐼",
    ]

    static let kaomoji: [String] = [
        "(^^)", "(^_^)", "(*^^*)", "(^o^)", "(＾▽＾)", "(≧▽≦)", "(´▽｀)", "(*´▽｀*)", "(´・ω・｀)",
        "(・∀・)", "(>_<)", "(T_T)", "(;_;)", "(´;ω;｀)", "(＞＜)", "(*_*)", "(°_°)", "(・_・;)",
        "(^_^;)", "(ー_ー)", "(￣ー￣)", "(｀・ω・´)", "(ノ´∀｀*)", "ヽ(・∀・)ﾉ", "ヾ(＾∇＾)", "(・ω・)ノ",
        "m(_ _)m", "(_ _)", "orz", "(っ´▽｀)っ", "(⌒▽⌒)", "(^^;", "(≧∇≦)", "(^з^)-☆",
    ]
}
```

- [ ] **Step 2: `Keyboard/Views/Panels.swift`**

```swift
import SwiftUI

/// パネルの共通の枠：左に中身、右に ⌫ と「戻る」
struct PanelChrome<Content: View>: View {
    @ObservedObject var state: KeyboardState
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: Metrics.spacing) {
                RepeatKey(systemImage: "delete.left") { state.backspace() }
                SideKey(title: "戻る", height: Metrics.keyHeight * 3 + Metrics.spacing * 2) { state.backToKana() }
            }
            .frame(width: Metrics.sideWidth)
        }
    }
}

struct SymbolPanel: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        PanelChrome(state: state) {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
                    ForEach(PanelData.symbols, id: \.self) { symbol in
                        Button { state.insertDirect(symbol) } label: {
                            Text(symbol)
                                .font(.system(size: 20))
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct EmojiPanel: View {
    @ObservedObject var state: KeyboardState
    let tab: EmojiTab

    var body: some View {
        PanelChrome(state: state) {
            VStack(spacing: 4) {
                Picker("", selection: Binding(get: { tab }, set: { state.mode = .emoji($0) })) {
                    Text("顔文字").tag(EmojiTab.kaomoji)
                    Text("絵文字").tag(EmojiTab.emoji)
                }
                .pickerStyle(.segmented)
                ScrollView {
                    if tab == .emoji {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 8), spacing: 2) {
                            ForEach(PanelData.emoji, id: \.self) { emoji in
                                Button { state.insertDirect(emoji) } label: {
                                    Text(emoji)
                                        .font(.system(size: 26))
                                        .frame(maxWidth: .infinity, minHeight: 36)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                            ForEach(PanelData.kaomoji, id: \.self) { kaomoji in
                                Button { state.insertDirect(kaomoji) } label: {
                                    Text(kaomoji)
                                        .font(.system(size: 14))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                        .frame(maxWidth: .infinity, minHeight: 36)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// ⚙：覚えた言葉を全部忘れる（押すと確認する：設計書 4章）
struct SettingsPanel: View {
    @ObservedObject var state: KeyboardState
    @State private var confirming = false
    @State private var done = false

    var body: some View {
        PanelChrome(state: state) {
            VStack(spacing: 12) {
                if done {
                    Text("覚えた言葉を全部忘れました")
                } else if confirming {
                    Text("本当に全部忘れますか？")
                    HStack(spacing: 12) {
                        Button("忘れる", role: .destructive) {
                            state.forgetAll()
                            done = true
                        }
                        Button("やめる") { confirming = false }
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("覚えた言葉を全部忘れる") { confirming = true }
                        .buttonStyle(.bordered)
                }
            }
        }
    }
}
```

- [ ] **Step 3: `Keyboard/Views/KeyboardView.swift` の `content` を置き換える**

置き換える前：

```swift
        case .symbol, .emoji, .settings:
            // Task 8 で専用の画面に置き換える。それまではキーを出しておく。
            KeyGrid(state: state)
```

置き換えた後：

```swift
        case .symbol:
            SymbolPanel(state: state)
        case .emoji(let tab):
            EmojiPanel(state: state, tab: tab)
        case .settings:
            SettingsPanel(state: state)
```

- [ ] **Step 4: プッシュして組み立てが通るのを確かめる**

```bash
git add Keyboard
git commit -m "feat: 記号・顔文字/絵文字・全部忘れるの画面を追加" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push
bash scripts/ci-wait.sh ios.yml
```

Expected: `PASS`

---

### Task 9: TestFlight への自動アップロード（Apple 側の準備はご本人）

前提：ご本人の **Apple Developer Program の登録が終わっている**こと。まだなら、登録が済むまでこの Task は待つ（Task 1〜8 は登録なしで進められる）。

**Files:**
- Create: `ci/ExportOptions.plist`
- Modify: `.github/workflows/ios.yml`（`upload` ジョブを追加）

**Interfaces:**
- Consumes: `project.yml` のスキーム `FlickKeyboard`、Bundle ID 2つ（Task 6）
- Produces: GitHub Secrets `APPLE_TEAM_ID` / `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_P8`、リポジトリ変数 `UPLOAD_ENABLED=true`

- [ ] **Step 1: `ci/ExportOptions.plist` を作る**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>upload</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>REPLACED_IN_CI</string>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
</dict>
</plist>
```

- [ ] **Step 2: `.github/workflows/ios.yml` の最後（`build` ジョブの後）に `upload` ジョブを足す**

```yaml
  upload:
    needs: build
    if: github.event_name != 'pull_request' && github.ref == 'refs/heads/main' && vars.UPLOAD_ENABLED == 'true'
    runs-on: macos-26
    env:
      APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
    steps:
      - uses: actions/checkout@v4
      - name: Cache dictionary
        uses: actions/cache@v4
        with:
          path: Vendor/azooKey_dictionary_storage
          key: dictionary-832fbb0d3039dfaa4b2183956f3d96f6b07eec4d
      - name: Fetch dictionary
        run: bash scripts/fetch-dictionary.sh
      - name: Install XcodeGen
        run: brew install xcodegen
      - name: Generate project
        run: xcodegen generate
      - name: Archive (unsigned)
        run: |
          xcodebuild archive \
            -project FlickKeyboard.xcodeproj \
            -scheme FlickKeyboard \
            -sdk iphoneos \
            -configuration Release \
            -destination 'generic/platform=iOS' \
            -archivePath build/FlickKeyboard.xcarchive \
            CODE_SIGNING_ALLOWED=NO
      - name: Write API key
        env:
          ASC_KEY_P8: ${{ secrets.ASC_KEY_P8 }}
        run: |
          mkdir -p private_keys
          printf '%s\n' "$ASC_KEY_P8" > private_keys/AuthKey.p8
      - name: Sign with cloud signing and upload to TestFlight
        env:
          ASC_KEY_ID: ${{ secrets.ASC_KEY_ID }}
          ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
        run: |
          plutil -replace teamID -string "$APPLE_TEAM_ID" ci/ExportOptions.plist
          xcodebuild -exportArchive \
            -archivePath build/FlickKeyboard.xcarchive \
            -exportOptionsPlist ci/ExportOptions.plist \
            -exportPath build/export \
            -allowProvisioningUpdates \
            -authenticationKeyPath "$PWD/private_keys/AuthKey.p8" \
            -authenticationKeyID "$ASC_KEY_ID" \
            -authenticationKeyIssuerID "$ASC_ISSUER_ID"
```

- [ ] **Step 3: コミットしてプッシュする（UPLOAD_ENABLED がまだないので upload は動かない）**

```bash
git add ci/ExportOptions.plist .github/workflows/ios.yml
git commit -m "ci: TestFlight への自動アップロードを追加" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push
bash scripts/ci-wait.sh ios.yml
```

Expected: `PASS`（build だけ動き、upload は skipped）

- [ ] **Step 4: ご本人に Apple のサイトで準備してもらう（1ステップずつ案内。スクショで確認）**

1. **チームID を確認する**：developer.apple.com/account →「メンバーシップの詳細」→「チームID」（英数字 10文字）。
2. **アプリのIDを 2つ登録する**：developer.apple.com/account →「証明書、ID、プロファイル」→「識別子（Identifiers）」→「＋」→「App IDs」→「App」→
   - 説明 `FlickKeyboard`、Bundle ID（Explicit）`io.github.kainaga009900-cmd.flickkeyboard` → 続ける → 登録
   - もう一度「＋」から、説明 `FlickKeyboard Keyboard`、Bundle ID `io.github.kainaga009900-cmd.flickkeyboard.keyboard` → 登録
   - どちらも「機能（Capabilities）」は何もチェックしない。
3. **App Store Connect にアプリを作る**：appstoreconnect.apple.com →「アプリ」→「＋」→「新規App」→ プラットフォーム iOS、名前（App Store にまだない名前。仮でよく、あとで変えられる）、言語 日本語、バンドルID `io.github.kainaga009900-cmd.flickkeyboard`、SKU `flickkeyboard`、アクセス「フルアクセス」→ 作成。
4. **組み立て用の鍵（API キー）を作る**：App Store Connect →「ユーザとアクセス」→「統合」→「App Store Connect API」→「チームキー」→「＋」→ 名前 `github-actions`、アクセス「Admin」→ 生成。
   - 「API キーをダウンロード」で `.p8` ファイルを保存する（**1回しかダウンロードできない**）。
   - 画面の「キーID」と「Issuer ID」を控える。
   - この鍵は強い権限を持つので、GitHub Secrets 以外には貼らない。もし漏れたら、同じ画面で「取り消す」を押す。
5. **GitHub に鍵を登録する**（ご本人が操作する）：github.com/kainaga009900-cmd/flick-keyboard →「Settings」→「Secrets and variables」→「Actions」→「New repository secret」で 4つ登録する。
   - `APPLE_TEAM_ID`：1 のチームID
   - `ASC_KEY_ID`：4 のキーID
   - `ASC_ISSUER_ID`：4 の Issuer ID
   - `ASC_KEY_P8`：`.p8` ファイルをメモ帳で開き、`-----BEGIN PRIVATE KEY-----` から `-----END PRIVATE KEY-----` まで全部コピーして貼る

- [ ] **Step 5: アップロードを有効にして実行する**

ご本人から「5 まで終わった」と聞いたら：

```bash
gh variable set UPLOAD_ENABLED --body true
gh workflow run ios.yml --ref main
```

少し待ってから、動いている実行を見つけて待つ：

```bash
ID=$(gh run list --workflow ios.yml --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$ID" --exit-status --interval 15
```

Expected: `build` と `upload` がどちらも成功。
うまくいかないとき：
- `Cloud signing permission error` や `No profiles for ...`：Step 4 の 4 で鍵のアクセスが「Admin」になっているか確認してもらう。
- `No suitable application records were found`：Step 4 の 3 の Bundle ID が合っているか確認してもらう。

- [ ] **Step 6: ご本人の iPhone に入れる（1ステップずつ案内）**

1. App Store Connect →「アプリ」→ 作ったアプリ →「TestFlight」→ 10〜30分でビルドが出てくる。
2. 「内部テスト」の「＋」→ グループ名 `自分` → 自分の Apple ID を追加 → ビルドを追加。
3. iPhone で App Store から「TestFlight」アプリを入れ、同じ Apple ID で開く →「変換キーボード」→「インストール」。
4. iPhone の「設定」→ 一般 → キーボード → キーボード →「新しいキーボードを追加」→「変換キーボード」。
5. LINE を開いて 🌐 を長押し →「変換キーボード」に切り替えて、スクショを送ってもらう。

---

### Task 10: iPhone で確かめて直す

**Files:**
- Modify: 見つかった問題に応じて `Keyboard/` の該当ファイル
- Modify（marked text の問題があったときだけ）: `Keyboard/ProxyWriter.swift`

- [ ] **Step 1: ご本人に次を試してもらい、それぞれスクショで結果をもらう**

| # | 試すこと | うまくいった状態 |
|---|---|---|
| 1 | LINE で「かいぎ」と打つ | 太い段に 会議・懐疑 など、細い段に 会議室 などが出る。読みの違う言葉は出ない |
| 2 | 回議 を 3回選んで、4回目に「かいぎ」と打つ | 回議 が先頭に出る |
| 3 | 回議 を選んですぐ ⌫ を 3回くり返し、「かいぎ」と打つ | 回議 は先頭に出ない |
| 4 | 打っている時・打っていない時を行き来する | キーボードの高さが変わらない |
| 5 | 記号・123・あA・☺・^^・カーソル移動・閉じる・⚙ | それぞれの画面に切り替わり、入力できる |
| 6 | ⚙ →「覚えた言葉を全部忘れる」→「忘れる」 | 2 で先頭に出た 回議 が先頭に出なくなる |
| 7 | メモ・Instagram でも打つ | LINE と同じように打てる |
| 8 | iPhone の「設定」でこのキーボードの「フルアクセス」がオフのまま | 1〜7 がすべてできる |

- [ ] **Step 2: 変換中の文字（下線）が LINE などでおかしい場合だけ、`Keyboard/ProxyWriter.swift` を次に置き換える**

おかしい例：変換中の文字が二重になる、確定すると文字が消える、カーソルが飛ぶ。この版は下線を使わず、「仮に入れた文字を消して入れ直す」やり方にする。

```swift
import UIKit
import KeyboardCore

/// Composer が出した TextOp を入力欄に反映する（下線なし版）。
/// 変換中の文字もいったん普通に入れておき、変わるたびに消して入れ直す。
final class ProxyWriter {
    /// いま入力欄に仮に入れてある文字
    private var shown = ""

    func apply(_ op: TextOp, to proxy: UITextDocumentProxy) {
        switch op {
        case .setComposing(let text):
            replaceShown(with: text, proxy: proxy)
            shown = text
        case .commit(let text):
            replaceShown(with: text, proxy: proxy)
            shown = ""
        case .deleteBackward(let count):
            for _ in 0..<count {
                proxy.deleteBackward()
            }
        }
    }

    private func replaceShown(with text: String, proxy: UITextDocumentProxy) {
        for _ in 0..<shown.count {
            proxy.deleteBackward()
        }
        if !text.isEmpty {
            proxy.insertText(text)
        }
    }
}
```

- [ ] **Step 3: 直したら、プッシュして TestFlight の新しいビルドで Step 1 の該当項目をもう一度試してもらう**

```bash
git add Keyboard
git commit -m "fix: iPhone での確認で見つかった問題を直す" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push
bash scripts/ci-wait.sh ios.yml
```

Expected: `PASS`。1〜8 がすべて「うまくいった状態」になるまでくり返す。

---

### Task 11: App Store に申請する

**Files:**
- Create: `PRIVACY.md`, `SUPPORT.md`, `scripts/make-screenshots.ps1`

- [ ] **Step 1: `PRIVACY.md` を作る**

```markdown
# プライバシーポリシー（変換キーボード）

変換キーボードは、あなたの情報を集めません。

- 打った文字、覚えた言葉、そのほかの情報を、インターネットに送ることはありません。
- 「3回選んだ言葉を覚える」ための記録は、iPhone の中（このキーボード自身の保存場所）にだけ保存します。
- キーボードの ⚙ から「覚えた言葉を全部忘れる」を押すと、この記録はすべて消えます。
- フルアクセスは必要ありません。

お問い合わせ: https://github.com/kainaga009900-cmd/flick-keyboard/issues
```

- [ ] **Step 2: `SUPPORT.md` を作る**

```markdown
# サポート（変換キーボード）

## 使えるようにする

1. iPhone の「設定」→ 一般 → キーボード → キーボード →「新しいキーボードを追加」→「変換キーボード」
2. 文字を打つ画面で 🌐 を長押しして「変換キーボード」を選ぶ

## 困ったとき・ご意見

https://github.com/kainaga009900-cmd/flick-keyboard/issues に書いてください。
```

- [ ] **Step 3: `scripts/make-screenshots.ps1` を作る**（ご本人のスクショを App Store の大きさ 1290×2796 にそろえる）

```powershell
# 使い方: powershell -ExecutionPolicy Bypass -File scripts/make-screenshots.ps1 -InputDir <スクショのフォルダ>
# 縦横比を保って 1290x2796 に収め、余白は白で埋める。出力は <InputDir>\appstore\
param([Parameter(Mandatory = $true)][string]$InputDir)
Add-Type -AssemblyName System.Drawing
$outDir = Join-Path $InputDir "appstore"
New-Item -ItemType Directory -Force $outDir | Out-Null
Get-ChildItem -LiteralPath $InputDir -File | Where-Object { $_.Extension -in ".png", ".jpg", ".jpeg" } | ForEach-Object {
    $src = [System.Drawing.Image]::FromFile($_.FullName)
    $W = 1290; $H = 2796
    $scale = [Math]::Min($W / $src.Width, $H / $src.Height)
    $w = [int]($src.Width * $scale); $h = [int]($src.Height * $scale)
    $dst = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($dst)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.Clear([System.Drawing.Color]::White)
    $g.DrawImage($src, [int](($W - $w) / 2), [int](($H - $h) / 2), $w, $h)
    $out = Join-Path $outDir ($_.BaseName + ".png")
    $dst.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $dst.Dispose(); $src.Dispose()
    Write-Output "作りました: $out"
}
```

- [ ] **Step 4: コミットしてプッシュする**

```bash
git add PRIVACY.md SUPPORT.md scripts/make-screenshots.ps1
git commit -m "docs: プライバシーポリシーとサポート、スクショ整形スクリプトを追加" -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
git push
```

- [ ] **Step 5: アプリ名を決めてもらう**

設計書 11章で「未定」のままのアプリ名を、ご本人に決めてもらう（App Store にまだない名前）。決まったら `project.yml` の `CFBundleDisplayName`（2か所）と、`App/ContentView.swift`・`PRIVACY.md`・`SUPPORT.md` の「変換キーボード」を置き換えて、プッシュする。

- [ ] **Step 6: ご本人に App Store Connect で入力してもらう（1ステップずつ案内）**

1. スクショ：TestFlight 版を使っている画面を 3〜5枚撮って PC に送ってもらい、`scripts/make-screenshots.ps1` で大きさをそろえる → 「6.9インチ ディスプレイ」の欄に入れる。
2. 説明文（下の文を案内。ご本人が直してよい）：

   > 予測変換の押し間違いを防ぐ、日本語フリックキーボードです。
   > ・打った読みと同じ候補だけを出します。読みの違う言葉（打ち間違いの勝手な補正）は出しません。
   > ・予測は細い段に分けて出すので、変換の候補と混ざりません。
   > ・3回選んだ言葉だけを覚えます。確定してすぐ消した言葉は「間違い」として数えません。
   > ・打った文字をインターネットに送りません。フルアクセスは必要ありません。

3. キーワード：`キーボード,フリック,変換,予測変換,誤変換,押し間違い,日本語入力`
4. サポートURL：`https://github.com/kainaga009900-cmd/flick-keyboard/blob/main/SUPPORT.md`
5. プライバシーポリシーURL：`https://github.com/kainaga009900-cmd/flick-keyboard/blob/main/PRIVACY.md`
6. 「App のプライバシー」→「データの収集」→「いいえ、このAppからデータを収集しません」。
7. 価格：無料。年齢制限の質問にはすべて「なし」。
8. ビルド：TestFlight で確かめたビルドを選ぶ →「審査用に追加」→「審査へ提出」。

- [ ] **Step 7: 審査の結果を待つ**

リジェクトされたら、Apple からのメッセージのスクショをもらい、指摘ごとに直す（キーボードの審査ルールは設計書 8章）。
