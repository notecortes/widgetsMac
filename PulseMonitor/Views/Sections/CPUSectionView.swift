import SwiftUI
import Charts
// import PulseCore

@MainActor public struct CPUSectionView: View {
    @ObservedObject public var viewModel: CPUViewModel
    private var snapshot: CPUSnapshot { viewModel.snapshot }

    @MainActor public init(viewModel: CPUViewModel? = nil) {
        self.viewModel = viewModel ?? SystemMonitor.shared.cpuVM
    }

    public init(snapshot: CPUSnapshot) {
        self.viewModel = CPUViewModel(snapshot: snapshot)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header stats
            HStack(spacing: 16) {
                CircularGaugeView(
                    value: snapshot.totalUsage,
                    title: Formatters.percentageInteger(snapshot.totalUsage),
                    subtitle: "CPU Total",
                    color: Theme.cpu,
                    size: 88
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Usuario:", systemImage: "person.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(Formatters.percentage(snapshot.userUsage))
                            .font(.system(size: 12, weight: .semibold))
                            .monospacedDigit()
                    }

                    HStack {
                        Label("Sistema:", systemImage: "gearshape.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(Formatters.percentage(snapshot.systemUsage))
                            .font(.system(size: 12, weight: .semibold))
                            .monospacedDigit()
                    }

                    HStack {
                        Label("Inactivo:", systemImage: "moon.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(Formatters.percentage(snapshot.idleUsage))
                            .font(.system(size: 12, weight: .semibold))
                            .monospacedDigit()
                    }

                    if let temp = snapshot.temperature {
                        HStack {
                            Label("Temperatura:", systemImage: "thermometer.medium")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(Formatters.temperature(temp))
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                                .foregroundColor(Theme.thermal(temperature: temp))
                        }
                    }
                }
            }
            .liquidGlassCard()

            // Performance vs Efficiency Cores breakdown
            if !snapshot.performanceCoreUsages.isEmpty || !snapshot.efficiencyCoreUsages.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Núcleos Apple Silicon")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)

                    if !snapshot.performanceCoreUsages.isEmpty {
                        Text("Núcleos de Rendimiento (P-Cores) · \(snapshot.performanceCoreUsages.count)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: min(4, snapshot.performanceCoreUsages.count)), spacing: 6) {
                            ForEach(Array(snapshot.performanceCoreUsages.enumerated()), id: \.offset) { idx, load in
                                CoreBarItem(title: "P\(idx + 1)", load: load, color: Theme.cpu)
                            }
                        }
                    }

                    if !snapshot.efficiencyCoreUsages.isEmpty {
                        Text("Núcleos de Eficiencia (E-Cores) · \(snapshot.efficiencyCoreUsages.count)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.top, 4)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: min(4, snapshot.efficiencyCoreUsages.count)), spacing: 6) {
                            ForEach(Array(snapshot.efficiencyCoreUsages.enumerated()), id: \.offset) { idx, load in
                                CoreBarItem(title: "E\(idx + 1)", load: load, color: Color.teal)
                            }
                        }
                    }
                }
                .liquidGlassCard()
            }

            // Historical Swift Chart
            VStack(alignment: .leading, spacing: 6) {
                Text("Historial de Actividad (60s)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)

                SparklineChart(data: snapshot.history, color: Theme.cpu, height: 75, showArea: true)
            }
            .liquidGlassCard()
        }
    }
}

private struct CoreBarItem: View {
    let title: String
    let load: Double
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.15))
                    .frame(height: 38)

                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(height: max(3, 38 * CGFloat(min(1.0, max(0.0, load / 100.0)))))
            }

            HStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                Text(Formatters.percentageInteger(load))
                    .font(.system(size: 9, weight: .regular))
                    .monospacedDigit()
            }
            .foregroundColor(.secondary)
        }
    }
}
