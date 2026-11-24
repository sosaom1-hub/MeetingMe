import SwiftUI

/// Moments the user marked while recording (⭐ and the Watch marker types); tapping one jumps playback there.
struct MarkersSection: View {
    let markers: [TimeInterval]
    var notes: [RecordingManifest.TimedNote] = []
    let player: ChunkPlayer

    private var items: [(time: TimeInterval, kind: MarkerKind)] {
        let typed = notes.compactMap { note in MarkerKind(noteText: note.text).map { (note.time, $0) } }
        return (markers.map { ($0, MarkerKind.important) } + typed).sorted { $0.time < $1.time }
    }

    var body: some View {
        if !items.isEmpty {
            Section("จุดที่ทำเครื่องหมาย") {
                ForEach(items, id: \.time) { item in
                    Button {
                        player.seek(to: item.time)
                    } label: {
                        HStack {
                            Label(item.kind.label, systemImage: item.kind.systemImage)
                            Spacer()
                            Text(Duration.seconds(item.time).formatted(.time(pattern: .hourMinuteSecond)))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                    .accessibilityHint("เล่นเสียงจากจุดนี้")
                }
            }
        }
    }
}
