import SwiftUI

struct HomeView: View {
    @Environment(IntentRequests.self) private var requests
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
        // "เริ่มบันทึกประชุม" from Siri, Shortcuts or the Action button.
        .onChange(of: requests.startRequestedAt, initial: true) {
            if requests.consumeStartRequest() {
                startRequested = true
            }
        }
        .consentStartFlow(isRequested: $startRequested)
    }
}
