import Foundation
import Testing
@testable import ERPMobile

struct HRPersonnelTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Bucharest")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    private var september2026: HRMonthPeriod { HRMonthPeriod(year: 2026, month: 9) }

    @Test func weekdayHoursAreEight() {
        #expect(HRScheduleMath.hours(from: "09:00", to: "17:00") == 8)
        #expect(HRScheduleMath.endTime(from: "09:00", hours: 4) == "13:00")
    }

    @Test func mondayFridayOpenDaysInSeptember2026() {
        let days = HRScheduleMath.openDays(
            in: september2026,
            schedule: HRWeekdaySchedule.defaultWeek(),
            calendar: calendar
        )
        #expect(days.count == 22)
    }

    @Test func payrollUsesAllOpenDaysWhenFirmWorksFiveDays() {
        let run = HRPayrollRun(
            id: UUID(),
            companyId: UUID(),
            year: 2026,
            month: 9,
            status: .draft
        )
        let contract = HRContract(
            id: UUID(),
            companyId: run.companyId,
            employeeId: UUID(),
            contractType: HRContractType.cim.rawValue,
            jobTitle: "Vânzător",
            startDate: date(2026, 1, 1),
            hoursPerDay: 8,
            grossSalary: 5000
        )
        var settings = HRSettings.defaults(companyId: run.companyId)
        settings.schedule = HRWeekdaySchedule.defaultWeek()
        let lines = HRPayrollGenerator.makeLines(run: run, contracts: [contract], settings: settings, calendar: calendar)
        #expect(lines.count == 1)
        #expect(lines[0].baseHours == 176)
        #expect(lines[0].hoursWorked == 176)
        #expect(lines[0].grossAmount == 5000)
        #expect(lines[0].casAmount == 1250)
        #expect(lines[0].cassAmount == 500)
        #expect(lines[0].taxAmount == 325)
        #expect(lines[0].camAmount == Decimal(string: "112.5")!)
        #expect(lines[0].netAmount == 2925)
    }

    @Test func payrollLineRecalcSubtractsLeave() {
        var line = HRPayrollLine(
            id: UUID(),
            runId: UUID(),
            companyId: UUID(),
            employeeId: UUID(),
            contractId: UUID(),
            baseHours: 176,
            hoursWorked: 176,
            grossAmount: 5000,
            netAmount: 5000
        )
        line.daysCO = 2
        line.bonuses = 200
        line.deductions = 100
        line.recalculate(contractGross: 5000, hoursPerDay: 8)
        #expect(line.hoursCO == 16)
        #expect(line.hoursWorked == 160)
        #expect(line.grossAmount == 5200)
        #expect(line.netAmount == 5100)
    }

    @Test func timesheetPlacesHoursAndIntervalsOnWeekdays() {
        let employeeId = UUID()
        let results = HRTimesheetGenerator.generate(
            period: september2026,
            schedule: HRWeekdaySchedule.defaultWeek(),
            employees: [
                HRTimesheetGenerator.EmployeeInput(
                    employeeId: employeeId,
                    index: 0,
                    hoursPerDay: 8,
                    hoursWorked: 176,
                    hoursCO: 0,
                    hoursCM: 0,
                    daysCO: 0,
                    daysCM: 0
                )
            ],
            calendar: calendar
        )
        #expect(results.count == 1)
        #expect(results[0].errorMessage == nil)
        let work = results[0].days.filter { $0.kind == .work }
        #expect(work.count == 22)
        #expect(work.allSatisfy { $0.startTime == "09:00" && $0.endTime == "17:00" })
        #expect(work.reduce(0) { $0 + $1.hours } == 176)
    }

    @Test func timesheetSevenDayWeekUsesFivePlusTwoAndStaggers() {
        let schedule = (1...7).map {
            HRWeekdaySchedule(weekday: $0, isWorking: true, startTime: "09:00", endTime: "17:00")
        }
        let first = UUID()
        let second = UUID()
        let openCount = HRScheduleMath.openDays(in: september2026, schedule: schedule, calendar: calendar).count
        #expect(openCount == 30)
        let workSlots = (0..<30).filter { [true, true, true, true, true, false, false][$0 % 7] }.count
        let hours = Decimal(workSlots) * 8
        let results = HRTimesheetGenerator.generate(
            period: september2026,
            schedule: schedule,
            employees: [
                HRTimesheetGenerator.EmployeeInput(
                    employeeId: first, index: 0, hoursPerDay: 8, hoursWorked: hours,
                    hoursCO: 0, hoursCM: 0, daysCO: 0, daysCM: 0
                ),
                HRTimesheetGenerator.EmployeeInput(
                    employeeId: second, index: 1, hoursPerDay: 8, hoursWorked: hours,
                    hoursCO: 0, hoursCM: 0, daysCO: 0, daysCM: 0
                )
            ],
            calendar: calendar
        )
        #expect(results.allSatisfy { $0.errorMessage == nil })
        let firstRest = results[0].days.filter { $0.kind == .rest }.map(\.workDate)
        let secondRest = results[1].days.filter { $0.kind == .rest }.map(\.workDate)
        #expect(!firstRest.isEmpty)
        #expect(Set(firstRest) != Set(secondRest))
        #expect(results[0].days.filter { $0.kind == .work }.reduce(0) { $0 + $1.hours } == hours)
    }

    @Test func timesheetErrorsWhenHoursExceedFivePlusTwoSlots() {
        let schedule = (1...7).map {
            HRWeekdaySchedule(weekday: $0, isWorking: true, startTime: "09:00", endTime: "17:00")
        }
        let results = HRTimesheetGenerator.generate(
            period: september2026,
            schedule: schedule,
            employees: [
                HRTimesheetGenerator.EmployeeInput(
                    employeeId: UUID(),
                    index: 0,
                    hoursPerDay: 8,
                    hoursWorked: 240,
                    hoursCO: 0,
                    hoursCM: 0,
                    daysCO: 0,
                    daysCM: 0
                )
            ],
            calendar: calendar
        )
        #expect(results[0].errorMessage != nil)
    }

    @Test func journalWritesSalaryDebitCreditPair() {
        let run = HRPayrollRun(id: UUID(), companyId: UUID(), year: 2026, month: 9, status: .draft)
        var line = HRPayrollLine(
            id: UUID(),
            runId: run.id,
            companyId: run.companyId,
            employeeId: UUID(),
            contractId: UUID(),
            baseHours: 176,
            hoursWorked: 176,
            grossAmount: 5000,
            netAmount: 5000
        )
        line.applyStatutoryContributions()
        let draft = HRPayrollLineDraft(
            line: line,
            employeeName: "Ion Pop",
            employeeCode: "1001",
            jobTitle: "Vânzător",
            workLocationId: nil,
            workLocationName: "",
            contractGross: 5000,
            hoursPerDay: 8
        )
        let entries = HRPayrollJournalBuilder.build(
            run: run,
            drafts: [draft],
            settings: HRSettings.defaults(companyId: run.companyId),
            calendar: calendar
        )
        #expect(entries.map(\.account) == [
            "641", "421",
            "421", "444",
            "421", "4315",
            "421", "4316",
            "6461", "436"
        ])
        #expect(entries.map(\.amount) == [
            5000, 5000,
            325, 325,
            1250, 1250,
            500, 500,
            Decimal(string: "112.5")!, Decimal(string: "112.5")!
        ])
        #expect(entries[0].employeeCode == "1001")
        let collected = HRPayrollNCUniqueAccountCollector.exportEntries(entries, style: .collectedUniqueAccount)
        #expect(collected.map(\.account) == [
            "641", "421",
            "421", "444", "444", "4311",
            "421", "4315", "4315", "4311",
            "421", "4316", "4316", "4311",
            "6461", "436", "436", "4311"
        ])
        #expect(HRPayrollNextUpExporter.headers.count == 21)
        #expect(HRPayrollNextUpExporter.headers[8] == "Debit/credit")
        #expect(HRPayrollNextUpExporter.headers[9] == "Marca")
        #expect(HRPayrollNextUpExporter.headers[16] == "Partener- Cod fiscal")
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
