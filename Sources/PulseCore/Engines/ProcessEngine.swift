import Foundation
import AppKit
import Darwin

public final class ProcessEngine: @unchecked Sendable {
    public static let shared = ProcessEngine()

    private var previousCpuTimes: [Int32: (user: UInt64, system: UInt64, timestamp: Date)] = [:]
    private let lock = NSLock()

    private init() {}

    public func sampleTopProcesses(limit: Int = 10) -> [ProcessItem] {
        lock.lock()
        defer { lock.unlock() }

        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }

        var pids = [Int32](repeating: 0, count: Int(count))
        let actual = proc_listallpids(&pids, Int32(MemoryLayout<Int32>.stride * pids.count))
        guard actual > 0 else { return [] }

        let validCount = Int(actual)
        let now = Date()

        var items: [ProcessItem] = []
        var newCpuTimes: [Int32: (user: UInt64, system: UInt64, timestamp: Date)] = [:]

        for i in 0..<validCount {
            let pid = pids[i]
            guard pid > 0 else { continue }

            var taskInfo = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.stride)
            let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, size)

            guard result == size else { continue }

            let totalUser = taskInfo.pti_total_user
            let totalSys = taskInfo.pti_total_system
            let resident = taskInfo.pti_resident_size

            // Only consider processes taking at least 1MB of RAM
            guard resident > 1024 * 1024 else { continue }

            var cpuUsage = 0.0
            if let prev = previousCpuTimes[pid] {
                let elapsed = max(0.5, now.timeIntervalSince(prev.timestamp))
                let deltaUser = totalUser >= prev.user ? totalUser - prev.user : 0
                let deltaSys = totalSys >= prev.system ? totalSys - prev.system : 0
                // pti_total_user is in nanoseconds
                let totalDeltaSeconds = Double(deltaUser + deltaSys) / 1_000_000_000.0
                cpuUsage = (totalDeltaSeconds / elapsed) * 100.0
            }

            newCpuTimes[pid] = (totalUser, totalSys, now)

            // Resolve friendly name
            var name = ""
            var bundleId: String? = nil

            if let app = NSRunningApplication(processIdentifier: pid) {
                name = app.localizedName ?? ""
                bundleId = app.bundleIdentifier
            }

            if name.isEmpty {
                var nameBuffer = [CChar](repeating: 0, count: 256)
                if proc_name(pid, &nameBuffer, 256) > 0 {
                    nameBuffer.withUnsafeBufferPointer { ptr in
                        if let base = ptr.baseAddress {
                            name = String(cString: base)
                        }
                    }
                }
            }

            if name.isEmpty || name == "launchd" || name == "kernel_task" {
                continue
            }

            items.append(ProcessItem(
                pid: pid,
                name: name,
                cpuPercentage: min(800.0, max(0.0, cpuUsage)),
                memoryBytes: resident,
                bundleIdentifier: bundleId
            ))
        }

        self.previousCpuTimes = newCpuTimes

        // Sort by CPU usage primarily, then by Memory
        items.sort {
            if abs($0.cpuPercentage - $1.cpuPercentage) > 1.0 {
                return $0.cpuPercentage > $1.cpuPercentage
            }
            return $0.memoryBytes > $1.memoryBytes
        }

        return Array(items.prefix(limit))
    }

    /// Terminates a process gracefully with fallback to SIGTERM
    @discardableResult
    public func terminateProcess(pid: Int32) -> Bool {
        if let app = NSRunningApplication(processIdentifier: pid) {
            if app.terminate() {
                return true
            }
        }
        return kill(pid, SIGTERM) == 0
    }
}
