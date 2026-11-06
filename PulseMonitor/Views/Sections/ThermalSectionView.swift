import SwiftUI
// import PulseCore

@MainActor public struct ThermalSectionView: View {
    @ObservedObject public var viewModel: ThermalViewModel
    private var snapshot: ThermalSnapshot { viewModel.snapshot }

    @MainActor public init(viewModel: ThermalViewModel? = nil) {
        self.viewModel = viewModel ?? SystemMonitor.shared.thermalVM
    }

    public init(snapshot: ThermalSnapshot) {
        self.viewModel = ThermalViewModel(snapshot: snapshot)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Temperature & Thermal State
            HStack(spacing: 16) {
                CircularGaugeView(
                    value: snapshot.socTemperature ?? 40.0,
                    maxValue: 105.0,
                    title: Formatters.temperature(snapshot.socTemperature),
                    subtitle: "SoC",
                    color: Theme.thermal(temperature: snapshot.socTemperature),
                    size: 88
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Estado Térmico:", systemImage: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(snapshot.thermalState.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(thermalStateColor(snapshot.thermalState))
                    }

                    if let cpu = snapshot.cpuTemperature {
                        HStack {
                            Label("CPU Proximidad:", systemImage: "cpu")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(Formatters.temperature(cpu))
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                        }
                    }

                    if let gpu = snapshot.gpuTemperature {
                        HStack {
                            Label("GPU:", systemImage: "sparkles")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(Formatters.temperature(gpu))
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                        }
                    }
                }
            }
            .liquidGlassCard()

            // Fans
            VStack(alignment: .leading, spacing: 8) {
                Text("Ventiladores")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)

                if snapshot.fans.isEmpty {
                    Text("Refrigeración Pasiva / Ventiladores en reposo (0 RPM)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(snapshot.fans) { fan in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Label(fan.name, systemImage: "fan.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text(Formatters.rpm(fan.currentRPM))
                                    .font(.system(size: 12, weight: .bold))
                                    .monospacedDigit()
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.gray.opacity(0.18)).frame(height: 6)
                                    Capsule()
                                        .fill(fan.percentage > 70 ? Color.orange : Color.blue)
                                        .frame(width: max(4, geo.size.width * CGFloat(fan.percentage / 100.0)), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .liquidGlassCard()
        }
    }

    private func thermalStateColor(_ state: ThermalPressureState) -> Color {
        switch state {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        }
    }
}
