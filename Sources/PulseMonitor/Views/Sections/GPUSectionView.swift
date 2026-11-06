import SwiftUI
import Charts
import PulseCore

@MainActor public struct GPUSectionView: View {
    @ObservedObject public var viewModel: GPUViewModel
    private var snapshot: GPUSnapshot { viewModel.snapshot }

    @MainActor public init(viewModel: GPUViewModel? = nil) {
        self.viewModel = viewModel ?? SystemMonitor.shared.gpuVM
    }

    public init(snapshot: GPUSnapshot) {
        self.viewModel = GPUViewModel(snapshot: snapshot)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                CircularGaugeView(
                    value: snapshot.usage,
                    title: Formatters.percentageInteger(snapshot.usage),
                    subtitle: "GPU",
                    color: Theme.gpu,
                    size: 88
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Uso de Gráficos:", systemImage: "sparkles")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(Formatters.percentage(snapshot.usage))
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                    }

                    if let freq = snapshot.frequencyMHz, freq > 0 {
                        HStack {
                            Label("Frecuencia:", systemImage: "bolt.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.0f MHz", freq))
                                .font(.system(size: 13, weight: .semibold))
                                .monospacedDigit()
                        }
                    }

                    HStack {
                        Label("Estado:", systemImage: "shield.checkerboard")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(snapshot.usage > 70.0 ? "Alta Carga" : (snapshot.usage > 20.0 ? "Activa" : "Reposo"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(snapshot.usage > 70.0 ? .orange : .green)
                    }
                }
            }
            .liquidGlassCard()

            VStack(alignment: .leading, spacing: 6) {
                Text("Historial de Gráficos (60s)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)

                SparklineChart(data: snapshot.history, color: Theme.gpu, height: 85, showArea: true)
            }
            .liquidGlassCard()
        }
    }
}
