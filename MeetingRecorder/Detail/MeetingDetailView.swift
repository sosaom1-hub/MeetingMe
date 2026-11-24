import SwiftUI

struct MeetingDetailView: View {
    @Bindable var meeting: Meeting

    @Environment(\.dismiss) private var dismiss
    @State private var player = ChunkPlayer()
    @State private var pendingDelete: Meeting?

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
                PlayerControls(player: player)
                    .padding(.vertical, 8)
            }

            if !meeting.markers.isEmpty {
                Section("จุดสำคัญ") {
                    ForEach(meeting.markers, id: \.self) { marker in
                        Button {
                            player.seek(to: marker)
                        } label: {
                            Label(Duration.seconds(marker).formatted(.time(pattern: .hourMinuteSecond)), systemImage: "star.fill")
                                .monospacedDigit()
                        }
                        .tint(.primary)
                        .accessibilityHint("เล่นเสียงจากจุดนี้")
                    }
                }
            }

            Section("ถอดเสียง") {
                ContentUnavailableView(
                    "ยังไม่ได้ถอดเสียง",
                    systemImage: "text.quote",
                    description: Text("การถอดเสียงผ่านเครื่อง Mac จะเพิ่มในขั้นถัดไป")
                )
            }
        }
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("ลบ", systemImage: "trash", role: .destructive) {
                    pendingDelete = meeting
                }
            }
        }
        .meetingDeleteConfirmation(for: $pendingDelete) { dismiss() }
        .task(id: meeting.chunks?.count) {
            await player.load(meeting.sortedChunks.map { meeting.directory.appending(path: $0.fileName) })
        }
        .onDisappear(perform: player.pause)
    }
}
