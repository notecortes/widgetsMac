import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers
import PulseCore

// MARK: - View Model

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var samplingInterval: Double = 2.0 {
        didSet {
            UserDefaults.standard.set(samplingInterval, forKey: "samplingIntervalSetting")
            SystemMonitor.shared.updateSamplingInterval(samplingInterval)
        }
    }

    @Published public var monthlyQuotaGB: Double = 100.0 {
        didSet {
            UserDefaults.standard.set(monthlyQuotaGB, forKey: "monthlyQuotaGBSetting")
        }
    }

    @Published public var cpuAlertThreshold: Double = 90.0 {
        didSet {
            UserDefaults.standard.set(cpuAlertThreshold, forKey: "cpuAlertThreshold")
        }
    }

    @Published public var memoryAlertThreshold: Double = 85.0 {
        didSet {
            UserDefaults.standard.set(memoryAlertThreshold, forKey: "memoryAlertThreshold")
        }
    }

    @Published public var diskAlertThreshold: Double = 90.0 {
        didSet {
            UserDefaults.standard.set(diskAlertThreshold, forKey: "diskAlertThreshold")
        }
    }

    @Published public var batteryAlertThreshold: Double = 20.0 {
        didSet {
            UserDefaults.standard.set(batteryAlertThreshold, forKey: "batteryAlertThreshold")
        }
    }

    @Published public var tempAlertThreshold: Double = 90.0 {
        didSet {
            UserDefaults.standard.set(tempAlertThreshold, forKey: "tempAlertThreshold")
        }
    }

    @Published public var alertsEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(alertsEnabled, forKey: "alertsEnabled")
        }
    }

    @Published public var selectedTab: SettingsTab = .general
    @Published public var exportMessage: String? = nil
    @Published public var testAlertSent: Bool = false
    @Published public var launchAtLogin: Bool = false
    @Published public var approvalNeeded: Bool = false
    @Published public var menuBarDisplayMode: String = UserDefaults.standard.string(forKey: "menuBarDisplayMode") ?? "cpu"

    public init() {
        let d = UserDefaults.standard
        if let s = d.object(forKey: "samplingIntervalSetting") as? Double, s > 0 { self.samplingInterval = s }
        if let q = d.object(forKey: "monthlyQuotaGBSetting") as? Double, q > 0 { self.monthlyQuotaGB = q }
        if let c = d.object(forKey: "cpuAlertThreshold") as? Double, c > 0 { self.cpuAlertThreshold = c }
        if let m = d.object(forKey: "memoryAlertThreshold") as? Double, m > 0 { self.memoryAlertThreshold = m }
        if let dk = d.object(forKey: "diskAlertThreshold") as? Double, dk > 0 { self.diskAlertThreshold = dk }
        if let b = d.object(forKey: "batteryAlertThreshold") as? Double, b > 0 { self.batteryAlertThreshold = b }
        if let t = d.object(forKey: "tempAlertThreshold") as? Double, t > 0 { self.tempAlertThreshold = t }
        if let a = d.object(forKey: "alertsEnabled") as? Bool { self.alertsEnabled = a }

        // Source of truth is SMAppService status, not UserDefaults
        self.launchAtLogin = LoginItem.isEnabled
        self.approvalNeeded = LoginItem.needsApproval
    }

    public func syncLoginItem() {
        self.launchAtLogin = LoginItem.isEnabled
        self.approvalNeeded = LoginItem.needsApproval
    }

    public func toggleLaunchAtLogin(_ on: Bool) {
        do {
            try LoginItem.set(on)
            self.approvalNeeded = LoginItem.needsApproval
            self.launchAtLogin = LoginItem.isEnabled
        } catch {
            PulseLog.settings.error("Autoarranque: \(error.localizedDescription)")
            self.approvalNeeded = LoginItem.needsApproval
            self.launchAtLogin = LoginItem.isEnabled
        }
    }

    public func save() {
        let d = UserDefaults.standard
        d.set(samplingInterval, forKey: "samplingIntervalSetting")
        d.set(monthlyQuotaGB, forKey: "monthlyQuotaGBSetting")
        d.set(cpuAlertThreshold, forKey: "cpuAlertThreshold")
        d.set(memoryAlertThreshold, forKey: "memoryAlertThreshold")
        d.set(diskAlertThreshold, forKey: "diskAlertThreshold")
        d.set(batteryAlertThreshold, forKey: "batteryAlertThreshold")
        d.set(tempAlertThreshold, forKey: "tempAlertThreshold")
        d.set(alertsEnabled, forKey: "alertsEnabled")
    }

    public func resetToDefaults() {
        self.samplingInterval = 2.0
        self.monthlyQuotaGB = 100.0
        self.cpuAlertThreshold = 90.0
        self.memoryAlertThreshold = 85.0
        self.diskAlertThreshold = 90.0
        self.batteryAlertThreshold = 20.0
        self.tempAlertThreshold = 90.0
        self.alertsEnabled = true
        self.save()
        self.exportMessage = "Valores predeterminados restablecidos"
        uiLog.info("[TEST] 🔄 Valores predeterminados restablecidos")
    }

    public func copyDiagnosticReport() {
        let diag = SystemEngine.shared.generateDiagnosticSummary()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diag, forType: .string)
        self.exportMessage = "Diagnóstico copiado al portapapeles"
        uiLog.info("[TEST] 📋 Diagnóstico copiado al portapapeles desde Ajustes")
    }

    public func exportSettingsJSON() -> String {
        let dict: [String: Any] = [
            "samplingInterval": samplingInterval,
            "monthlyQuotaGB": monthlyQuotaGB,
            "cpuAlertThreshold": cpuAlertThreshold,
            "memoryAlertThreshold": memoryAlertThreshold,
            "diskAlertThreshold": diskAlertThreshold,
            "batteryAlertThreshold": batteryAlertThreshold,
            "tempAlertThreshold": tempAlertThreshold,
            "alertsEnabled": alertsEnabled
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            uiLog.info("[TEST] 📤 Ajustes exportados a JSON")
            return str
        }
        return "{}"
    }

    public func importSettingsJSON(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return
        }
        if let s = dict["samplingInterval"] as? Double { samplingInterval = s }
        if let q = dict["monthlyQuotaGB"] as? Double { monthlyQuotaGB = q }
        if let c = dict["cpuAlertThreshold"] as? Double { cpuAlertThreshold = c }
        if let m = dict["memoryAlertThreshold"] as? Double { memoryAlertThreshold = m }
        if let d = dict["diskAlertThreshold"] as? Double { diskAlertThreshold = d }
        if let b = dict["batteryAlertThreshold"] as? Double { batteryAlertThreshold = b }
        if let t = dict["tempAlertThreshold"] as? Double { tempAlertThreshold = t }
        if let a = dict["alertsEnabled"] as? Bool { alertsEnabled = a }
        save()
        exportMessage = "Ajustes importados correctamente"
        uiLog.info("[TEST] 📥 Ajustes importados desde JSON")
    }
}

// MARK: - Settings Tab

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Apariencia"
    case alerts = "Alertas"
    case network = "Red y Cuota"
    case history = "Historial"
    case advanced = "Avanzado"
    case about = "Acerca de"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintpalette"
        case .alerts: return "bell.badge"
        case .network: return "network"
        case .history: return "clock.arrow.circlepath"
        case .advanced: return "slider.horizontal.3"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Settings View

public struct SettingsView: View {
    @StateObject private var vm = SettingsViewModel()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Window Header with Tab Bar
            HStack(spacing: 6) {
                ForEach(SettingsTab.allCases) { tab in
                    Button(action: {
                        PulseLog.ui.info("⚙️ Ajustes: Pestaña seleccionada: \(tab.rawValue)")
                        withAnimation(.easeInOut(duration: 0.15)) {
                            vm.selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: vm.selectedTab == tab ? .bold : .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(vm.selectedTab == tab ? Color.accentColor : Color.white.opacity(0.06))
                        )
                        .foregroundColor(vm.selectedTab == tab ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Divider().opacity(0.3)

            // Tab Content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    switch vm.selectedTab {
                    case .general:
                        generalSection
                    case .appearance:
                        appearanceSection
                    case .alerts:
                        alertsSection
                    case .network:
                        networkSection
                    case .history:
                        historySection
                    case .advanced:
                        advancedSection
                    case .about:
                        aboutSection
                    }
                }
                .padding(18)
            }
            .frame(minHeight: 400, maxHeight: .infinity)

            Divider().opacity(0.3)

            // Footer
            HStack {
                Spacer()
                Button("Cerrar") { AppDelegate.shared.closeSettings() }
                    .keyboardShortcut(.cancelAction)   // Esc también cierra
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.03))
        }
        .frame(minWidth: 540, minHeight: 520)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Sections

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(label: Label("Muestreo y Rendimiento", systemImage: "speedometer").font(.system(size: 13, weight: .bold))) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Intervalo de Muestreo:", selection: $vm.samplingInterval) {
                        Text("1 segundo (Alta precisión)").tag(1.0)
                        Text("2 segundos (Recomendado)").tag(2.0)
                        Text("5 segundos (Bajo consumo)").tag(5.0)
                    }
                    .pickerStyle(.radioGroup)

                    Divider().opacity(0.3)

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Modo Ahorro Inteligente")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Pulse Monitor incrementa automáticamente el intervalo a 5s cuando tu Mac activa el Modo de Bajo Consumo.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
            }

            GroupBox(label: Label("Sistema y Arranque", systemImage: "macwindow").font(.system(size: 13, weight: .bold))) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Ejecutar Pulse Monitor al iniciar el Mac", isOn: Binding(
                        get: { vm.launchAtLogin },
                        set: { vm.toggleLaunchAtLogin($0) }
                    ))
                    .onAppear {
                        vm.syncLoginItem()
                    }

                    if vm.approvalNeeded {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Apruébalo en Ajustes del Sistema ▸ General ▸ Elementos de inicio")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                            Button("Abrir Ajustes del Sistema") {
                                LoginItem.openApprovalScreen()
                            }
                            .controlSize(.small)
                        }
                        .padding(.top, 4)
                    }

                    Divider().opacity(0.3)

                    HStack {
                        Text("Atajo global para HUD flotante:")
                            .font(.system(size: 12))
                        Spacer()
                        Text("⌥⌘M")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.12)))
                    }

                    HStack {
                        Text("Panel HUD flotante always-on-top:")
                            .font(.system(size: 12))
                        Spacer()
                        Button("Alternar HUD") {
                            uiLog.info("[TEST] 🪟 Toggle HUD pulsado desde Ajustes")
                            AppDelegate.shared?.toggleHUD()
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(label: Label("Barra de Menús", systemImage: "menubar.rectangle").font(.system(size: 13, weight: .bold))) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Métrica que se mostrará junto al icono en la barra superior:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Picker("Mostrar en la barra de menús:", selection: Binding(
                        get: { vm.menuBarDisplayMode },
                        set: {
                            vm.menuBarDisplayMode = $0
                            UserDefaults.standard.set($0, forKey: "menuBarDisplayMode")
                            AppDelegate.shared.updateMenuBarTitle()
                        }
                    )) {
                        Text("CPU (ej. 24 %)").tag("cpu")
                        Text("Memoria (ej. 28.5 GB)").tag("memory")
                        Text("Red (ej. ↓ 2.4 MB/s)").tag("network")
                        Text("Batería (ej. 80 %)").tag("battery")
                        Text("Solo icono").tag("iconOnly")
                    }
                    .pickerStyle(.radioGroup)
                }
                .padding(8)
            }

            GroupBox(label: Label("HUD Flotante", systemImage: "macwindow").font(.system(size: 13, weight: .bold))) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Panel HUD Always-On-Top")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Muestra un mini panel translúcido flotante con las 5 métricas clave.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Alternar HUD") {
                            AppDelegate.shared.toggleHUD()
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(label: Label("Alertas Inteligentes de Hardware", systemImage: "bell.badge").font(.system(size: 13, weight: .bold))) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Activar notificaciones de hardware en tiempo real", isOn: $vm.alertsEnabled)

                    if vm.alertsEnabled {
                        Divider().opacity(0.3)

                        VStack(spacing: 10) {
                            HStack {
                                Text("Alerta de CPU:")
                                    .frame(width: 140, alignment: .leading)
                                Text("> \(Int(vm.cpuAlertThreshold))%")
                                    .font(.system(size: 11, weight: .bold))
                                    .monospacedDigit()
                                    .frame(width: 50, alignment: .trailing)
                                Slider(value: $vm.cpuAlertThreshold, in: 50...98, step: 2)
                            }

                            HStack {
                                Text("Presión de RAM:")
                                    .frame(width: 140, alignment: .leading)
                                Text("> \(Int(vm.memoryAlertThreshold))%")
                                    .font(.system(size: 11, weight: .bold))
                                    .monospacedDigit()
                                    .frame(width: 50, alignment: .trailing)
                                Slider(value: $vm.memoryAlertThreshold, in: 50...98, step: 2)
                            }

                            HStack {
                                Text("Ocupación de Disco:")
                                    .frame(width: 140, alignment: .leading)
                                Text("> \(Int(vm.diskAlertThreshold))%")
                                    .font(.system(size: 11, weight: .bold))
                                    .monospacedDigit()
                                    .frame(width: 50, alignment: .trailing)
                                Slider(value: $vm.diskAlertThreshold, in: 70...98, step: 2)
                            }

                            HStack {
                                Text("Nivel de Batería baja:")
                                    .frame(width: 140, alignment: .leading)
                                Text("< \(Int(vm.batteryAlertThreshold))%")
                                    .font(.system(size: 11, weight: .bold))
                                    .monospacedDigit()
                                    .frame(width: 50, alignment: .trailing)
                                Slider(value: $vm.batteryAlertThreshold, in: 5...30, step: 5)
                            }

                            HStack {
                                Text("Temperatura del SoC:")
                                    .frame(width: 140, alignment: .leading)
                                Text("> \(Int(vm.tempAlertThreshold))°C")
                                    .font(.system(size: 11, weight: .bold))
                                    .monospacedDigit()
                                    .frame(width: 50, alignment: .trailing)
                                Slider(value: $vm.tempAlertThreshold, in: 70...100, step: 2)
                            }
                        }

                        Divider().opacity(0.3)

                        HStack {
                            Button("Enviar Notificación de Prueba") {
                                PulseLog.ui.info("🔔 Ajustes: Enviar Notificación de Prueba pulsado")
                                AlertEngine.shared.triggerTestAlert()
                                withAnimation {
                                    vm.testAlertSent = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                    withAnimation {
                                        vm.testAlertSent = false
                                    }
                                }
                            }

                            if vm.testAlertSent {
                                Label("¡Notificación enviada!", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.green)
                                    .transition(.opacity)
                            }

                            Spacer()
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(label: Label("Control de Cuota Mensual", systemImage: "network").font(.system(size: 13, weight: .bold))) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Configura un límite mensual para vigilar el consumo de datos de tu conexión o tethering.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Text("Límite mensual:")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        TextField("GB", value: $vm.monthlyQuotaGB, format: .number)
                            .frame(width: 90)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                        Text("GB")
                            .font(.system(size: 12, weight: .semibold))
                    }

                    HStack(spacing: 6) {
                        Text("Valores rápidos:")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        ForEach([50.0, 100.0, 200.0, 500.0], id: \.self) { gb in
                            Button("\(Int(gb)) GB") {
                                vm.monthlyQuotaGB = gb
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    Divider().opacity(0.3)

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 13))
                        Text("Pulse Monitor emitirá una alerta preventiva al alcanzar el 80% y una alerta crítica al 100% de la cuota.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(label: Label("Exportación y Registro", systemImage: "externaldrive.badge.timemachine").font(.system(size: 13, weight: .bold))) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pulse Monitor registra métricas de hardware de forma eficiente en almacenamiento local. Puedes exportar el histórico para análisis en hojas de cálculo o herramientas externas.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Button(action: {
                            PulseLog.ui.info("📤 Ajustes: Exportar JSON pulsado")
                            exportHistory(asJSON: true)
                        }) {
                            Label("Exportar JSON", systemImage: "doc.badge.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: {
                            PulseLog.ui.info("📤 Ajustes: Exportar CSV pulsado")
                            exportHistory(asJSON: false)
                        }) {
                            Label("Exportar CSV", systemImage: "tablecells.badge.ellipsis")
                        }
                        .buttonStyle(.bordered)
                    }

                    if let msg = vm.exportMessage {
                        Label(msg, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                            .padding(.top, 4)
                            .transition(.opacity)
                    }
                }
                .padding(8)
            }
        }
    }

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(label: Label("Diagnóstico del Sistema", systemImage: "stethoscope").font(.system(size: 13, weight: .bold))) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Genera un informe completo en texto plano de hardware, CPU, memoria, red y batería.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Button("Copiar Diagnóstico al Portapapeles") {
                        vm.copyDiagnosticReport()
                    }
                    .controlSize(.small)
                }
                .padding(8)
            }

            GroupBox(label: Label("Valores y Copia de Seguridad", systemImage: "arrow.counterclockwise.circle").font(.system(size: 13, weight: .bold))) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Button("Restablecer Valores") {
                            vm.resetToDefaults()
                        }
                        .controlSize(.small)

                        Button("Copiar Ajustes (JSON)") {
                            let json = vm.exportSettingsJSON()
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(json, forType: .string)
                            vm.exportMessage = "Ajustes JSON copiados al portapapeles"
                        }
                        .controlSize(.small)
                    }

                    if let msg = vm.exportMessage {
                        Label(msg, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                            .padding(.top, 4)
                            .transition(.opacity)
                    }
                }
                .padding(8)
            }

            GroupBox(label: Label("Atajos de Teclado Globales", systemImage: "command").font(.system(size: 13, weight: .bold))) {
                VStack(spacing: 6) {
                    HStack {
                        Text("Alternar HUD Flotante:")
                            .font(.system(size: 11))
                        Spacer()
                        Text("⌥⌘M")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    HStack {
                        Text("Abrir Ajustes:")
                            .font(.system(size: 11))
                        Spacer()
                        Text("⌘,")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    HStack {
                        Text("Menú Contextual:")
                            .font(.system(size: 11))
                        Spacer()
                        Text("Clic derecho en icono")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .padding(8)
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
                .padding(.top, 10)

            Text("Pulse Monitor")
                .font(.system(size: 18, weight: .bold))

            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
            Text("Versión \(version) (Build \(build)) · macOS 27.2 / 26+")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Divider().opacity(0.3)

            VStack(alignment: .leading, spacing: 6) {
                Label("100% Local: Cero telemetría, cero analíticas", systemImage: "lock.shield.fill")
                Label("0 Dependencias externas: Swift nativo", systemImage: "apple.terminal.fill")
                Label("10 Widgets interactivos de escritorio para macOS", systemImage: "square.grid.2x2")
                Label("HUD flotante Always-On-Top (⌥⌘M)", systemImage: "macwindow")
                Label("Menú contextual con clic derecho en la barra", systemImage: "cursorarrow.click.2")
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .padding(.horizontal, 20)

            HStack(spacing: 12) {
                Button("Copiar Diagnóstico") {
                    vm.copyDiagnosticReport()
                }
                .controlSize(.small)

                Button("Cerrar") {
                    AppDelegate.shared.closeSettings()
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
    }

    // MARK: - Export

    private func exportHistory(asJSON: Bool) {
        let panel = NSSavePanel()
        let stamp = Formatters.dateStamp()
        panel.nameFieldStringValue = asJSON ? "pulse_history_\(stamp).json" : "pulse_history_\(stamp).csv"
        panel.allowedContentTypes = [asJSON ? .json : .commaSeparatedText]

        if panel.runModal() == .OK, let url = panel.url {
            let content = asJSON ? SystemMonitor.shared.generateHistoryJSON() : SystemMonitor.shared.generateHistoryCSV()
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                withAnimation {
                    vm.exportMessage = "Guardado con éxito en \(url.lastPathComponent)"
                }
            } catch {
                PulseLog.settings.error("Failed to export history: \(error.localizedDescription)")
            }
        }
    }
}

// Backward compatibility alias
public struct SettingsSheetView: View {
    public init(monitor: SystemMonitor) {}
    public var body: some View {
        SettingsView()
    }
}
