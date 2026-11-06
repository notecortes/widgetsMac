import Foundation
import IOKit
import IOKit.ps

public final class BatteryEngine: @unchecked Sendable {
    public static let shared = BatteryEngine()

    private let lock = NSLock()

    private init() {}

    public func sample() -> BatterySnapshot {
        lock.lock()
        defer { lock.unlock() }

        var snapshot = BatterySnapshot()

        guard let snapshotBlob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshotBlob)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            // Desktop Mac without battery
            snapshot.hasBattery = false
            snapshot.isACPowered = true
            snapshot.percentage = 100.0
            return snapshot
        }

        var foundBattery = false
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshotBlob, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            if let type = desc[kIOPSTypeKey] as? String, type == kIOPSInternalBatteryType {
                foundBattery = true

                let curCap = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
                let maxCap = desc[kIOPSMaxCapacityKey] as? Int ?? 100
                snapshot.percentage = maxCap > 0 ? (Double(curCap) / Double(maxCap)) * 100.0 : 100.0

                snapshot.isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
                let powerState = desc[kIOPSPowerSourceStateKey] as? String
                snapshot.isACPowered = (powerState == kIOPSACPowerValue)

                if snapshot.isCharging {
                    if let toFull = desc[kIOPSTimeToFullChargeKey] as? Int, toFull > 0 {
                        snapshot.timeRemainingMinutes = toFull
                    }
                } else {
                    if let toEmpty = desc[kIOPSTimeToEmptyKey] as? Int, toEmpty > 0 {
                        snapshot.timeRemainingMinutes = toEmpty
                    }
                }
            }
        }

        snapshot.hasBattery = foundBattery
        if !foundBattery {
            snapshot.isACPowered = true
            return snapshot
        }

        // Query AppleSmartBattery for Hardware telemetry (cycles, health, instantaneous Watts)
        sampleSmartBatteryHardware(into: &snapshot)

        return snapshot
    }

    private func sampleSmartBatteryHardware(into snapshot: inout BatterySnapshot) {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("AppleSmartBattery")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return
        }

        let service = IOIteratorNext(iterator)
        if service != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any] {

                if let cycle = dict["CycleCount"] as? Int {
                    snapshot.cycleCount = cycle
                }

                if let bData = dict["BatteryData"] as? [String: Any] {
                    let rawMax = (bData["AppleRawMaxCapacity"] as? Int) ?? (dict["AppleRawMaxCapacity"] as? Int) ?? (dict["MaxCapacity"] as? Int)
                    let design = (bData["DesignCapacity"] as? Int) ?? (dict["DesignCapacity"] as? Int)
                    if let rawMax = rawMax, let design = design, design > 0 {
                        snapshot.healthPercentage = min(100.0, (Double(rawMax) / Double(design)) * 100.0)
                    }

                    if let tempRaw = bData["Temperature"] as? Double {
                        // 0.1 Kelvin to Celsius
                        snapshot.temperature = (tempRaw / 10.0) - 273.15
                    }
                }

                // Voltage (mV) and Amperage (mA or signed int)
                let voltage = dict["Voltage"] as? Double ?? 0.0
                let amperageRaw = dict["Amperage"] as? NSNumber
                if let ampNum = amperageRaw, voltage > 0 {
                    let rawVal = ampNum.int64Value
                    // Amperage is often signed 16 or 32-bit integer in mA
                    let signedAmp = Double(Int16(truncatingIfNeeded: rawVal))
                    let watts = abs(signedAmp * voltage) / 1_000_000.0
                    if watts > 0.1 && watts < 200.0 {
                        snapshot.powerDrawWatts = watts
                    }
                }

                // If on AC charger, use charger details as well
                if snapshot.powerDrawWatts == nil,
                   let adapter = dict["AdapterDetails"] as? [String: Any],
                   let w = adapter["Watts"] as? Double, w > 0 {
                    snapshot.powerDrawWatts = w
                }
            }
            IOObjectRelease(service)
        }
        IOObjectRelease(iterator)
    }
}
