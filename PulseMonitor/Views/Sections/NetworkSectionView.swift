import SwiftUI
import Charts
// import PulseCore

@MainActor public struct NetworkSectionView: View {
    @ObservedObject public var viewModel: NetworkViewModel
    private var snapshot: NetworkSnapshot { viewModel.snapshot }

    @MainActor public init(viewModel: NetworkViewModel? = nil) {
        self.viewModel = viewModel ?? SystemMonitor.shared.networkVM
    }

    public init(snapshot: NetworkSnapshot) {
        self.viewModel = NetworkViewModel(snapshot: snapshot)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Live speeds
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Bajada", systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.network)
                    Text(Formatters.speed(snapshot.downloadSpeedBytesPerSec))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Label("Subida", systemImage: "arrow.up.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.networkUpload)
                    Text(Formatters.speed(snapshot.uploadSpeedBytesPerSec))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
            .liquidGlassCard()

            // Accumulations & Quotas
            VStack(alignment: .leading, spacing: 8) {
                Text("Consumo Acumulado")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)

                HStack {
                    Text("Total Hoy:")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("↓ \(Formatters.fileBytes(snapshot.dailyDownloadBytes))  ↑ \(Formatters.fileBytes(snapshot.dailyUploadBytes))")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                }

                HStack {
                    Text("Total Mensual:")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(Formatters.fileBytes(snapshot.monthlyTotalBytes))
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                }

                // Monthly Quota bar if configured
                if let quota = snapshot.monthlyQuotaBytes, quota > 0, let pct = snapshot.quotaPercentage {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("Cuota Mensual (\(Formatters.fileBytes(quota))):")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(Formatters.percentage(pct))
                                .font(.system(size: 11, weight: .bold))
                                .monospacedDigit()
                                .foregroundColor(pct >= 90.0 ? .red : (pct >= 80.0 ? .orange : Theme.network))
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.gray.opacity(0.18)).frame(height: 6)
                                Capsule()
                                    .fill(pct >= 90.0 ? Color.red : (pct >= 80.0 ? Color.orange : Theme.network))
                                    .frame(width: max(4, geo.size.width * CGFloat(min(1.0, pct / 100.0))), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(.top, 2)
                }
            }
            .liquidGlassCard()

            // Network Addresses
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("IP Local:", systemImage: "network")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(snapshot.localIPv4 ?? "No conectada")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                }

                HStack {
                    Label("Interfaz:", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(snapshot.interfaceName)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .liquidGlassCard()

            // Swift Chart
            VStack(alignment: .leading, spacing: 6) {
                Text("Historial de Red (60s)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)

                SparklineChart(data: snapshot.historyDown, color: Theme.network, height: 75, showArea: true)
            }
            .liquidGlassCard()
        }
    }
}
