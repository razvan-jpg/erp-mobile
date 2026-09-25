import Foundation

enum HRPayrollRunStatus: String, Codable, Sendable {
    case draft
    case ready
    case closed
}

enum HRTimesheetKind: String, Codable, Sendable {
    case work
    case co
    case cm
    case rest

    var labelKey: String {
        switch self {
        case .work: return "module.hr.kind_work"
        case .co: return "module.hr.kind_co"
        case .cm: return "module.hr.kind_cm"
        case .rest: return "module.hr.kind_rest"
        }
    }
}

enum HRContractType: String, Codable, CaseIterable, Identifiable, Sendable {
    case cim
    case determined
    case partTime

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .cim: return "module.hr.contract_cim"
        case .determined: return "module.hr.contract_determined"
        case .partTime: return "module.hr.contract_part_time"
        }
    }
}

struct HRWeekdaySchedule: Codable, Equatable, Identifiable, Sendable {
    var weekday: Int
    var isWorking: Bool
    var startTime: String
    var endTime: String

    var id: Int { weekday }

    enum CodingKeys: String, CodingKey {
        case weekday
        case isWorking
        case startTime
        case endTime
    }

    var dailyHours: Decimal {
        HRScheduleMath.hours(from: startTime, to: endTime)
    }

    static func defaultWeek() -> [HRWeekdaySchedule] {
        (1...7).map { weekday in
            HRWeekdaySchedule(
                weekday: weekday,
                isWorking: weekday <= 5,
                startTime: "09:00",
                endTime: "17:00"
            )
        }
    }
}

struct HRSettings: Codable, Identifiable, Sendable {
    var companyId: UUID
    var schedule: [HRWeekdaySchedule]
    var expenseAccount: String
    var payableAccount: String
    var casAccount: String
    var cassAccount: String
    var taxAccount: String
    var camExpenseAccount: String
    var camAccount: String
    var journal: String
    var firstNoteNumber: Int
    var oneNotePerEmployee: Bool
    var createdAt: Date? = nil
    var updatedAt: Date? = nil

    var id: UUID { companyId }

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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static func defaults(companyId: UUID) -> HRSettings {
        HRSettings(
            companyId: companyId,
            schedule: HRWeekdaySchedule.defaultWeek(),
            expenseAccount: "641",
            payableAccount: "421",
            casAccount: "4315",
            cassAccount: "4316",
            taxAccount: "444",
            camExpenseAccount: "6461",
            camAccount: "436",
            journal: "OD",
            firstNoteNumber: 1,
            oneNotePerEmployee: false,
            createdAt: nil,
            updatedAt: nil
        )
    }

    func schedule(forISOWeekday weekday: Int) -> HRWeekdaySchedule? {
        schedule.first { $0.weekday == weekday }
    }
}

struct HREmployee: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var companyId: UUID
    var employeeCode: String
    var fullName: String
    var cnp: String?
    var iban: String?
    var phone: String?
    var defaultWorkLocationId: UUID?
    var isActive: Bool
    var createdAt: Date? = nil
    var updatedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case companyId = "company_id"
        case employeeCode = "employee_code"
        case fullName = "full_name"
        case cnp, iban, phone
        case defaultWorkLocationId = "default_work_location_id"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct HRContract: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var companyId: UUID
    var employeeId: UUID
    var contractType: String
    var jobTitle: String
    var corCode: String?
    var workLocationId: UUID?
    var startDate: Date
    var endDate: Date?
    @SupabaseDecimal var hoursPerDay: Decimal
    @SupabaseDecimal var grossSalary: Decimal
    var createdAt: Date?
    var updatedAt: Date?

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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID,
        companyId: UUID,
        employeeId: UUID,
        contractType: String,
        jobTitle: String,
        corCode: String? = nil,
        workLocationId: UUID? = nil,
        startDate: Date,
        endDate: Date? = nil,
        hoursPerDay: Decimal,
        grossSalary: Decimal,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.companyId = companyId
        self.employeeId = employeeId
        self.contractType = contractType
        self.jobTitle = jobTitle
        self.corCode = corCode
        self.workLocationId = workLocationId
        self.startDate = startDate
        self.endDate = endDate
        self.hoursPerDay = hoursPerDay
        self.grossSalary = grossSalary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func isActive(in period: HRMonthPeriod, calendar: Calendar = .current) -> Bool {
        let range = period.dateInterval(calendar: calendar)
        if startDate > range.end { return false }
        if let endDate, endDate < range.start { return false }
        return true
    }
}

struct HRPayrollRun: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var companyId: UUID
    var year: Int
    var month: Int
    var status: HRPayrollRunStatus
    var createdAt: Date? = nil
    var updatedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case companyId = "company_id"
        case year, month, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var period: HRMonthPeriod { HRMonthPeriod(year: year, month: month) }

    var isClosed: Bool { status == .closed }
}

struct HRPayrollLine: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var runId: UUID
    var companyId: UUID
    var employeeId: UUID
    var contractId: UUID
    @SupabaseDecimal var baseHours: Decimal
    @SupabaseDecimal var hoursWorked: Decimal
    @SupabaseDecimal var hoursCO: Decimal
    @SupabaseDecimal var hoursCM: Decimal
    @SupabaseDecimal var daysCO: Decimal
    @SupabaseDecimal var daysCM: Decimal
    @SupabaseDecimal var bonuses: Decimal
    @SupabaseDecimal var otherAdditions: Decimal
    @SupabaseDecimal var deductions: Decimal
    @SupabaseDecimal var casAmount: Decimal
    @SupabaseDecimal var cassAmount: Decimal
    @SupabaseDecimal var taxAmount: Decimal
    @SupabaseDecimal var camAmount: Decimal
    @SupabaseDecimal var grossAmount: Decimal
    @SupabaseDecimal var netAmount: Decimal
    var notes: String?
    var timesheetError: String?
    var createdAt: Date?
    var updatedAt: Date?

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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID,
        runId: UUID,
        companyId: UUID,
        employeeId: UUID,
        contractId: UUID,
        baseHours: Decimal,
        hoursWorked: Decimal,
        hoursCO: Decimal = 0,
        hoursCM: Decimal = 0,
        daysCO: Decimal = 0,
        daysCM: Decimal = 0,
        bonuses: Decimal = 0,
        otherAdditions: Decimal = 0,
        deductions: Decimal = 0,
        casAmount: Decimal = 0,
        cassAmount: Decimal = 0,
        taxAmount: Decimal = 0,
        camAmount: Decimal = 0,
        grossAmount: Decimal,
        netAmount: Decimal,
        notes: String? = nil,
        timesheetError: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.runId = runId
        self.companyId = companyId
        self.employeeId = employeeId
        self.contractId = contractId
        self.baseHours = baseHours
        self.hoursWorked = hoursWorked
        self.hoursCO = hoursCO
        self.hoursCM = hoursCM
        self.daysCO = daysCO
        self.daysCM = daysCM
        self.bonuses = bonuses
        self.otherAdditions = otherAdditions
        self.deductions = deductions
        self.casAmount = casAmount
        self.cassAmount = cassAmount
        self.taxAmount = taxAmount
        self.camAmount = camAmount
        self.grossAmount = grossAmount
        self.netAmount = netAmount
        self.notes = notes
        self.timesheetError = timesheetError
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    mutating func recalculate(contractGross: Decimal, hoursPerDay: Decimal) {
        if daysCO > 0 {
            hoursCO = HRScheduleMath.round2(daysCO * hoursPerDay)
        }
        if daysCM > 0 {
            hoursCM = HRScheduleMath.round2(daysCM * hoursPerDay)
        }
        hoursWorked = max(0, HRScheduleMath.round2(baseHours - hoursCO - hoursCM))
        grossAmount = HRScheduleMath.round2(contractGross + bonuses + otherAdditions)
        netAmount = max(0, HRScheduleMath.round2(grossAmount - deductions - casAmount - cassAmount - taxAmount))
    }

    mutating func applyStatutoryContributions() {
        let amounts = HRPayrollStatutoryRates.computed(gross: grossAmount)
        casAmount = amounts.cas
        cassAmount = amounts.cass
        taxAmount = amounts.tax
        camAmount = amounts.cam
        netAmount = max(0, HRScheduleMath.round2(grossAmount - deductions - casAmount - cassAmount - taxAmount))
    }
}

enum HRPayrollStatutoryRates {
    static let cas: Decimal = Decimal(string: "0.25")!
    static let cass: Decimal = Decimal(string: "0.10")!
    static let tax: Decimal = Decimal(string: "0.10")!
    static let cam: Decimal = Decimal(string: "0.0225")!

    struct Amounts {
        var cas: Decimal
        var cass: Decimal
        var tax: Decimal
        var cam: Decimal
    }

    static func computed(gross: Decimal) -> Amounts {
        let casAmount = HRScheduleMath.round2(gross * cas)
        let cassAmount = HRScheduleMath.round2(gross * cass)
        let taxAmount = HRScheduleMath.round2(max(0, gross - casAmount - cassAmount) * tax)
        let camAmount = HRScheduleMath.round2(gross * cam)
        return Amounts(cas: casAmount, cass: cassAmount, tax: taxAmount, cam: camAmount)
    }

    static func amounts(for line: HRPayrollLine) -> Amounts {
        let computed = computed(gross: line.grossAmount)
        return Amounts(
            cas: line.casAmount > 0 ? line.casAmount : computed.cas,
            cass: line.cassAmount > 0 ? line.cassAmount : computed.cass,
            tax: line.taxAmount > 0 ? line.taxAmount : computed.tax,
            cam: line.camAmount > 0 ? line.camAmount : computed.cam
        )
    }
}

struct HRTimesheetDay: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var runId: UUID
    var companyId: UUID
    var employeeId: UUID
    var workDate: Date
    var startTime: String?
    var endTime: String?
    @SupabaseDecimal var hours: Decimal
    var kind: HRTimesheetKind
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case runId = "run_id"
        case companyId = "company_id"
        case employeeId = "employee_id"
        case workDate = "work_date"
        case startTime = "start_time"
        case endTime = "end_time"
        case hours, kind
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID,
        runId: UUID,
        companyId: UUID,
        employeeId: UUID,
        workDate: Date,
        startTime: String?,
        endTime: String?,
        hours: Decimal,
        kind: HRTimesheetKind,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.runId = runId
        self.companyId = companyId
        self.employeeId = employeeId
        self.workDate = workDate
        self.startTime = startTime
        self.endTime = endTime
        self.hours = hours
        self.kind = kind
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct HRMonthPeriod: Hashable, Sendable {
    var year: Int
    var month: Int

    static func current(calendar: Calendar = .current, now: Date = Date()) -> HRMonthPeriod {
        let parts = calendar.dateComponents([.year, .month], from: now)
        return HRMonthPeriod(year: parts.year ?? 2026, month: parts.month ?? 1)
    }

    func dateInterval(calendar: Calendar = .current) -> (start: Date, end: Date) {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        let start = calendar.date(from: components) ?? Date()
        let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? start
        return (start, end)
    }

    func days(calendar: Calendar = .current) -> [Date] {
        let range = dateInterval(calendar: calendar)
        var days: [Date] = []
        var cursor = range.start
        while cursor <= range.end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    var label: String {
        String(format: "%02d / %04d", month, year)
    }
}

enum HRScheduleMath {
    static func isoWeekday(for date: Date, calendar: Calendar = .current) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }

    static func minutes(from time: String) -> Int {
        let parts = time.split(separator: ":")
        let hour = Int(parts.first ?? "0") ?? 0
        let minute = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        return hour * 60 + minute
    }

    static func timeString(minutes: Int) -> String {
        let normalized = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60)
        return String(format: "%02d:%02d", normalized / 60, normalized % 60)
    }

    static func hours(from start: String, to end: String) -> Decimal {
        let startMinutes = minutes(from: start)
        var endMinutes = minutes(from: end)
        if endMinutes <= startMinutes {
            endMinutes += 24 * 60
        }
        let value = Decimal(endMinutes - startMinutes) / 60
        return round2(value)
    }

    static func endTime(from start: String, hours: Decimal) -> String {
        let added = NSDecimalNumber(decimal: hours * 60).intValue
        return timeString(minutes: minutes(from: start) + added)
    }

    static func round2(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 2, .plain)
        return output
    }

    static func openDays(
        in period: HRMonthPeriod,
        schedule: [HRWeekdaySchedule],
        calendar: Calendar = .current
    ) -> [Date] {
        period.days(calendar: calendar).filter { date in
            let weekday = isoWeekday(for: date, calendar: calendar)
            return schedule.first(where: { $0.weekday == weekday })?.isWorking == true
        }
    }

    static func workingDayCount(
        in period: HRMonthPeriod,
        schedule: [HRWeekdaySchedule],
        calendar: Calendar = .current
    ) -> Int {
        openDays(in: period, schedule: schedule, calendar: calendar).count
    }
}

struct HRPayrollLineDraft: Identifiable, Hashable, Sendable {
    var line: HRPayrollLine
    var employeeName: String
    var employeeCode: String
    var jobTitle: String
    var workLocationId: UUID?
    var workLocationName: String
    var contractGross: Decimal
    var hoursPerDay: Decimal

    var id: UUID { line.id }
}

struct HRTimesheetEmployeeResult: Sendable {
    var employeeId: UUID
    var days: [HRTimesheetDraftDay]
    var errorMessage: String?
}

struct HRTimesheetDraftDay: Sendable {
    var workDate: Date
    var startTime: String?
    var endTime: String?
    var hours: Decimal
    var kind: HRTimesheetKind
}

struct HRJournalEntry: Identifiable, Sendable {
    var id = UUID()
    var number: Int
    var journal: String
    var dateYYYYMMDD: Int
    var documentNumber: String
    var account: String
    var accountTitle: String
    var explanation: String
    var amount: Decimal
    var debitCredit: String
    var employeeCode: String
}

enum HRListingsKind: String, CaseIterable, Identifiable, Sendable {
    case payrollGeneral
    case payrollByLocation
    case payslips
    case timesheet
    case journal
    case nextUpExcel

    var id: String { rawValue }
}
