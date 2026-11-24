import SwiftUI

/// Recording reminder shown before each recording (unless snoozed for 24 h). Makes no legal claims.
struct ConsentSheet: View {
    let consentText: String
    let showsMicNotice: Bool
    @Binding var snooze: Bool
    let onStart: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Label("ก่อนเริ่มบันทึก", systemImage: "person.2.wave.2")
                    .font(.headline)

                Text(consentText)

                if showsMicNotice {
                    Label("ไมค์อยู่บนข้อมือ เสียงคนที่นั่งไกลอาจเบาหรือถอดความได้ไม่ครบ", systemImage: "applewatch.radiowaves.left.and.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Toggle("ไม่ต้องเตือน 24 ชม.", isOn: $snooze)
                    .font(.footnote)

                Button("เริ่มบันทึก", systemImage: "mic.fill") {
                    dismiss()
                    onStart()
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.recording)
                .frame(maxWidth: .infinity)
            }
            .scenePadding()
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }
}
