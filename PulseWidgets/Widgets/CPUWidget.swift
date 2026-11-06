import WidgetKit
import SwiftUI
import Charts
// import PulseCore

public struct CPUWidget: Widget {
    public let kind: String = "com.pulse.widget.cpu"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseTimelineProvider()) { entry in
            WidgetContainerView(snapshot: entry.snapshot) { snapshot in
                CPUWidgetView(snapshot: snapshot.cpu)
            }
        }
        .configurationDisplayName("Procesador CPU")
        .description("Carga total del procesador, desglose P/E y temperatura.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

public struct CPUWidgetView: View {
    @Environment(\.widgetFamily) var family
    public let snapshot: CPUSnapshot

    public var body: some View {
        if family == .systemSmall {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("CPU", systemImage: "cpu")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.blue)
                    Spacer()
                    if let temp = snapshot.temperature {
                        Text(Formatters.temperature(temp))
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text(Formatters.percentageInteger(snapshot.totalUsage))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)

                Spacer()

                // Sparkline
                if !snapshot.history.isEmpty {
                    Chart {
                        ForEach(snapshot.history) { p in
                            LineMark(x: .value("T", p.timestamp), y: .value("V", p.value))
                                .foregroundStyle(Color.blue)
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartLegend(.hidden)
                    .frame(height: 24)
                }
            }
            .padding(10)
        } else {
            // Medium
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("CPU", systemImage: "cpu")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.blue)
                        Spacer()
                    }

                    Text(Formatters.percentageInteger(snapshot.totalUsage))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    if let temp = snapshot.temperature {
                        Text("Temperatura: \(Formatters.temperature(temp))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Text("P-Cores: \(snapshot.performanceCoreUsages.count) · E-Cores: \(snapshot.efficiencyCoreUsages.count)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .frame(width: 120, alignment: .leading)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Actividad de Núcleos")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)

                    if !snapshot.coreUsages.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: min(6, snapshot.coreUsages.count)), spacing: 4) {
                            ForEach(Array(snapshot.coreUsages.prefix(12).enumerated()), id: \.offset) { _, load in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.blue.opacity(0.2 + (load / 100.0) * 0.8))
                                    .frame(height: 14)
                            }
                        }
                    }

                    if !snapshot.history.isEmpty {
                        Chart {
                            ForEach(snapshot.history) { p in
                                AreaMark(x: .value("T", p.timestamp), y: .value("V", p.value))
                                    .foregroundStyle(Color.blue.opacity(0.25))
                                LineMark(x: .value("T", p.timestamp), y: .value("V", p.value))
                                    .foregroundStyle(Color.blue)
                            }
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .chartLegend(.hidden)
                        .frame(height: 28)
                    }
                }
            }
            .padding(12)
        }
    }
}
