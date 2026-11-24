import SwiftUI

struct MeetingDetailView: View {
    @Bindable var meeting: Meeting

    @Environment(\.dismiss) private var dismiss
    @State private var player = ChunkPlayer()
    @State private var pendingDelete: Meeting?
    @State private var isShowingSummary = false
    @State private var isShowingExport = false
    @State private var isShowingAsk = false

    var body: some View {
        List {
            Section {
                TextField("ชื่อประชุม", text: $meeting.title, axis: .vertical)
                    .font(.title2)
                    .bold()
                LabeledContent("วันที่", value: meeting.startedAt.formatted(date: .long, time: .shortened))
                LabeledContent("ความยาว", value: Duration.seconds(meeting.duration).formatted(.time(pattern: .hourMinuteSecond)))
                StatusChip(state: meeting.state, source: meeting.source)
            }

            Section("เสียง") {
                if let deletedAt = meeting.audioDeletedAt {
                    Label("ลบไฟล์เสียงแล้วตามการตั้งค่า เมื่อ \(deletedAt.formatted(date: .abbreviated, time: .shortened)) · transcript ยังอยู่", systemImage: "speaker.slash")
                        .foregroundStyle(.secondary)
                } else {
                    PlayerControls(player: player)
                        .padding(.vertical, 8)
                }
            }

            MarkersSection(markers: meeting.markers, notes: meeting.timedNotes, player: player)

            SummarySection(meeting: meeting) { isShowingSummary = true }

            NotesSection(meeting: meeting, player: player)

            TranscriptSection(meeting: meeting, player: player)
        }
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("ถาม AI", systemImage: "sparkles") { isShowingAsk = true }
                    .disabled(!meeting.sortedChunks.contains { $0.result != nil })
            }
            ToolbarItem(placement: .primaryAction) {
                Button("ส่งออก", systemImage: "square.and.arrow.up") { isShowingExport = true }
                    .disabled(meeting.transcriptLines.isEmpty && meeting.summaryText == nil)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("ลบ", systemImage: "trash", role: .destructive) {
                    pendingDelete = meeting
                }
            }
        }
        .sheet(isPresented: $isShowingSummary) { SummarySheet(meeting: meeting) }
        .sheet(isPresented: $isShowingExport) { ExportSheet(meeting: meeting) }
        .sheet(isPresented: $isShowingAsk) { AskAISheet(initialSelection: [meeting.id]) }
        .meetingDeleteConfirmation(for: $pendingDelete) { dismiss() }
        .task(id: meeting.chunks?.count) {
            await player.load(meeting.sortedChunks.map { meeting.directory.appending(path: $0.fileName) })
        }
        .onDisappear(perform: player.pause)
        .onChange(of: meeting.title) { meeting.refreshSearchText() }
    }
}
