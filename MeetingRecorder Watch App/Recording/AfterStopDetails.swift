import SwiftUI

/// Right after stopping on the Watch: check the audio, name the recording, pick its type.
/// Title and type ride along in the manifest to the iPhone (see `ChunkedRecorder.updateDetails`).
struct AfterStopDetails: View {
    @Environment(ChunkedRecorder.self) private var recorder
    @State private var player = LastSecondsPlayer()

    private var title: String? { recorder.manifest?.title }
    private var type: RecordingType? { recorder.manifest?.recordingType.flatMap(RecordingType.init(rawValue:)) }

    var body: some View {
        VStack {
            Button(player.isPlaying ? "หยุดฟัง" : "ฟัง 10 วิสุดท้าย", systemImage: player.isPlaying ? "stop.fill" : "play.fill") {
                player.toggle()
            }
            .buttonStyle(.glass)
            .accessibilityHint("เช็คว่าเสียงชัดพอ")

            if let message = player.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.warning)
            }

            NavigationLink {
                TitlePickerView { recorder.updateDetails(title: $0, type: nil) }
            } label: {
                Label(title ?? "ตั้งชื่อ", systemImage: "character.cursor.ibeam")
                    .lineLimit(2)
            }

            Picker("ประเภท", selection: Binding {
                type ?? .meeting
            } set: {
                recorder.updateDetails(title: nil, type: $0)
            }) {
                ForEach(RecordingType.allCases) { Label($0.label, systemImage: $0.systemImage).tag($0) }
            }
            .pickerStyle(.navigationLink)
        }
        .onDisappear(perform: player.stop)
    }
}
