import Foundation
import Testing
@testable import MeetingRecorder

struct RemoteTests {
    @Test func stateRoundTripsThroughMessage() throws {
        let state = RemoteState(phase: .recording, elapsed: 75.5, level: 0.4, markers: 3)
        #expect(RemoteState(message: state.message) == state)
    }

    @Test func rejectsBadStatePayloads() {
        let good = RemoteState(phase: .paused, elapsed: 1, level: 0, markers: 0).message
        var wrongKind = good; wrongKind[TransferMessage.kind] = TransferMessage.Kind.ack.rawValue
        var badPhase = good; badPhase["phase"] = "exploded"
        var negative = good; negative["elapsed"] = -1.0
        var infinite = good; infinite["elapsed"] = Double.infinity
        for payload in [wrongKind, badPhase, negative, infinite] {
            #expect(RemoteState(message: payload) == nil)
        }
        var loud = good; loud["level"] = 7.0
        #expect(RemoteState(message: loud)?.level == 1)
    }

    @Test func commandRoundTripsAndRejectsUnknown() {
        #expect(RemoteCommand(message: RemoteCommand.stop.message) == .stop)
        #expect(RemoteCommand(message: [TransferMessage.kind: "remoteCommand", TransferMessage.command: "selfDestruct"]) == nil)
        #expect(RemoteCommand(message: [TransferMessage.command: "stop"]) == nil)
    }

    @Test @MainActor func phoneAnswersWithoutRecorderAndIgnoresMarkerWhenIdle() {
        let service = PhoneTransferService()
        #expect(service.handle(.status)[TransferMessage.error] != nil)

        service.recorder = ChunkedRecorder(source: .phone)
        #expect(RemoteState(message: service.handle(.status)) == .idle)
        #expect(RemoteState(message: service.handle(.marker)) == .idle)
        #expect(RemoteState(message: service.handle(.stop)) == .idle)
    }
}
