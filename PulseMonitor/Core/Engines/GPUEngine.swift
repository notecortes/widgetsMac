import Foundation
import IOKit

public final class GPUEngine: @unchecked Sendable {
    public static let shared = GPUEngine()

    private var historyBuffer = CircularBuffer<DataPoint>(capacity: 60)
    private let lock = NSLock()

    private init() {}

    public func sample() -> GPUSnapshot {
        lock.lock()
        defer { lock.unlock() }

        var snapshot = GPUSnapshot()

        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOAccelerator")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return snapshot
        }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any],
               let stats = dict["PerformanceStatistics"] as? [String: Any] {

                if let util = stats["Device Utilization %"] as? NSNumber {
                    snapshot.usage = max(snapshot.usage, min(100.0, util.doubleValue))
                } else if let util = stats["GPU Core Utilization"] as? NSNumber {
                    snapshot.usage = max(snapshot.usage, min(100.0, util.doubleValue * 100.0))
                }

                if let freq = stats["Core Clock(MHz)"] as? NSNumber {
                    snapshot.frequencyMHz = freq.doubleValue
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)

        historyBuffer.append(DataPoint(value: snapshot.usage))
        snapshot.history = historyBuffer.values

        return snapshot
    }
}
