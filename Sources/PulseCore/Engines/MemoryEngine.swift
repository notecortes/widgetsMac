import Foundation
import Darwin

public final class MemoryEngine: @unchecked Sendable {
    public static let shared = MemoryEngine()

    private var historyBuffer = CircularBuffer<DataPoint>(capacity: 60)
    private let lock = NSLock()
    private let totalRAM: UInt64

    private init() {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &size, &len, nil, 0) == 0 {
            self.totalRAM = size
        } else {
            self.totalRAM = 0
        }
    }

    public func sample() -> MemorySnapshot {
        lock.lock()
        defer { lock.unlock() }

        var snapshot = MemorySnapshot()
        snapshot.totalBytes = totalRAM

        var vmStat = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let kerr = withUnsafeMutablePointer(to: &vmStat) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        var pageSize: vm_size_t = 16384
        _ = host_page_size(mach_host_self(), &pageSize)

        if kerr == KERN_SUCCESS {
            let pSize = UInt64(pageSize)
            let active = UInt64(vmStat.active_count) * pSize
            let inactive = UInt64(vmStat.inactive_count) * pSize
            let wired = UInt64(vmStat.wire_count) * pSize
            let compressed = UInt64(vmStat.compressor_page_count) * pSize
            let free = UInt64(vmStat.free_count) * pSize

            // Activity Monitor style:
            // Used = Wired + Compressed + Active (App Memory)
            let used = min(totalRAM, wired + compressed + active)
            let available = totalRAM > used ? totalRAM - used : free

            snapshot.activeBytes = active
            snapshot.inactiveBytes = inactive
            snapshot.wiredBytes = wired
            snapshot.compressedBytes = compressed
            snapshot.freeBytes = max(free, available)
            snapshot.usedBytes = used
        } else {
            snapshot.usedBytes = totalRAM / 2
            snapshot.freeBytes = totalRAM / 2
        }

        // Swap usage via sysctl
        var swap = xsw_usage()
        var swapLen = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &swapLen, nil, 0) == 0 {
            snapshot.swapUsedBytes = UInt64(swap.xsu_used)
            snapshot.swapTotalBytes = UInt64(swap.xsu_total)
        }

        // Memory pressure
        var pressureLevel: Int32 = 1
        var pLen = MemoryLayout<Int32>.size
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureLevel, &pLen, nil, 0) == 0 {
            switch pressureLevel {
            case 2:
                snapshot.pressureLevel = .warning
                snapshot.pressurePercentage = 70.0
            case 4:
                snapshot.pressureLevel = .critical
                snapshot.pressurePercentage = 95.0
            default:
                snapshot.pressureLevel = .normal
                let ratio = snapshot.totalBytes > 0 ? (Double(snapshot.usedBytes) / Double(snapshot.totalBytes)) * 100.0 : 0.0
                snapshot.pressurePercentage = min(60.0, ratio * 0.75)
            }
        } else {
            let ratio = snapshot.totalBytes > 0 ? (Double(snapshot.usedBytes) / Double(snapshot.totalBytes)) * 100.0 : 0.0
            snapshot.pressurePercentage = ratio
            if ratio > 85.0 {
                snapshot.pressureLevel = .critical
            } else if ratio > 70.0 {
                snapshot.pressureLevel = .warning
            } else {
                snapshot.pressureLevel = .normal
            }
        }

        historyBuffer.append(DataPoint(value: snapshot.usedPercentage))
        snapshot.history = historyBuffer.values

        return snapshot
    }
}
