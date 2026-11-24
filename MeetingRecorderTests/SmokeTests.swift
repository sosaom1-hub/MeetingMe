import Testing
@testable import MeetingRecorder

struct SmokeTests {
    @Test func chunkDurationIsFiveMinutes() {
        #expect(RecordingDefaults.chunkDuration == 300)
    }
}
