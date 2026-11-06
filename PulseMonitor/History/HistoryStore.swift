import Foundation
// import PulseCore

public struct MetricHistoryRecord: Codable, Sendable {
    public let timestamp: Date
    public let cpuUsage: Double
    public let ramUsageBytes: UInt64
    public let diskUsedBytes: UInt64
    public let netDownSpeed: Double
    public let netUpSpeed: Double
    public let batteryPercentage: Double
    public let socTemperature: Double?

    public init(
        timestamp: Date = Date(),
        cpuUsage: Double,
        ramUsageBytes: UInt64,
        diskUsedBytes: UInt64,
        netDownSpeed: Double,
        netUpSpeed: Double,
        batteryPercentage: Double,
        socTemperature: Double?
    ) {
        self.timestamp = timestamp
        self.cpuUsage = cpuUsage
        self.ramUsageBytes = ramUsageBytes
        self.diskUsedBytes = diskUsedBytes
        self.netDownSpeed = netDownSpeed
        self.netUpSpeed = netUpSpeed
        self.batteryPercentage = batteryPercentage
        self.socTemperature = socTemperature
    }
}

public final class HistoryStore: @unchecked Sendable {
    public static let shared = HistoryStore()

    private var recentRecords: [MetricHistoryRecord] = []
    private var lastSampleTime: Date = Date.distantPast
    private var lastBatchFlushTime: Date = Date()
    private let lock = NSLock()

    private let fileManager = FileManager.default
    private var historyFileURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("PulseMonitor", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("pulse_history.json")
    }

    private init() {
        loadFromDisk()
    }

    public func record(snapshot: SystemSnapshot) {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        // Downsample: keep at most 1 record every 30 seconds for the 24h history
        guard now.timeIntervalSince(lastSampleTime) >= 30.0 else { return }
        lastSampleTime = now

        let record = MetricHistoryRecord(
            timestamp: now,
            cpuUsage: snapshot.cpu.totalUsage,
            ramUsageBytes: snapshot.memory.usedBytes,
            diskUsedBytes: snapshot.disk.volumes.first?.usedBytes ?? 0,
            netDownSpeed: snapshot.network.downloadSpeedBytesPerSec,
            netUpSpeed: snapshot.network.uploadSpeedBytesPerSec,
            batteryPercentage: snapshot.battery.percentage,
            socTemperature: snapshot.thermal.socTemperature
        )

        recentRecords.append(record)

        // Prune older than 24 hours (2880 records max)
        let cutoff = now.addingTimeInterval(-86400)
        recentRecords.removeAll { $0.timestamp < cutoff }

        // Batch flush every 5 minutes to protect SSD lifespan
        if now.timeIntervalSince(lastBatchFlushTime) > 300.0 {
            lastBatchFlushTime = now
            flushToDisk()
        }
    }

    private func flushToDisk() {
        do {
            let data = try JSONEncoder().encode(recentRecords)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {}
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: historyFileURL),
              let list = try? JSONDecoder().decode([MetricHistoryRecord].self, from: data) else {
            return
        }
        let cutoff = Date().addingTimeInterval(-86400)
        self.recentRecords = list.filter { $0.timestamp >= cutoff }
    }

    public func exportCSV() -> String {
        lock.lock()
        defer { lock.unlock() }

        var csv = "Timestamp,CPU_Usage_Pct,RAM_Used_Bytes,Disk_Used_Bytes,Net_Down_BytesSec,Net_Up_BytesSec,Battery_Pct,SoC_Temp_C\n"
        let f = ISO8601DateFormatter()

        for r in recentRecords {
            let ts = f.string(from: r.timestamp)
            let temp = r.socTemperature != nil ? String(format: "%.1f", r.socTemperature!) : ""
            csv += "\(ts),\(String(format: "%.2f", r.cpuUsage)),\(r.ramUsageBytes),\(r.diskUsedBytes),\(String(format: "%.1f", r.netDownSpeed)),\(String(format: "%.1f", r.netUpSpeed)),\(String(format: "%.1f", r.batteryPercentage)),\(temp)\n"
        }
        return csv
    }

    public func exportJSON() -> String {
        lock.lock()
        defer { lock.unlock() }

        let enc = JSONEncoder()
        enc.outputFormatting = .prettyPrinted
        enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(recentRecords), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "[]"
    }
}
