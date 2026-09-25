import Foundation
import Testing
@testable import ERPMobile

struct CalendarDateEncodingTests {

    private var bucharest: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Bucharest")!
        return calendar
    }

    @Test func localMidnightInRomaniaKeepsTheChosenDay() {
        let date = bucharest.date(from: DateComponents(year: 2026, month: 8, day: 5))!
        #expect(SupabaseDecoding.dateOnlyString(from: date, calendar: bucharest) == "2026-08-05")
    }

    @Test func dateOnlyStringDoesNotUseUTCAndShiftBackADay() {
        let localMidnight = bucharest.date(from: DateComponents(year: 2026, month: 8, day: 5))!
        // 5 Aug 00:00 EEST == 4 Aug 21:00 UTC — UTC formatters used to write 2026-08-04.
        #expect(SupabaseDecoding.dateOnlyString(from: localMidnight, calendar: bucharest) == "2026-08-05")
    }

    @Test func dateOnlyParseRoundTripsTheCalendarDayInRomania() throws {
        let parsed = SupabaseDecoding.parseDate("2026-08-05", calendar: bucharest)
        let date = try #require(parsed)
        let parts = bucharest.dateComponents([.year, .month, .day], from: date)
        #expect(parts.year == 2026)
        #expect(parts.month == 8)
        #expect(parts.day == 5)
        #expect(SupabaseDecoding.dateOnlyString(from: date, calendar: bucharest) == "2026-08-05")
    }

    @Test func utcMidnightStillMapsToTheSameCalendarDayInRomania() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let utcMidnight = utc.date(from: DateComponents(year: 2026, month: 8, day: 5))!
        #expect(SupabaseDecoding.dateOnlyString(from: utcMidnight, calendar: bucharest) == "2026-08-05")
    }
}
