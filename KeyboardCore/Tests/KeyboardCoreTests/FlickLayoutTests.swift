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
