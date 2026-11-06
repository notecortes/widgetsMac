import Foundation
import PulseCore

func assertTrue(_ condition: Bool, _ msg: String) {
    if !condition {
        print("❌ Assertion Failed: \(msg)")
        exit(1)
    } else {
        print("✅ \(msg)")
    }
}

print("🧪 Starting PulseCore Comprehensive Engine Tests...")

// 1. CircularBuffer test
var buffer = CircularBuffer<Int>(capacity: 3)
assertTrue(buffer.isEmpty, "CircularBuffer starts empty")
buffer.append(10)
buffer.append(20)
buffer.append(30)
buffer.append(40)
assertTrue(buffer.count == 3, "CircularBuffer drops oldest on overflow")
assertTrue(buffer.values == [20, 30, 40], "CircularBuffer maintains chronological ordering")
assertTrue(buffer.last == 40, "CircularBuffer reports correct last item")

// 2. CPUEngine test
let cpu = CPUEngine.shared
print("CPU P-Cores: \(cpu.pCoreCount), E-Cores: \(cpu.eCoreCount)")
_ = cpu.sample()
Thread.sleep(forTimeInterval: 0.15)
let cpuSnap = cpu.sample()
assertTrue(cpuSnap.totalUsage >= 0.0 && cpuSnap.totalUsage <= 100.0, "CPU Total Usage valid: \(cpuSnap.totalUsage)%")
assertTrue(!cpuSnap.coreUsages.isEmpty, "Core Usages count: \(cpuSnap.coreUsages.count)")
assertTrue(!cpuSnap.performanceCoreUsages.isEmpty, "P-Cores count: \(cpuSnap.performanceCoreUsages.count)")

// 3. MemoryEngine test
let mem = MemoryEngine.shared
let memSnap = mem.sample()
assertTrue(memSnap.totalBytes > 0, "Memory total > 0 (\(Formatters.bytes(memSnap.totalBytes)))")
assertTrue(memSnap.usedBytes > 0, "Memory used > 0 (\(Formatters.bytes(memSnap.usedBytes)))")
assertTrue(memSnap.freeBytes > 0, "Memory free > 0 (\(Formatters.bytes(memSnap.freeBytes)))")

// 4. DiskEngine test
let disk = DiskEngine.shared
let diskSnap = disk.sample()
assertTrue(!diskSnap.volumes.isEmpty, "Disk volumes detected: \(diskSnap.volumes.count)")
if let primary = diskSnap.volumes.first {
    assertTrue(primary.totalBytes > 0, "Primary volume total > 0 (\(Formatters.fileBytes(primary.totalBytes)))")
    print("Primary volume: \(primary.name) at \(primary.mountPoint), used \(primary.usedPercentage)%")
}

// 5. NetworkEngine test (F3)
let net = NetworkEngine.shared
_ = net.sample()
Thread.sleep(forTimeInterval: 0.2)
let netSnap = net.sample(monthlyQuotaBytes: 50 * 1024 * 1024 * 1024)
print("Network Down: \(Formatters.speed(netSnap.downloadSpeedBytesPerSec)), Up: \(Formatters.speed(netSnap.uploadSpeedBytesPerSec))")
print("Local IP: \(netSnap.localIPv4 ?? "none")")
assertTrue(netSnap.downloadSpeedBytesPerSec >= 0, "Network download speed non-negative")
assertTrue(netSnap.uploadSpeedBytesPerSec >= 0, "Network upload speed non-negative")

// 6. BatteryEngine test (F3)
let batt = BatteryEngine.shared
let battSnap = batt.sample()
print("Battery Present: \(battSnap.hasBattery), Level: \(battSnap.percentage)%, AC: \(battSnap.isACPowered), Watts: \(Formatters.watts(battSnap.powerDrawWatts)), Cycles: \(battSnap.cycleCount ?? 0)")
assertTrue(battSnap.percentage >= 0 && battSnap.percentage <= 100, "Battery percentage valid")

// 7. GPUEngine test (F3)
let gpu = GPUEngine.shared
let gpuSnap = gpu.sample()
print("GPU Load: \(Formatters.percentage(gpuSnap.usage))")
assertTrue(gpuSnap.usage >= 0 && gpuSnap.usage <= 100, "GPU usage valid")

// 8. ThermalEngine & SMC test (F3)
let thermal = ThermalEngine.shared
let thermalSnap = thermal.sample()
print("SoC Temp: \(Formatters.temperature(thermalSnap.socTemperature)), Thermal State: \(thermalSnap.thermalState.rawValue), Fans: \(thermalSnap.fans.count)")
assertTrue(thermalSnap.socTemperature != nil, "Thermal SoC temperature sampled")

// 9. SystemEngine test (F3)
let sys = SystemEngine.shared
let sysSnap = sys.sample()
print("Chip: \(sysSnap.chipName), Model: \(sysSnap.modelName), OS: \(sysSnap.osVersion), Uptime: \(Formatters.uptime(sysSnap.uptimeSeconds))")
assertTrue(!sysSnap.chipName.isEmpty, "Chip name detected")
assertTrue(sysSnap.uptimeSeconds > 0, "System uptime positive")

// 10. ProcessEngine test (F3)
let proc = ProcessEngine.shared
_ = proc.sampleTopProcesses(limit: 5)
Thread.sleep(forTimeInterval: 0.2)
let topProcs = proc.sampleTopProcesses(limit: 5)
print("Top Processes sampled: \(topProcs.count)")
for p in topProcs {
    print(" - [PID \(p.pid)] \(p.name): CPU \(Formatters.percentage(p.cpuPercentage)), RAM \(Formatters.bytes(p.memoryBytes))")
}
assertTrue(!topProcs.isEmpty, "Top processes identified")

// 11. SharedSnapshotStore test
let store = SharedSnapshotStore.shared
var snap = SystemSnapshot()
snap.cpu.totalUsage = 37.5
snap.memory.usedBytes = 16 * 1024 * 1024 * 1024
store.save(snap)
let loaded = store.load()!
assertTrue(abs(loaded.cpu.totalUsage - 37.5) < 0.001, "Snapshot saved and reloaded CPU correctly")
assertTrue(loaded.memory.usedBytes == 16 * 1024 * 1024 * 1024, "Snapshot saved and reloaded RAM correctly")

// 12. Formatters caching test
assertTrue(Formatters.bytes(1024 * 1024) == "1 MB", "Formatters.bytes formats 1 MB correctly")
assertTrue(Formatters.speed(1024 * 1024 * 5) == "5.00 MB/s", "Formatters.speed formats MB/s correctly")
assertTrue(!Formatters.dateStamp().isEmpty, "Formatters.dateStamp generates non-empty timestamp")

// 13. Settings Persistence test
let d = UserDefaults.standard
d.set(5.0, forKey: "samplingIntervalSetting")
d.set(250.0, forKey: "monthlyQuotaGBSetting")
d.set(95.0, forKey: "cpuAlertThreshold")
d.set(false, forKey: "alertsEnabled")

assertTrue(d.double(forKey: "samplingIntervalSetting") == 5.0, "Settings samplingIntervalSetting persists")
assertTrue(d.double(forKey: "monthlyQuotaGBSetting") == 250.0, "Settings monthlyQuotaGBSetting persists")
assertTrue(d.double(forKey: "cpuAlertThreshold") == 95.0, "Settings cpuAlertThreshold persists")
assertTrue(d.bool(forKey: "alertsEnabled") == false, "Settings alertsEnabled persists")

// Restore default settings
d.set(2.0, forKey: "samplingIntervalSetting")
d.set(100.0, forKey: "monthlyQuotaGBSetting")
d.set(90.0, forKey: "cpuAlertThreshold")
d.set(true, forKey: "alertsEnabled")

print("🎉 ALL PULSE ENGINE, FORMATTER, AND SETTINGS TESTS PASSED SUCCESSFULLY!")
