import AppKit
import SwiftUI

final class HudPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    static func make() -> HudPanel {
        let p = HudPanel(contentRect: NSRect(x: 0, y: 0, width: 230, height: 190),
                         styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered, defer: false)
        p.isFloatingPanel = true; p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isOpaque = false; p.backgroundColor = .clear
        p.hasShadow = true; p.isMovableByWindowBackground = true
        p.contentView = NSHostingView(rootView: HudView())
        if let s = NSScreen.main?.visibleFrame {
            p.setFrameOrigin(NSPoint(x: s.maxX - 242, y: s.maxY - 198))
        }
        return p
    }
}

struct HudRow: View {
    let icon: String; let color: Color; let label: String; let value: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 18)
            Text(label).font(.system(size: 11)).opacity(0.75)
            Spacer()
            Text(value).font(.system(size: 11, weight: .semibold).monospacedDigit())
        }
    }
}

struct HudView: View {
    @ObservedObject var m = SystemMonitor.shared   // ajusta al nombre real de tu singleton
    var body: some View {
        VStack(spacing: 8) {
            HudRow(icon: "cpu", color: .blue, label: "CPU",
                   value: String(format: "%.1f %%", m.cpuUsage))
            HudRow(icon: "memorychip", color: .purple, label: "Memoria",
                   value: String(format: "%.1f / %.0f GB", m.memoryUsedGB, m.memoryTotalGB))
            HudRow(icon: "arrow.down", color: .green, label: "Red ↓",
                   value: m.downloadSpeedFormatted)
            HudRow(icon: "battery.75percent", color: .green, label: "Batería",
                   value: m.batteryPercent.map { "\(Int($0)) %" } ?? "--")
            HudRow(icon: "thermometer.medium", color: .orange, label: "Temp SoC",
                   value: m.socTemperature.map { "\(Int($0)) °C" } ?? "--")
        }
        .padding(14).frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
