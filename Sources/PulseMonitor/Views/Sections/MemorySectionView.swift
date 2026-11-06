import SwiftUI
import Charts
import PulseCore

@MainActor public struct MemorySectionView: View {
    @ObservedObject public var viewModel: MemoryViewModel
    private var snapshot: MemorySnapshot { viewModel.snapshot }

    @MainActor public init(viewModel: MemoryViewModel? = nil) {
        self.viewModel = viewModel ?? SystemMonitor.shared.memoryVM
    }

    public init(snapshot: MemorySnapshot) {
        self.viewModel = MemoryViewModel(snapshot: snapshot)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Gauge & Quick overview
            HStack(spacing: 16) {
                CircularGaugeView(
                    value: snapshot.usedPercentage,
                    title: Formatters.percentageInteger(snapshot.usedPercentage),
                    subtitle: "Usada",
                    color: Theme.memory,
                    size: 88
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Memoria Usada:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(Formatters.bytes(snapshot.usedBytes))
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Memoria Libre:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(Formatters.bytes(snapshot.freeBytes))
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Memoria Total:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(Formatters.bytes(snapshot.totalBytes))
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Presión:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(snapshot.pressureLevel.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(snapshot.pressureLevel == .critical ? .red : (snapshot.pressureLevel == .warning ? .orange : .green))
                    }
                }
            }
            .liquidGlassCard()

            // Detailed Memory breakdown bar (App, Wired, Compressed, Inactive/Free)
            VStack(alignment: .leading, spacing: 8) {
                Text("Desglose de Memoria")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)

                GeometryReader { geo in
                    let total = max(1.0, Double(snapshot.totalBytes))
                    let wApp = geo.size.width * CGFloat(Double(snapshot.activeBytes) / total)
                    let wWired = geo.size.width * CGFloat(Double(snapshot.wiredBytes) / total)
                    let wComp = geo.size.width * CGFloat(Double(snapshot.compressedBytes) / total)

                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Theme.memory)
                            .frame(width: max(2, wApp))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.blue)
                            .frame(width: max(2, wWired))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange)
                            .frame(width: max(2, wComp))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.25))
                    }
                }
                .frame(height: 10)

                // Legend
                HStack(spacing: 12) {
                    LegendItem(color: Theme.memory, label: "Apps: \(Formatters.bytes(snapshot.activeBytes))")
                    LegendItem(color: Color.blue, label: "Wired: \(Formatters.bytes(snapshot.wiredBytes))")
                }
                HStack(spacing: 12) {
                    LegendItem(color: Color.orange, label: "Comp: \(Formatters.bytes(snapshot.compressedBytes))")
                    LegendItem(color: Color.gray.opacity(0.5), label: "Swap: \(Formatters.bytes(snapshot.swapUsedBytes))")
                }
            }
            .liquidGlassCard()

            // Swift Chart
            VStack(alignment: .leading, spacing: 6) {
                Text("Historial de Presión y Uso (60s)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)

                SparklineChart(data: snapshot.history, color: Theme.memory, height: 75, showArea: true)
            }
            .liquidGlassCard()
        }
    }
}

private struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}
