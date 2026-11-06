import Foundation
import Darwin

public final class SystemEngine: @unchecked Sendable {
    public static let shared = SystemEngine()

    public static func sysctlString(_ name: String) -> String? {
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &buf, &size, nil, 0)
        let bytes = buf.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }
        let str = String(decoding: bytes, as: UTF8.self)
        return str.isEmpty ? nil : str
    }

    public static func sysctlUInt64(_ name: String) -> UInt64 {
        var v: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname(name, &v, &size, nil, 0)
        return v
    }

    public let chipName: String
    public let modelName: String
    public let totalRAM: UInt64
    public let osVersion: String

    public var ramGB: Int {
        Int((Double(totalRAM) / pow(1024, 3)).rounded())
    }

    private init() {
        self.chipName = Self.sysctlString("machdep.cpu.brand_string") ?? "Desconocido"
        self.modelName = Self.sysctlString("hw.model") ?? ""
        self.totalRAM = Self.sysctlUInt64("hw.memsize")

        // OS Version
        let os = ProcessInfo.processInfo.operatingSystemVersion
        self.osVersion = "macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
    }

    public func sample() -> SystemInfoSnapshot {
        var snapshot = SystemInfoSnapshot()
        snapshot.chipName = chipName
        snapshot.modelName = modelName
        snapshot.totalRAM = totalRAM
        snapshot.osVersion = osVersion
        snapshot.uptimeSeconds = ProcessInfo.processInfo.systemUptime

        var loadAverages = [Double](repeating: 0.0, count: 3)
        if getloadavg(&loadAverages, 3) == 3 {
            snapshot.loadAverages = loadAverages
        }

        return snapshot
    }

    public func generateDiagnosticSummary() -> String {
        let snap = SharedSnapshotStore.shared.load() ?? SystemSnapshot()
        let sys = sample()
        return """
        === Pulse Monitor Diagnostic Report ===
        Generado: \(Formatters.dateStamp())
        Equipo: \(sys.chipName) (\(sys.modelName))
        Memoria Total: \(Formatters.bytes(sys.totalRAM))
        Sistema Operativo: \(sys.osVersion)
        Uptime: \(Formatters.uptime(sys.uptimeSeconds))
        Carga Media: \(sys.loadAverages.map { String(format: "%.2f", $0) }.joined(separator: ", "))
        CPU Total: \(String(format: "%.1f %%", snap.cpu.totalUsage)) (P-Cores: \(snap.cpu.performanceCoreUsages.count), E-Cores: \(snap.cpu.efficiencyCoreUsages.count))
        RAM Usada: \(Formatters.bytes(snap.memory.usedBytes)) / \(Formatters.bytes(snap.memory.totalBytes)) (\(String(format: "%.1f %%", snap.memory.usedPercentage)))
        Presión Memoria: \(snap.memory.pressureLevel.rawValue) (\(String(format: "%.1f %%", snap.memory.pressurePercentage)))
        Red: IP Local \(snap.network.localIPv4 ?? "Desconocida") | ↓ \(Formatters.speed(snap.network.downloadSpeedBytesPerSec)) | ↑ \(Formatters.speed(snap.network.uploadSpeedBytesPerSec))
        Batería: \(snap.battery.hasBattery ? "\(Int(snap.battery.percentage))% (Salud: \(Int(snap.battery.healthPercentage ?? 100))%, Ciclos: \(snap.battery.cycleCount ?? 0))" : "Sin batería (Sobremesa)")
        Térmica: SoC \(snap.thermal.socTemperature.map { "\(Int($0)) °C" } ?? "--") | Estado: \(snap.thermal.thermalState.rawValue)
        Almacenamiento: \(snap.disk.volumes.map { "\($0.name): \(Formatters.fileBytes($0.usedBytes)) usados / \(Formatters.fileBytes($0.totalBytes))" }.joined(separator: "; "))
        ========================================
        """
    }
}
