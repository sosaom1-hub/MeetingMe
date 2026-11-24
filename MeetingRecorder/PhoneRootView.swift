import SwiftData
import SwiftUI

/// Wires the recorder and Watch transfers into the meeting store once the model context exists.
struct PhoneRootView: View {
    @Environment(ChunkedRecorder.self) private var recorder
    @Environment(PhoneTransferService.self) private var transfer
    @Environment(\.modelContext) private var context

    var body: some View {
        LibraryView()
            .tint(Theme.recording)
            .task { connect() }
    }

    private func connect() {
        let store = MeetingStore(context: context)
        recorder.onFinish = { store.upsert($0) }
        transfer.onManifest = { store.upsert($0) }

        // iPhone recordings cut off by a crash or force-quit become "interrupted" meetings.
        let recovered = (try? RecoveryScanner.recover(
            root: RecordingPaths.root,
            source: .phone,
            durationOf: RecordingPaths.duration(of:)
        )) ?? []
        recovered.forEach(store.upsert)

        // Meetings saved before full-text search existed have an empty index.
        let unindexed = (try? context.fetch(FetchDescriptor<Meeting>(predicate: #Predicate { $0.searchText == "" }))) ?? []
        unindexed.forEach { $0.refreshSearchText() }
        try? context.save()

        transfer.activate()
    }
}
