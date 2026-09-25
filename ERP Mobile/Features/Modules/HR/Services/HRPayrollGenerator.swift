import Foundation

enum HRPayrollGenerator {
    static func makeLines(
        run: HRPayrollRun,
        contracts: [HRContract],
        settings: HRSettings,
        calendar: Calendar = .current
    ) -> [HRPayrollLine] {
        let period = run.period
        let openDays = HRScheduleMath.openDays(in: period, schedule: settings.schedule, calendar: calendar)
        let workingWeekdays = settings.schedule.filter(\.isWorking).count
        let payableDays = workingWeekdays >= 6
            ? Decimal(workSlots(dayCount: openDays.count, offset: 0))
            : Decimal(openDays.count)
        return contracts
            .filter { $0.isActive(in: period, calendar: calendar) }
            .sorted { lhs, rhs in
                if lhs.employeeId == rhs.employeeId {
                    return lhs.startDate < rhs.startDate
                }
                return lhs.employeeId.uuidString < rhs.employeeId.uuidString
            }
            .map { contract in
                let baseHours = HRScheduleMath.round2(payableDays * contract.hoursPerDay)
                var line = HRPayrollLine(
                    id: UUID(),
                    runId: run.id,
                    companyId: run.companyId,
                    employeeId: contract.employeeId,
                    contractId: contract.id,
                    baseHours: baseHours,
                    hoursWorked: baseHours,
                    grossAmount: contract.grossSalary,
                    netAmount: contract.grossSalary
                )
                line.recalculate(contractGross: contract.grossSalary, hoursPerDay: contract.hoursPerDay)
                line.applyStatutoryContributions()
                return line
            }
    }

    private static func workSlots(dayCount: Int, offset: Int) -> Int {
        let cycle = [true, true, true, true, true, false, false]
        return (0..<dayCount).filter { cycle[(($0 + offset) % 7 + 7) % 7] }.count
    }
}
