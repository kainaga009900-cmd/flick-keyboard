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
