import WidgetKit
import SwiftUI
// import PulseCore

public struct MemoryWidget: Widget {
    public let kind: String = "com.pulse.widget.memory"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseTimelineProvider()) { entry in
            WidgetContainerView(snapshot: entry.snapshot) { snapshot in
                MemoryWidgetView(snapshot: snapshot.memory)
            }
        }
        .configurationDisplayName("Memoria RAM")
        .description("Memoria usada, libre, comprimida y presión del sistema.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

public struct MemoryWidgetView: View {
    @Environment(\.widgetFamily) var family
    public let snapshot: MemorySnapshot

    public var body: some View {
        if family == .systemSmall {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("RAM", systemImage: "memorychip")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.purple)
                    Spacer()
                    Text(snapshot.pressureLevel.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(snapshot.pressureLevel == .critical ? .red : (snapshot.pressureLevel == .warning ? .orange : .green))
                }

                Spacer()

                Text(Formatters.bytes(snapshot.usedBytes))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text("de \(Formatters.bytes(snapshot.totalBytes))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                // Stacked bar
                GeometryReader { geo in
                    let total = max(1.0, Double(snapshot.totalBytes))
                    let wUsed = geo.size.width * CGFloat(Double(snapshot.usedBytes) / total)

                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.2)).frame(height: 6)
                        Capsule().fill(Color.purple).frame(width: max(4, wUsed), height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(10)
        } else {
            // Medium
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Memoria RAM", systemImage: "memorychip")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.purple)

                    Text(Formatters.bytes(snapshot.usedBytes))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Text("Total: \(Formatters.bytes(snapshot.totalBytes))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text("Presión: \(snapshot.pressureLevel.rawValue)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(snapshot.pressureLevel == .critical ? .red : (snapshot.pressureLevel == .warning ? .orange : .green))
                }
                .frame(width: 130, alignment: .leading)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Apps (Activa):")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(Formatters.bytes(snapshot.activeBytes))
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Alámbrica (Wired):")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(Formatters.bytes(snapshot.wiredBytes))
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Comprimida:")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(Formatters.bytes(snapshot.compressedBytes))
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Swap usado:")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(Formatters.bytes(snapshot.swapUsedBytes))
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                    }
                }
            }
            .padding(12)
        }
    }
}
