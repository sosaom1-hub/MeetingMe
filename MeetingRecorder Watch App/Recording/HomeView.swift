import SwiftUI

struct HomeView: View {
    @ScaledMetric(relativeTo: .title) private var recordButtonSize = 76.0

    @State private var preflight = PreflightStatus()
    @State private var startRequested = false

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            Button {
                startRequested = true
            } label: {
                Label("เริ่มบันทึก", systemImage: "mic.fill")
                    .labelStyle(.iconOnly)
                    .font(.title)
                    .frame(width: recordButtonSize, height: recordButtonSize)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .tint(Theme.recording)

            Text("เริ่มบันทึก")
                .font(.headline)

            Spacer(minLength: 0)
            PreflightLine(status: preflight)
        }
        .navigationTitle("ประชุม")
        .onAppear { preflight = .current() }
        .consentStartFlow(isRequested: $startRequested)
    }
}
