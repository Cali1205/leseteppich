import XCTest
@testable import Leseteppich

final class AppSettingsTests: XCTestCase {
    func testLegacyAppSettingsWithoutVersionMigratesAllowManualConfirmToFalse() throws {
        let legacyJSON = """
        {
          "showSyllableColors": true,
          "showSyllableArcs": false,
          "speechRate": 0.42,
          "strictness": "gentle",
          "allowManualConfirm": true,
          "preferOnDeviceRecognition": true,
          "autoAdvanceOnMatch": true
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(AppSettings.self, from: legacyJSON)
        XCTAssertEqual(decoded.settingsVersion, AppSettings.currentSettingsVersion)
        XCTAssertFalse(decoded.allowManualConfirm)
        XCTAssertFalse(decoded.showSyllableArcs)
        XCTAssertEqual(decoded.speechRate, 0.42, accuracy: 0.001)
        XCTAssertFalse(decoded.allowAudioHelp)
        XCTAssertTrue(decoded.autoListenNextTile)
        XCTAssertNil(decoded.selectedVoiceIdentifier)
        XCTAssertTrue(decoded.feedbackSounds)
    }

    func testFeedbackSoundsRoundTripsWhenDisabled() throws {
        let data = try JSONEncoder().encode(AppSettings(feedbackSounds: false))
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertFalse(decoded.feedbackSounds)
    }

    func testVersion1AppSettingsMigratesAllowManualConfirmToFalse() throws {
        let v1JSON = """
        {
          "settingsVersion": 1,
          "allowManualConfirm": true
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(AppSettings.self, from: v1JSON)
        XCTAssertEqual(decoded.settingsVersion, AppSettings.currentSettingsVersion)
        XCTAssertFalse(decoded.allowManualConfirm)
    }

    func testVersion2AppSettingsPreservesExplicitAllowManualConfirmTrue() throws {
        let v2JSON = """
        {
          "settingsVersion": 2,
          "allowManualConfirm": true
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(AppSettings.self, from: v2JSON)
        XCTAssertEqual(decoded.settingsVersion, 2)
        XCTAssertTrue(decoded.allowManualConfirm)
    }

    func testRoundTripPreservesExplicitAllowManualConfirmTrue() throws {
        let settings = AppSettings(allowManualConfirm: true)
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded.settingsVersion, AppSettings.currentSettingsVersion)
        XCTAssertTrue(decoded.allowManualConfirm)
    }

    func testAppSettingsDefaultAndEmptyJSONDecodeToCurrentVersionAndFalse() throws {
        let defaults = AppSettings()
        XCTAssertEqual(defaults.settingsVersion, AppSettings.currentSettingsVersion)
        XCTAssertFalse(defaults.allowManualConfirm)

        let minimalJSON = "{}".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppSettings.self, from: minimalJSON)
        XCTAssertEqual(decoded.settingsVersion, AppSettings.currentSettingsVersion)
        XCTAssertFalse(decoded.allowManualConfirm)
    }
}
