import SwiftUI

/// Quick title: type or dictate, or tap a recent title / preset. Calendar titles come later (Batch B3).
struct TitlePickerView: View {
    let onPick: (String) -> Void

    @AppStorage("recentTitles") private var recentRaw = ""
    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""

    private static let presets = ["ประชุมทีม", "ประชุมลูกค้า", "ประชุมผู้บริหาร", "บรรยาย", "สัมภาษณ์"]

    private var recent: [String] {
        recentRaw.split(separator: "\n").map(String.init)
    }

    var body: some View {
        List {
            Section {
                TextField("พิมพ์หรือพูดชื่อ", text: $typed)
                    .onSubmit { pick(typed) }
            }
            if !recent.isEmpty {
                Section("ล่าสุด") {
                    ForEach(recent, id: \.self) { title in
                        Button(title) { pick(title) }
                    }
                }
            }
            Section("ทั่วไป") {
                ForEach(Self.presets.filter { !recent.contains($0) }, id: \.self) { title in
                    Button(title) { pick(title) }
                }
            }
        }
        .navigationTitle("ตั้งชื่อ")
    }

    private func pick(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onPick(trimmed)
        recentRaw = ([trimmed] + recent.filter { $0 != trimmed }).prefix(6).joined(separator: "\n")
        dismiss()
    }
}
