import Foundation

struct OrgSummary: Hashable {
    var allocated: Double
    var approved: Double
    var pending: Double
    var pendingCount: Int
    var needsInfoCount: Int
    var remaining: Double { (allocated - approved).rounded2 }
    var available: Double { (remaining - pending).rounded2 }
    var byCategory: [(id: CategoryId, approved: Double, pending: Double)]

    static func == (a: OrgSummary, b: OrgSummary) -> Bool {
        a.allocated == b.allocated && a.approved == b.approved && a.pending == b.pending
    }
    func hash(into h: inout Hasher) {
        h.combine(allocated); h.combine(approved); h.combine(pending)
    }
}

extension Double {
    var rounded2: Double { (self * 100).rounded() / 100 }
}

extension AppState {
    func summary(_ orgId: String) -> OrgSummary {
        let allocated = allocations.filter { $0.orgId == orgId }.reduce(0) { $0 + $1.amount }.rounded2
        let exps = expenses.filter { $0.orgId == orgId }
        let approved = exps.filter { $0.status == .approved }.reduce(0) { $0 + $1.amount }.rounded2
        let pendingList = exps.filter { $0.status == .pending || $0.status == .needsInfo }
        let pending = pendingList.reduce(0) { $0 + $1.amount }.rounded2
        let cats = CategoryId.allCases.map { c in
            (id: c,
             approved: exps.filter { $0.category == c && $0.status == .approved }.reduce(0) { $0 + $1.amount }.rounded2,
             pending: exps.filter { $0.category == c && ($0.status == .pending || $0.status == .needsInfo) }.reduce(0) { $0 + $1.amount }.rounded2)
        }
        return OrgSummary(allocated: allocated, approved: approved, pending: pending,
                          pendingCount: exps.filter { $0.status == .pending }.count,
                          needsInfoCount: exps.filter { $0.status == .needsInfo }.count,
                          byCategory: cats)
    }

    func notices(for u: User) -> [Notice] {
        notices.filter { n in
            if let uid = n.to.userId { return uid == u.id }
            if let org = n.to.orgId { return (u.role == .officer || u.role == .advisor) && u.orgIds.contains(org) }
            if let role = n.to.role { return role == u.role }
            return false
        }.sorted { $0.at > $1.at }
    }

    func visibleOrgs(for u: User) -> [Org] {
        switch u.role {
        case .accounts, .platform: return orgs
        default: return orgs.filter { u.orgIds.contains($0.id) }
        }
    }

    var fundingAnnouncement: Announcement? { announcements.first { $0.kind == "funding" } }
}

enum Permissions {
    static func canSeeCboard(_ u: User, _ o: Org) -> Bool {
        switch u.role {
        case .accounts: true
        case .officer, .advisor: u.orgIds.contains(o.id)
        case .platform: false
        }
    }
}

// MARK: - Offline reducer

enum Reducer {
    static func notice(to: NoticeTarget, kind: String, title: String, body: String, ref: String? = nil, at: String = Fmt.nowISO()) -> Notice {
        Notice(id: "nt_\(UUID().uuidString.prefix(8))", to: to, title: title, body: body, at: at, kind: kind, ref: ref, readBy: [])
    }

    static func apply(_ a: WireAction, to state: inout AppState) {
        let now = Fmt.nowISO()
        state.version += 1
        state.updatedAt = now
        switch a.type {
        case "expense/submit":
            guard var e = a.expense, !state.expenses.contains(where: { $0.id == e.id }) else { return }
            e.status = .pending
            state.expenses.insert(e, at: 0)
            let org = state.org(e.orgId)?.name ?? "an organization"
            let doc = e.docType == .check ? "Check\(e.checkNumber.map { " #\($0)" } ?? "")" : "Receipt"
            state.notices.insert(notice(to: .init(role: .accounts), kind: "submitted", title: "New expense from \(org)", body: "\(doc) · \(e.vendor) · \(Fmt.usd(e.amount))", ref: e.id), at: 0)
        case "expense/review":
            guard let id = a.id, let i = state.expenses.firstIndex(where: { $0.id == id }), let raw = a.status, let st = ExpenseStatus(rawValue: raw) else { return }
            state.expenses[i].status = st
            state.expenses[i].reviewNote = a.note
            state.expenses[i].reviewedBy = a.by
            state.expenses[i].reviewedAt = a.at ?? now
            state.expenses[i].history.append(ExpenseEvent(at: a.at ?? now, by: a.by ?? "", action: raw, note: a.note))
            let e = state.expenses[i]
            let title = st == .approved ? "\(Fmt.usd(e.amount)) approved" : st == .rejected ? "\(Fmt.usd(e.amount)) was not approved" : "Student Accounts needs one more document"
            let verb = st == .approved ? "approved" : st == .rejected ? "declined" : "needs more documentation for"
            state.notices.insert(notice(to: .init(orgId: e.orgId), kind: raw, title: title, body: "Student Accounts \(verb) \(e.vendor) · \(e.description)\(a.note.map { " — “\($0)”" } ?? "")", ref: e.id), at: 0)
        case "expense/document":
            guard let id = a.id, let i = state.expenses.firstIndex(where: { $0.id == id }) else { return }
            if let img = a.image { state.expenses[i].image = img }
            state.expenses[i].status = .pending
            state.expenses[i].history.append(ExpenseEvent(at: now, by: a.by ?? "", action: "documented", note: a.note))
            let e = state.expenses[i]
            state.notices.insert(notice(to: .init(role: .accounts), kind: "submitted", title: "\(state.org(e.orgId)?.name ?? "An organization") added documentation", body: "\(e.vendor) · \(Fmt.usd(e.amount)) is back in your queue.", ref: e.id), at: 0)
        case "budget/adjust":
            guard let al = a.allocation else { return }
            state.allocations.append(al)
            state.notices.insert(notice(to: .init(orgId: al.orgId), kind: "budget", title: al.amount >= 0 ? "\(Fmt.usd(al.amount)) added to your budget" : "\(Fmt.usd(abs(al.amount))) removed from your budget", body: al.note), at: 0)
        case "funding/submit":
            guard let orgId = a.orgId, let i = state.orgs.firstIndex(where: { $0.id == orgId }) else { return }
            state.orgs[i].funding = Funding(status: "submitted", submittedAt: now, requested: a.requested)
            state.notices.insert(notice(to: .init(role: .accounts), kind: "funding", title: "\(state.orgs[i].name) submitted its funding request", body: a.requested.map { "Requested \(Fmt.usd($0)) for 2027–28" } ?? "Annual funding request received"), at: 0)
        case "access/report":
            guard let uid = a.userId, let u = state.users.first(where: { $0.id == uid }) else { return }
            let orgs = state.orgs.filter { u.orgIds.contains($0.id) }.map(\.name)
            let to: NoticeTarget = .init(role: .accounts)
            state.notices.insert(notice(to: to, kind: "access", title: "\(u.name) says their account is set up wrong", body: "\(u.email) is linked to \(orgs.isEmpty ? u.title : orgs.joined(separator: ", "))."), at: 0)
        case "announcement/publish":
            guard let an = a.announcement else { return }
            state.announcements.insert(an, at: 0)
            state.notices.insert(notice(to: .init(role: .officer), kind: "announcement", title: an.title, body: an.dueDate.map { "Due \(Fmt.longDate($0))" } ?? String(an.body.prefix(90)), ref: an.id), at: 0)
        case "notice/read":
            guard let uid = a.userId, let ids = a.ids else { return }
            for i in state.notices.indices where ids.contains(state.notices[i].id) && !state.notices[i].readBy.contains(uid) {
                state.notices[i].readBy.append(uid)
            }
        case "user/create":
            guard let u = a.user, !state.users.contains(where: { $0.email == u.email }) else { return }
            state.users.append(u)
        case "user/update":
            guard let id = a.id, let i = state.users.firstIndex(where: { $0.id == id }) else { return }
            if let r = a.patch?.role, let role = Role(rawValue: r) { state.users[i].role = role }
            if let act = a.patch?.active { state.users[i].active = act }
            if let n = a.patch?.name { state.users[i].name = n }
            if let t = a.patch?.title { state.users[i].title = t }
            if let o = a.patch?.orgIds { state.users[i].orgIds = o }
        case "org/update":
            guard let id = a.id, let i = state.orgs.firstIndex(where: { $0.id == id }) else { return }
            if let act = a.patch?.active { state.orgs[i].active = act }
            if let adv = a.patch?.advisorId { state.orgs[i].advisorId = adv }
        case "demo/reset":
            state = AppState.seed()
        default:
            break
        }
    }
}

// MARK: - Formatting

enum Fmt {
    private static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    static func usd(_ v: Double, cents: Bool = true) -> String {
        currency.minimumFractionDigits = cents ? 2 : 0
        currency.maximumFractionDigits = cents ? 2 : 0
        return currency.string(from: NSNumber(value: v)) ?? "$\(v)"
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain = ISO8601DateFormatter()
    private static let day: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func nowISO() -> String { iso.string(from: Date()) }
    static func todayDay() -> String { day.string(from: Date()) }
    static func dayString(_ d: Date) -> String { day.string(from: d) }

    static func date(_ s: String) -> Date {
        if s.count == 10, let d = day.date(from: s) { return d.addingTimeInterval(12 * 3600) }
        return iso.date(from: s) ?? isoPlain.date(from: s) ?? Date()
    }

    static func shortDate(_ s: String) -> String { date(s).formatted(.dateTime.month(.abbreviated).day()) }
    static func longDate(_ s: String) -> String { date(s).formatted(.dateTime.month(.wide).day().year()) }
    static func monthYear(_ s: String) -> String { date(s).formatted(.dateTime.month(.wide).year()) }

    static func relative(_ s: String) -> String {
        let secs = Date().timeIntervalSince(date(s))
        if secs < 45 { return "Just now" }
        if secs < 3600 { return "\(Int(secs / 60))m ago" }
        if secs < 86400 { return "\(Int(secs / 3600))h ago" }
        if secs < 7 * 86400 { return "\(Int(secs / 86400))d ago" }
        return shortDate(s)
    }

    static func daysUntil(_ day: String) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date(day))).day ?? 0
    }

    static func greeting() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }
}

func newId(_ prefix: String) -> String {
    "\(prefix)_\(String(Int(Date().timeIntervalSince1970 * 1000), radix: 36))\(UUID().uuidString.prefix(4).lowercased())"
}
