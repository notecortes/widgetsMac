import WidgetKit
import SwiftUI
import PulseCore

public struct TopAppsWidget: Widget {
    public let kind: String = "com.pulse.widget.topapps"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseTimelineProvider()) { entry in
            WidgetContainerView(snapshot: entry.snapshot) { snapshot in
                TopAppsWidgetView(snapshot: snapshot)
            }
        }
        .configurationDisplayName("Top Apps y Procesos")
        .description("Las aplicaciones que más recursos de CPU y RAM consumen en este momento.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

public struct TopAppsWidgetView: View {
    @Environment(\.widgetFamily) var family
    public let snapshot: SystemSnapshot

    public var body: some View {
        let procs = snapshot.topProcesses

        if family == .systemSmall {
            VStack(alignment: .leading, spacing: 5) {
                Label("Top Apps", systemImage: "list.bullet.rectangle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.accentColor)

                Spacer()

                if procs.isEmpty {
                    Text("Sin datos")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(procs.prefix(3)) { p in
                        HStack(spacing: 4) {
                            Text(p.name)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text(Formatters.percentageInteger(p.cpuPercentage))
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(p.cpuPercentage > 20 ? .orange : .secondary)
                        }
                    }
                }
                Spacer()
            }
            .padding(10)
        } else {
            // Medium
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Aplicaciones Principales", systemImage: "list.bullet.rectangle")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.accentColor)
                    Spacer()
                    Text("CPU · RAM")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                if procs.isEmpty {
                    Text("No hay procesos disponibles")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(procs.prefix(4)) { p in
                        HStack(spacing: 8) {
                            Text(p.name.prefix(1).uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .frame(width: 16, height: 16)
                                .background(Circle().fill(Color.white.opacity(0.1)))

                            Text(p.name)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)

                            Spacer()

                            Text(Formatters.percentage(p.cpuPercentage))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(p.cpuPercentage > 30 ? .orange : .primary)
                                .frame(width: 45, alignment: .trailing)

                            Text(Formatters.bytes(p.memoryBytes))
                                .font(.system(size: 10, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                                .frame(width: 55, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(12)
        }
    }
}
