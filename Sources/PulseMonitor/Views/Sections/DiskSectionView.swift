import SwiftUI
import Charts
import PulseCore

@MainActor public struct DiskSectionView: View {
    @ObservedObject public var viewModel: DiskViewModel
    private var snapshot: DiskSnapshot { viewModel.snapshot }

    @MainActor public init(viewModel: DiskViewModel? = nil) {
        self.viewModel = viewModel ?? SystemMonitor.shared.diskVM
    }

    public init(snapshot: DiskSnapshot) {
        self.viewModel = DiskViewModel(snapshot: snapshot)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Mounted volumes list
            VStack(alignment: .leading, spacing: 10) {
                Text("Volúmenes de Almacenamiento")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)

                ForEach(snapshot.volumes) { vol in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: vol.isSystem ? "internaldrive.fill" : "externaldrive.fill")
                                .foregroundColor(Theme.disk)
                                .font(.system(size: 13))

                            Text(vol.name)
                                .font(.system(size: 13, weight: .semibold))

                            Spacer()

                            Text("\(Formatters.fileBytes(vol.usedBytes)) / \(Formatters.fileBytes(vol.totalBytes))")
                                .font(.system(size: 11))
                                .monospacedDigit()
                                .foregroundColor(.secondary)

                            Text(Formatters.percentageInteger(vol.usedPercentage))
                                .font(.system(size: 12, weight: .bold))
                                .monospacedDigit()
                                .foregroundColor(warningColor(for: vol.usedPercentage))
                        }

                        // Progress bar with 80%/90% color warning
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.gray.opacity(0.18))
                                    .frame(height: 7)

                                Capsule()
                                    .fill(warningColor(for: vol.usedPercentage))
                                    .frame(width: max(4, geo.size.width * CGFloat(min(1.0, vol.usedPercentage / 100.0))), height: 7)
                            }
                        }
                        .frame(height: 7)
                    }
                    .padding(.vertical, 3)
                }
            }
            .liquidGlassCard()

            // Disk I/O (Throughput & IOPS)
            VStack(alignment: .leading, spacing: 8) {
                Text("Rendimiento de E/S de Disco")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)

                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("Lectura", systemImage: "arrow.down.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                        Text(Formatters.speed(snapshot.readSpeedBytesPerSec))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(String(format: "%.0f IOPS", snapshot.readIOPS))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 3) {
                        Label("Escritura", systemImage: "arrow.up.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.disk)
                        Text(Formatters.speed(snapshot.writeSpeedBytesPerSec))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(String(format: "%.0f IOPS", snapshot.writeIOPS))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .liquidGlassCard()

            // Swift Chart I/O
            VStack(alignment: .leading, spacing: 6) {
                Text("Actividad de E/S (60s)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)

                SparklineChart(data: snapshot.historyWrite, color: Theme.disk, height: 75, showArea: true)
            }
            .liquidGlassCard()
        }
    }

    private func warningColor(for percentage: Double) -> Color {
        if percentage >= 90.0 {
            return Color.red
        } else if percentage >= 80.0 {
            return Color.orange
        } else {
            return Theme.disk
        }
    }
}
