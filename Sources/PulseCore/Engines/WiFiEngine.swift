import Foundation
import CoreWLAN

public final class WiFiEngine: @unchecked Sendable {
    public static let shared = WiFiEngine()

    private let lock = NSLock()

    private init() {}

    public func sample() -> WiFiSnapshot {
        lock.lock()
        defer { lock.unlock() }

        var snapshot = WiFiSnapshot()

        guard let interface = CWWiFiClient.shared().interface() else {
            return snapshot
        }

        let ssid = interface.ssid()
        let bssid = interface.bssid()
        let rssi = interface.rssiValue()
        let noise = interface.noiseMeasurement()
        let txRate = interface.transmitRate()
        let channel = interface.wlanChannel()?.channelNumber ?? 0

        snapshot.isConnected = (ssid != nil) || (rssi != 0)
        snapshot.ssid = ssid ?? (snapshot.isConnected ? "Wi-Fi Conectado" : nil)
        snapshot.bssid = bssid
        snapshot.rssi = rssi
        snapshot.noise = noise
        snapshot.channel = Int(channel)
        snapshot.txRate = txRate

        if channel >= 1 && channel <= 14 {
            snapshot.band = "2.4 GHz"
        } else if channel >= 36 && channel <= 177 {
            snapshot.band = "5 GHz"
        } else if channel > 177 {
            snapshot.band = "6 GHz"
        } else {
            snapshot.band = "5 GHz"
        }

        return snapshot
    }
}
