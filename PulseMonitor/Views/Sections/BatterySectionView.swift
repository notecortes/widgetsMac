import SwiftUI
// import PulseCore

@MainActor public struct BatterySectionView: View {
    @ObservedObject public var viewModel: BatteryViewModel
    private var snapshot: BatterySnapshot { viewModel.snapshot }

    @MainActor public init(viewModel: BatteryViewModel? = nil) {
        self.viewModel = viewModel ?? SystemMonitor.shared.batteryVM
    }

    public init(snapshot: BatterySnapshot) {
        self.viewModel = BatteryViewModel(snapshot: snapshot)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !snapshot.hasBattery {
                VStack(spacing: 8) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("Alimentación de CA Conectada")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Este equipo no cuenta con batería interna.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .liquidGlassCard()
            } else {
                HStack(spacing: 16) {
                    CircularGaugeView(
                        value: snapshot.percentage,
                        title: Formatters.percentageInteger(snapshot.percentage),
                        subtitle: snapshot.isCharging ? "Cargando" : "Batería",
                        color: Theme.battery(percentage: snapshot.percentage, isCharging: snapshot.isCharging),
                        size: 88
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Fuente:")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(snapshot.isACPowered ? "Adaptador CA" : "Batería")
                                .font(.system(size: 12, weight: .semibold))
                        }

                        if let mins = snapshot.timeRemainingMinutes {
                            HStack {
                                Text(snapshot.isCharging ? "Tiempo para carga:" : "Tiempo restante:")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(mins / 60)h \(mins % 60)m")
                                    .font(.system(size: 12, weight: .semibold))
                                    .monospacedDigit()
                            }
                        }

                        if let watts = snapshot.powerDrawWatts {
                            HStack {
                                Text(snapshot.isCharging ? "Potencia de carga:" : "Consumo actual:")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(Formatters.watts(watts))
                                    .font(.system(size: 12, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundColor(snapshot.isCharging ? .green : .primary)
                            }
                        }

                        if let health = snapshot.healthPercentage {
                            HStack {
                                Text("Salud:")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(Formatters.percentage(health))
                                    .font(.system(size: 12, weight: .semibold))
                                    .monospacedDigit()
                            }
                        }

                        if let cycles = snapshot.cycleCount {
                            HStack {
                                Text("Ciclos:")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(cycles)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .liquidGlassCard()
            }
        }
    }
}
