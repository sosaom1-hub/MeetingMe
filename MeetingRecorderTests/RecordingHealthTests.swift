import Foundation
import Testing
@testable import MeetingRecorder

struct SilenceDetectorTests {
    /// Feeds (level, time) pairs and returns the result for each.
    private func run(_ ticks: [(Float, TimeInterval)]) -> [Bool] {
        var detector = SilenceDetector()
        return ticks.map { detector.update(level: $0.0, at: $0.1) }
    }

    @Test func flagsOnlyAfterAFullMinuteOfQuiet() {
        #expect(run([(0.02, 0), (0.02, 59.75), (0.02, 60)]) == [false, false, true])
    }

    @Test func anyLouderTickResetsTheClock() {
        let results = run([
            (0.02, 0),
            (0.5, 30),   // someone speaks
            (0.02, 31),
            (0.02, 90),
            (0.02, 91),
            (0.3, 92),   // warning clears as soon as sound returns
        ])
        #expect(results == [false, false, false, false, true, false])
    }
}

struct RecordingBudgetTests {
    private let gigabyte: Int64 = 1_000_000_000

    @Test func storageOnlyUntilBatteryRateIsMeasurable() throws {
        let early = try #require(RecordingBudget.hoursLeft(batteryAtStart: 0.8, batteryNow: 0.8, elapsed: 120, freeBytes: gigabyte))
        // ~14.4 MB/h at 32 kbps: 1 GB is about 68 h.
        #expect(early > 60 && early < 75)
    }

    @Test func batteryLimitsWhenItRunsOutFirst() throws {
        // 10 % per hour from 80 %, stopping at 10 %: about 6 h left after 1 h.
        let hours = try #require(RecordingBudget.hoursLeft(batteryAtStart: 0.8, batteryNow: 0.7, elapsed: 3600, freeBytes: 10 * gigabyte))
        #expect(abs(hours - 6) < 0.01)
    }

    @Test func unknownWhenNothingIsReported() {
        #expect(RecordingBudget.hoursLeft(batteryAtStart: nil, batteryNow: nil, elapsed: 3600, freeBytes: nil) == nil)
    }
}
