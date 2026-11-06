import Foundation

public enum Formatters: Sendable {
    private static let lock = NSLock()

    nonisolated(unsafe) private static let memoryFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .memory
        f.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        f.includesUnit = true
        f.isAdaptive = true
        return f
    }()

    nonisolated(unsafe) private static let fileFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        f.includesUnit = true
        f.isAdaptive = true
        return f
    }()

    private static let dateStampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmm"
        return f
    }()

    public static func bytes(_ bytes: UInt64) -> String {
        lock.lock()
        defer { lock.unlock() }
        return memoryFormatter.string(fromByteCount: Int64(bytes))
    }

    public static func fileBytes(_ bytes: UInt64) -> String {
        lock.lock()
        defer { lock.unlock() }
        return fileFormatter.string(fromByteCount: Int64(bytes))
    }

    public static func dateStamp(_ date: Date = Date()) -> String {
        lock.lock()
        defer { lock.unlock() }
        return dateStampFormatter.string(from: date)
    }

    public static func speed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return String(format: "%.0f B/s", bytesPerSecond)
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024.0)
        } else if bytesPerSecond < 1024 * 1024 * 1024 {
            return String(format: "%.2f MB/s", bytesPerSecond / (1024.0 * 1024.0))
        } else {
            return String(format: "%.2f GB/s", bytesPerSecond / (1024.0 * 1024.0 * 1024.0))
        }
    }

    public static func percentage(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    public static func percentageInteger(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    public static func temperature(_ celsius: Double?) -> String {
        guard let c = celsius else { return "-- °C" }
        return String(format: "%.0f °C", c)
    }

    public static func watts(_ watts: Double?) -> String {
        guard let w = watts else { return "-- W" }
        return String(format: "%.1f W", w)
    }

    public static func uptime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    public static func rpm(_ rpm: Double) -> String {
        String(format: "%.0f RPM", rpm)
    }
}
