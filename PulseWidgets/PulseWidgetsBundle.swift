import WidgetKit
import SwiftUI

@main
public struct PulseWidgetsBundle: WidgetBundle {
    public init() {}

    public var body: some Widget {
        DateCalendarWidget()
        WeatherWidget()
        NetworkWidget()
        CPUWidget()
        BatteryWidget()
        MemoryWidget()
        DiskWidget()
        SystemSummaryWidget()
        TopAppsWidget()
        ThermalFansWidget()
    }
}
