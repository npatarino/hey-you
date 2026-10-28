import Foundation
@testable import HeyYouKit

/// Europe/Madrid, as in PRD annex B.
let madrid: TimeZone = {
    guard let zone = TimeZone(identifier: "Europe/Madrid") else { fatalError("missing tz") }
    return zone
}()

var madridCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = madrid
    calendar.firstWeekday = 2
    return calendar
}

/// Parses "2026-11-03 10:58:30" (or without seconds) in Europe/Madrid.
func date(_ string: String) -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = madrid
    formatter.dateFormat = string.count > 16 ? "yyyy-MM-dd HH:mm:ss" : "yyyy-MM-dd HH:mm"
    guard let date = formatter.date(from: string) else { fatalError("bad date \(string)") }
    return date
}

func url(_ string: String) -> URL {
    guard let url = URL(string: string) else { fatalError("bad url \(string)") }
    return url
}

let meetLink = MeetingLink(provider: .googleMeet, url: url("https://meet.google.com/abc-defg-hij"))
let zoomLink = MeetingLink(provider: .zoom, url: url("https://zoom.us/j/91234567890?pwd=abc"))

extension CalendarEvent {
    static func fixture(
        id: String? = nil,
        title: String,
        start: String,
        end: String? = nil,
        isAllDay: Bool = false,
        link: MeetingLink? = meetLink,
        status: AttendeeStatus = .accepted,
        others: Bool = true,
        calendarID: String = "primary"
    ) -> CalendarEvent {
        let startDate = date(start)
        return CalendarEvent(
            id: id ?? title,
            calendarID: calendarID,
            title: title,
            start: startDate,
            end: end.map(date) ?? startDate.addingTimeInterval(30 * 60),
            isAllDay: isAllDay,
            meetingLink: link,
            attendeeStatus: status,
            hasOtherAttendees: others,
            htmlLink: url("https://calendar.google.com/event?eid=\(id ?? title)")
        )
    }
}

let free = EffectiveSettings(AppSettings(), isPro: false)

func pro(_ configure: (inout AppSettings) -> Void = { _ in }) -> EffectiveSettings {
    var settings = AppSettings()
    settings.applyProDefaults()
    configure(&settings)
    return EffectiveSettings(settings, isPro: true)
}
