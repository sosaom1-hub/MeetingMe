import SwiftUI

/// Correct one transcript line. The original is shown so the user can compare.
struct EditLineSheet: View {
    let original: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("ข้อความ") {
                    TextField("ข้อความ", text: $text, axis: .vertical)
                        .lineSpacing(4)
                        .focused($isFocused)
                }
                Section("ต้นฉบับจากการถอดเสียง") {
                    Text(original)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("แก้ไขบรรทัด")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") {
                        onSave(text)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text == original)
                }
            }
            .onAppear {
                text = original
                isFocused = true
            }
        }
        .presentationDetents([.medium, .large])
    }
}
