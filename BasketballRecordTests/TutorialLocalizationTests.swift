import XCTest
@testable import BasketballRecord

final class TutorialLocalizationTests: XCTestCase {
    func testEnglishTutorialDoesNotContainCJKText() {
        let data = TutorialDataProvider.localizedData(for: "en", playerIDs: [UUID(), UUID(), UUID(), UUID()])
        let text = data.players.all.map(\.name).joined(separator: " ")
            + data.players.homeTeamName
            + data.players.awayTeamName
            + data.tasks.map { $0.description + $0.hint }.joined()
        let unexpected = text.unicodeScalars.filter { scalar in
            let value = scalar.value
            return (0x3000...0x9FFF).contains(value) || (0xAC00...0xD7AF).contains(value)
        }

        XCTAssertTrue(unexpected.isEmpty, "Unexpected characters: \(String(unexpected.map(Character.init)))")
    }

    func testSimplifiedChineseTutorialDoesNotContainTraditionalTaskText() {
        let data = TutorialDataProvider.localizedData(for: "zh-Hans", playerIDs: [UUID(), UUID(), UUID(), UUID()])
        let text = data.tasks.map { $0.description + $0.hint }.joined()
        let traditionalOnlyCharacters = CharacterSet(charactersIn: "隊籃補請說進沒")

        XCTAssertFalse(text.unicodeScalars.contains { traditionalOnlyCharacters.contains($0) }, "Traditional characters found in simplified Chinese tutorial")
    }
}
