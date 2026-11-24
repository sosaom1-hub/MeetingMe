import SwiftData
import SwiftUI

struct MeetingList: View {
    @Query private var meetings: [Meeting]
    @State private var pendingDelete: Meeting?
    private let isSearching: Bool

    init(searchText: String, sort: LibrarySort) {
        let text = searchText
        let filter: Predicate<Meeting>? = text.isEmpty ? nil : #Predicate { $0.title.localizedStandardContains(text) }
        let order = sort == .date
            ? [SortDescriptor(\Meeting.startedAt, order: .reverse)]
            : [SortDescriptor(\Meeting.title)]
        _meetings = Query(filter: filter, sort: order, animation: .default)
        isSearching = !text.isEmpty
    }

    var body: some View {
        if meetings.isEmpty {
            if isSearching {
                ContentUnavailableView.search
            } else {
                ContentUnavailableView(
                    "ยังไม่มีการบันทึก",
                    systemImage: "waveform",
                    description: Text("เริ่มบันทึกจาก Apple Watch หรือกด “บันทึกใหม่” ด้านล่าง")
                )
            }
        } else {
            List(meetings) { meeting in
                NavigationLink(value: meeting) {
                    MeetingRow(meeting: meeting)
                }
                .swipeActions {
                    Button("ลบ", systemImage: "trash", role: .destructive) {
                        pendingDelete = meeting
                    }
                }
            }
            .meetingDeleteConfirmation(for: $pendingDelete)
        }
    }
}
