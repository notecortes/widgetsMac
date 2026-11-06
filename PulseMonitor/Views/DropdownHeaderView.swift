import SwiftUI
import AppKit
// import PulseCore

public struct DropdownHeaderView: View {
    @ObservedObject public var viewModel: HeaderViewModel
    public var onOpenSettings: (() -> Void)? = nil

    public init(viewModel: HeaderViewModel, onOpenSettings: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onOpenSettings = onOpenSettings
    }

    public init(monitor: SystemMonitor, onOpenSettings: (() -> Void)? = nil) {
        self.viewModel = monitor.headerVM
        self.onOpenSettings = onOpenSettings
    }

    private var systemInfo: SystemInfoSnapshot { viewModel.systemInfo }
    private var network: NetworkSnapshot { viewModel.network }
    private var wifi: WiFiSnapshot { viewModel.wifi }
    private var calendar: CalendarSnapshot { viewModel.calendar }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Hardware Info Header
            HStack(alignment: .top) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 22))
                    .foregroundColor(.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(systemInfo.chipName)
                        .font(.system(size: 14, weight: .bold))
                    Text("\(systemInfo.modelName) · \(Formatters.bytes(systemInfo.totalRAM)) · \(systemInfo.osVersion)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    uiLog.info("[TEST] ⚙️ Botón Ajustes pulsado en cabecera")
                    AppDelegate.shared?.openSettings()
                    onOpenSettings?()
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Ajustes de Pulse Monitor (⌘,)")
            }

            // Uptime and Load Average Row
            HStack(spacing: 14) {
                Label("Activo: \(Formatters.uptime(systemInfo.uptimeSeconds))", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                let loads = systemInfo.loadAverages
                let loadStr = loads.count == 3 ? String(format: "%.2f  %.2f  %.2f", loads[0], loads[1], loads[2]) : "0.00"
                Label("Carga: \(loadStr)", systemImage: "chart.bar.xaxis")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }

            Divider().opacity(0.4)

            // Quick Actions Bar
            HStack(spacing: 8) {
                // Copy IP Button
                QuickActionButton(
                    icon: "network",
                    title: network.localIPv4 ?? "IP",
                    action: {
                        if let ip = network.localIPv4 {
                            PulseLog.ui.info("📋 Copiar IP pulsado: \(ip)")
                            viewModel.copyToClipboard(ip, label: "IP copiada")
                        }
                    }
                )

                // Copy SSID Button
                if let ssid = wifi.ssid {
                    QuickActionButton(
                        icon: "wifi",
                        title: ssid,
                        action: {
                            PulseLog.ui.info("📶 Copiar SSID pulsado: \(ssid)")
                            viewModel.copyToClipboard(ssid, label: "SSID copiado")
                        }
                    )
                }

                // Activity Monitor
                QuickActionButton(
                    icon: "waveform.path.ecg",
                    title: "Monitor",
                    action: {
                        PulseLog.ui.info("📈 Abrir Monitor de Actividad pulsado")
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
                    }
                )

                // Quick Join Meeting if available
                if let meeting = calendar.nextMeetingURL {
                    QuickActionButton(
                        icon: "video.fill",
                        title: "Reunión",
                        isHighlighted: true,
                        action: {
                            PulseLog.ui.info("🎥 Unirse a reunión pulsado: \(meeting)")
                            if let url = URL(string: meeting) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    )
                }
            }

            if let notice = viewModel.copiedNotice {
                Text(notice)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.green)
                    .transition(.opacity)
            }
        }
        .liquidGlassCard()
    }
}

private struct QuickActionButton: View {
    let icon: String
    let title: String
    var isHighlighted: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHighlighted ? Color.blue : Color.white.opacity(0.08))
            )
            .foregroundColor(isHighlighted ? .white : .primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
