import Foundation
import SwiftData
import Testing
@testable import MeetingRecorder

struct NotesAndEditingTests {
    @Test func timedNotesJoinTheTimelineBeforeSpeechAtTheSameTime() {
        let chunk = ChunkTranscript(text: "ก ข", segments: [.init(start: 10, end: 11, text: "ก"), .init(start: 20, end: 21, text: "ข")])

        let lines = TranscriptLine.build(chunks: [(300, chunk)], markers: [], notes: [.init(time: 20, text: "ถามเรื่องงบ")])

        #expect(lines.map(\.kind) == [.speech("ก"), .note("ถามเรื่องงบ"), .speech("ข")])
        #expect(lines.map(\.source) == [.init(chunk: 0, segment: 0), nil, .init(chunk: 0, segment: 1)])
        #expect(TranscriptLine.plainText(lines).contains("📝 โน้ตผู้บันทึก: ถามเรื่องงบ"))
    }

    @Test func manifestsWithoutNotesStillDecode() throws {
        let json = #"{"id":"6F1C2B9E-6C1F-4F7A-9C6B-0D2E8F7B1A11","source":"watch","startedAt":"2026-11-24T08:00:00Z","status":"finished","chunks":[],"markers":[]}"#
        let manifest = try RecordingManifest.decode(Data(json.utf8))
        #expect(manifest.notes == nil)
    }

    @Test func editingALineUpdatesTextAndSearch() throws {
        let container = try ModelContainer(for: Meeting.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = MeetingStore(context: container.mainContext)
        let meeting = Meeting(id: UUID(), startedAt: .now, source: .phone)
        container.mainContext.insert(meeting)
        let chunk = AudioChunk(index: 0, fileName: ChunkPlanner.fileName(for: 0), duration: 300)
        meeting.chunks = [chunk]
        chunk.result = ChunkTranscript(text: "ทีมอีก ย้ายระบบ", segments: [.init(start: 0, end: 1, text: "ทีมอีก"), .init(start: 2, end: 3, text: "ย้ายระบบ")])

        store.editTranscript(meeting, at: .init(chunk: 0, segment: 0), text: "ทีม IT")

        #expect(chunk.result?.segments.map(\.text) == ["ทีม IT", "ย้ายระบบ"])
        #expect(chunk.transcript == "ทีม IT ย้ายระบบ")
        #expect(meeting.searchText.contains("ทีม it"))

        store.editTranscript(meeting, at: .init(chunk: 0, segment: 1), text: "   ")
        #expect(chunk.result?.segments[1].text == "ย้ายระบบ")
    }
}

struct SearchTests {
    @Test func searchTextCoversTranscriptSummaryAndNotesWithSnippet() throws {
        let container = try ModelContainer(for: Meeting.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let meeting = Meeting(id: UUID(), startedAt: .now, source: .watch)
        container.mainContext.insert(meeting)
        let chunk = AudioChunk(index: 0, fileName: ChunkPlanner.fileName(for: 0), duration: 300)
        meeting.chunks = [chunk]
        chunk.result = ChunkTranscript(text: "ฝ่ายการตลาดเสนอให้เพิ่มงบโฆษณาออนไลน์ร้อยละสิบ", segments: [])
        meeting.summaryText = "## มติ\n- ย้ายไป Microsoft Teams"
        meeting.myNotes = "โทรหาผู้ขายวันจันทร์"

        meeting.refreshSearchText()

        #expect(meeting.searchText.contains("โฆษณา"))
        #expect(meeting.searchText.contains("microsoft teams"))
        #expect(meeting.searchText.contains("ผู้ขาย"))
        #expect(meeting.snippet(matching: "Teams")?.contains("teams") == true)
        #expect(meeting.snippet(matching: "ประชุม") == nil) // in the title only: no snippet
    }

    @Test func libraryPredicateFindsTranscriptWords() throws {
        let container = try ModelContainer(for: Meeting.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let hit = Meeting(id: UUID(), startedAt: .now, source: .phone)
        let miss = Meeting(id: UUID(), startedAt: .now, source: .phone)
        context.insert(hit)
        context.insert(miss)
        hit.myNotes = "ส่ง SharePoint link"
        hit.refreshSearchText()
        miss.refreshSearchText()

        let text = "sharepoint"
        let found = try context.fetch(FetchDescriptor<Meeting>(predicate: #Predicate {
            $0.title.localizedStandardContains(text) || $0.searchText.contains(text)
        }))
        #expect(found.map(\.id) == [hit.id])
    }
}

struct AskPromptTests {
    private let sources: [AskPromptBuilder.Source] = [
        .init(title: "ประชุม 1", date: Date(timeIntervalSince1970: 1_800_000_000), summary: "## สรุป\nเรื่องงบ", body: "[0:00:05] ตกลงงบ 10 ล้าน"),
        .init(title: "ประชุม 2", date: Date(timeIntervalSince1970: 1_800_600_000), summary: nil, body: "[0:01:00] แก้งบเป็น 12 ล้าน"),
    ]

    @Test func questionPromptIsGroundedAndCitesMeetings() throws {
        let prompt = try #require(AskPromptBuilder(sources: sources, template: .question, question: "งบเท่าไร", language: .thai).parts().first)

        #expect(prompt.contains("“ไม่มีในบันทึก”"))
        #expect(prompt.contains("คำถาม: งบเท่าไร"))
        #expect(prompt.contains("### ประชุม 1"))
        #expect(prompt.contains("[0:01:00] แก้งบเป็น 12 ล้าน"))
        #expect(prompt.contains("ให้ยึด transcript เป็นหลัก"))
    }

    @Test func compareNeedsTwoMeetingsAndFollowUpUsesNotSpecified() throws {
        #expect(AskPromptBuilder.Template.compare.minimumMeetings == 2)
        let email = try #require(AskPromptBuilder(sources: [sources[0]], template: .followUpEmail, question: "", language: .english).parts().first)
        #expect(email.contains("“Not specified”"))
    }

    @Test func longInputSplitsLikeTheSummaryPrompt() {
        let body = (0..<500).map { "[0:\($0 / 60):\($0 % 60)] บรรทัดที่ \($0) ของการประชุมที่ยาวมาก" }.joined(separator: "\n")
        let parts = AskPromptBuilder(sources: [.init(title: "ยาว", date: .now, summary: nil, body: body)], template: .recurringTopics, question: "", language: .thai, maxPartCharacters: 6_000).parts()

        #expect(parts.count > 1)
        #expect(parts.allSatisfy { $0.count <= 6_000 })
        #expect(parts.last?.contains("หาหัวข้อที่ถูกพูดถึง") == true)
    }

    @Test func recordingTypeShapesSummaryPrompt() throws {
        let prompt = try #require(ClaudePromptBuilder(title: "วิชา", date: .now, transcript: "x", outputs: [.summary], language: .thai, recordingType: .lecture).parts().first)
        #expect(prompt.contains("แนวคิดหลัก"))
    }
}

struct MarkerKindTests {
    @Test func typedMarkersRoundTripThroughNotes() {
        for kind in MarkerKind.allCases where kind != .important {
            #expect(MarkerKind(noteText: kind.noteText) == kind)
        }
        #expect(MarkerKind(noteText: "⭐ จุดสำคัญ") == nil) // ⭐ lives in `markers`, never in notes
        #expect(MarkerKind(noteText: "✅ งานที่ต้องทำ เพิ่มเติม") == nil) // typed text is a normal note
    }

    @Test func promptShowsWatchMarkersAsMarkersNotTypedNotes() {
        let lines = TranscriptLine.build(
            chunks: [(300, ChunkTranscript(text: "x", segments: [.init(start: 1, end: 2, text: "x")]))],
            markers: [],
            notes: [.init(time: 30, text: MarkerKind.decision.noteText), .init(time: 40, text: "โทรหาผู้ขาย")]
        )
        let text = TranscriptLine.plainText(lines)
        #expect(text.contains("[0:00:30] ⚖️ ผู้บันทึกทำเครื่องหมาย: มติ"))
        #expect(text.contains("[0:00:40] 📝 โน้ตผู้บันทึก: โทรหาผู้ขาย"))
    }

    @Test func promptExplainsMarkerEmoji() throws {
        let prompt = try #require(ClaudePromptBuilder(title: "t", date: .now, transcript: "x", outputs: [.summary], language: .thai).parts().first)
        #expect(prompt.contains("✅ = มีงานที่ต้องทำ"))
    }
}
