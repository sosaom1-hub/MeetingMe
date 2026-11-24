import SwiftData
import SwiftUI

struct MeetingList: View {
    @Query private var meetings: [Meeting]
    @Binding var selection: Meeting?
    @State private var pendingDelete: Meeting?
    private let isSearching: Bool
    private let query: String

    init(searchText: String, sort: LibrarySort, selection: Binding<Meeting?>) {
        _selection = selection
        let text = searchText.trimmingCharacters(in: .whitespaces)
        let lowered = text.lowercased()
        // Title, plus the lowercased index of transcript, summary and notes (see Meeting.refreshSearchText).
        let filter: Predicate<Meeting>? = text.isEmpty ? nil : #Predicate {
            $0.title.localizedStandardContains(text) || $0.searchText.contains(lowered)
        }
        query = text
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
            List(meetings, selection: $selection) { meeting in
                NavigationLink(value: meeting) {
                    MeetingRow(meeting: meeting, snippet: isSearching ? meeting.snippet(matching: query) : nil)
                }
                .swipeActions {
                    Button("ลบ", systemImage: "trash", role: .destructive) {
                        pendingDelete = meeting
                    }
                }
            }
            .meetingDeleteConfirmation(for: $pendingDelete) {
                // The deleted meeting may be the one open in the detail column.
                selection = nil
            }
        }
    }
}
