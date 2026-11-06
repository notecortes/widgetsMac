import WidgetKit
import SwiftUI
// import PulseCore

public struct DiskWidget: Widget {
    public let kind: String = "com.pulse.widget.disk"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseTimelineProvider()) { entry in
            WidgetContainerView(snapshot: entry.snapshot) { snapshot in
                DiskWidgetView(snapshot: snapshot.disk)
            }
        }
        .configurationDisplayName("Disco y Almacenamiento")
        .description("Capacidad ocupada y disponible con alertas visuales al 80% y 90%.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

public struct DiskWidgetView: View {
    @Environment(\.widgetFamily) var family
    public let snapshot: DiskSnapshot

    private func colorForPercentage(_ p: Double) -> Color {
        if p >= 90.0 {
            return .red
        } else if p >= 80.0 {
            return .orange
        } else {
            return .orange
        }
    }

    public var body: some View {
        let primary = snapshot.volumes.first ?? VolumeInfo(name: "Disco", mountPoint: "/", totalBytes: 0, freeBytes: 0)

        if family == .systemSmall {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("Disco", systemImage: "internaldrive")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(colorForPercentage(primary.usedPercentage))
                    Spacer()
                    Text(Formatters.percentageInteger(primary.usedPercentage))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(colorForPercentage(primary.usedPercentage))
                }

                Spacer()

                Text(Formatters.fileBytes(primary.usedBytes))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text("de \(Formatters.fileBytes(primary.totalBytes))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.2)).frame(height: 6)
                        Capsule()
                            .fill(colorForPercentage(primary.usedPercentage))
                            .frame(width: max(4, geo.size.width * CGFloat(min(1.0, primary.usedPercentage / 100.0))), height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(10)
        } else {
            // Medium
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Almacenamiento", systemImage: "internaldrive")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(colorForPercentage(primary.usedPercentage))
                    Spacer()
                    Text("Lectura: \(Formatters.speed(snapshot.readSpeedBytesPerSec)) · Escritura: \(Formatters.speed(snapshot.writeSpeedBytesPerSec))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                ForEach(snapshot.volumes.prefix(2)) { vol in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(vol.name)
                                .font(.system(size: 11, weight: .semibold))
                            Spacer()
                            Text("\(Formatters.fileBytes(vol.usedBytes)) / \(Formatters.fileBytes(vol.totalBytes)) (\(Formatters.percentageInteger(vol.usedPercentage)))")
                                .font(.system(size: 10))
                                .monospacedDigit()
                                .foregroundColor(colorForPercentage(vol.usedPercentage))
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.gray.opacity(0.18)).frame(height: 6)
                                Capsule()
                                    .fill(colorForPercentage(vol.usedPercentage))
                                    .frame(width: max(4, geo.size.width * CGFloat(min(1.0, vol.usedPercentage / 100.0))), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
            .padding(12)
        }
    }
}
