import SwiftUI

enum LibrarySort: String, CaseIterable, Identifiable {
    case date, title
    var id: Self { self }
    var label: String { self == .date ? "วันที่ล่าสุด" : "ชื่อ ก–ฮ" }
}

struct LibraryView: View {
    @Environment(ChunkedRecorder.self) private var recorder

    @State private var searchText = ""
    @State private var sort = LibrarySort.date
    @State private var startRequested = false
    @State private var isShowingRecorder = false
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            MeetingList(searchText: searchText, sort: sort)
                .navigationTitle("บันทึกประชุม")
                .searchable(text: $searchText, prompt: "ค้นหาชื่อประชุม")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("ตั้งค่า", systemImage: "gearshape") { isShowingSettings = true }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu("เรียงลำดับ", systemImage: "arrow.up.arrow.down") {
                            Picker("เรียงตาม", selection: $sort) {
                                ForEach(LibrarySort.allCases) { Text($0.label).tag($0) }
                            }
                        }
                    }
                }
                .navigationDestination(for: Meeting.self) { MeetingDetailView(meeting: $0) }
                .safeAreaBar(edge: .bottom) {
                    Button {
                        startRequested = true
                    } label: {
                        Label("บันทึกใหม่", systemImage: "mic.fill")
                            .font(.title3)
                            .bold()
                            .padding(.horizontal)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.extraLarge)
                    .tint(Theme.recording)
                    .padding(.bottom)
                }
        }
        .consentStartFlow(isRequested: $startRequested)
        .onChange(of: recorder.phase) { _, phase in
            isShowingRecorder = phase != .idle
        }
        .fullScreenCover(isPresented: $isShowingRecorder) {
            PhoneRecordingView()
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
    }
}
