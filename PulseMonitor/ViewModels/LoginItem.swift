import Foundation
import ServiceManagement
// import PulseCore

public enum LoginItem {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    public static func set(_ on: Bool) throws {
        if on {
            try SMAppService.mainApp.register()
            PulseLog.settings.info("✅ SMAppService.mainApp.register() exitoso")
        } else {
            try SMAppService.mainApp.unregister()
            PulseLog.settings.info("🛑 SMAppService.mainApp.unregister() exitoso")
        }
    }

    public static func openApprovalScreen() {
        PulseLog.settings.info("⚙️ Abriendo Ajustes del Sistema ▸ Elementos de inicio")
        SMAppService.openSystemSettingsLoginItems()
    }
}
