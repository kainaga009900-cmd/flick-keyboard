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
