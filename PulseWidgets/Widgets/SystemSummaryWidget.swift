import WidgetKit
import SwiftUI
// import PulseCore

public struct SystemSummaryWidget: Widget {
    public let kind: String = "com.pulse.widget.systemsummary"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseTimelineProvider()) { entry in
            WidgetContainerView(snapshot: entry.snapshot) { snapshot in
                SystemSummaryWidgetView(snapshot: snapshot)
            }
        }
        .configurationDisplayName("Resumen del Sistema")
        .description("Panel general con CPU, Memoria, Disco, Red y Batería al estilo Usage.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

public struct SystemSummaryWidgetView: View {
    @Environment(\.widgetFamily) var family
    public let snapshot: SystemSnapshot

    public var body: some View {
        if family == .systemSmall {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Label {
                        Text(Formatters.percentageInteger(snapshot.cpu.totalUsage))
                            .font(.system(size: 11, weight: .bold))
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "cpu")
                            .foregroundColor(.blue)
                    }
                    Spacer()
                    Label {
                        Text(Formatters.percentageInteger(snapshot.memory.usedPercentage))
                            .font(.system(size: 11, weight: .bold))
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "memorychip")
                            .foregroundColor(.purple)
                    }
                }
                .font(.system(size: 10))

                Divider().opacity(0.3)

                HStack(spacing: 8) {
                    let firstVol = snapshot.disk.volumes.first
                    Label {
                        Text(Formatters.percentageInteger(firstVol?.usedPercentage ?? 0))
                            .font(.system(size: 11, weight: .bold))
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "internaldrive")
                            .foregroundColor(.orange)
                    }
                    Spacer()
                    if snapshot.battery.hasBattery {
                        Label {
                            Text(Formatters.percentageInteger(snapshot.battery.percentage))
                                .font(.system(size: 11, weight: .bold))
                                .monospacedDigit()
                        } icon: {
                            Image(systemName: snapshot.battery.isCharging ? "battery.100.bolt" : "battery.100")
                                .foregroundColor(snapshot.battery.percentage <= 20 ? .red : .green)
                        }
                    } else {
                        Label {
                            Text(Formatters.speed(snapshot.network.downloadSpeedBytesPerSec))
                                .font(.system(size: 10, weight: .bold))
                                .monospacedDigit()
                        } icon: {
                            Image(systemName: "arrow.down")
                                .foregroundColor(.green)
                        }
                    }
                }
                .font(.system(size: 10))
            }
            .padding(10)
        } else if family == .systemMedium {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    SummaryMiniCard(
                        icon: "cpu",
                        title: "CPU",
                        value: Formatters.percentageInteger(snapshot.cpu.totalUsage),
                        progress: snapshot.cpu.totalUsage,
                        color: Color.blue
                    )

                    SummaryMiniCard(
                        icon: "memorychip",
                        title: "RAM",
                        value: Formatters.percentageInteger(snapshot.memory.usedPercentage),
                        progress: snapshot.memory.usedPercentage,
                        color: Color.purple
                    )

                    let firstVol = snapshot.disk.volumes.first
                    SummaryMiniCard(
                        icon: "internaldrive",
                        title: "Disco",
                        value: Formatters.percentageInteger(firstVol?.usedPercentage ?? 0),
                        progress: firstVol?.usedPercentage ?? 0,
                        color: Color.orange
                    )
                }

                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "network")
                            .font(.system(size: 11))
                            .foregroundColor(Color.green)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("↓ \(Formatters.speed(snapshot.network.downloadSpeedBytesPerSec))")
                                .font(.system(size: 10, weight: .bold))
                                .monospacedDigit()
                            Text("↑ \(Formatters.speed(snapshot.network.uploadSpeedBytesPerSec))")
                                .font(.system(size: 9))
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))

                    if snapshot.battery.hasBattery {
                        HStack(spacing: 6) {
                            Image(systemName: snapshot.battery.isCharging ? "battery.100.bolt" : "battery.100")
                                .font(.system(size: 13))
                                .foregroundColor(snapshot.battery.percentage <= 20 ? .red : .green)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(Formatters.percentageInteger(snapshot.battery.percentage))
                                    .font(.system(size: 11, weight: .bold))
                                    .monospacedDigit()
                                Text(snapshot.battery.isCharging ? "Cargando" : (snapshot.battery.powerDrawWatts != nil ? Formatters.watts(snapshot.battery.powerDrawWatts) : "Batería"))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                    }
                }
            }
            .padding(12)
        } else {
            // Large Widget
            VStack(alignment: .leading, spacing: 12) {
                // Header Chip & Uptime
                HStack {
                    Label(snapshot.system.chipName, systemImage: "apple.logo")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    Text("Activo: \(Formatters.uptime(snapshot.system.uptimeSeconds))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Divider()

                // Row Items in Usage Style
                WidgetUsageRow(icon: "cpu", label: "CPU", value: Formatters.percentage(snapshot.cpu.totalUsage), progress: snapshot.cpu.totalUsage, color: Color.blue)
                WidgetUsageRow(icon: "memorychip", label: "Memoria RAM", value: "\(Formatters.bytes(snapshot.memory.usedBytes)) / \(Formatters.bytes(snapshot.memory.totalBytes))", progress: snapshot.memory.usedPercentage, color: Color.purple)

                if let vol = snapshot.disk.volumes.first {
                    WidgetUsageRow(icon: "internaldrive", label: "Disco (\(vol.name))", value: "\(Formatters.fileBytes(vol.usedBytes)) / \(Formatters.fileBytes(vol.totalBytes))", progress: vol.usedPercentage, color: Color.orange)
                }

                WidgetUsageRow(icon: "arrow.down.circle", label: "Descarga de Red", value: Formatters.speed(snapshot.network.downloadSpeedBytesPerSec), progress: nil, color: Color.green)
                WidgetUsageRow(icon: "arrow.up.circle", label: "Subida de Red", value: Formatters.speed(snapshot.network.uploadSpeedBytesPerSec), progress: nil, color: Color.cyan)

                if snapshot.battery.hasBattery {
                    WidgetUsageRow(icon: snapshot.battery.isCharging ? "battery.100.bolt" : "battery.100", label: "Batería", value: Formatters.percentageInteger(snapshot.battery.percentage), progress: snapshot.battery.percentage, color: snapshot.battery.percentage <= 20 ? Color.red : Color.green)
                }

                if let temp = snapshot.thermal.socTemperature {
                    WidgetUsageRow(icon: "thermometer.medium", label: "Temperatura SoC", value: Formatters.temperature(temp), progress: nil, color: Color.red)
                }
            }
            .padding(14)
        }
    }
}

private struct SummaryMiniCard: View {
    let icon: String
    let title: String
    let value: String
    let progress: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.18)).frame(height: 4)
                    Capsule()
                        .fill(color)
                        .frame(width: max(2, geo.size.width * CGFloat(min(1.0, progress / 100.0))), height: 4)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
    }
}

private struct WidgetUsageRow: View {
    let icon: String
    let label: String
    let value: String
    let progress: Double?
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 11, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if let p = progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(color.opacity(0.18)).frame(height: 5)
                        Capsule()
                            .fill(color)
                            .frame(width: max(3, geo.size.width * CGFloat(min(1.0, p / 100.0))), height: 5)
                    }
                }
                .frame(width: 55, height: 5)
            }
        }
    }
}
