import Foundation
import Supabase

enum HRPersonnelService {
    private static let client = SupabaseManager.client

    static func fetchSettings(companyId: UUID) async throws -> HRSettings {
        let rows: [HRSettings] = try await client
            .from("hr_settings")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .limit(1)
            .execute()
            .value
        if var existing = rows.first {
            if existing.schedule.count != 7 {
                existing.schedule = mergedSchedule(existing.schedule)
            }
            return existing
        }
        return HRSettings.defaults(companyId: companyId)
    }

    @discardableResult
    static func saveSettings(_ settings: HRSettings) async throws -> HRSettings {
        let payload = HRSettingsUpsert(from: settings)
        let rows: [HRSettings] = try await client
            .from("hr_settings")
            .upsert(payload, onConflict: "company_id")
            .select()
            .execute()
            .value
        guard var saved = rows.first else { throw ServiceError.invalidResponse }
        if saved.schedule.count != 7 {
            saved.schedule = mergedSchedule(saved.schedule)
        }
        return saved
    }

    static func fetchEmployees(companyId: UUID) async throws -> [HREmployee] {
        try await client
            .from("hr_employees")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .order("full_name", ascending: true)
            .execute()
            .value
    }

    static func createEmployee(_ employee: HREmployee) async throws -> HREmployee {
        let rows: [HREmployee] = try await client
            .from("hr_employees")
            .insert(HREmployeePayload(from: employee))
            .select()
            .execute()
            .value
        guard let created = rows.first else { throw ServiceError.invalidResponse }
        return created
    }

    static func updateEmployee(_ employee: HREmployee) async throws -> HREmployee {
        let rows: [HREmployee] = try await client
            .from("hr_employees")
            .update(HREmployeeUpdate(from: employee))
            .eq("id", value: employee.id.uuidString)
            .select()
            .execute()
            .value
        guard let updated = rows.first else { throw ServiceError.invalidResponse }
        return updated
    }

    static func deleteEmployee(id: UUID) async throws {
        try await client.from("hr_employees").delete().eq("id", value: id.uuidString).execute()
    }

    static func fetchContracts(companyId: UUID) async throws -> [HRContract] {
        try await client
            .from("hr_contracts")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .order("start_date", ascending: false)
            .execute()
            .value
    }

    static func createContract(_ contract: HRContract) async throws -> HRContract {
        let rows: [HRContract] = try await client
            .from("hr_contracts")
            .insert(HRContractPayload(from: contract))
            .select()
            .execute()
            .value
        guard let created = rows.first else { throw ServiceError.invalidResponse }
        return created
    }

    static func updateContract(_ contract: HRContract) async throws -> HRContract {
        let rows: [HRContract] = try await client
            .from("hr_contracts")
            .update(HRContractUpdate(from: contract))
            .eq("id", value: contract.id.uuidString)
            .select()
            .execute()
            .value
        guard let updated = rows.first else { throw ServiceError.invalidResponse }
        return updated
    }

    static func deleteContract(id: UUID) async throws {
        try await client.from("hr_contracts").delete().eq("id", value: id.uuidString).execute()
    }

    static func fetchRun(companyId: UUID, period: HRMonthPeriod) async throws -> HRPayrollRun? {
        let rows: [HRPayrollRun] = try await client
            .from("hr_payroll_runs")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .eq("year", value: period.year)
            .eq("month", value: period.month)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    static func fetchLines(runId: UUID) async throws -> [HRPayrollLine] {
        try await client
            .from("hr_payroll_lines")
            .select()
            .eq("run_id", value: runId.uuidString)
            .execute()
            .value
    }

    static func fetchTimesheet(runId: UUID) async throws -> [HRTimesheetDay] {
        try await client
            .from("hr_timesheet_days")
            .select()
            .eq("run_id", value: runId.uuidString)
            .order("work_date", ascending: true)
            .execute()
            .value
    }

    static func generatePayroll(companyId: UUID, period: HRMonthPeriod) async throws -> HRPayrollRun {
        let settings = try await fetchSettings(companyId: companyId)
        if settings.updatedAt == nil {
            try await saveSettings(settings)
        }
        let contracts = try await fetchContracts(companyId: companyId)
        if let existing = try await fetchRun(companyId: companyId, period: period) {
            if existing.isClosed {
                throw HRServiceError.runClosed
            }
            try await client.from("hr_timesheet_days").delete().eq("run_id", value: existing.id.uuidString).execute()
            try await client.from("hr_payroll_lines").delete().eq("run_id", value: existing.id.uuidString).execute()
            let lines = HRPayrollGenerator.makeLines(run: existing, contracts: contracts, settings: settings)
            if !lines.isEmpty {
                try await client.from("hr_payroll_lines").insert(lines.map(HRPayrollLinePayload.init(from:))).execute()
            }
            return try await updateRunStatus(existing, status: .draft)
        }

        let run = HRPayrollRun(
            id: UUID(),
            companyId: companyId,
            year: period.year,
            month: period.month,
            status: .draft,
            createdAt: nil,
            updatedAt: nil
        )
        let inserted: [HRPayrollRun] = try await client
            .from("hr_payroll_runs")
            .insert(HRPayrollRunPayload(from: run))
            .select()
            .execute()
            .value
        guard let saved = inserted.first else { throw ServiceError.invalidResponse }
        let lines = HRPayrollGenerator.makeLines(run: saved, contracts: contracts, settings: settings)
        if !lines.isEmpty {
            try await client.from("hr_payroll_lines").insert(lines.map(HRPayrollLinePayload.init(from:))).execute()
        }
        return saved
    }

    static func saveLine(_ line: HRPayrollLine) async throws -> HRPayrollLine {
        let rows: [HRPayrollLine] = try await client
            .from("hr_payroll_lines")
            .update(HRPayrollLineUpdate(from: line))
            .eq("id", value: line.id.uuidString)
            .select()
            .execute()
            .value
        guard let updated = rows.first else { throw ServiceError.invalidResponse }
        return updated
    }

    static func updateRunStatus(_ run: HRPayrollRun, status: HRPayrollRunStatus) async throws -> HRPayrollRun {
        let rows: [HRPayrollRun] = try await client
            .from("hr_payroll_runs")
            .update(["status": status.rawValue])
            .eq("id", value: run.id.uuidString)
            .select()
            .execute()
            .value
        guard let updated = rows.first else { throw ServiceError.invalidResponse }
        return updated
    }

    static func generateTimesheet(run: HRPayrollRun, drafts: [HRPayrollLineDraft], settings: HRSettings) async throws {
        if run.isClosed { throw HRServiceError.runClosed }
        try await client.from("hr_timesheet_days").delete().eq("run_id", value: run.id.uuidString).execute()
        let grouped = Dictionary(grouping: drafts, by: { $0.line.employeeId })
        let employeeIds = grouped.keys.sorted { lhs, rhs in
            (grouped[lhs]?.first?.employeeName ?? "") < (grouped[rhs]?.first?.employeeName ?? "")
        }
        let inputs = employeeIds.enumerated().compactMap { index, employeeId -> HRTimesheetGenerator.EmployeeInput? in
            guard let lines = grouped[employeeId] else { return nil }
            return HRTimesheetGenerator.EmployeeInput(
                employeeId: employeeId,
                index: index,
                hoursPerDay: lines.map(\.hoursPerDay).max() ?? 8,
                hoursWorked: lines.reduce(0) { $0 + $1.line.hoursWorked },
                hoursCO: lines.reduce(0) { $0 + $1.line.hoursCO },
                hoursCM: lines.reduce(0) { $0 + $1.line.hoursCM },
                daysCO: lines.reduce(0) { $0 + $1.line.daysCO },
                daysCM: lines.reduce(0) { $0 + $1.line.daysCM }
            )
        }
        let results = HRTimesheetGenerator.generate(period: run.period, schedule: settings.schedule, employees: inputs)
        var days: [HRTimesheetDayPayload] = []
        for result in results {
            for day in result.days {
                days.append(
                    HRTimesheetDayPayload(
                        id: UUID(),
                        runId: run.id,
                        companyId: run.companyId,
                        employeeId: result.employeeId,
                        workDate: SupabaseDecoding.dateOnlyString(from: day.workDate),
                        startTime: day.startTime,
                        endTime: day.endTime,
                        hours: NSDecimalNumber(decimal: day.hours).stringValue,
                        kind: day.kind.rawValue
                    )
                )
            }
            for draft in grouped[result.employeeId] ?? [] {
                var line = draft.line
                line.timesheetError = result.errorMessage
                _ = try await saveLine(line)
            }
        }
        if !days.isEmpty {
            try await client.from("hr_timesheet_days").insert(days).execute()
        }
    }

    static func drafts(
        lines: [HRPayrollLine],
        employees: [HREmployee],
        contracts: [HRContract],
        locations: [CompanyWorkLocation]
    ) -> [HRPayrollLineDraft] {
        let employeesById = Dictionary(uniqueKeysWithValues: employees.map { ($0.id, $0) })
        let contractsById = Dictionary(uniqueKeysWithValues: contracts.map { ($0.id, $0) })
        let locationsById = Dictionary(uniqueKeysWithValues: locations.map { ($0.id, $0) })
        return lines.map { line in
            let employee = employeesById[line.employeeId]
            let contract = contractsById[line.contractId]
            let locationId = contract?.workLocationId ?? employee?.defaultWorkLocationId
            return HRPayrollLineDraft(
                line: line,
                employeeName: employee?.fullName ?? "—",
                employeeCode: employee?.employeeCode ?? "—",
                jobTitle: contract?.jobTitle ?? "—",
                workLocationId: locationId,
                workLocationName: locationId.flatMap { locationsById[$0]?.denumire } ?? "",
                contractGross: contract?.grossSalary ?? line.grossAmount,
                hoursPerDay: contract?.hoursPerDay ?? 8
            )
        }
        .sorted { $0.employeeName.localizedStandardCompare($1.employeeName) == .orderedAscending }
    }

    private static func mergedSchedule(_ existing: [HRWeekdaySchedule]) -> [HRWeekdaySchedule] {
        let defaults = HRWeekdaySchedule.defaultWeek()
        return defaults.map { day in
            existing.first { $0.weekday == day.weekday } ?? day
        }
    }
}

enum HRServiceError: LocalizedError {
    case runClosed

    var errorDescription: String? {
        switch self {
        case .runClosed:
            return L10n.tr("module.hr.error_run_closed")
        }
    }
}

private struct HRSettingsUpsert: Encodable {
    let companyId: UUID
    let schedule: [HRWeekdaySchedule]
    let expenseAccount: String
    let payableAccount: String
    let casAccount: String
    let cassAccount: String
    let taxAccount: String
    let camExpenseAccount: String
    let camAccount: String
    let journal: String
    let firstNoteNumber: Int
    let oneNotePerEmployee: Bool

    enum CodingKeys: String, CodingKey {
        case companyId = "company_id"
        case schedule
        case expenseAccount = "expense_account"
        case payableAccount = "payable_account"
        case casAccount = "cas_account"
        case cassAccount = "cass_account"
        case taxAccount = "tax_account"
        case camExpenseAccount = "cam_expense_account"
        case camAccount = "cam_account"
        case journal
        case firstNoteNumber = "first_note_number"
        case oneNotePerEmployee = "one_note_per_employee"
    }

    init(from settings: HRSettings) {
        companyId = settings.companyId
        schedule = settings.schedule
        expenseAccount = settings.expenseAccount
        payableAccount = settings.payableAccount
        casAccount = settings.casAccount
        cassAccount = settings.cassAccount
        taxAccount = settings.taxAccount
        camExpenseAccount = settings.camExpenseAccount
        camAccount = settings.camAccount
        journal = settings.journal
        firstNoteNumber = settings.firstNoteNumber
        oneNotePerEmployee = settings.oneNotePerEmployee
    }
}

private struct HREmployeePayload: Encodable {
    let id: UUID
    let companyId: UUID
    let employeeCode: String
    let fullName: String
    let cnp: String?
    let iban: String?
    let phone: String?
    let defaultWorkLocationId: UUID?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case companyId = "company_id"
        case employeeCode = "employee_code"
        case fullName = "full_name"
        case cnp, iban, phone
        case defaultWorkLocationId = "default_work_location_id"
        case isActive = "is_active"
    }

    init(from employee: HREmployee) {
        id = employee.id
        companyId = employee.companyId
        employeeCode = employee.employeeCode
        fullName = employee.fullName
        cnp = employee.cnp
        iban = employee.iban
        phone = employee.phone
        defaultWorkLocationId = employee.defaultWorkLocationId
        isActive = employee.isActive
    }
}

private struct HREmployeeUpdate: Encodable {
    let employeeCode: String
    let fullName: String
    let cnp: String?
    let iban: String?
    let phone: String?
    let defaultWorkLocationId: UUID?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case employeeCode = "employee_code"
        case fullName = "full_name"
        case cnp, iban, phone
        case defaultWorkLocationId = "default_work_location_id"
        case isActive = "is_active"
    }

    init(from employee: HREmployee) {
        employeeCode = employee.employeeCode
        fullName = employee.fullName
        cnp = employee.cnp
        iban = employee.iban
        phone = employee.phone
        defaultWorkLocationId = employee.defaultWorkLocationId
        isActive = employee.isActive
    }
}

private struct HRContractPayload: Encodable {
    let id: UUID
    let companyId: UUID
    let employeeId: UUID
    let contractType: String
    let jobTitle: String
    let corCode: String?
    let workLocationId: UUID?
    let startDate: String
    let endDate: String?
    let hoursPerDay: String
    let grossSalary: String

    enum CodingKeys: String, CodingKey {
        case id
        case companyId = "company_id"
        case employeeId = "employee_id"
        case contractType = "contract_type"
        case jobTitle = "job_title"
        case corCode = "cor_code"
        case workLocationId = "work_location_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case hoursPerDay = "hours_per_day"
        case grossSalary = "gross_salary"
    }

    init(from contract: HRContract) {
        id = contract.id
        companyId = contract.companyId
        employeeId = contract.employeeId
        contractType = contract.contractType
        jobTitle = contract.jobTitle
        corCode = contract.corCode
        workLocationId = contract.workLocationId
        startDate = SupabaseDecoding.dateOnlyString(from: contract.startDate)
        endDate = contract.endDate.map { SupabaseDecoding.dateOnlyString(from: $0) }
        hoursPerDay = NSDecimalNumber(decimal: contract.hoursPerDay).stringValue
        grossSalary = NSDecimalNumber(decimal: contract.grossSalary).stringValue
    }
}

private struct HRContractUpdate: Encodable {
    let contractType: String
    let jobTitle: String
    let corCode: String?
    let workLocationId: UUID?
    let startDate: String
    let endDate: String?
    let hoursPerDay: String
    let grossSalary: String

    enum CodingKeys: String, CodingKey {
        case contractType = "contract_type"
        case jobTitle = "job_title"
        case corCode = "cor_code"
        case workLocationId = "work_location_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case hoursPerDay = "hours_per_day"
        case grossSalary = "gross_salary"
    }

    init(from contract: HRContract) {
        contractType = contract.contractType
        jobTitle = contract.jobTitle
        corCode = contract.corCode
        workLocationId = contract.workLocationId
        startDate = SupabaseDecoding.dateOnlyString(from: contract.startDate)
        endDate = contract.endDate.map { SupabaseDecoding.dateOnlyString(from: $0) }
        hoursPerDay = NSDecimalNumber(decimal: contract.hoursPerDay).stringValue
        grossSalary = NSDecimalNumber(decimal: contract.grossSalary).stringValue
    }
}

private struct HRPayrollRunPayload: Encodable {
    let id: UUID
    let companyId: UUID
    let year: Int
    let month: Int
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case companyId = "company_id"
        case year, month, status
    }

    init(from run: HRPayrollRun) {
        id = run.id
        companyId = run.companyId
        year = run.year
        month = run.month
        status = run.status.rawValue
    }
}

private struct HRPayrollLinePayload: Encodable {
    let id: UUID
    let runId: UUID
    let companyId: UUID
    let employeeId: UUID
    let contractId: UUID
    let baseHours: String
    let hoursWorked: String
    let hoursCO: String
    let hoursCM: String
    let daysCO: String
    let daysCM: String
    let bonuses: String
    let otherAdditions: String
        let deductions: String
        let casAmount: String
        let cassAmount: String
        let taxAmount: String
        let camAmount: String
        let grossAmount: String
        let netAmount: String
        let notes: String?
        let timesheetError: String?

        enum CodingKeys: String, CodingKey {
            case id
            case runId = "run_id"
            case companyId = "company_id"
            case employeeId = "employee_id"
            case contractId = "contract_id"
            case baseHours = "base_hours"
            case hoursWorked = "hours_worked"
            case hoursCO = "hours_co"
            case hoursCM = "hours_cm"
            case daysCO = "days_co"
            case daysCM = "days_cm"
            case bonuses
            case otherAdditions = "other_additions"
            case deductions
            case casAmount = "cas_amount"
            case cassAmount = "cass_amount"
            case taxAmount = "tax_amount"
            case camAmount = "cam_amount"
            case grossAmount = "gross_amount"
            case netAmount = "net_amount"
            case notes
            case timesheetError = "timesheet_error"
        }

        init(from line: HRPayrollLine) {
            id = line.id
            runId = line.runId
            companyId = line.companyId
            employeeId = line.employeeId
            contractId = line.contractId
            baseHours = NSDecimalNumber(decimal: line.baseHours).stringValue
            hoursWorked = NSDecimalNumber(decimal: line.hoursWorked).stringValue
            hoursCO = NSDecimalNumber(decimal: line.hoursCO).stringValue
            hoursCM = NSDecimalNumber(decimal: line.hoursCM).stringValue
            daysCO = NSDecimalNumber(decimal: line.daysCO).stringValue
            daysCM = NSDecimalNumber(decimal: line.daysCM).stringValue
            bonuses = NSDecimalNumber(decimal: line.bonuses).stringValue
            otherAdditions = NSDecimalNumber(decimal: line.otherAdditions).stringValue
            deductions = NSDecimalNumber(decimal: line.deductions).stringValue
            casAmount = NSDecimalNumber(decimal: line.casAmount).stringValue
            cassAmount = NSDecimalNumber(decimal: line.cassAmount).stringValue
            taxAmount = NSDecimalNumber(decimal: line.taxAmount).stringValue
            camAmount = NSDecimalNumber(decimal: line.camAmount).stringValue
            grossAmount = NSDecimalNumber(decimal: line.grossAmount).stringValue
            netAmount = NSDecimalNumber(decimal: line.netAmount).stringValue
            notes = line.notes
            timesheetError = line.timesheetError
        }
    }

    private struct HRPayrollLineUpdate: Encodable {
        let hoursWorked: String
        let hoursCO: String
        let hoursCM: String
        let daysCO: String
        let daysCM: String
        let bonuses: String
        let otherAdditions: String
        let deductions: String
        let casAmount: String
        let cassAmount: String
        let taxAmount: String
        let camAmount: String
        let grossAmount: String
        let netAmount: String
        let notes: String?
        let timesheetError: String?

        enum CodingKeys: String, CodingKey {
            case hoursWorked = "hours_worked"
            case hoursCO = "hours_co"
            case hoursCM = "hours_cm"
            case daysCO = "days_co"
            case daysCM = "days_cm"
            case bonuses
            case otherAdditions = "other_additions"
            case deductions
            case casAmount = "cas_amount"
            case cassAmount = "cass_amount"
            case taxAmount = "tax_amount"
            case camAmount = "cam_amount"
            case grossAmount = "gross_amount"
            case netAmount = "net_amount"
            case notes
            case timesheetError = "timesheet_error"
        }

        init(from line: HRPayrollLine) {
            hoursWorked = NSDecimalNumber(decimal: line.hoursWorked).stringValue
            hoursCO = NSDecimalNumber(decimal: line.hoursCO).stringValue
            hoursCM = NSDecimalNumber(decimal: line.hoursCM).stringValue
            daysCO = NSDecimalNumber(decimal: line.daysCO).stringValue
            daysCM = NSDecimalNumber(decimal: line.daysCM).stringValue
            bonuses = NSDecimalNumber(decimal: line.bonuses).stringValue
            otherAdditions = NSDecimalNumber(decimal: line.otherAdditions).stringValue
            deductions = NSDecimalNumber(decimal: line.deductions).stringValue
            casAmount = NSDecimalNumber(decimal: line.casAmount).stringValue
            cassAmount = NSDecimalNumber(decimal: line.cassAmount).stringValue
            taxAmount = NSDecimalNumber(decimal: line.taxAmount).stringValue
            camAmount = NSDecimalNumber(decimal: line.camAmount).stringValue
            grossAmount = NSDecimalNumber(decimal: line.grossAmount).stringValue
            netAmount = NSDecimalNumber(decimal: line.netAmount).stringValue
            notes = line.notes
            timesheetError = line.timesheetError
        }
    }

private struct HRTimesheetDayPayload: Encodable {
    let id: UUID
    let runId: UUID
    let companyId: UUID
    let employeeId: UUID
    let workDate: String
    let startTime: String?
    let endTime: String?
    let hours: String
    let kind: String

    enum CodingKeys: String, CodingKey {
        case id
        case runId = "run_id"
        case companyId = "company_id"
        case employeeId = "employee_id"
        case workDate = "work_date"
        case startTime = "start_time"
        case endTime = "end_time"
        case hours, kind
    }
}
