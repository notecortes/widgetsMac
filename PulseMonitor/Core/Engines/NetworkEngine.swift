import Foundation
import Darwin

public final class NetworkEngine: @unchecked Sendable {
    public static let shared = NetworkEngine()

    private var previousInBytes: UInt64 = 0
    private var previousOutBytes: UInt64 = 0
    private var previousTimestamp: Date = Date()

    private var historyDown = CircularBuffer<DataPoint>(capacity: 60)
    private var historyUp = CircularBuffer<DataPoint>(capacity: 60)
    private let lock = NSLock()

    // Monthly Quota and Accumulation storage keys
    private let defaults = UserDefaults.standard
    private let dailyInKey = "pulse_net_daily_in"
    private let dailyOutKey = "pulse_net_daily_out"
    private let dailyDateKey = "pulse_net_daily_date"
    private let monthlyInPrefix = "pulse_net_monthly_in_"
    private let monthlyOutPrefix = "pulse_net_monthly_out_"

    private init() {
        let (inB, outB) = sampleTotalNetworkBytes()
        self.previousInBytes = inB
        self.previousOutBytes = outB
        self.previousTimestamp = Date()
    }

    public func sample(monthlyQuotaBytes: UInt64? = nil) -> NetworkSnapshot {
        lock.lock()
        defer { lock.unlock() }

        var snapshot = NetworkSnapshot()
        snapshot.monthlyQuotaBytes = monthlyQuotaBytes

        let now = Date()
        let elapsed = max(0.5, now.timeIntervalSince(previousTimestamp))
        let (currentInBytes, currentOutBytes) = sampleTotalNetworkBytes()

        if previousInBytes > 0 && currentInBytes >= previousInBytes {
            let deltaIn = currentInBytes - previousInBytes
            let deltaOut = currentOutBytes >= previousOutBytes ? currentOutBytes - previousOutBytes : 0

            snapshot.downloadSpeedBytesPerSec = Double(deltaIn) / elapsed
            snapshot.uploadSpeedBytesPerSec = Double(deltaOut) / elapsed

            updateAccumulations(deltaIn: deltaIn, deltaOut: deltaOut)
        }

        self.previousInBytes = currentInBytes
        self.previousOutBytes = currentOutBytes
        self.previousTimestamp = now

        let (dIn, dOut) = readDailyAccumulation()
        snapshot.dailyDownloadBytes = dIn
        snapshot.dailyUploadBytes = dOut

        let (mIn, mOut) = readMonthlyAccumulation()
        snapshot.monthlyDownloadBytes = mIn
        snapshot.monthlyUploadBytes = mOut

        snapshot.localIPv4 = getLocalIPv4Address()
        snapshot.interfaceName = getPrimaryInterfaceName()

        historyDown.append(DataPoint(value: snapshot.downloadSpeedBytesPerSec))
        historyUp.append(DataPoint(value: snapshot.uploadSpeedBytesPerSec))

        snapshot.historyDown = historyDown.values
        snapshot.historyUp = historyUp.values

        return snapshot
    }

    private func updateAccumulations(deltaIn: UInt64, deltaOut: UInt64) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDate = defaults.object(forKey: dailyDateKey) as? Date ?? today

        var dailyIn = defaults.object(forKey: dailyInKey) as? UInt64 ?? 0
        var dailyOut = defaults.object(forKey: dailyOutKey) as? UInt64 ?? 0

        if !calendar.isDate(lastDate, inSameDayAs: today) {
            dailyIn = 0
            dailyOut = 0
            defaults.set(today, forKey: dailyDateKey)
        }

        dailyIn += deltaIn
        dailyOut += deltaOut
        defaults.set(dailyIn, forKey: dailyInKey)
        defaults.set(dailyOut, forKey: dailyOutKey)

        // Monthly accumulation
        let monthKey = currentMonthIdentifier()
        var monthlyIn = defaults.object(forKey: monthlyInPrefix + monthKey) as? UInt64 ?? 0
        var monthlyOut = defaults.object(forKey: monthlyOutPrefix + monthKey) as? UInt64 ?? 0
        monthlyIn += deltaIn
        monthlyOut += deltaOut
        defaults.set(monthlyIn, forKey: monthlyInPrefix + monthKey)
        defaults.set(monthlyOut, forKey: monthlyOutPrefix + monthKey)
    }

    private func readDailyAccumulation() -> (UInt64, UInt64) {
        let dIn = defaults.object(forKey: dailyInKey) as? UInt64 ?? 0
        let dOut = defaults.object(forKey: dailyOutKey) as? UInt64 ?? 0
        return (dIn, dOut)
    }

    private func readMonthlyAccumulation() -> (UInt64, UInt64) {
        let monthKey = currentMonthIdentifier()
        let mIn = defaults.object(forKey: monthlyInPrefix + monthKey) as? UInt64 ?? 0
        let mOut = defaults.object(forKey: monthlyOutPrefix + monthKey) as? UInt64 ?? 0
        return (mIn, mOut)
    }

    private func currentMonthIdentifier() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    private func sampleTotalNetworkBytes() -> (inBytes: UInt64, outBytes: UInt64) {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len: Int = 0

        guard sysctl(&mib, 6, nil, &len, nil, 0) == 0 else {
            return (0, 0)
        }

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: len)
        defer { buffer.deallocate() }

        guard sysctl(&mib, 6, buffer, &len, nil, 0) == 0 else {
            return (0, 0)
        }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var cursor = buffer
        let end = buffer.advanced(by: len)

        while cursor < end {
            let ifm = cursor.withMemoryRebound(to: if_msghdr.self, capacity: 1) { $0.pointee }
            if ifm.ifm_type == RTM_IFINFO2 {
                let ifm2 = cursor.withMemoryRebound(to: if_msghdr2.self, capacity: 1) { $0.pointee }
                let flags = Int32(ifm2.ifm_flags)
                // Skip loopback (IFF_LOOPBACK = 0x8) and down interfaces
                if (flags & IFF_UP) != 0 && (flags & IFF_LOOPBACK) == 0 {
                    totalIn += UInt64(ifm2.ifm_data.ifi_ibytes)
                    totalOut += UInt64(ifm2.ifm_data.ifi_obytes)
                }
            }
            cursor = cursor.advanced(by: Int(ifm.ifm_msglen))
        }

        return (totalIn, totalOut)
    }

    public func getLocalIPv4Address() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            let interface = current.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            let name = String(cString: interface.ifa_name)

            if addrFamily == UInt8(AF_INET) && (name == "en0" || name == "en1" || name == "bridge0") {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, 0, NI_NUMERICHOST) == 0 {
                    return hostname.withUnsafeBufferPointer { ptr in
                        ptr.baseAddress.map { String(cString: $0) }
                    }
                }
            }
            ptr = current.pointee.ifa_next
        }
        return nil
    }

    public func getPrimaryInterfaceName() -> String {
        return "en0"
    }
}
