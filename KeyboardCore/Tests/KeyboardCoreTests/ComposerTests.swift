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

    func testEditingTheRestAfterAPartialChoiceStillCountsTheChoice() {
        _ = composer.type("あしたかいぎ")
        _ = composer.selectCandidate(at: 1)   // 明日 を確定、かいぎ が残る
        clock.advance(1)
        _ = composer.backspace()              // 残りの読みを消すだけで、明日 は消していない
        _ = composer.type("と")
        XCTAssertEqual(composer.learning.count(reading: "あした", text: "明日"), 1)
    }

    func testDeletingIntoAPartialChoiceWithinFiveSecondsIsNotCounted() {
        _ = composer.type("あしたかいぎ")
        _ = composer.selectCandidate(at: 1)   // 明日 を確定、かいぎ が残る
        clock.advance(1)
        for _ in 0..<3 { _ = composer.backspace() }   // かいぎ を全部消す
        XCTAssertEqual(composer.backspace(), [.deleteBackward(1)])   // 明日 に食い込む
        _ = composer.type("と")
        XCTAssertEqual(composer.learning.count(reading: "あした", text: "明日"), 0)
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

    func testAbandonDropsTheReadingWithoutWritingAnything() {
        _ = composer.type("かいぎ")
        composer.abandon()
        XCTAssertEqual(composer.reading, "")
        XCTAssertEqual(composer.candidates, .empty)
        XCTAssertEqual(provider.resetCount, 1)
        XCTAssertEqual(composer.type("あ"), [.setComposing("あ")])
    }

    func testAbandonCountsThePreviousChoice() {
        choose(2)
        clock.advance(1)
        composer.abandon()
        XCTAssertEqual(composer.learning.count(reading: "かいぎ", text: "回議"), 1)
    }

    func testLearningRevisionChangesOnlyWhenLearningChanges() {
        XCTAssertEqual(composer.learningRevision, 0)
        choose(2)
        XCTAssertEqual(composer.learningRevision, 0)        // まだ回数に入れていない
        clock.advance(10)
        _ = composer.type("か")
        XCTAssertEqual(composer.learningRevision, 1)        // 数えた
        _ = composer.flush()
        choose(2)
        clock.advance(1)
        _ = composer.backspace()                            // 5秒以内の ⌫ → 数えない
        XCTAssertEqual(composer.learningRevision, 1)
        composer.forgetAll()
        XCTAssertEqual(composer.learningRevision, 2)
    }
}
