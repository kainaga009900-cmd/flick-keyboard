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
