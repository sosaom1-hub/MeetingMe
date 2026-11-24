import SwiftUI

/// ⭐ moments the user tapped while recording; tapping one jumps playback there.
struct MarkersSection: View {
    let markers: [TimeInterval]
    let player: ChunkPlayer

    var body: some View {
        if !markers.isEmpty {
            Section("จุดสำคัญ") {
                ForEach(markers, id: \.self) { marker in
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
    }
}
