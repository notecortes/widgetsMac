import WidgetKit
import SwiftUI
import Charts
import PulseCore

public struct NetworkWidget: Widget {
    public let kind: String = "com.pulse.widget.network"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseTimelineProvider()) { entry in
            WidgetContainerView(snapshot: entry.snapshot) { snapshot in
                NetworkWidgetView(snapshot: snapshot.network)
            }
        }
        .configurationDisplayName("Red y Conexión")
        .description("Velocidad de subida y bajada en tiempo real, consumo diario e IP.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

public struct NetworkWidgetView: View {
    @Environment(\.widgetFamily) var family
    public let snapshot: NetworkSnapshot

    public var body: some View {
        if family == .systemSmall {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("Red", systemImage: "network")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.green)
                    Spacer()
                    Text(snapshot.interfaceName)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 1) {
                    Text("↓ \(Formatters.speed(snapshot.downloadSpeedBytesPerSec))")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.primary)

                    Text("↑ \(Formatters.speed(snapshot.uploadSpeedBytesPerSec))")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack {
                    Text("Hoy: \(Formatters.fileBytes(snapshot.dailyDownloadBytes + snapshot.dailyUploadBytes))")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
        } else {
            // Medium
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Red", systemImage: "network")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.green)
                        Spacer()
                        Text(snapshot.localIPv4 ?? "Sin IP")
                            .font(.system(size: 10))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("↓ Bajada")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(Formatters.speed(snapshot.downloadSpeedBytesPerSec))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text("↑ Subida")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(Formatters.speed(snapshot.uploadSpeedBytesPerSec))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                    }

                    Spacer()

                    Text("Total mensual: \(Formatters.fileBytes(snapshot.monthlyTotalBytes))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(width: 140, alignment: .leading)

                Divider()

                // History chart or Quota Gauge
                VStack(alignment: .leading, spacing: 2) {
                    Text("Historial (60s)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)

                    if !snapshot.historyDown.isEmpty {
                        Chart {
                            ForEach(snapshot.historyDown) { p in
                                AreaMark(x: .value("T", p.timestamp), y: .value("V", p.value))
                                    .foregroundStyle(Color.green.opacity(0.3))
                                LineMark(x: .value("T", p.timestamp), y: .value("V", p.value))
                                    .foregroundStyle(Color.green)
                            }
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .chartLegend(.hidden)
                        .frame(height: 55)
                    }
                }
            }
            .padding(12)
        }
    }
}
