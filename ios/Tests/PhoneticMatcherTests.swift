import XCTest
@testable import Leseteppich

final class PhoneticMatcherTests: XCTestCase {
    private struct VectorFile: Decodable {
        let schemaVersion: Int
        let cases: [VectorCase]
    }

    private struct VectorCase: Decodable {
        let name: String
        let expected: String
        let accepted: [String]
        let spoken: [String]
        let strictness: MatchingStrictness
        let shouldMatch: Bool
    }

    func testSharedPhoneticTestVectors() throws {
        let testBundle = Bundle(for: type(of: self))
        let url = try XCTUnwrap(
            testBundle.url(forResource: "phonetic_matching", withExtension: "json"),
            "Missing shared phonetic_matching.json in test bundle"
        )
        let data = try Data(contentsOf: url)
        let vectors = try JSONDecoder().decode(VectorFile.self, from: data)
        XCTAssertEqual(vectors.schemaVersion, 1)
        XCTAssertGreaterThanOrEqual(vectors.cases.count, 5)

        let matcher = PhoneticMatcher()
        for vector in vectors.cases {
            let result = matcher.match(
                hypotheses: vector.spoken,
                expected: vector.expected,
                accepted: vector.accepted,
                strictness: vector.strictness
            )
            XCTAssertEqual(
                result.isMatch,
                vector.shouldMatch,
                "Vector '\(vector.name)' failed: expected \(vector.shouldMatch), got \(result.isMatch) (reason: \(result.reason))"
            )
        }
    }

    func testFillerWordBeforeTargetStillMatches() {
        let matcher = PhoneticMatcher()
        let tile = ReadingTile(
            id: "test_mama",
            display: "Mama",
            syllables: ["Ma", "ma"],
            spokenText: "Mama",
            acceptedTranscriptions: ["mama"]
        )
        let result = matcher.match(hypotheses: ["ähm Mama"], tile: tile, strictness: .normal)
        XCTAssertTrue(result.isMatch)
    }

    func testEmptySpeechNeverMatches() {
        let matcher = PhoneticMatcher()
        let result = matcher.match(hypotheses: ["", "   "], expected: "Oma", strictness: .gentle)
        XCTAssertFalse(result.isMatch)
    }
}
