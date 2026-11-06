import WidgetKit
import SwiftUI
// import PulseCore

public struct DateCalendarWidget: Widget {
    public let kind: String = "com.pulse.widget.datecalendar"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseTimelineProvider()) { entry in
            WidgetContainerView(snapshot: entry.snapshot) { snapshot in
                DateCalendarWidgetView(snapshot: snapshot)
            }
        }
        .configurationDisplayName("Fecha y Calendario")
        .description("Muestra la fecha destacada y los próximos eventos o reuniones.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

public struct DateCalendarWidgetView: View {
    @Environment(\.widgetFamily) var family
    public let snapshot: SystemSnapshot

    public var body: some View {
        let now = Date()
        let cal = Calendar.current
        let dayNum = cal.component(.day, from: now)
        let weekdayStr = cal.weekdaySymbols[cal.component(.weekday, from: now) - 1].capitalized
        let monthStr = cal.monthSymbols[cal.component(.month, from: now) - 1].uppercased()

        if family == .systemSmall {
            VStack(alignment: .leading, spacing: 4) {
                Text(weekdayStr)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.red)

                Text("\(dayNum)")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)

                Text(monthStr)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                if let meeting = snapshot.calendar.nextMeetingTitle {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.blue)
                        Text(meeting)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                    }
                }
            }
            .padding(10)
        } else {
            // Medium
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(weekdayStr)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.red)
                    Text("\(dayNum)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(monthStr)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .frame(width: 80, alignment: .leading)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("PRÓXIMOS EVENTOS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)

                    if snapshot.calendar.upcomingEvents.isEmpty {
                        Text("Sin eventos hoy")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(snapshot.calendar.upcomingEvents.prefix(2)) { event in
                            HStack(spacing: 6) {
                                Circle().fill(Color.blue).frame(width: 5, height: 5)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(event.title)
                                        .font(.system(size: 11, weight: .medium))
                                        .lineLimit(1)
                                    Text(event.isAllDay ? "Todo el día" : event.startDate.formatted(date: .omitted, time: .shortened))
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(12)
        }
    }
}
