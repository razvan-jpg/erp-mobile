import Foundation

enum HRTimesheetGenerator {
    private static let hourTolerance = Decimal(string: "0.01") ?? 0.01

    struct EmployeeInput: Sendable {
        var employeeId: UUID
        var index: Int
        var hoursPerDay: Decimal
        var hoursWorked: Decimal
        var hoursCO: Decimal
        var hoursCM: Decimal
        var daysCO: Decimal
        var daysCM: Decimal
    }

    static func generate(
        period: HRMonthPeriod,
        schedule: [HRWeekdaySchedule],
        employees: [EmployeeInput],
        calendar: Calendar = .current
    ) -> [HRTimesheetEmployeeResult] {
        let openDays = HRScheduleMath.openDays(in: period, schedule: schedule, calendar: calendar)
        guard !openDays.isEmpty else {
            return employees.map {
                HRTimesheetEmployeeResult(
                    employeeId: $0.employeeId,
                    days: [],
                    errorMessage: L10n.tr("module.hr.timesheet_error_no_open_days")
                )
            }
        }

        var results = employees.map { input in
            assign(input: input, openDays: openDays, schedule: schedule, calendar: calendar)
        }

        if employees.count > 1, schedule.filter(\.isWorking).count >= 6 {
            applyCoverage(
                results: &results,
                employees: employees,
                openDays: openDays,
                schedule: schedule,
                calendar: calendar
            )
        }
        return results
    }

    private static func assign(
        input: EmployeeInput,
        openDays: [Date],
        schedule: [HRWeekdaySchedule],
        calendar: Calendar,
        offsetOverride: Int? = nil
    ) -> HRTimesheetEmployeeResult {
        let offset = offsetOverride ?? ((input.index * 2) % 7)
        let usesRotation = schedule.filter(\.isWorking).count >= 6
        let pattern = usesRotation
            ? workPattern(dayCount: openDays.count, offset: offset)
            : Array(repeating: true, count: openDays.count)
        var remainingCO = resolvedAbsenceHours(hours: input.hoursCO, days: input.daysCO, hoursPerDay: input.hoursPerDay)
        var remainingCM = resolvedAbsenceHours(hours: input.hoursCM, days: input.daysCM, hoursPerDay: input.hoursPerDay)
        var remainingWork = HRScheduleMath.round2(max(0, input.hoursWorked))

        var slots: [HRTimesheetDraftDay] = []
        for (index, date) in openDays.enumerated() {
            let daySchedule = schedule.first { $0.weekday == HRScheduleMath.isoWeekday(for: date, calendar: calendar) }
            let daily = daySchedule?.dailyHours ?? input.hoursPerDay
            let start = daySchedule?.startTime ?? "09:00"
            let end = daySchedule?.endTime ?? "17:00"
            let isWorkSlot = pattern[index]

            if remainingCO > hourTolerance {
                let used = min(remainingCO, daily)
                slots.append(day(date, start: start, end: used < daily ? HRScheduleMath.endTime(from: start, hours: used) : end, hours: used, kind: .co))
                remainingCO = HRScheduleMath.round2(remainingCO - used)
                continue
            }
            if remainingCM > hourTolerance {
                let used = min(remainingCM, daily)
                slots.append(day(date, start: start, end: used < daily ? HRScheduleMath.endTime(from: start, hours: used) : end, hours: used, kind: .cm))
                remainingCM = HRScheduleMath.round2(remainingCM - used)
                continue
            }
            if !isWorkSlot {
                slots.append(day(date, start: nil, end: nil, hours: 0, kind: .rest))
                continue
            }
            if remainingWork > hourTolerance {
                let used = min(remainingWork, daily)
                slots.append(day(date, start: start, end: used < daily ? HRScheduleMath.endTime(from: start, hours: used) : end, hours: used, kind: .work))
                remainingWork = HRScheduleMath.round2(remainingWork - used)
            } else {
                slots.append(day(date, start: nil, end: nil, hours: 0, kind: .rest))
            }
        }

        var error: String?
        if remainingCO > hourTolerance || remainingCM > hourTolerance {
            error = L10n.tr("module.hr.timesheet_error_absence")
        } else if remainingWork > hourTolerance {
            error = L10n.tr("module.hr.timesheet_error_hours")
        }
        return HRTimesheetEmployeeResult(employeeId: input.employeeId, days: slots, errorMessage: error)
    }

    private static func applyCoverage(
        results: inout [HRTimesheetEmployeeResult],
        employees: [EmployeeInput],
        openDays: [Date],
        schedule: [HRWeekdaySchedule],
        calendar: Calendar
    ) {
        let active = employees.enumerated().compactMap { index, input -> Int? in
            results[index].errorMessage == nil && input.hoursWorked > hourTolerance ? index : nil
        }
        guard active.count > 1 else { return }

        for (dayIndex, date) in openDays.enumerated() {
            let allAbsent = active.allSatisfy { index in
                guard results[index].days.indices.contains(dayIndex) else { return false }
                let kind = results[index].days[dayIndex].kind
                return kind == .co || kind == .cm
            }
            if allAbsent { continue }
            if isCovered(results: results, dayIndex: dayIndex, active: active) { continue }
            var covered = false
            for employeeIndex in active {
                guard results[employeeIndex].errorMessage == nil else { continue }
                for offset in 0..<7 {
                    let candidate = assign(
                        input: employees[employeeIndex],
                        openDays: openDays,
                        schedule: schedule,
                        calendar: calendar,
                        offsetOverride: offset
                    )
                    guard candidate.errorMessage == nil else { continue }
                    var trial = results
                    trial[employeeIndex] = candidate
                    if isCovered(results: trial, dayIndex: dayIndex, active: active) {
                        results[employeeIndex] = candidate
                        covered = true
                        break
                    }
                }
                if covered { break }
            }
            if !covered {
                if let first = active.first {
                    results[first].errorMessage = L10n.tr(
                        "module.hr.timesheet_error_coverage",
                        SupplierFormatting.date(date)
                    )
                }
                return
            }
        }
    }

    private static func isCovered(results: [HRTimesheetEmployeeResult], dayIndex: Int, active: [Int]) -> Bool {
        active.contains { index in
            guard results[index].days.indices.contains(dayIndex) else { return false }
            return results[index].days[dayIndex].kind == .work
        }
    }

    private static func workPattern(dayCount: Int, offset: Int) -> [Bool] {
        let cycle = [true, true, true, true, true, false, false]
        return (0..<dayCount).map { cycle[(($0 + offset) % 7 + 7) % 7] }
    }

    private static func resolvedAbsenceHours(hours: Decimal, days: Decimal, hoursPerDay: Decimal) -> Decimal {
        if days > 0 {
            return HRScheduleMath.round2(days * hoursPerDay)
        }
        return HRScheduleMath.round2(max(0, hours))
    }

    private static func day(
        _ date: Date,
        start: String?,
        end: String?,
        hours: Decimal,
        kind: HRTimesheetKind
    ) -> HRTimesheetDraftDay {
        HRTimesheetDraftDay(workDate: date, startTime: start, endTime: end, hours: hours, kind: kind)
    }
}
