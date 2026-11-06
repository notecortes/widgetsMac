import WidgetKit
import SwiftUI
// import PulseCore

public struct ThermalFansWidget: Widget {
    public let kind: String = "com.pulse.widget.thermalfans"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseTimelineProvider()) { entry in
            WidgetContainerView(snapshot: entry.snapshot) { snapshot in
                ThermalFansWidgetView(snapshot: snapshot.thermal)
            }
        }
        .configurationDisplayName("Térmica y Ventiladores")
        .description("Temperatura del SoC, presión térmica y revoluciones por minuto.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

public struct ThermalFansWidgetView: View {
    @Environment(\.widgetFamily) var family
    public let snapshot: ThermalSnapshot

    private var thermalColor: Color {
        guard let t = snapshot.socTemperature else { return .green }
        if t >= 85.0 {
            return .red
        } else if t >= 70.0 {
            return .orange
        } else {
            return .green
        }
    }

    public var body: some View {
        if family == .systemSmall {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("Térmica", systemImage: "flame.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(thermalColor)
                    Spacer()
                    Text(snapshot.thermalState.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(thermalColor)
                }

                Spacer()

                Text(Formatters.temperature(snapshot.socTemperature))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(thermalColor)

                Spacer()

                if let firstFan = snapshot.fans.first {
                    HStack {
                        Image(systemName: "fan.fill")
                            .font(.system(size: 9))
                        Text(Formatters.rpm(firstFan.currentRPM))
                            .font(.system(size: 9, weight: .semibold))
                            .monospacedDigit()
                    }
                    .foregroundColor(.secondary)
                } else {
                    Text("Refrigeración pasiva")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
        } else {
            // Medium
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Temperatura", systemImage: "flame.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(thermalColor)

                    Text(Formatters.temperature(snapshot.socTemperature))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(thermalColor)

                    Text("Estado: \(snapshot.thermalState.rawValue)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(width: 120, alignment: .leading)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("VENTILADORES")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)

                    if snapshot.fans.isEmpty {
                        Text("Equipo en refrigeración pasiva (0 RPM)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(snapshot.fans) { fan in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(fan.name)
                                        .font(.system(size: 10, weight: .medium))
                                    Spacer()
                                    Text(Formatters.rpm(fan.currentRPM))
                                        .font(.system(size: 10, weight: .bold))
                                        .monospacedDigit()
                                }

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.gray.opacity(0.18)).frame(height: 5)
                                        Capsule()
                                            .fill(Color.blue)
                                            .frame(width: max(2, geo.size.width * CGFloat(fan.percentage / 100.0)), height: 5)
                                    }
                                }
                                .frame(height: 5)
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
    }
}
