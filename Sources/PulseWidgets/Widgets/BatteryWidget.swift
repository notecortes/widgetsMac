import WidgetKit
import SwiftUI
import PulseCore

public struct BatteryWidget: Widget {
    public let kind: String = "com.pulse.widget.battery"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseTimelineProvider()) { entry in
            WidgetContainerView(snapshot: entry.snapshot) { snapshot in
                BatteryWidgetView(snapshot: snapshot.battery)
            }
        }
        .configurationDisplayName("Batería y Energía")
        .description("Nivel de batería, vatios de potencia, ciclos y tiempo restante.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

public struct BatteryWidgetView: View {
    @Environment(\.widgetFamily) var family
    public let snapshot: BatterySnapshot

    private var dynamicColor: Color {
        if snapshot.isCharging {
            return .green
        }
        if snapshot.percentage <= 15.0 {
            return .red
        } else if snapshot.percentage <= 30.0 {
            return .orange
        } else {
            return .green
        }
    }

    public var body: some View {
        if !snapshot.hasBattery {
            VStack(spacing: 6) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                Text("Alimentación CA")
                    .font(.system(size: 11, weight: .semibold))
                Text("Sin batería")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(10)
        } else if family == .systemSmall {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("Batería", systemImage: snapshot.isCharging ? "battery.100.bolt" : "battery.100")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(dynamicColor)
                    Spacer()
                    if let watts = snapshot.powerDrawWatts {
                        Text(Formatters.watts(watts))
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(snapshot.isCharging ? .green : .primary)
                    }
                }

                Spacer()

                Text(Formatters.percentageInteger(snapshot.percentage))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(dynamicColor)

                Spacer()

                if let mins = snapshot.timeRemainingMinutes {
                    Text(snapshot.isCharging ? "Carga completa en \(mins / 60)h \(mins % 60)m" : "Restante: \(mins / 60)h \(mins % 60)m")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
        } else {
            // Medium
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Label(snapshot.isCharging ? "Cargando" : "Batería", systemImage: snapshot.isCharging ? "battery.100.bolt" : "battery.100")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(dynamicColor)
                    }

                    Text(Formatters.percentageInteger(snapshot.percentage))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(dynamicColor)

                    if let watts = snapshot.powerDrawWatts {
                        Text("Potencia: \(Formatters.watts(watts))")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(snapshot.isCharging ? .green : .secondary)
                    }
                }
                .frame(width: 120, alignment: .leading)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    if let mins = snapshot.timeRemainingMinutes {
                        HStack {
                            Text(snapshot.isCharging ? "Para completar:" : "Tiempo restante:")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(mins / 60)h \(mins % 60)m")
                                .font(.system(size: 10, weight: .semibold))
                                .monospacedDigit()
                        }
                    }

                    if let health = snapshot.healthPercentage {
                        HStack {
                            Text("Salud de la batería:")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(Formatters.percentage(health))
                                .font(.system(size: 10, weight: .semibold))
                                .monospacedDigit()
                        }
                    }

                    if let cycles = snapshot.cycleCount {
                        HStack {
                            Text("Ciclos:")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(cycles)")
                                .font(.system(size: 10, weight: .semibold))
                                .monospacedDigit()
                        }
                    }
                }
            }
            .padding(12)
        }
    }
}
