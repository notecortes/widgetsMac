import WidgetKit
import SwiftUI
// import PulseCore

public struct WeatherWidget: Widget {
    public let kind: String = "com.pulse.widget.weather"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseTimelineProvider()) { entry in
            WidgetContainerView(snapshot: entry.snapshot) { snapshot in
                WeatherWidgetView(snapshot: snapshot.weather)
            }
        }
        .configurationDisplayName("Clima y Pronóstico")
        .description("Temperatura actual, sensación térmica, viento y pronóstico.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

public struct WeatherWidgetView: View {
    @Environment(\.widgetFamily) var family
    public let snapshot: WeatherSnapshot

    public var body: some View {
        if family == .systemSmall {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: snapshot.symbolName)
                        .font(.system(size: 24))
                        .symbolRenderingMode(.multicolor)
                    Spacer()
                    Text(String(format: "%.0f°", snapshot.temperature))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }

                Text(snapshot.conditionText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                HStack {
                    Label(String(format: "%.0f°", snapshot.feelsLike), systemImage: "thermometer")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    Label(String(format: "%.0f km/h", snapshot.windSpeed), systemImage: "wind")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Text(snapshot.locationName)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(10)
        } else {
            // Medium
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Image(systemName: snapshot.symbolName)
                            .font(.system(size: 28))
                            .symbolRenderingMode(.multicolor)
                        Text(String(format: "%.0f°", snapshot.temperature))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }

                    Text(snapshot.conditionText)
                        .font(.system(size: 12, weight: .semibold))

                    Text("Sensación: \(String(format: "%.0f°", snapshot.feelsLike)) · Viento: \(String(format: "%.0f km/h", snapshot.windSpeed))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text(snapshot.locationName)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .frame(width: 130, alignment: .leading)

                Divider()

                // Hourly Forecast
                HStack(spacing: 6) {
                    ForEach(snapshot.hourlyForecast.prefix(4)) { item in
                        VStack(spacing: 3) {
                            Text(item.timeString)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Image(systemName: item.symbolName)
                                .font(.system(size: 14))
                                .symbolRenderingMode(.multicolor)
                                .frame(height: 18)
                            Text(String(format: "%.0f°", item.temperature))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(12)
        }
    }
}
