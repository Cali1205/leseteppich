import XCTest
@testable import Leseteppich

final class ContentSchemaTests: XCTestCase {
    func testBuiltInCarpetsLoadAndValidate() throws {
        let appBundle = Bundle(for: BundleContentLoader.self)
        let loader = BundleContentLoader(bundle: appBundle)
        let carpets = try loader.loadBuiltInCarpets()

        XCTAssertEqual(carpets.count, 8)
        for carpet in carpets {
            XCTAssertEqual(carpet.tiles.count, 16, "Carpet \(carpet.id) should have a 4x4 grid (16 tiles)")
            XCTAssertEqual(carpet.columns, 4)
            for tile in carpet.tiles {
                XCTAssertEqual(tile.syllables.joined(), tile.display)
                XCTAssertFalse(tile.spokenText.isEmpty)
            }
        }
    }

    func testBuiltInDiceBoardsLoadAndValidate() throws {
        let appBundle = Bundle(for: BundleContentLoader.self)
        let loader = BundleContentLoader(bundle: appBundle)
        let boards = try loader.loadBuiltInDiceBoards()

        XCTAssertFalse(boards.isEmpty)
        let first = try XCTUnwrap(boards.first)
        XCTAssertEqual(first.columns.count, 6)
        XCTAssertEqual(first.columns.map(\.diceValue), [1, 2, 3, 4, 5, 6])
        XCTAssertGreaterThanOrEqual(first.rowCount, 6)
    }
}
