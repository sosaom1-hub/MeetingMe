import SwiftUI

struct PlayerControls: View {
    let player: ChunkPlayer

    @State private var scrubTime: TimeInterval = 0
    @State private var isScrubbing = false

    var body: some View {
        VStack {
            Slider(value: $scrubTime, in: 0...max(player.duration, 1)) { editing in
                isScrubbing = editing
                if !editing {
                    player.seek(to: scrubTime)
                }
            }
            .accessibilityLabel("ตำแหน่งที่เล่น")
            .accessibilityValue(format(scrubTime))

            HStack {
                Text(format(scrubTime))
                Spacer()
                Text("-" + format(max(player.duration - scrubTime, 0)))
            }
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)

            GlassEffectContainer {
                HStack {
                    Button("ย้อน 15 วินาที", systemImage: "gobackward.15") { player.skip(by: -15) }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.glass)

                    Button(player.isPlaying ? "หยุดชั่วคราว" : "เล่น", systemImage: player.isPlaying ? "pause.fill" : "play.fill", action: player.togglePlay)
                        .labelStyle(.iconOnly)
                        .font(.title)
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.circle)

                    Button("ข้าม 15 วินาที", systemImage: "goforward.15") { player.skip(by: 15) }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.glass)
                }
                .controlSize(.large)
            }

            if let message = player.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.warning)
            }
        }
        .disabled(!player.isReady)
        .onChange(of: player.currentTime) { _, time in
            if !isScrubbing {
                scrubTime = time
            }
        }
    }

    private func format(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond))
    }
}
