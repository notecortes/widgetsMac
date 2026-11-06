import Foundation
import EventKit

public actor CalendarEngine {
    public static let shared = CalendarEngine()

    private let store = EKEventStore()

    private init() {}

    public func sample() async -> CalendarSnapshot {
        var snapshot = CalendarSnapshot()

        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .notDetermined {
            do {
                _ = try await store.requestFullAccessToEvents()
            } catch {
                return snapshot
            }
        } else if status != .fullAccess {
            return snapshot
        }

        let now = Date()
        let end = Calendar.current.date(byAdding: .hour, value: 24, to: now) ?? now.addingTimeInterval(86400)
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let events = store.events(matching: predicate)

        var eventInfos: [CalendarEventInfo] = []

        for e in events {
            let meetingUrl = extractMeetingURL(from: e)
            let info = CalendarEventInfo(
                id: e.eventIdentifier ?? UUID().uuidString,
                title: e.title ?? "Evento",
                startDate: e.startDate,
                endDate: e.endDate,
                isAllDay: e.isAllDay,
                meetingURL: meetingUrl,
                location: e.location
            )
            eventInfos.append(info)

            // Look for first upcoming meeting with video URL
            if snapshot.nextMeetingURL == nil && meetingUrl != nil && e.startDate >= now {
                snapshot.nextMeetingURL = meetingUrl
                snapshot.nextMeetingTitle = e.title
                snapshot.minutesUntilNextMeeting = info.minutesUntilStart
            }
        }

        eventInfos.sort { $0.startDate < $1.startDate }
        snapshot.upcomingEvents = eventInfos

        return snapshot
    }

    private func extractMeetingURL(from event: EKEvent) -> String? {
        if let url = event.url?.absoluteString, isVideoMeetingURL(url) {
            return url
        }
        if let location = event.location, let found = findMeetingURL(in: location) {
            return found
        }
        if let notes = event.notes, let found = findMeetingURL(in: notes) {
            return found
        }
        return nil
    }

    private func findMeetingURL(in text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) ?? []
        for match in matches {
            if let range = Range(match.range, in: text) {
                let candidate = String(text[range])
                if isVideoMeetingURL(candidate) {
                    return candidate
                }
            }
        }
        return nil
    }

    private func isVideoMeetingURL(_ url: String) -> Bool {
        let lower = url.lowercased()
        return lower.contains("meet.google.com") ||
               lower.contains("zoom.us/j") ||
               lower.contains("teams.microsoft.com") ||
               lower.contains("webex.com")
    }
}
