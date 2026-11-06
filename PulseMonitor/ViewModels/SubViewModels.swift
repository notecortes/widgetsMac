import SwiftUI
import Combine
import AppKit
// import PulseCore

@MainActor
public final class HeaderViewModel: ObservableObject {
    @Published public var systemInfo: SystemInfoSnapshot
    @Published public var network: NetworkSnapshot
    @Published public var wifi: WiFiSnapshot
    @Published public var calendar: CalendarSnapshot
    @Published public var copiedNotice: String?

    public init(
        systemInfo: SystemInfoSnapshot = SystemInfoSnapshot(),
        network: NetworkSnapshot = NetworkSnapshot(),
        wifi: WiFiSnapshot = WiFiSnapshot(),
        calendar: CalendarSnapshot = CalendarSnapshot()
    ) {
        self.systemInfo = systemInfo
        self.network = network
        self.wifi = wifi
        self.calendar = calendar
    }

    public func update(
        system: SystemInfoSnapshot,
        network: NetworkSnapshot,
        wifi: WiFiSnapshot,
        calendar: CalendarSnapshot
    ) {
        self.systemInfo = system
        self.network = network
        self.wifi = wifi
        self.calendar = calendar
    }

    public func copyToClipboard(_ text: String, label: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        withAnimation {
            self.copiedNotice = label
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            withAnimation {
                self?.copiedNotice = nil
            }
        }
    }
}

@MainActor
public final class FooterViewModel: ObservableObject {
    @Published public var isMonitoringPaused: Bool = false
    @Published public var showFloatingHUD: Bool = false

    public init() {}
}

@MainActor
public final class SummaryViewModel: ObservableObject {
    @Published public var snapshot: SystemSnapshot

    public init(snapshot: SystemSnapshot = .preview) {
        self.snapshot = snapshot
    }
}

@MainActor
public final class CPUViewModel: ObservableObject {
    @Published public var snapshot: CPUSnapshot

    public init(snapshot: CPUSnapshot = CPUSnapshot()) {
        self.snapshot = snapshot
    }
}

@MainActor
public final class GPUViewModel: ObservableObject {
    @Published public var snapshot: GPUSnapshot

    public init(snapshot: GPUSnapshot = GPUSnapshot()) {
        self.snapshot = snapshot
    }
}

@MainActor
public final class MemoryViewModel: ObservableObject {
    @Published public var snapshot: MemorySnapshot

    public init(snapshot: MemorySnapshot = MemorySnapshot()) {
        self.snapshot = snapshot
    }
}

@MainActor
public final class DiskViewModel: ObservableObject {
    @Published public var snapshot: DiskSnapshot

    public init(snapshot: DiskSnapshot = DiskSnapshot()) {
        self.snapshot = snapshot
    }
}

@MainActor
public final class NetworkViewModel: ObservableObject {
    @Published public var snapshot: NetworkSnapshot

    public init(snapshot: NetworkSnapshot = NetworkSnapshot()) {
        self.snapshot = snapshot
    }
}

@MainActor
public final class BatteryViewModel: ObservableObject {
    @Published public var snapshot: BatterySnapshot

    public init(snapshot: BatterySnapshot = BatterySnapshot()) {
        self.snapshot = snapshot
    }
}

@MainActor
public final class ThermalViewModel: ObservableObject {
    @Published public var snapshot: ThermalSnapshot

    public init(snapshot: ThermalSnapshot = ThermalSnapshot()) {
        self.snapshot = snapshot
    }
}

@MainActor
public final class WeatherViewModel: ObservableObject {
    @Published public var snapshot: WeatherSnapshot

    public init(snapshot: WeatherSnapshot = WeatherSnapshot()) {
        self.snapshot = snapshot
    }
}

@MainActor
public final class CalendarViewModel: ObservableObject {
    @Published public var snapshot: CalendarSnapshot

    public init(snapshot: CalendarSnapshot = CalendarSnapshot()) {
        self.snapshot = snapshot
    }
}

@MainActor
public final class ProcessesViewModel: ObservableObject {
    @Published public var processes: [ProcessItem] = []
    @Published public var searchText: String = ""
    @Published public var sortByCPU: Bool = true
    @Published public var processToTerminate: ProcessItem? = nil
    @Published public var showConfirmDialog: Bool = false

    public init() {}

    public var filteredProcesses: [ProcessItem] {
        var list = processes
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }
        if sortByCPU {
            list.sort { $0.cpuPercentage > $1.cpuPercentage }
        } else {
            list.sort { $0.memoryBytes > $1.memoryBytes }
        }
        return list
    }
}
