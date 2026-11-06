import Foundation
import Darwin

public final class CPUEngine: @unchecked Sendable {
    public static let shared = CPUEngine()

    private var previousPerCoreTicks: [[Int64]] = []
    private var historyBuffer = CircularBuffer<DataPoint>(capacity: 60)
    private let lock = NSLock()

    public private(set) var pCoreCount: Int = 0
    public private(set) var eCoreCount: Int = 0

    private init() {
        detectCoreTopology()
    }

    private func detectCoreTopology() {
        var pCores: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("hw.perflevel0.logicalcpu", &pCores, &size, nil, 0) == 0 {
            self.pCoreCount = Int(pCores)
        }

        var eCores: Int32 = 0
        size = MemoryLayout<Int32>.size
        if sysctlbyname("hw.perflevel1.logicalcpu", &eCores, &size, nil, 0) == 0 {
            self.eCoreCount = Int(eCores)
        }

        if pCoreCount == 0 && eCoreCount == 0 {
            // Fallback for Intel or virtualization
            var totalCores: Int32 = 0
            size = MemoryLayout<Int32>.size
            if sysctlbyname("hw.ncpu", &totalCores, &size, nil, 0) == 0 {
                self.pCoreCount = Int(totalCores)
            } else {
                self.pCoreCount = 4
            }
        }
    }

    public func sample() -> CPUSnapshot {
        lock.lock()
        defer { lock.unlock() }

        var snapshot = CPUSnapshot()

        var cpuCount: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &cpuInfo,
            &infoCount
        )

        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else {
            return snapshot
        }

        let numCPUs = Int(cpuCount)
        var coreLoads: [Double] = []
        var totalUserTicks: Int64 = 0
        var totalSystemTicks: Int64 = 0
        var totalIdleTicks: Int64 = 0
        var totalNiceTicks: Int64 = 0

        var currentPerCoreTicks: [[Int64]] = []

        for i in 0..<numCPUs {
            let offset = Int(CPU_STATE_MAX) * i
            let user = Int64(cpuInfo[offset + Int(CPU_STATE_USER)])
            let system = Int64(cpuInfo[offset + Int(CPU_STATE_SYSTEM)])
            let idle = Int64(cpuInfo[offset + Int(CPU_STATE_IDLE)])
            let nice = Int64(cpuInfo[offset + Int(CPU_STATE_NICE)])

            currentPerCoreTicks.append([user, system, idle, nice])

            if i < previousPerCoreTicks.count {
                let prev = previousPerCoreTicks[i]
                let dUser = max(0, user - prev[0])
                let dSystem = max(0, system - prev[1])
                let dIdle = max(0, idle - prev[2])
                let dNice = max(0, nice - prev[3])
                let dTotal = dUser + dSystem + dIdle + dNice

                totalUserTicks += dUser
                totalSystemTicks += dSystem
                totalIdleTicks += dIdle
                totalNiceTicks += dNice

                let coreUsage = dTotal > 0 ? (Double(dUser + dSystem + dNice) / Double(dTotal)) * 100.0 : 0.0
                coreLoads.append(min(100.0, max(0.0, coreUsage)))
            } else {
                coreLoads.append(0.0)
            }
        }

        // Deallocate the mach memory buffer to avoid memory leaks
        let vmSize = vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vmSize)

        self.previousPerCoreTicks = currentPerCoreTicks

        let grandTotal = totalUserTicks + totalSystemTicks + totalIdleTicks + totalNiceTicks
        if grandTotal > 0 {
            snapshot.userUsage = (Double(totalUserTicks) / Double(grandTotal)) * 100.0
            snapshot.systemUsage = (Double(totalSystemTicks) / Double(grandTotal)) * 100.0
            snapshot.idleUsage = (Double(totalIdleTicks) / Double(grandTotal)) * 100.0
            snapshot.totalUsage = min(100.0, max(0.0, snapshot.userUsage + snapshot.systemUsage + (Double(totalNiceTicks) / Double(grandTotal)) * 100.0))
        } else {
            snapshot.totalUsage = 0.0
            snapshot.idleUsage = 100.0
        }

        snapshot.coreUsages = coreLoads

        // Split into Performance and Efficiency cores
        if pCoreCount > 0 && coreLoads.count >= (pCoreCount + eCoreCount) {
            snapshot.performanceCoreUsages = Array(coreLoads[0..<pCoreCount])
            snapshot.efficiencyCoreUsages = Array(coreLoads[pCoreCount..<(pCoreCount + eCoreCount)])
        } else {
            snapshot.performanceCoreUsages = coreLoads
            snapshot.efficiencyCoreUsages = []
        }

        historyBuffer.append(DataPoint(value: snapshot.totalUsage))
        snapshot.history = historyBuffer.values

        return snapshot
    }
}
