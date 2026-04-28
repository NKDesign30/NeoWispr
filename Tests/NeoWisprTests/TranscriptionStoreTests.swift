import Foundation
import XCTest
@testable import NeoWispr

@MainActor
final class TranscriptionStoreTests: XCTestCase {

    func testTimeSavedAndSpeedFactorUseTypingBaseline() {
        let entries = [
            TranscriptionEntry(text: "eins zwei drei vier", wordCount: 4, durationMs: 3_000),
            TranscriptionEntry(text: "fünf sechs sieben acht", wordCount: 4, durationMs: 6_000),
        ]
        let store = TranscriptionStore(entries: entries)

        XCTAssertEqual(store.wordsTotal, 8)
        XCTAssertEqual(store.totalSpeechMs, 9_000)
        XCTAssertEqual(store.timeSavedMs, 3_000)
        XCTAssertEqual(store.speedFactor, 1.333, accuracy: 0.01)
    }

    func testWordsByDayAggregatesAndFillsEmptyDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let entries = [
            TranscriptionEntry(text: "heute", timestamp: today, wordCount: 3),
            TranscriptionEntry(text: "gestern eins", timestamp: yesterday, wordCount: 2),
            TranscriptionEntry(text: "gestern zwei", timestamp: yesterday.addingTimeInterval(3600), wordCount: 5),
        ]
        let store = TranscriptionStore(entries: entries)

        let result = store.wordsByDay(lastDays: 3)

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].words, 0)
        XCTAssertEqual(result[1].words, 7)
        XCTAssertEqual(result[2].words, 3)
    }
}
