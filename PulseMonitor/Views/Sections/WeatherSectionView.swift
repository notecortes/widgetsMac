import SwiftUI
// import PulseCore

@MainActor public struct WeatherSectionView: View {
    @ObservedObject public var viewModel: WeatherViewModel
    public var onRefresh: (() -> Void)? = nil
    private var snapshot: WeatherSnapshot { viewModel.snapshot }

    @MainActor public init(viewModel: WeatherViewModel? = nil, onRefresh: (() -> Void)? = nil) {
        self.viewModel = viewModel ?? SystemMonitor.shared.weatherVM
        self.onRefresh = onRefresh
    }

    public init(snapshot: WeatherSnapshot, onRefresh: (() -> Void)? = nil) {
        self.viewModel = WeatherViewModel(snapshot: snapshot)
        self.onRefresh = onRefresh
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Main Weather Header
            HStack(spacing: 16) {
                Image(systemName: snapshot.symbolName)
                    .font(.system(size: 46))
                    .symbolRenderingMode(.multicolor)
                    .frame(width: 60)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(String(format: "%.0f°C", snapshot.temperature))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Spacer()
                        if let refresh = onRefresh {
                            Button(action: refresh) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                        }
                    }

                    Text(snapshot.conditionText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)

                    HStack(spacing: 12) {
                        Label("Sensación: \(String(format: "%.0f°", snapshot.feelsLike))", systemImage: "thermometer")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Label(String(format: "%.0f km/h", snapshot.windSpeed), systemImage: "wind")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .liquidGlassCard()

            // 6-hour forecast cards
            if !snapshot.hourlyForecast.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pronóstico Próximas Horas")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(snapshot.hourlyForecast) { item in
                            VStack(spacing: 4) {
                                Text(item.timeString)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)

                                Image(systemName: item.symbolName)
                                    .font(.system(size: 16))
                                    .symbolRenderingMode(.multicolor)
                                    .frame(height: 22)

                                Text(String(format: "%.0f°", item.temperature))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                        }
                    }
                }
                .liquidGlassCard()
            }

            HStack {
                Label(snapshot.locationName, systemImage: "location.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Open-Meteo · Caché 15m")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }
}
