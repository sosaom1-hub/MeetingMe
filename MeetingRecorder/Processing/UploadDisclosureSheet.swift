import SwiftUI

/// Shown once, before the first audio upload: says exactly where the audio goes.
struct UploadDisclosureSheet: View {
    let serverURL: String
    let onAccept: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label("เสียงจะไปที่เครื่อง Mac ของคุณเท่านั้น", systemImage: "lock.shield")
                        .font(.title3)
                        .bold()
                    Text("แอปจะส่งไฟล์เสียงทีละส่วน (ส่วนละ 5 นาที) ไปที่:")
                    Text(serverURL)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                    Text("ผ่านเครือข่าย Tailscale ของคุณเอง ไม่ส่งไปบริการ cloud ใด และไม่มีบัญชีผู้ใช้")
                    Text("เครื่อง Mac ถอดเสียงด้วยโมเดล OpenThai แล้วส่งข้อความกลับมาเก็บบน iPhone ไฟล์เสียงต้นฉบับยังอยู่บน iPhone ตามเดิม")
                        .foregroundStyle(.secondary)
                }
                .scenePadding()
            }
            .navigationTitle("ก่อนถอดเสียงครั้งแรก")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("เข้าใจแล้ว ถอดเสียง") {
                        dismiss()
                        onAccept()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
