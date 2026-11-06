import Foundation

// MARK: - Enums
public enum MemoryPressureLevel: String, Codable, Sendable {
    case normal = "Normal"
    case warning = "Aviso"
    case critical = "Crítica"
}

public enum ThermalPressureState: String, Codable, Sendable {
    case nominal = "Nominal"
    case fair = "Moderado"
    case serious = "Serio"
    case critical = "Crítico"
}

// MARK: - Sub-Snapshots
public struct CPUSnapshot: Codable, Sendable {
    public var totalUsage: Double = 0.0
    public var userUsage: Double = 0.0
    public var systemUsage: Double = 0.0
    public var idleUsage: Double = 100.0
    public var coreUsages: [Double] = []
    public var performanceCoreUsages: [Double] = []
    public var efficiencyCoreUsages: [Double] = []
    public var history: [DataPoint] = []
    public var temperature: Double? = nil

    public init() {}
}

public struct GPUSnapshot: Codable, Sendable {
    public var usage: Double = 0.0
    public var frequencyMHz: Double? = nil
    public var history: [DataPoint] = []

    public init() {}
}

public struct MemorySnapshot: Codable, Sendable {
    public var totalBytes: UInt64 = 0
    public var usedBytes: UInt64 = 0
    public var freeBytes: UInt64 = 0
    public var activeBytes: UInt64 = 0
    public var inactiveBytes: UInt64 = 0
    public var wiredBytes: UInt64 = 0
    public var compressedBytes: UInt64 = 0
    public var swapUsedBytes: UInt64 = 0
    public var swapTotalBytes: UInt64 = 0
    public var pressureLevel: MemoryPressureLevel = .normal
    public var pressurePercentage: Double = 0.0
    public var history: [DataPoint] = []

    public init() {}

    public var usedPercentage: Double {
        guard totalBytes > 0 else { return 0.0 }
        return (Double(usedBytes) / Double(totalBytes)) * 100.0
    }
}

public struct VolumeInfo: Identifiable, Codable, Sendable {
    public var id: String { mountPoint }
    public var name: String
    public var mountPoint: String
    public var totalBytes: UInt64
    public var freeBytes: UInt64
    public var isSystem: Bool

    public init(name: String, mountPoint: String, totalBytes: UInt64, freeBytes: UInt64, isSystem: Bool = false) {
        self.name = name
        self.mountPoint = mountPoint
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        self.isSystem = isSystem
    }

    public var usedBytes: UInt64 {
        totalBytes > freeBytes ? totalBytes - freeBytes : 0
    }

    public var usedPercentage: Double {
        guard totalBytes > 0 else { return 0.0 }
        return (Double(usedBytes) / Double(totalBytes)) * 100.0
    }
}

public struct DiskSnapshot: Codable, Sendable {
    public var volumes: [VolumeInfo] = []
    public var readSpeedBytesPerSec: Double = 0.0
    public var writeSpeedBytesPerSec: Double = 0.0
    public var readIOPS: Double = 0.0
    public var writeIOPS: Double = 0.0
    public var historyRead: [DataPoint] = []
    public var historyWrite: [DataPoint] = []

    public init() {}
}

public struct NetworkSnapshot: Codable, Sendable {
    public var downloadSpeedBytesPerSec: Double = 0.0
    public var uploadSpeedBytesPerSec: Double = 0.0
    public var dailyDownloadBytes: UInt64 = 0
    public var dailyUploadBytes: UInt64 = 0
    public var monthlyDownloadBytes: UInt64 = 0
    public var monthlyUploadBytes: UInt64 = 0
    public var monthlyQuotaBytes: UInt64? = nil
    public var localIPv4: String? = nil
    public var publicIPv4: String? = nil
    public var interfaceName: String = "en0"
    public var historyDown: [DataPoint] = []
    public var historyUp: [DataPoint] = []

    public init() {}

    public var monthlyTotalBytes: UInt64 {
        monthlyDownloadBytes + monthlyUploadBytes
    }

    public var quotaPercentage: Double? {
        guard let quota = monthlyQuotaBytes, quota > 0 else { return nil }
        return min(100.0, (Double(monthlyTotalBytes) / Double(quota)) * 100.0)
    }
}

public struct BatterySnapshot: Codable, Sendable {
    public var hasBattery: Bool = false
    public var percentage: Double = 100.0
    public var isCharging: Bool = false
    public var isACPowered: Bool = true
    public var timeRemainingMinutes: Int? = nil
    public var cycleCount: Int? = nil
    public var healthPercentage: Double? = nil
    public var powerDrawWatts: Double? = nil
    public var temperature: Double? = nil

    public init() {}
}

public struct FanInfo: Identifiable, Codable, Sendable {
    public var id: Int
    public var name: String
    public var currentRPM: Double
    public var minRPM: Double
    public var maxRPM: Double

    public init(id: Int, name: String, currentRPM: Double, minRPM: Double, maxRPM: Double) {
        self.id = id
        self.name = name
        self.currentRPM = currentRPM
        self.minRPM = minRPM
        self.maxRPM = maxRPM
    }

    public var percentage: Double {
        guard maxRPM > minRPM else { return 0.0 }
        return max(0.0, min(100.0, ((currentRPM - minRPM) / (maxRPM - minRPM)) * 100.0))
    }
}

public struct ThermalSnapshot: Codable, Sendable {
    public var socTemperature: Double? = nil
    public var cpuTemperature: Double? = nil
    public var gpuTemperature: Double? = nil
    public var thermalState: ThermalPressureState = .nominal
    public var fans: [FanInfo] = []

    public init() {}
}

public struct SystemInfoSnapshot: Codable, Sendable {
    public var chipName: String = "Apple Silicon"
    public var modelName: String = "Mac"
    public var totalRAM: UInt64 = 0
    public var osVersion: String = "macOS"
    public var uptimeSeconds: TimeInterval = 0
    public var loadAverages: [Double] = [0.0, 0.0, 0.0]

    public var ramGB: Int {
        Int((Double(totalRAM) / pow(1024, 3)).rounded())
    }

    public init() {}
}

public struct ProcessItem: Identifiable, Codable, Sendable {
    public var id: Int32 { pid }
    public var pid: Int32
    public var name: String
    public var cpuPercentage: Double
    public var memoryBytes: UInt64
    public var bundleIdentifier: String?

    public init(pid: Int32, name: String, cpuPercentage: Double, memoryBytes: UInt64, bundleIdentifier: String? = nil) {
        self.pid = pid
        self.name = name
        self.cpuPercentage = cpuPercentage
        self.memoryBytes = memoryBytes
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct WiFiSnapshot: Codable, Sendable {
    public var isConnected: Bool = false
    public var ssid: String? = nil
    public var bssid: String? = nil
    public var rssi: Int = 0
    public var noise: Int = 0
    public var channel: Int = 0
    public var band: String = "5 GHz"
    public var txRate: Double = 0.0

    public init() {}
}

public struct HourlyForecast: Identifiable, Codable, Sendable {
    public var id: String { timeString }
    public var timeString: String
    public var temperature: Double
    public var symbolName: String

    public init(timeString: String, temperature: Double, symbolName: String) {
        self.timeString = timeString
        self.temperature = temperature
        self.symbolName = symbolName
    }
}

public struct WeatherSnapshot: Codable, Sendable {
    public var temperature: Double = 20.0
    public var feelsLike: Double = 20.0
    public var weatherCode: Int = 0
    public var conditionText: String = "Despejado"
    public var symbolName: String = "sun.max.fill"
    public var windSpeed: Double = 5.0
    public var hourlyForecast: [HourlyForecast] = []
    public var locationName: String = "Ubicación actual"
    public var lastUpdated: Date = Date()

    public init() {}
}

public struct CalendarEventInfo: Identifiable, Codable, Sendable {
    public var id: String
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var isAllDay: Bool
    public var meetingURL: String?
    public var location: String?

    public init(id: String, title: String, startDate: Date, endDate: Date, isAllDay: Bool, meetingURL: String? = nil, location: String? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.meetingURL = meetingURL
        self.location = location
    }

    public var minutesUntilStart: Int {
        Int(startDate.timeIntervalSince(Date()) / 60.0)
    }
}

public struct CalendarSnapshot: Codable, Sendable {
    public var upcomingEvents: [CalendarEventInfo] = []
    public var nextMeetingURL: String? = nil
    public var nextMeetingTitle: String? = nil
    public var minutesUntilNextMeeting: Int? = nil

    public init() {}
}

// MARK: - Root System Snapshot
public struct SystemSnapshot: Codable, Sendable {
    public var timestamp: Date = Date()
    public var cpu: CPUSnapshot = CPUSnapshot()
    public var gpu: GPUSnapshot = GPUSnapshot()
    public var memory: MemorySnapshot = MemorySnapshot()
    public var disk: DiskSnapshot = DiskSnapshot()
    public var network: NetworkSnapshot = NetworkSnapshot()
    public var battery: BatterySnapshot = BatterySnapshot()
    public var thermal: ThermalSnapshot = ThermalSnapshot()
    public var system: SystemInfoSnapshot = SystemInfoSnapshot()
    public var topProcesses: [ProcessItem] = []
    public var wifi: WiFiSnapshot = WiFiSnapshot()
    public var weather: WeatherSnapshot = WeatherSnapshot()
    public var calendar: CalendarSnapshot = CalendarSnapshot()

    public init() {}

    /// Placeholder for widget gallery previews (reads actual hardware if available, never hardcoded M3 or demo RAM)
    public static var preview: SystemSnapshot {
        var s = SystemSnapshot()
        s.cpu.totalUsage = 18.5
        s.cpu.coreUsages = [24.0, 15.0, 30.0, 12.0, 10.0, 8.0, 20.0, 16.0]
        s.cpu.performanceCoreUsages = [24.0, 15.0, 30.0, 12.0]
        s.cpu.efficiencyCoreUsages = [10.0, 8.0, 20.0, 16.0]

        // Read real hardware for RAM and Chip so even gallery placeholder shows actual device
        var ramBytes: UInt64 = 0
        var ramSize = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &ramBytes, &ramSize, nil, 0)
        let actualRAM = ramBytes > 0 ? ramBytes : 16 * 1024 * 1024 * 1024

        var chipSize = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &chipSize, nil, 0)
        var chip = "Apple Silicon"
        if chipSize > 0 {
            var buf = [CChar](repeating: 0, count: chipSize)
            sysctlbyname("machdep.cpu.brand_string", &buf, &chipSize, nil, 0)
            let bytes = buf.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }
            let s = String(decoding: bytes, as: UTF8.self)
            if !s.isEmpty { chip = s }
        }

        var modelSize = 0
        sysctlbyname("hw.model", nil, &modelSize, nil, 0)
        var model = "Mac"
        if modelSize > 0 {
            var buf = [CChar](repeating: 0, count: modelSize)
            sysctlbyname("hw.model", &buf, &modelSize, nil, 0)
            let bytes = buf.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }
            let s = String(decoding: bytes, as: UTF8.self)
            if !s.isEmpty { model = s }
        }

        s.memory.totalBytes = actualRAM
        s.memory.usedBytes = actualRAM / 2
        s.memory.freeBytes = actualRAM - s.memory.usedBytes
        s.disk.volumes = [
            VolumeInfo(name: "Macintosh HD", mountPoint: "/", totalBytes: 500 * 1024 * 1024 * 1024, freeBytes: 210 * 1024 * 1024 * 1024, isSystem: true)
        ]
        s.battery.hasBattery = true
        s.battery.percentage = 88.0
        s.battery.isCharging = false
        s.battery.powerDrawWatts = 9.4
        s.thermal.socTemperature = 42.0
        s.network.downloadSpeedBytesPerSec = 2.4 * 1024 * 1024
        s.network.uploadSpeedBytesPerSec = 450 * 1024
        s.system.chipName = chip
        s.system.modelName = model
        s.system.totalRAM = actualRAM
        let os = ProcessInfo.processInfo.operatingSystemVersion
        s.system.osVersion = "macOS \(os.majorVersion).\(os.minorVersion)"
        s.system.uptimeSeconds = ProcessInfo.processInfo.systemUptime
        s.system.loadAverages = [1.2, 1.4, 1.1]
        s.wifi.isConnected = true
        s.wifi.ssid = "Wi-Fi"
        s.wifi.rssi = -52
        s.weather.temperature = 21.0
        s.weather.feelsLike = 21.5
        s.weather.conditionText = "Despejado"
        s.weather.locationName = "Ubicación"
        return s
    }

    public static var demo: SystemSnapshot {
        preview
    }
}
