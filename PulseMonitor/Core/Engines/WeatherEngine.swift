import Foundation

public actor WeatherEngine {
    public static let shared = WeatherEngine()

    private let session = URLSession(configuration: .default)
    private var lastFetchDate: Date?
    private var cachedSnapshot = WeatherSnapshot()

    public var latitude: Double = 39.4699
    public var longitude: Double = -0.3763
    public var locationName: String = "Valencia"

    private init() {}

    public func sample(forceRefresh: Bool = false) async -> WeatherSnapshot {
        if !forceRefresh,
           let last = lastFetchDate,
           Date().timeIntervalSince(last) < 900 { // 15 min cache
            return cachedSnapshot
        }

        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m&hourly=temperature_2m,weather_code&forecast_hours=6"

        guard let url = URL(string: urlStr) else {
            return cachedSnapshot
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return cachedSnapshot
            }

            let result = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

            var s = WeatherSnapshot()
            s.temperature = result.current.temperature_2m
            s.feelsLike = result.current.apparent_temperature
            s.weatherCode = result.current.weather_code
            s.windSpeed = result.current.wind_speed_10m
            s.locationName = locationName
            s.conditionText = conditionDescription(for: result.current.weather_code)
            s.symbolName = sfSymbol(for: result.current.weather_code)
            s.lastUpdated = Date()

            var forecasts: [HourlyForecast] = []
            let count = min(result.hourly.time.count, result.hourly.temperature_2m.count)
            for i in 0..<min(6, count) {
                let timeStr = result.hourly.time[i]
                let hourPart = timeStr.components(separatedBy: "T").last ?? timeStr
                let temp = result.hourly.temperature_2m[i]
                let code = i < result.hourly.weather_code.count ? result.hourly.weather_code[i] : result.current.weather_code
                forecasts.append(HourlyForecast(
                    timeString: hourPart,
                    temperature: temp,
                    symbolName: sfSymbol(for: code)
                ))
            }
            s.hourlyForecast = forecasts

            self.cachedSnapshot = s
            self.lastFetchDate = Date()
            return s
        } catch {
            return cachedSnapshot
        }
    }

    private func sfSymbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 61, 63, 65, 80, 81, 82: return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "sun.max.fill"
        }
    }

    private func conditionDescription(for code: Int) -> String {
        switch code {
        case 0: return "Despejado"
        case 1, 2: return "Parcialmente nublado"
        case 3: return "Nublado"
        case 45, 48: return "Niebla"
        case 51, 53, 55: return "Llovizna"
        case 61, 63, 65: return "Lluvia"
        case 71, 73, 75: return "Nieve"
        case 80, 81, 82: return "Chubascos"
        case 95, 96, 99: return "Tormenta"
        default: return "Despejado"
        }
    }
}

// MARK: - Open-Meteo Decodable Structs
private struct OpenMeteoResponse: Codable {
    let current: CurrentWeather
    let hourly: HourlyWeather
}

private struct CurrentWeather: Codable {
    let temperature_2m: Double
    let apparent_temperature: Double
    let weather_code: Int
    let wind_speed_10m: Double
}

private struct HourlyWeather: Codable {
    let time: [String]
    let temperature_2m: [Double]
    let weather_code: [Int]
}
