import SwiftUI
// import PulseCore

public enum SectionTab: String, CaseIterable, Identifiable {
    case summary = "Resumen"
    case cpu = "CPU"
    case gpu = "GPU"
    case memory = "Memoria"
    case disk = "Disco"
    case network = "Red"
    case battery = "Batería"
    case thermal = "Térmica"
    case weather = "Clima"
    case calendar = "Calendario"
    case processes = "Procesos"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .summary: return "square.grid.2x2.fill"
        case .cpu: return "cpu"
        case .gpu: return "sparkles"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .network: return "network"
        case .battery: return "battery.100"
        case .thermal: return "thermometer.medium"
        case .weather: return "sun.max.fill"
        case .calendar: return "calendar"
        case .processes: return "list.bullet.rectangle"
        }
    }
}

@MainActor
public final class TabNavigationModel: ObservableObject {
    public static let shared = TabNavigationModel()
    @Published public var selectedTab: SectionTab {
        didSet {
            UserDefaults.standard.set(selectedTab.rawValue, forKey: "lastSelectedTab")
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "lastSelectedTab"),
           let tab = SectionTab(rawValue: saved) {
            self.selectedTab = tab
        } else {
            self.selectedTab = .summary
        }
    }
}

public struct DropdownView: View {
    @ObservedObject private var nav = TabNavigationModel.shared

    public init(monitor: SystemMonitor? = nil) {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            DropdownHeaderView(
                viewModel: SystemMonitor.shared.headerVM,
                onOpenSettings: {
                    uiLog.info("[TEST] ⚙️ Botón Ajustes pulsado")
                    AppDelegate.shared?.openSettings()
                }
            )
            .padding([.top, .horizontal], 12)
            .padding(.bottom, 8)

            // Section Tabs Scroll / Picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(SectionTab.allCases) { tab in
                        Button(action: {
                            uiLog.info("[TEST] 📑 Pestaña seleccionada: \(tab.rawValue)")
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                nav.selectedTab = tab
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 11))
                                Text(tab.rawValue)
                                    .font(.system(size: 11, weight: nav.selectedTab == tab ? .bold : .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(nav.selectedTab == tab ? Color.accentColor : Color.white.opacity(0.08))
                            )
                            .foregroundColor(nav.selectedTab == tab ? .white : .primary)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Pestaña \(tab.rawValue)")
                        .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 8)

            Divider().opacity(0.3)

            // Section Content Body
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 12) {
                    switch nav.selectedTab {
                    case .summary:
                        SummarySectionView(viewModel: SystemMonitor.shared.summaryVM)
                    case .cpu:
                        CPUSectionView(viewModel: SystemMonitor.shared.cpuVM)
                    case .gpu:
                        GPUSectionView(viewModel: SystemMonitor.shared.gpuVM)
                    case .memory:
                        MemorySectionView(viewModel: SystemMonitor.shared.memoryVM)
                    case .disk:
                        DiskSectionView(viewModel: SystemMonitor.shared.diskVM)
                    case .network:
                        NetworkSectionView(viewModel: SystemMonitor.shared.networkVM)
                    case .battery:
                        BatterySectionView(viewModel: SystemMonitor.shared.batteryVM)
                    case .thermal:
                        ThermalSectionView(viewModel: SystemMonitor.shared.thermalVM)
                    case .weather:
                        WeatherSectionView(
                            viewModel: SystemMonitor.shared.weatherVM,
                            onRefresh: {
                                PulseLog.ui.info("🔄 Refrescar clima pulsado")
                                Task { await SystemMonitor.shared.refreshWeather() }
                            }
                        )
                    case .calendar:
                        CalendarSectionView(viewModel: SystemMonitor.shared.calendarVM)
                    case .processes:
                        ProcessesSectionView(viewModel: SystemMonitor.shared.processesVM)
                    }
                }
                .padding(12)
            }
            .frame(height: 280)

            Divider().opacity(0.3)

            // Footer bar
            DropdownFooterView(viewModel: SystemMonitor.shared.footerVM)
        }
        .frame(width: 380)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
        )
    }
}

private struct DropdownFooterView: View {
    @ObservedObject public var viewModel: FooterViewModel

    var body: some View {
        HStack {
            // HUD toggle
            Button(action: {
                uiLog.info("[TEST] 🪟 Botón HUD pulsado")
                AppDelegate.shared?.toggleHUD()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "macwindow")
                    Text("HUD")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            Spacer()

            // Pause / Resume monitoring
            Button(action: {
                PulseLog.ui.info("⏸️ Toggle Pausa monitorización pulsado")
                SystemMonitor.shared.toggleMonitoringPause()
            }) {
                Image(systemName: viewModel.isMonitoringPaused ? "play.circle.fill" : "pause.circle")
                    .font(.system(size: 14))
                    .foregroundColor(viewModel.isMonitoringPaused ? .orange : .secondary)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help(viewModel.isMonitoringPaused ? "Reanudar monitorización" : "Pausar monitorización")

            // Quit app
            Button(action: {
                PulseLog.ui.info("⏻ Salir de la app pulsado")
                NSApplication.shared.terminate(nil)
            }) {
                Image(systemName: "power")
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.85))
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.12)))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Salir de Pulse Monitor")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.04))
    }
}

// Summary view combining key metrics in Usage style
private struct SummarySectionView: View {
    @ObservedObject public var viewModel: SummaryViewModel

    var body: some View {
        let snapshot = viewModel.snapshot
        VStack(spacing: 8) {
            UsageRow(
                icon: "cpu",
                label: "CPU",
                value: Formatters.percentage(snapshot.cpu.totalUsage),
                color: Theme.cpu,
                progress: snapshot.cpu.totalUsage,
                sparklineData: snapshot.cpu.history
            )

            UsageRow(
                icon: "memorychip",
                label: "Memoria",
                value: Formatters.bytes(snapshot.memory.usedBytes),
                color: Theme.memory,
                progress: snapshot.memory.usedPercentage,
                sparklineData: snapshot.memory.history
            )

            if let firstVol = snapshot.disk.volumes.first {
                UsageRow(
                    icon: "internaldrive",
                    label: "Disco (\(firstVol.name))",
                    value: Formatters.percentage(firstVol.usedPercentage),
                    color: Theme.disk,
                    progress: firstVol.usedPercentage,
                    sparklineData: snapshot.disk.historyWrite
                )
            }

            UsageRow(
                icon: "arrow.down.circle",
                label: "Red Bajada",
                value: Formatters.speed(snapshot.network.downloadSpeedBytesPerSec),
                color: Theme.network,
                sparklineData: snapshot.network.historyDown
            )

            UsageRow(
                icon: "arrow.up.circle",
                label: "Red Subida",
                value: Formatters.speed(snapshot.network.uploadSpeedBytesPerSec),
                color: Theme.networkUpload,
                sparklineData: snapshot.network.historyUp
            )

            if snapshot.battery.hasBattery {
                UsageRow(
                    icon: snapshot.battery.isCharging ? "battery.100.bolt" : "battery.100",
                    label: "Batería",
                    value: "\(Formatters.percentageInteger(snapshot.battery.percentage)) \(snapshot.battery.powerDrawWatts != nil ? "(\(Formatters.watts(snapshot.battery.powerDrawWatts)))" : "")",
                    color: Theme.battery(percentage: snapshot.battery.percentage, isCharging: snapshot.battery.isCharging),
                    progress: snapshot.battery.percentage
                )
            }

            if let temp = snapshot.thermal.socTemperature {
                UsageRow(
                    icon: "thermometer.medium",
                    label: "Temperatura SoC",
                    value: Formatters.temperature(temp),
                    color: Theme.thermal(temperature: temp)
                )
            }
        }
        .liquidGlassCard()
    }
}
