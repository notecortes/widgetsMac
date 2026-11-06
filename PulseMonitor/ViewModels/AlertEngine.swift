import Foundation
import UserNotifications
// import PulseCore

public final class AlertEngine: @unchecked Sendable {
    public static let shared = AlertEngine()

    private var lastFiredDates: [String: Date] = [:]
    private let cooldownSeconds: TimeInterval = 900 // 15 minutes anti-debounce
    private let lock = NSLock()

    private var isNotificationSupported: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    private init() {
        if isNotificationSupported {
            requestAuthorization()
        }
    }

    public func requestAuthorization() {
        guard isNotificationSupported else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func triggerTestAlert() {
        guard isNotificationSupported else { return }
        let content = UNMutableNotificationContent()
        content.title = "Pulse Monitor - Alerta de Prueba"
        content.body = "El sistema de notificaciones inteligentes está funcionando correctamente."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "test_alert_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    public func evaluate(snapshot: SystemSnapshot) {
        lock.lock()
        defer { lock.unlock() }

        let defaults = UserDefaults.standard
        let alertsEnabled = defaults.object(forKey: "alertsEnabled") as? Bool ?? true
        guard alertsEnabled else { return }

        let cpuThreshold = defaults.object(forKey: "cpuAlertThreshold") as? Double ?? 90.0
        let memThreshold = defaults.object(forKey: "memoryAlertThreshold") as? Double ?? 85.0
        let diskThreshold = defaults.object(forKey: "diskAlertThreshold") as? Double ?? 90.0
        let battThreshold = defaults.object(forKey: "batteryAlertThreshold") as? Double ?? 20.0
        let tempThreshold = defaults.object(forKey: "tempAlertThreshold") as? Double ?? 90.0

        // 1. CPU alert
        if snapshot.cpu.totalUsage >= cpuThreshold {
            fireAlert(
                id: "cpu_alert",
                title: "Alto uso de CPU",
                body: "El uso de la CPU ha alcanzado el \(Formatters.percentageInteger(snapshot.cpu.totalUsage))."
            )
        }

        // 2. Memory Critical alert
        if snapshot.memory.usedPercentage >= memThreshold || snapshot.memory.pressureLevel == .critical {
            fireAlert(
                id: "memory_alert",
                title: "Presión de Memoria Alta",
                body: "La memoria RAM está ocupada al \(Formatters.percentageInteger(snapshot.memory.usedPercentage)). Presión: \(snapshot.memory.pressureLevel.rawValue)."
            )
        }

        // 3. Disk alert
        if let primary = snapshot.disk.volumes.first, primary.usedPercentage >= diskThreshold {
            fireAlert(
                id: "disk_alert",
                title: "Espacio en Disco Crítico",
                body: "El volumen \(primary.name) está al \(Formatters.percentageInteger(primary.usedPercentage)) de capacidad."
            )
        }

        // 4. Battery low alert
        if snapshot.battery.hasBattery && !snapshot.battery.isCharging && snapshot.battery.percentage <= battThreshold {
            fireAlert(
                id: "battery_alert",
                title: "Batería Baja",
                body: "Nivel de batería restante: \(Formatters.percentageInteger(snapshot.battery.percentage)). Conecta el cargador."
            )
        }

        // 5. Thermal alert
        if let temp = snapshot.thermal.socTemperature, temp >= tempThreshold {
            fireAlert(
                id: "temp_alert",
                title: "Temperatura Elevada",
                body: "La temperatura del procesador ha alcanzado \(Formatters.temperature(temp))."
            )
        }

        // 6. Network Quota alert
        if let quota = snapshot.network.monthlyQuotaBytes, quota > 0, let pct = snapshot.network.quotaPercentage {
            if pct >= 100.0 {
                fireAlert(
                    id: "net_quota_100",
                    title: "Cuota de Red Superada",
                    body: "Has alcanzado el 100% de tu cuota mensual de datos (\(Formatters.fileBytes(quota)))."
                )
            } else if pct >= 80.0 {
                fireAlert(
                    id: "net_quota_80",
                    title: "Aviso de Cuota de Red",
                    body: "Has consumido el \(Formatters.percentageInteger(pct)) de tu cuota de datos mensual."
                )
            }
        }
    }

    private func fireAlert(id: String, title: String, body: String) {
        guard isNotificationSupported else { return }
        let now = Date()
        if let last = lastFiredDates[id], now.timeIntervalSince(last) < cooldownSeconds {
            // Anti-bounce cooldown active
            return
        }

        lastFiredDates[id] = now

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
