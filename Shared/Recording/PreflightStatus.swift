import Foundation
#if os(watchOS)
import WatchKit
#else
import UIKit
#endif

/// Battery and storage check shown before recording starts. Warns; never blocks.
nonisolated struct PreflightStatus: Sendable, Equatable {
    static let bytesPerHour = Double(RecordingDefaults.bitRate) / 8 * 3600
    static let lowBattery: Float = 0.3
    static let lowStorageBytes: Int64 = 200_000_000

    /// 0…1, nil when the device does not report it (e.g. simulator).
    var batteryLevel: Float?
    var freeBytes: Int64?

    var hoursOfAudioLeft: Double? {
        freeBytes.map { Double($0) / Self.bytesPerHour }
    }

    var isBatteryLow: Bool { (batteryLevel ?? 1) < Self.lowBattery }
    var isStorageLow: Bool { (freeBytes ?? .max) < Self.lowStorageBytes }

    @MainActor
    static func current() -> PreflightStatus {
        #if os(watchOS)
        let device = WKInterfaceDevice.current()
        device.isBatteryMonitoringEnabled = true
        let level = device.batteryLevel
        #else
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        #endif
        let values = try? URL.applicationSupportDirectory.deletingLastPathComponent()
            .resourceValues(forKeys: [.volumeAvailableCapacityKey])
        return PreflightStatus(
            batteryLevel: level >= 0 ? level : nil,
            freeBytes: values?.volumeAvailableCapacity.map(Int64.init)
        )
    }
}
