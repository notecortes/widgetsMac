import SwiftUI
import Combine
import WidgetKit
import PulseCore

@MainActor
public final class SystemMonitor: ObservableObject {
    public static let shared = SystemMonitor()

    @Published public var snapshot: SystemSnapshot = SystemSnapshot.preview
    @Published public var isMonitoringPaused: Bool = false
    @Published public var showFloatingHUD: Bool = false
    @Published public var samplingInterval: TimeInterval = 2.0

    // Granular sub-viewmodels to prevent monolithic re-renders
    public let headerVM = HeaderViewModel()
    public let footerVM = FooterViewModel()
    public let summaryVM = SummaryViewModel()
    public let cpuVM = CPUViewModel()
    public let gpuVM = GPUViewModel()
    public let memoryVM = MemoryViewModel()
    public let diskVM = DiskViewModel()
    public let networkVM = NetworkViewModel()
    public let batteryVM = BatteryViewModel()
    public let thermalVM = ThermalViewModel()
    public let weatherVM = WeatherViewModel()
    public let calendarVM = CalendarViewModel()
    public let processesVM = ProcessesViewModel()

    // UI View State (centralized for MVVM and macro-free compilation)
    @Published public var selectedTab: SectionTab = .summary
    @Published public var showSettingsSheet: Bool = false
    @Published public var copiedNotice: String? = nil
    @Published public var processSearchText: String = ""
    @Published public var processSortByCPU: Bool = true
    @Published public var processToTerminate: ProcessItem? = nil
    @Published public var showProcessConfirmDialog: Bool = false

    // Direct published properties for HudView and MenuBar Extra
    @Published public var cpuUsage: Double = 0.0
    @Published public var memoryUsedGB: Double = 0.0
    @Published public var memoryTotalGB: Double = 0.0
    @Published public var downloadSpeedFormatted: String = "0 B/s"
    @Published public var batteryPercent: Double? = nil
    @Published public var socTemperature: Double? = nil

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.pulse.sampling", qos: .utility)
    private let sampler = SystemSampler()
    private var lastWidgetReloadTime: Date = .distantPast

    private init() {
        self.cpuUsage = self.snapshot.cpu.totalUsage
        self.memoryUsedGB = Double(self.snapshot.memory.usedBytes) / (1024.0 * 1024.0 * 1024.0)
        self.memoryTotalGB = Double(self.snapshot.memory.totalBytes) / (1024.0 * 1024.0 * 1024.0)
        self.downloadSpeedFormatted = Formatters.speed(self.snapshot.network.downloadSpeedBytesPerSec)
        self.batteryPercent = self.snapshot.battery.hasBattery ? self.snapshot.battery.percentage : nil
        self.socTemperature = self.snapshot.thermal.socTemperature

        // Write initial snapshot so widgets have immediate data
        SharedSnapshotStore.shared.save(self.snapshot)
        let initPath = SharedSnapshotStore.shared.storageFileURL.path
        uiLog.info("[TEST] 📄 snapshot.json inicial guardado en: \(initPath, privacy: .public)")
        startMonitoring()
        setupPowerModeObserver()
    }

    public func startMonitoring() {
        stopMonitoring()

        let interval = samplingInterval
        self.timer = sampler.startTimer(queue: queue, interval: interval) { [weak self] sampleData in
            Task { @MainActor [weak self] in
                self?.applySample(sampleData)
            }
        }
    }

    public func stopMonitoring() {
        timer?.cancel()
        timer = nil
    }

    public func updateSamplingInterval(_ newInterval: TimeInterval) {
        self.samplingInterval = max(1.0, newInterval)
        startMonitoring()
    }

    private func setupPowerModeObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if ProcessInfo.processInfo.isLowPowerModeEnabled {
                    self.updateSamplingInterval(5.0)
                } else {
                    let saved = UserDefaults.standard.double(forKey: "samplingIntervalSetting")
                    self.updateSamplingInterval(saved > 0 ? saved : 2.0)
                }
            }
        }
    }

    private func applySample(_ sample: SystemSampler.SampleData) {
        guard !isMonitoringPaused else { return }

        if sample.shouldSampleWeather {
            Task {
                let w = await WeatherEngine.shared.sample()
                self.snapshot.weather = w
            }
        }

        if sample.shouldSampleCalendar {
            Task {
                let c = await CalendarEngine.shared.sample()
                self.snapshot.calendar = c
            }
        }

        var updated = self.snapshot
        updated.timestamp = Date()
        updated.cpu = sample.cpu
        updated.memory = sample.mem
        updated.disk = sample.disk
        updated.network = sample.net
        updated.battery = sample.batt
        updated.gpu = sample.gpu
        updated.thermal = sample.thermal
        updated.system = sample.sys
        updated.wifi = sample.wifi

        if let procs = sample.topProcs {
            updated.topProcesses = procs
        }

        self.snapshot = updated
        self.cpuUsage = sample.cpu.totalUsage
        self.memoryUsedGB = Double(sample.mem.usedBytes) / (1024.0 * 1024.0 * 1024.0)
        self.memoryTotalGB = Double(sample.mem.totalBytes) / (1024.0 * 1024.0 * 1024.0)
        self.downloadSpeedFormatted = Formatters.speed(sample.net.downloadSpeedBytesPerSec)
        self.batteryPercent = sample.batt.hasBattery ? sample.batt.percentage : nil
        self.socTemperature = sample.thermal.socTemperature

        // Update granular sub-viewmodels
        headerVM.update(
            system: sample.sys,
            network: sample.net,
            wifi: sample.wifi,
            calendar: self.snapshot.calendar
        )
        summaryVM.snapshot = updated
        cpuVM.snapshot = sample.cpu
        gpuVM.snapshot = sample.gpu
        memoryVM.snapshot = sample.mem
        diskVM.snapshot = sample.disk
        networkVM.snapshot = sample.net
        batteryVM.snapshot = sample.batt
        thermalVM.snapshot = sample.thermal
        if let procs = sample.topProcs {
            processesVM.processes = procs
        }

        // Evaluate Alerts
        AlertEngine.shared.evaluate(snapshot: updated)

        // Record into History
        HistoryStore.shared.record(snapshot: updated)

        // Write snapshot.json to App Group in each sampling cycle for Widgets to read
        SharedSnapshotStore.shared.save(updated)
        let snapshotPath = SharedSnapshotStore.shared.storageFileURL.path
        uiLog.info("[TEST] 📄 snapshot.json guardado en: \(snapshotPath, privacy: .public)")

        // Reload WidgetKit timelines with throttle (maximum 1 call every 10 seconds)
        let now = Date()
        if now.timeIntervalSince(lastWidgetReloadTime) >= 10.0 {
            lastWidgetReloadTime = now
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    public func refreshWeather() async {
        let w = await WeatherEngine.shared.sample(forceRefresh: true)
        self.snapshot.weather = w
        self.weatherVM.snapshot = w
        SharedSnapshotStore.shared.save(self.snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    public func terminateProcess(pid: Int32) {
        ProcessEngine.shared.terminateProcess(pid: pid)
        // Refresh processes immediately
        let procs = ProcessEngine.shared.sampleTopProcesses(limit: 10)
        self.snapshot.topProcesses = procs
        self.processesVM.processes = procs
    }

    public func toggleFloatingHUD() {
        showFloatingHUD.toggle()
        footerVM.showFloatingHUD = showFloatingHUD
        AppDelegate.shared?.toggleHUD()
    }

    public func toggleMonitoringPause() {
        isMonitoringPaused.toggle()
        footerVM.isMonitoringPaused = isMonitoringPaused
    }

    public func generateHistoryCSV() -> String {
        HistoryStore.shared.exportCSV()
    }

    public func generateHistoryJSON() -> String {
        HistoryStore.shared.exportJSON()
    }
}

// MARK: - Background Hardware Sampler with Staggered Cadence

private final class SystemSampler: @unchecked Sendable {
    private var processCounter: Int = 0
    private var weatherCounter: Int = 0
    private var calendarCounter: Int = 0
    private var diskCounter: Int = 0
    private var batteryCounter: Int = 0
    private var thermalCounter: Int = 0
    private var systemCounter: Int = 0
    private var wifiCounter: Int = 0

    private var cachedDisk: DiskSnapshot = DiskSnapshot()
    private var cachedBattery: BatterySnapshot = BatterySnapshot()
    private var cachedThermal: ThermalSnapshot = ThermalSnapshot()
    private var cachedSystem: SystemInfoSnapshot = SystemInfoSnapshot()
    private var cachedWiFi: WiFiSnapshot = WiFiSnapshot()
    private var hasInitialSample: Bool = false

    struct SampleData: Sendable {
        let cpu: CPUSnapshot
        let mem: MemorySnapshot
        let disk: DiskSnapshot
        let net: NetworkSnapshot
        let batt: BatterySnapshot
        let gpu: GPUSnapshot
        let thermal: ThermalSnapshot
        let sys: SystemInfoSnapshot
        let wifi: WiFiSnapshot
        let topProcs: [ProcessItem]?
        let shouldSampleWeather: Bool
        let shouldSampleCalendar: Bool
    }

    func startTimer(
        queue: DispatchQueue,
        interval: TimeInterval,
        handler: @escaping @Sendable (SampleData) -> Void
    ) -> DispatchSourceTimer {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        // Coalescing leeway (250ms) to conserve Mac battery
        timer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(250))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            let data = self.sample(samplingInterval: interval)
            handler(data)
        }
        timer.resume()
        return timer
    }

    func sample(samplingInterval: TimeInterval) -> SampleData {
        let quotaGB = UserDefaults.standard.double(forKey: "monthlyQuotaGBSetting")
        let quotaBytes = quotaGB > 0 ? UInt64(quotaGB * 1024 * 1024 * 1024) : nil

        // 1. High-frequency live metrics (every tick ~2s)
        let cpu = CPUEngine.shared.sample()
        let mem = MemoryEngine.shared.sample()
        let net = NetworkEngine.shared.sample(monthlyQuotaBytes: quotaBytes)
        let gpu = GPUEngine.shared.sample()

        // 2. Staggered hardware queries (10s - 30s) to guarantee CPU < 1% in background
        diskCounter += 1
        if !hasInitialSample || diskCounter >= max(1, Int(10.0 / samplingInterval)) {
            diskCounter = 0
            cachedDisk = DiskEngine.shared.sample()
        }

        batteryCounter += 1
        if !hasInitialSample || batteryCounter >= max(1, Int(10.0 / samplingInterval)) {
            batteryCounter = 0
            cachedBattery = BatteryEngine.shared.sample()
        }

        thermalCounter += 1
        if !hasInitialSample || thermalCounter >= max(1, Int(10.0 / samplingInterval)) {
            thermalCounter = 0
            cachedThermal = ThermalEngine.shared.sample()
        }

        systemCounter += 1
        if !hasInitialSample || systemCounter >= max(1, Int(30.0 / samplingInterval)) {
            systemCounter = 0
            cachedSystem = SystemEngine.shared.sample()
        }

        wifiCounter += 1
        if !hasInitialSample || wifiCounter >= max(1, Int(15.0 / samplingInterval)) {
            wifiCounter = 0
            cachedWiFi = WiFiEngine.shared.sample()
        }

        hasInitialSample = true

        // 3. Top processes every ~5s
        processCounter += 1
        let topProcs: [ProcessItem]?
        let processThreshold = max(1, Int(5.0 / samplingInterval))
        if processCounter >= processThreshold {
            processCounter = 0
            topProcs = ProcessEngine.shared.sampleTopProcesses(limit: 10)
        } else {
            topProcs = nil
        }

        // 4. Weather (every 15 min)
        weatherCounter += 1
        let weatherThreshold = max(1, Int(900.0 / samplingInterval))
        let shouldWeather = weatherCounter >= weatherThreshold
        if shouldWeather {
            weatherCounter = 0
        }

        // 5. Calendar (every 2 min)
        calendarCounter += 1
        let calendarThreshold = max(1, Int(120.0 / samplingInterval))
        let shouldCalendar = calendarCounter >= calendarThreshold
        if shouldCalendar {
            calendarCounter = 0
        }

        return SampleData(
            cpu: cpu,
            mem: mem,
            disk: cachedDisk,
            net: net,
            batt: cachedBattery,
            gpu: gpu,
            thermal: cachedThermal,
            sys: cachedSystem,
            wifi: cachedWiFi,
            topProcs: topProcs,
            shouldSampleWeather: shouldWeather,
            shouldSampleCalendar: shouldCalendar
        )
    }
}
