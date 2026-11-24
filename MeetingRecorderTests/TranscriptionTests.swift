import Foundation
import SwiftData
import Testing
@testable import MeetingRecorder

struct TranscriptionTests {
    // MARK: Server response parsing

    @Test func parsesSegmentsFromLongFiles() throws {
        let json = #"{"display_text":"สวัสดี ครับ","duration_s":45.0,"segments":[{"start":0.4,"end":2.1,"text":"สวัสดี"},{"start":30.2,"end":31.0,"text":" "},{"start":31.5,"end":32.0,"text":"ครับ"}]}"#

        let transcript = try MacASRProvider.parse(Data(json.utf8))

        #expect(transcript.text == "สวัสดี ครับ")
        #expect(transcript.segments.map(\.text) == ["สวัสดี", "ครับ"])
    }

    @Test func shortFilesBecomeOneSegment() throws {
        let json = #"{"display_text":"ทดสอบ","duration_s":12.5}"#

        let transcript = try MacASRProvider.parse(Data(json.utf8))

        #expect(transcript.segments == [.init(start: 0, end: 12.5, text: "ทดสอบ")])
    }

    @Test func rejectsUnexpectedResponse() {
        #expect(throws: TranscriptionError.unreadableResponse) {
            try MacASRProvider.parse(Data(#"{"detail":"oops"}"#.utf8))
        }
    }

    @Test(arguments: ["", "ftp://mac/", "not a url", "https://"])
    func rejectsInvalidServerURLs(_ input: String) {
        #expect(MacASRProvider(string: input) == nil)
    }

    @Test func acceptsTailscaleAndLocalURLs() {
        #expect(MacASRProvider(string: " https://mac.tail1234.ts.net ") != nil)
        #expect(MacASRProvider(string: "http://127.0.0.1:18081") != nil)
    }

    // MARK: Transcript timeline

    @Test func linesUseMeetingTimeAndShowPendingChunksAndMarkers() {
        let first = ChunkTranscript(text: "a b", segments: [.init(start: 1, end: 2, text: "a"), .init(start: 200, end: 210, text: "b")])
        let third = ChunkTranscript(text: "c", segments: [.init(start: 5, end: 6, text: "c")])

        let lines = TranscriptLine.build(
            chunks: [(300, first), (300, nil), (300, third)],
            markers: [200]
        )

        #expect(lines.map(\.start) == [1, 200, 200, 300, 605])
        #expect(lines.map(\.kind) == [.speech("a"), .marker, .speech("b"), .pending(chunk: 2), .speech("c")])
    }

    // MARK: Pipeline retry

    @Test func retrySendsOnlyChunksWithoutTranscript() async throws {
        let container = try ModelContainer(for: Meeting.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let meeting = Meeting(id: UUID(), startedAt: .now, source: .watch)
        container.mainContext.insert(meeting)
        meeting.chunks = (0..<3).map { AudioChunk(index: $0, fileName: ChunkPlanner.fileName(for: $0), duration: 300) }
        let pipeline = TranscriptionPipeline()

        let failing = FakeProvider(unreachableOn: "chunk-001.m4a")
        await pipeline.run(meeting, provider: failing, language: .thai)

        #expect(meeting.state == .waitingForServer)
        #expect(meeting.sortedChunks.map { $0.result != nil } == [true, false, false])

        let working = FakeProvider(unreachableOn: nil)
        await pipeline.run(meeting, provider: working, language: .thai)

        #expect(meeting.state == .transcriptReady)
        #expect(await working.log.files == ["chunk-001.m4a", "chunk-002.m4a"])
    }

    // MARK: Real server (runs only when the Mac server is up on this machine)

    @Test(.enabled("Mac server running on 127.0.0.1:18081") { await MacServer.isUp }, .timeLimit(.minutes(2)))
    func transcribesThaiM4AOnLocalMacServer() async throws {
        let provider = try #require(MacASRProvider(string: MacServer.url))
        let fixture = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/thai-sample.m4a")

        let transcript = try await provider.transcribe(chunk: fixture, language: .thai)

        #expect(transcript.text.contains("งบประมาณ"))
        #expect(transcript.text.contains("วันศุกร์"))
    }
}

private actor CallLog {
    var files: [String] = []
    func append(_ file: String) { files.append(file) }
}

private struct FakeProvider: TranscriptionProvider {
    let unreachableOn: String?
    let log = CallLog()

    func health() async throws -> String { "fake" }

    func transcribe(chunk: URL, language: TranscriptLanguage) async throws -> ChunkTranscript {
        await log.append(chunk.lastPathComponent)
        if chunk.lastPathComponent == unreachableOn {
            throw TranscriptionError.serverUnreachable
        }
        return ChunkTranscript(text: chunk.lastPathComponent, segments: [.init(start: 0, end: 1, text: chunk.lastPathComponent)])
    }
}

private enum MacServer {
    static let url = "http://127.0.0.1:18081"

    static var isUp: Bool {
        get async {
            guard let provider = MacASRProvider(string: url) else { return false }
            return (try? await provider.health()) != nil
        }
    }
}
