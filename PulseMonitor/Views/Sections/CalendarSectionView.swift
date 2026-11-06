import SwiftUI
import AppKit
// import PulseCore

@MainActor public struct CalendarSectionView: View {
    @ObservedObject public var viewModel: CalendarViewModel
    private var snapshot: CalendarSnapshot { viewModel.snapshot }

    @MainActor public init(viewModel: CalendarViewModel? = nil) {
        self.viewModel = viewModel ?? SystemMonitor.shared.calendarVM
    }

    public init(snapshot: CalendarSnapshot) {
        self.viewModel = CalendarViewModel(snapshot: snapshot)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Next meeting banner with Quick Join Action
            if let meetingURL = snapshot.nextMeetingURL, let title = snapshot.nextMeetingTitle {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "video.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Próxima Reunión")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(title)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                        }

                        Spacer()

                        if let mins = snapshot.minutesUntilNextMeeting {
                            Text(mins > 0 ? "en \(mins) min" : "Ahora")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(mins <= 5 ? .red : .orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill((mins <= 5 ? Color.red : Color.orange).opacity(0.15)))
                        }
                    }

                    Button(action: {
                        PulseLog.ui.info("🎥 Unirse a reunión pulsado: \(meetingURL)")
                        if let url = URL(string: meetingURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.up.right.video.fill")
                            Text("Unirse a la Reunión")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue))
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                .liquidGlassCard()
            }

            // Events List
            VStack(alignment: .leading, spacing: 8) {
                Text("Próximos Eventos (24 Horas)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)

                if snapshot.upcomingEvents.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text("No hay eventos programados")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    ForEach(snapshot.upcomingEvents.prefix(6)) { event in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(event.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)

                                HStack(spacing: 4) {
                                    Text(formatEventTime(event))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)

                                    if let loc = event.location, !loc.isEmpty {
                                        Text("· \(loc)")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }

                            Spacer()

                            if let url = event.meetingURL {
                                Button(action: {
                                    if let u = URL(string: url) {
                                        NSWorkspace.shared.open(u)
                                    }
                                }) {
                                    Image(systemName: "video.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 3)

                        if event.id != snapshot.upcomingEvents.prefix(6).last?.id {
                            Divider().opacity(0.4)
                        }
                    }
                }
            }
            .liquidGlassCard()
        }
    }

    private func formatEventTime(_ event: CalendarEventInfo) -> String {
        if event.isAllDay {
            return "Todo el día"
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
    }
}
