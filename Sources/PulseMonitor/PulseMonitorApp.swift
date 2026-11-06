import AppKit
import SwiftUI
import os
import Combine
import PulseCore

public let uiLog = Logger(subsystem: "app.pulse", category: "ui")

typealias MainPanelView = DropdownView

@main
struct PulseMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate!
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?
    private var hudWindow: HudPanel?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ n: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)
        uiLog.info("[TEST] ✅ app lanzada")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let b = statusItem.button {
            b.image = NSImage(systemSymbolName: "waveform.path.ecg",
                              accessibilityDescription: "Pulse Monitor")
            b.image?.isTemplate = true
            b.imagePosition = .imageLeading            // icono a la izquierda, texto a la derecha
            b.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize(for: .small),
                                                weight: .medium)
            b.title = " --%"
            b.sendAction(on: [.leftMouseUp, .rightMouseUp])
            b.action = #selector(handleStatusBarClick); b.target = self

            // Suscripción al publisher del monitor para actualizar el título en vivo
            SystemMonitor.shared.$cpuUsage
                .receive(on: DispatchQueue.main)
                .removeDuplicates { abs($0 - $1) < 0.5 }   // sin redibujos inútiles
                .sink { [weak self, weak b] cpu in
                    self?.updateMenuBarTitle(button: b, cpu: cpu)
                }
                .store(in: &cancellables)

            SystemMonitor.shared.objectWillChange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    let mode = UserDefaults.standard.string(forKey: "menuBarDisplayMode") ?? "cpu"
                    if mode != "cpu" && mode != "iconOnly" {
                        self?.updateMenuBarTitle()
                    }
                }
                .store(in: &cancellables)
        }
        popover.contentViewController = NSHostingController(rootView: MainPanelView())
        popover.contentSize = NSSize(width: 400, height: 620)
        popover.behavior = .transient

        // Modo autoprueba: `open Pulse\ Monitor.app --args --selftest`
        if CommandLine.arguments.contains("--selftest") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                // Auditoría de hardware y snapshot
                var ramBytes: UInt64 = 0
                var size = MemoryLayout<UInt64>.size
                sysctlbyname("hw.memsize", &ramBytes, &size, nil, 0)
                let sysctlRAMGB = Int((Double(ramBytes) / pow(1024, 3)).rounded())

                var chipSize = 0
                sysctlbyname("machdep.cpu.brand_string", nil, &chipSize, nil, 0)
                var chipBuf = [CChar](repeating: 0, count: max(1, chipSize))
                sysctlbyname("machdep.cpu.brand_string", &chipBuf, &chipSize, nil, 0)
                let sysctlChip = String(decoding: chipBuf.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)

                let panelChip = SystemMonitor.shared.snapshot.system.chipName
                let panelRAMGB = Int(SystemMonitor.shared.memoryTotalGB.rounded())
                let panelCPU = SystemMonitor.shared.cpuUsage
                let panelBattery = SystemMonitor.shared.batteryPercent ?? 0
                let panelTemp = SystemMonitor.shared.socTemperature

                let snap = SharedSnapshotStore.shared.loadOptional()
                let snapChip = snap?.system.chipName ?? "NIL"
                let snapRAMGB = Int((Double(snap?.system.totalRAM ?? 0) / pow(1024, 3)).rounded())
                let snapCPU = snap?.cpu.totalUsage ?? 0
                let snapBattery = snap?.battery.percentage ?? 0
                let snapTemp = snap?.thermal.socTemperature

                uiLog.info("[AUDIT] 🔍 SYSCTL: Chip=\(sysctlChip, privacy: .public), RAM=\(sysctlRAMGB, privacy: .public) GB")
                uiLog.info("[AUDIT] 🔍 PANEL:  Chip=\(panelChip, privacy: .public), RAM=\(panelRAMGB, privacy: .public) GB, CPU=\(panelCPU, privacy: .public)%, Bat=\(panelBattery, privacy: .public)%, Temp=\(panelTemp.map { "\($0)°C" } ?? "N/A", privacy: .public)")
                uiLog.info("[AUDIT] 🔍 SNAPSHOT: Chip=\(snapChip, privacy: .public), RAM=\(snapRAMGB, privacy: .public) GB, CPU=\(snapCPU, privacy: .public)%, Bat=\(snapBattery, privacy: .public)%, Temp=\(snapTemp.map { "\($0)°C" } ?? "N/A", privacy: .public)")
                uiLog.info("[AUDIT] 🎯 COINCIDENCIA CHIP: \(sysctlChip == panelChip && panelChip == snapChip ? "✅ SÍ" : "❌ NO")")
                uiLog.info("[AUDIT] 🎯 COINCIDENCIA RAM:  \(sysctlRAMGB == panelRAMGB && panelRAMGB == snapRAMGB ? "✅ SÍ" : "❌ NO")")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                uiLog.info("[TEST] 🧪 abriendo Ajustes…"); self?.openSettings()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    uiLog.info("[TEST] 🧪 keyWindow=\(NSApp.keyWindow?.title ?? "NINGUNA")")
                    self?.closeSettings()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                        let policyIsAccessory = (NSApp.activationPolicy() == .accessory)
                        uiLog.info("[TEST] 🧪 activationPolicy tras closeSettings=\(policyIsAccessory ? "accessory (OK)" : "regular")")
                        self?.toggleHUD()
                        if !CommandLine.arguments.contains("--selftest-keep") {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { NSApp.terminate(nil) }
                        }
                    }
                }
            }
        }
    }

    func updateMenuBarTitle(button: NSStatusBarButton? = nil, cpu: Double? = nil) {
        guard let b = button ?? statusItem.button else { return }
        let mode = UserDefaults.standard.string(forKey: "menuBarDisplayMode") ?? "cpu"
        let currentCPU = cpu ?? SystemMonitor.shared.cpuUsage
        switch mode {
        case "cpu":
            b.title = " \(Int(currentCPU.rounded())) %"
        case "memory":
            b.title = String(format: " %.1f GB", SystemMonitor.shared.memoryUsedGB)
        case "network":
            b.title = " ↓ \(SystemMonitor.shared.downloadSpeedFormatted)"
        case "battery":
            if let bat = SystemMonitor.shared.batteryPercent {
                b.title = " \(Int(bat.rounded())) %"
            } else {
                b.title = ""
            }
        case "iconOnly":
            b.title = ""
        default:
            b.title = " \(Int(currentCPU.rounded())) %"
        }
        uiLog.debug("[TEST] statusItem.title actualizado a: '\(b.title)'")
    }

    @objc private func handleStatusBarClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let titleItem = NSMenuItem(title: "Pulse Monitor 1.0.0", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Mostrar/Ocultar Panel", action: #selector(togglePopover), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "Mostrar/Ocultar HUD", action: #selector(toggleHUDAction), keyEquivalent: "m"))
        menu.addItem(NSMenuItem(title: "Ajustes...", action: #selector(openSettingsAction), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Copiar Diagnóstico del Sistema", action: #selector(copyDiagnosticAction), keyEquivalent: "c"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Salir de Pulse Monitor", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleHUDAction() { toggleHUD() }
    @objc private func openSettingsAction() { openSettings() }
    @objc private func copyDiagnosticAction() {
        let diag = SystemEngine.shared.generateDiagnosticSummary()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diag, forType: .string)
        uiLog.info("[TEST] 📋 Diagnóstico copiado al portapapeles")
    }
    @objc private func quitApp() { NSApp.terminate(nil) }

    @objc private func togglePopover() {
        guard let b = statusItem.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else {
            uiLog.info("[TEST] abriendo panel")
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func openSettings() {
        uiLog.info("[TEST] ⚙️ openSettings llamado")
        if settingsWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 580),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "Ajustes de Pulse Monitor"
            w.contentView = NSHostingView(rootView: SettingsView())
            w.center(); w.isReleasedWhenClosed = false; w.delegate = self
            settingsWindow = w
        }
        NSApp.setActivationPolicy(.regular)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func closeSettings() {
        uiLog.info("[TEST] ⚙️ closeSettings llamado")
        settingsWindow?.performClose(nil)   // dispara windowWillClose → vuelve a .accessory
    }

    func toggleHUD() {
        uiLog.info("[TEST] HUD toggle")
        if let hud = hudWindow { hud.orderOut(nil); hudWindow = nil }
        else { hudWindow = HudPanel.make(); hudWindow?.orderFront(nil) }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ n: Notification) { NSApp.setActivationPolicy(.accessory) }
}
