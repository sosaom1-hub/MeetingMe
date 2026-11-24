import SwiftUI

/// Shared look for Watch and iPhone, so both apps stay consistent.
enum Theme {
    /// The only strong color in the app: it always means "recording".
    static let recording = Color.red
    static let warning = Color.orange
    static let success = Color.green
    static let meterBarCount = 16
    static let savedSummarySeconds = 4

    // MARK: Brand (docs/brand/README.md). Accents only: never use them for status.

    /// Main dark background.
    static let brandCharcoal = Color(hex: 0x101113)
    /// Cards and bubbles on charcoal.
    static let brandSurface = Color(hex: 0x23262A)
    /// Primary mark and text on dark backgrounds.
    static let brandIvory = Color(hex: 0xFFFDF8)
    /// Secondary text on dark backgrounds.
    static let brandIvoryShade = Color(hex: 0xD9D4C8)
    /// Accent. On light backgrounds use it for decoration only, never text (contrast 1.5 : 1).
    static let brandGold = Color(hex: 0xE7D4A7)
    static let brandGoldDeep = Color(hex: 0xB99A61)

    static let brandBackground = LinearGradient(
        colors: [Color(hex: 0x202124), brandCharcoal, Color(hex: 0x050607)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let brandGoldGradient = LinearGradient(
        colors: [brandGold, brandGoldDeep],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
