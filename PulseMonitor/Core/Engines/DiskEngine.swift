import Foundation
import IOKit
import IOKit.storage

public final class DiskEngine: @unchecked Sendable {
    public static let shared = DiskEngine()

    private var previousReadBytes: UInt64 = 0
    private var previousWriteBytes: UInt64 = 0
    private var previousReadOps: UInt64 = 0
    private var previousWriteOps: UInt64 = 0
    private var previousTimestamp: Date = Date()

    private var historyRead = CircularBuffer<DataPoint>(capacity: 60)
    private var historyWrite = CircularBuffer<DataPoint>(capacity: 60)
    private let lock = NSLock()

    private init() {
        let (rBytes, wBytes, rOps, wOps) = sampleIOKitStorageCounters()
        self.previousReadBytes = rBytes
        self.previousWriteBytes = wBytes
        self.previousReadOps = rOps
        self.previousWriteOps = wOps
        self.previousTimestamp = Date()
    }

    public func sample() -> DiskSnapshot {
        lock.lock()
        defer { lock.unlock() }

        var snapshot = DiskSnapshot()

        // 1. Mounted Volumes
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeIsInternalKey
        ]

        let fileManager = FileManager.default
        let urls = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []

        var volumes: [VolumeInfo] = []
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  let total = values.volumeTotalCapacity,
                  total > 0 else {
                continue
            }

            let name = values.volumeName ?? url.lastPathComponent
            let free = values.volumeAvailableCapacityForImportantUsage ?? 0
            let isSystem = url.path == "/"

            let vol = VolumeInfo(
                name: name,
                mountPoint: url.path,
                totalBytes: UInt64(total),
                freeBytes: UInt64(max(0, free)),
                isSystem: isSystem
            )
            volumes.append(vol)
        }

        // Sort so root "/" is first
        volumes.sort { $0.isSystem && !$1.isSystem }
        snapshot.volumes = volumes

        // 2. Disk I/O via IOKit
        let now = Date()
        let elapsed = max(0.5, now.timeIntervalSince(previousTimestamp))
        let (currentReadBytes, currentWriteBytes, currentReadOps, currentWriteOps) = sampleIOKitStorageCounters()

        if previousReadBytes > 0 || previousWriteBytes > 0 {
            let deltaReadBytes = currentReadBytes >= previousReadBytes ? currentReadBytes - previousReadBytes : 0
            let deltaWriteBytes = currentWriteBytes >= previousWriteBytes ? currentWriteBytes - previousWriteBytes : 0
            let deltaReadOps = currentReadOps >= previousReadOps ? currentReadOps - previousReadOps : 0
            let deltaWriteOps = currentWriteOps >= previousWriteOps ? currentWriteOps - previousWriteOps : 0

            snapshot.readSpeedBytesPerSec = Double(deltaReadBytes) / elapsed
            snapshot.writeSpeedBytesPerSec = Double(deltaWriteBytes) / elapsed
            snapshot.readIOPS = Double(deltaReadOps) / elapsed
            snapshot.writeIOPS = Double(deltaWriteOps) / elapsed
        }

        self.previousReadBytes = currentReadBytes
        self.previousWriteBytes = currentWriteBytes
        self.previousReadOps = currentReadOps
        self.previousWriteOps = currentWriteOps
        self.previousTimestamp = now

        historyRead.append(DataPoint(value: snapshot.readSpeedBytesPerSec))
        historyWrite.append(DataPoint(value: snapshot.writeSpeedBytesPerSec))

        snapshot.historyRead = historyRead.values
        snapshot.historyWrite = historyWrite.values

        return snapshot
    }

    private func sampleIOKitStorageCounters() -> (readBytes: UInt64, writeBytes: UInt64, readOps: UInt64, writeOps: UInt64) {
        var readBytes: UInt64 = 0
        var writeBytes: UInt64 = 0
        var readOps: UInt64 = 0
        var writeOps: UInt64 = 0

        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching(kIOBlockStorageDriverClass)
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return (0, 0, 0, 0)
        }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any],
               let stats = dict["Statistics"] as? [String: Any] {

                if let rB = stats["Bytes (Read)"] as? NSNumber {
                    readBytes += rB.uint64Value
                }
                if let wB = stats["Bytes (Write)"] as? NSNumber {
                    writeBytes += wB.uint64Value
                }
                if let rO = stats["Operations (Read)"] as? NSNumber {
                    readOps += rO.uint64Value
                }
                if let wO = stats["Operations (Write)"] as? NSNumber {
                    writeOps += wO.uint64Value
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)

        return (readBytes, writeBytes, readOps, writeOps)
    }
}
