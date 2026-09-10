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
