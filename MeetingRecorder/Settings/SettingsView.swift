import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.serverURL) private var serverURL = ""
    @AppStorage(AppSettings.transcriptLanguage) private var languageRaw = AppSettings.defaultLanguage

    @Environment(\.dismiss) private var dismiss
    @State private var testResult: Result<String, Error>?
    @State private var isTesting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://ชื่อเครื่อง.tailnet.ts.net", text: $serverURL)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: serverURL) { testResult = nil }

                    Button("ทดสอบการเชื่อมต่อ", systemImage: "antenna.radiowaves.left.and.right", action: test)
                        .disabled(serverURL.isEmpty || isTesting)

                    if isTesting {
                        ProgressView()
                    } else if let testResult {
                        switch testResult {
                        case .success(let model):
                            Label("เชื่อมต่อได้ · \(model)", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Theme.success)
                        case .failure(let error):
                            Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(Theme.warning)
                        }
                    }
                } header: {
                    Text("เครื่อง Mac สำหรับถอดเสียง")
                } footer: {
                    Text("บน Mac รัน tailscale serve --bg 18081 แล้วใช้ที่อยู่ https://…ts.net ที่ Tailscale แสดง ตอนทดสอบใน simulator ใช้ http://127.0.0.1:18081")
                }

                Section("ภาษาที่ถอดเสียง") {
                    Picker("ภาษา", selection: $languageRaw) {
                        ForEach(TranscriptLanguage.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("ความเป็นส่วนตัว") {
                    Label("เสียงและ transcript เก็บบน iPhone เครื่องนี้", systemImage: "iphone")
                    Label("ส่งเสียงไปถอดที่เครื่อง Mac ของคุณเท่านั้น และส่งเมื่อคุณกด “ถอดเสียง”", systemImage: "desktopcomputer")
                    Label("ไม่มีบัญชีผู้ใช้ ไม่มี cloud ไม่มี analytics", systemImage: "hand.raised")
                }
            }
            .navigationTitle("ตั้งค่า")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("เสร็จ") { dismiss() }
                }
            }
        }
    }

    private func test() {
        guard let provider = MacASRProvider(string: serverURL) else {
            testResult = .failure(TranscriptionError.invalidServerURL)
            return
        }
        isTesting = true
        Task {
            do {
                testResult = .success(try await provider.health())
            } catch {
                testResult = .failure(error)
            }
            isTesting = false
        }
    }
}
