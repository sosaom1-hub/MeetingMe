import SwiftData
import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.serverURL) private var serverURL = ""
    @AppStorage(AppSettings.transcriptLanguage) private var languageRaw = AppSettings.defaultLanguage
    @AppStorage(AppSettings.glossary) private var glossary = ""
    @AppStorage(AppSettings.defaultOutputs) private var defaultOutputsRaw = AppSettings.defaultOutputsValue
    @AppStorage(AppSettings.audioRetention) private var retentionRaw = AudioRetention.keep.rawValue
    @AppStorage(ConsentDefaults.storageKey) private var consentText = ConsentDefaults.text

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(PhoneTransferService.self) private var transfer
    @Environment(ChunkedRecorder.self) private var recorder
    @Query private var meetings: [Meeting]

    @State private var testResult: Result<String, Error>?
    @State private var isTesting = false
    @State private var isConfirmingDeleteAll = false

    var body: some View {
        NavigationStack {
            Form {
                serverSection
                languageSection
                outputsSection
                glossarySection
                consentSection
                retentionSection
                privacySection
            }
            .navigationTitle("ตั้งค่า")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("เสร็จ") { dismiss() }
                }
            }
            .confirmationDialog("ลบข้อมูลทั้งหมด?", isPresented: $isConfirmingDeleteAll, titleVisibility: .visible) {
                Button("ลบทั้งหมด \(meetings.count) ประชุม", role: .destructive) {
                    MeetingStore(context: context).deleteAll()
                }
            } message: {
                Text("ไฟล์เสียง, transcript และผลสรุปของทุกประชุม (\(meetings.count) รายการ) จะถูกลบออกจาก iPhone และกู้คืนไม่ได้ ไฟล์ที่ยังอยู่บนนาฬิกาไม่ถูกลบ")
            }
            .onChange(of: consentText) {
                transfer.sendConsentText()
            }
        }
    }

    // MARK: Sections

    private var serverSection: some View {
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
    }

    private var languageSection: some View {
        Section("ภาษาที่ถอดเสียง") {
            Picker("ภาษา", selection: $languageRaw) {
                ForEach(TranscriptLanguage.allCases) { Text($0.label).tag($0.rawValue) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }

    private var outputsSection: some View {
        Section {
            ForEach(OutputKind.allCases) { kind in
                Toggle(isOn: Binding {
                    OutputKind.decode(defaultOutputsRaw).contains(kind)
                } set: { isOn in
                    var kinds = OutputKind.decode(defaultOutputsRaw)
                    if isOn { kinds.insert(kind) } else { kinds.remove(kind) }
                    defaultOutputsRaw = OutputKind.encode(kinds)
                }) {
                    Label(kind.label, systemImage: kind.systemImage)
                }
            }
        } header: {
            Text("ผลสรุปที่เลือกไว้ล่วงหน้า")
        } footer: {
            Text("เป็นค่าเริ่มต้นเท่านั้น คุณยืนยันหรือเปลี่ยนได้ทุกครั้งก่อนสรุปแต่ละประชุม")
        }
    }

    private var glossarySection: some View {
        Section {
            TextField("วิภา\nธนพล\nMicrosoft Teams", text: $glossary, axis: .vertical)
                .lineLimit(3...10)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        } header: {
            Text("ชื่อคนและคำเฉพาะ")
        } footer: {
            Text("บรรทัดละหนึ่งคำ ตอนสรุป Claude จะใช้รายการนี้แก้ชื่อหรือคำที่ถอดเสียงผิด เช่น “วิพา” เป็น “วิภา” โดยไม่เติมคำที่ไม่มีคนพูด")
        }
    }

    private var consentSection: some View {
        Section {
            TextField("ข้อความเตือน", text: $consentText, axis: .vertical)
                .lineLimit(2...5)
            if consentText != ConsentDefaults.text {
                Button("ใช้ข้อความเริ่มต้น") { consentText = ConsentDefaults.text }
            }
        } header: {
            Text("ข้อความเตือนก่อนบันทึก")
        } footer: {
            Text("แสดงก่อนเริ่มบันทึกทั้งบน iPhone และนาฬิกา (ส่งไปนาฬิกาอัตโนมัติ) เป็นการเตือนความจำ ไม่ใช่คำแนะนำทางกฎหมาย")
        }
    }

    private var retentionSection: some View {
        Section {
            Picker("ไฟล์เสียง", selection: $retentionRaw) {
                ForEach(AudioRetention.allCases) { Text($0.label).tag($0.rawValue) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("การเก็บไฟล์เสียง")
        } footer: {
            Text(retentionRaw == AudioRetention.deleteAfterTranscript.rawValue
                 ? "หลังถอดเสียงครบทุกส่วน แอปจะลบไฟล์เสียงของประชุมนั้น เก็บไว้เฉพาะ transcript และผลสรุป จะฟังเสียงย้อนหลังไม่ได้ ใช้กับการถอดเสียงครั้งต่อไปเท่านั้น"
                 : "ไฟล์เสียงอยู่บน iPhone จนกว่าคุณจะลบประชุมนั้นเอง ประมาณ 14 MB ต่อชั่วโมง")
        }
    }

    private var privacySection: some View {
        Section("ความเป็นส่วนตัวและข้อมูล") {
            Label("เสียงและ transcript เก็บบน iPhone เครื่องนี้", systemImage: "iphone")
            Label("ส่งเสียงไปถอดที่เครื่อง Mac ของคุณเท่านั้น และส่งเมื่อคุณกด “ถอดเสียง”", systemImage: "desktopcomputer")
            Label("transcript ไปถึง Claude เฉพาะตอนที่คุณกดสรุปหรือแชร์เอง", systemImage: "square.and.arrow.up")
            Label("ไม่มีบัญชีผู้ใช้ ไม่มี cloud ไม่มี analytics", systemImage: "hand.raised")
            Button("ลบข้อมูลทั้งหมด…", systemImage: "trash", role: .destructive) {
                isConfirmingDeleteAll = true
            }
            .disabled(meetings.isEmpty || recorder.isActive)
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
