import SwiftUI

/// The user's own notes: typed during recording (with time, tap to play) and free text written afterwards.
struct NotesSection: View {
    @Bindable var meeting: Meeting
    let player: ChunkPlayer

    var body: some View {
        Section {
            ForEach(meeting.timedNotes, id: \.self) { note in
                Button {
                    player.seek(to: note.time)
                } label: {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Duration.seconds(note.time).formatted(.time(pattern: .hourMinuteSecond)))
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text(note.text)
                    }
                }
                .tint(.primary)
                .accessibilityHint("เล่นเสียงจากจุดนี้")
            }

            TextField("เขียนโน้ตเพิ่มเติม เช่น สิ่งที่ต้องทำต่อ ความเห็นของคุณ", text: $meeting.myNotes, axis: .vertical)
                .lineLimit(3...12)
                .onChange(of: meeting.myNotes) {
                    meeting.refreshSearchText()
                }
        } header: {
            Text("โน้ตของฉัน")
        } footer: {
            Text("โน้ตรวมอยู่ในการค้นหาและไฟล์ที่ส่งออก และส่งให้ Claude โดยระบุว่าเป็นโน้ตของคุณ ไม่ใช่คำพูดในห้อง")
        }
    }
}
