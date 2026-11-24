import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum LibrarySort: String, CaseIterable, Identifiable {
    case date, title
    var id: Self { self }
    var label: String { self == .date ? "วันที่ล่าสุด" : "ชื่อ ก–ฮ" }
}

struct LibraryView: View {
    @Environment(ChunkedRecorder.self) private var recorder
    @Environment(IntentRequests.self) private var requests

    @State private var searchText = ""
    @State private var sort = LibrarySort.date
    @State private var startRequested = false
    @State private var isShowingRecorder = false
    @State private var isShowingSettings = false
    @State private var isShowingAsk = false
    @State private var isImporting = false
    @State private var importProgress: (done: Int, total: Int)?
    @State private var importError: String?
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            MeetingList(searchText: searchText, sort: sort)
                .navigationTitle("บันทึกประชุม")
                .searchable(text: $searchText, prompt: "ค้นหาในชื่อ, transcript, สรุป, โน้ต")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("ตั้งค่า", systemImage: "gearshape") { isShowingSettings = true }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("ถาม AI", systemImage: "sparkles") { isShowingAsk = true }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("นำเข้าไฟล์เสียง", systemImage: "square.and.arrow.down") { isImporting = true }
                            .disabled(importProgress != nil)
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
        // "เริ่มบันทึกประชุม" from Siri, Shortcuts, or the iPhone Action button.
        .onChange(of: requests.startRequestedAt, initial: true) {
            if requests.consumeStartRequest() {
                startRequested = true
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
        .sheet(isPresented: $isShowingAsk) {
            AskAISheet()
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.audio]) { result in
            Task { await importAudio(result) }
        }
        .safeAreaInset(edge: .top) {
            if let importProgress {
                ProgressView(value: Double(importProgress.done), total: Double(max(importProgress.total, 1))) {
                    Text("กำลังนำเข้าไฟล์เสียง \(importProgress.done)/\(importProgress.total) ส่วน")
                }
                .padding()
                .background(.bar)
            }
        }
        .alert("นำเข้าไม่สำเร็จ", isPresented: Binding { importError != nil } set: { if !$0 { importError = nil } }) {
            Button("ตกลง", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }

    private func importAudio(_ result: Result<URL, Error>) async {
        guard case .success(let url) = result else {
            if case .failure(let error) = result { importError = error.localizedDescription }
            return
        }
        importProgress = (0, 1)
        defer { importProgress = nil }
        do {
            let manifest = try await AudioImporter.importFile(at: url) { done, total in
                importProgress = (done, total)
            }
            MeetingStore(context: context).upsert(manifest)
        } catch {
            importError = error.localizedDescription
        }
    }
}
