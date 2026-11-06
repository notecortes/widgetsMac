import Foundation
import os.log

public enum PulseLog {
    public static let monitor = Logger(subsystem: "app.pulse", category: "monitor")
    public static let engines = Logger(subsystem: "app.pulse", category: "engines")
    public static let alerts = Logger(subsystem: "app.pulse", category: "alerts")
    public static let widgets = Logger(subsystem: "app.pulse", category: "widgets")
    public static let widget = widgets
    public static let settings = Logger(subsystem: "app.pulse", category: "settings")
    public static let ui = Logger(subsystem: "app.pulse", category: "ui")
}
