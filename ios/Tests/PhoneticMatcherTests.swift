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

    func testSinglePhonemeAHandlesGermanASRVariants() {
        let matcher = PhoneticMatcher()
        let tile = ReadingTile(
            id: "c1_01",
            display: "a",
            syllables: ["a"],
            spokenText: "Ah",
            ipa: "aː",
            isSinglePhoneme: true,
            acceptedTranscriptions: ["a", "ah", "aa", "aaa", "aah", "äh", "ha", "ar"]
        )

        for spoken in ["a", "A", "ah", "aaa", "äh", "ha", "ar"] {
            let result = matcher.match(hypotheses: [spoken], tile: tile, strictness: .gentle)
            XCTAssertTrue(result.isMatch, "Expected '\(spoken)' to match single phoneme 'a'")
        }

        let wrong = matcher.match(hypotheses: ["oh"], tile: tile, strictness: .gentle)
        XCTAssertFalse(wrong.isMatch)
    }

    func testSingleLetterDisplayEnrichesTileWithSpokenTextAh() {
        let matcher = PhoneticMatcher()
        let tile = ReadingTile(
            id: "test_a_no_accepted",
            display: "a",
            syllables: ["a"],
            spokenText: "Ah",
            isSinglePhoneme: true,
            acceptedTranscriptions: []
        )

        XCTAssertTrue(matcher.match(hypotheses: ["a"], tile: tile, strictness: .normal).isMatch)
        XCTAssertTrue(matcher.match(hypotheses: ["ah"], tile: tile, strictness: .normal).isMatch)
        XCTAssertTrue(matcher.match(hypotheses: ["aaa"], tile: tile, strictness: .normal).isMatch)
        XCTAssertTrue(matcher.match(hypotheses: ["ha"], tile: tile, strictness: .normal).isMatch)
        XCTAssertTrue(matcher.match(hypotheses: ["äh"], tile: tile, strictness: .gentle).isMatch)
        XCTAssertFalse(matcher.match(hypotheses: ["oh"], tile: tile, strictness: .gentle).isMatch)
    }

    func testStrictnessThresholdsGentleNormalStrict() {
        let matcher = PhoneticMatcher()

        // "salat" vs "salas": 1 edit on length 5 -> similarity 0.80 (>= 0.75 gentle, < 0.84 normal)
        XCTAssertTrue(matcher.match(hypotheses: ["Salas"], expected: "Salat", strictness: .gentle).isMatch)
        XCTAssertFalse(matcher.match(hypotheses: ["Salas"], expected: "Salat", strictness: .normal).isMatch)
        XCTAssertFalse(matcher.match(hypotheses: ["Salas"], expected: "Salat", strictness: .strict).isMatch)

        // "tomaten" vs "tomates": 1 edit on length 7 -> similarity ~0.857 (>= 0.84 normal, rejected in strict)
        XCTAssertTrue(matcher.match(hypotheses: ["Tomates"], expected: "Tomaten", strictness: .normal).isMatch)
        XCTAssertFalse(matcher.match(hypotheses: ["Tomates"], expected: "Tomaten", strictness: .strict).isMatch)
    }

    func testShortTargetUnderFourCharsDisablesFuzzyMatching() {
        let matcher = PhoneticMatcher()
        // "lam" (len 3) vs "lame" (len 4) has similarity 0.75, which would pass gentle threshold (0.75) without the <4 guard
        let result = matcher.match(hypotheses: ["lame"], expected: "lam", strictness: .gentle)
        XCTAssertFalse(result.isMatch)
    }

    func testGermanUmlautsAndEszettMatchPhoneticEquivalents() {
        let matcher = PhoneticMatcher()
        XCTAssertTrue(matcher.match(hypotheses: ["Ber"], expected: "Bär", strictness: .normal).isMatch)
        XCTAssertTrue(matcher.match(hypotheses: ["Loewe"], expected: "Löwe", strictness: .normal).isMatch)
        XCTAssertTrue(matcher.match(hypotheses: ["Tuer"], expected: "Tür", strictness: .normal).isMatch)
        XCTAssertTrue(matcher.match(hypotheses: ["Fuss"], expected: "Fuß", strictness: .normal).isMatch)
    }
}
