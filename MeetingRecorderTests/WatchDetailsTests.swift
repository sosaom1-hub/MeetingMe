import Foundation
import SwiftData
import Testing
@testable import MeetingRecorder

struct WatchDetailsTests {
    let store: MeetingStore
    let id = UUID()

    init() throws {
        let container = try ModelContainer(for: Meeting.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        store = MeetingStore(context: ModelContext(container))
    }

    private func manifest(title: String?, type: RecordingType?) -> RecordingManifest {
        var manifest = RecordingManifest(id: id, source: .watch, startedAt: Date(timeIntervalSince1970: 1_800_000_000), status: .finished)
        manifest.title = title
        manifest.recordingType = type?.rawValue
        return manifest
    }

    private func meeting() throws -> Meeting {
        try #require(try store.context.fetch(FetchDescriptor<Meeting>()).first)
    }

    @Test func watchTitleAndTypeReplaceDefaults() throws {
        store.upsert(manifest(title: nil, type: nil))
        store.upsert(manifest(title: "ประชุมลูกค้า", type: .consultation))

        #expect(try meeting().title == "ประชุมลูกค้า")
        #expect(try meeting().recordingType == .consultation)
    }

    @Test func watchTitleNeverOverwritesAnIPhoneRename() throws {
        store.upsert(manifest(title: nil, type: nil))
        try meeting().title = "ชื่อที่ตั้งบน iPhone"

        store.upsert(manifest(title: "ประชุมทีม", type: nil))

        #expect(try meeting().title == "ชื่อที่ตั้งบน iPhone")
    }

    @Test func oldManifestsWithoutTitleStillDecode() throws {
        let json = #"{"id":"6F1C2B9E-6C1F-4F7A-9C6B-0D2E8F7B1A11","source":"watch","startedAt":"2026-11-24T08:00:00Z","status":"finished","chunks":[],"markers":[]}"#
        let decoded = try RecordingManifest.decode(Data(json.utf8))
        #expect(decoded.title == nil)
        #expect(decoded.recordingType == nil)
    }
}
