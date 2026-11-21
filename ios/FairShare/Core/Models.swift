import Foundation

enum Role: String, Codable, CaseIterable, Identifiable {
    case officer, accounts, advisor, platform
    var id: String { rawValue }
    var label: String {
        switch self {
        case .officer: "Organization officer"
        case .accounts: "Student Accounts"
        case .advisor: "Faculty advisor"
        case .platform: "Platform admin"
        }
    }
}

enum ExpenseStatus: String, Codable, CaseIterable {
    case pending
    case needsInfo = "needs_info"
    case approved
    case rejected

    var label: String {
        switch self {
        case .pending: "Pending review"
        case .needsInfo: "Needs documentation"
        case .approved: "Approved"
        case .rejected: "Rejected"
        }
    }
    var short: String {
        switch self {
        case .pending: "Pending"
        case .needsInfo: "Needs info"
        case .approved: "Approved"
        case .rejected: "Rejected"
        }
    }
}

enum DocType: String, Codable { case receipt, check }

enum CategoryId: String, Codable, CaseIterable, Identifiable {
    case food, prizes, printing, supplies, transport, equipment, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .food: "Food & refreshments"
        case .prizes: "Prizes & giveaways"
        case .printing: "Printing & promotion"
        case .supplies: "Event supplies"
        case .transport: "Transportation"
        case .equipment: "Equipment & materials"
        case .other: "Other"
        }
    }
    var short: String {
        switch self {
        case .food: "Food"
        case .prizes: "Prizes"
        case .printing: "Printing"
        case .supplies: "Supplies"
        case .transport: "Travel"
        case .equipment: "Equipment"
        case .other: "Other"
        }
    }
    var symbol: String {
        switch self {
        case .food: "fork.knife"
        case .prizes: "gift"
        case .printing: "printer"
        case .supplies: "shippingbox"
        case .transport: "bus"
        case .equipment: "wrench.and.screwdriver"
        case .other: "ellipsis.circle"
        }
    }
}

struct LineItem: Codable, Hashable {
    var name: String
    var amount: Double
}

struct ExpenseEvent: Codable, Hashable {
    var at: String
    var by: String
    var action: String
    var note: String?
}

struct Expense: Codable, Identifiable, Hashable {
    var id: String
    var orgId: String
    var docType: DocType
    var vendor: String
    var category: CategoryId
    var description: String
    var amount: Double
    var tax: Double?
    var date: String
    var items: [LineItem]?
    var checkNumber: String?
    var memo: String?
    var image: String?
    var scanned: [String]?
    var status: ExpenseStatus
    var submittedBy: String
    var submittedAt: String
    var reviewNote: String?
    var reviewedBy: String?
    var reviewedAt: String?
    var history: [ExpenseEvent]
}

struct Allocation: Codable, Identifiable, Hashable {
    var id: String
    var orgId: String
    var amount: Double
    var note: String
    var at: String
    var by: String
}

struct Funding: Codable, Hashable {
    var status: String
    var submittedAt: String?
    var requested: Double?
}

struct Org: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var initials: String
    var email: String
    var cboard: String
    var advisorId: String
    var term: String
    var mission: String
    var active: Bool
    var funding: Funding
}

struct User: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var email: String
    var role: Role
    var title: String
    var orgIds: [String]
    var active: Bool

    var firstName: String {
        name.replacingOccurrences(of: "Prof. ", with: "").replacingOccurrences(of: "Dr. ", with: "").components(separatedBy: " ").first ?? name
    }
    var initials: String {
        let parts = name.replacingOccurrences(of: "Prof. ", with: "").replacingOccurrences(of: "Dr. ", with: "").split(separator: " ")
        return parts.prefix(2).compactMap { $0.first.map(String.init) }.joined()
    }
}

enum Audience: Codable, Hashable {
    case all
    case orgs([String])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self), s == "all" { self = .all; return }
        self = .orgs(try c.decode([String].self))
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .all: try c.encode("all")
        case .orgs(let ids): try c.encode(ids)
        }
    }
    func includes(_ orgId: String) -> Bool {
        if case .orgs(let ids) = self { return ids.contains(orgId) }
        return true
    }
}

struct Announcement: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var body: String
    var kind: String
    var audience: Audience
    var dueDate: String?
    var link: String?
    var linkLabel: String?
    var requiresAction: Bool
    var createdAt: String
    var by: String
}

struct DocumentItem: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var kind: String
    var summary: String
    var url: String?
    var updatedAt: String
    var audience: Audience
}

struct NoticeTarget: Codable, Hashable {
    var orgId: String?
    var role: Role?
    var userId: String?
}

struct Notice: Codable, Identifiable, Hashable {
    var id: String
    var to: NoticeTarget
    var title: String
    var body: String
    var at: String
    var kind: String
    var ref: String?
    var readBy: [String]
}

struct Institution: Codable, Hashable {
    var name: String
    var domain: String
    var term: String
    var aiEnabled: Bool
}

struct AppState: Codable, Hashable {
    var version: Int
    var updatedAt: String
    var institution: Institution
    var orgs: [Org]
    var users: [User]
    var expenses: [Expense]
    var allocations: [Allocation]
    var announcements: [Announcement]
    var documents: [DocumentItem]
    var notices: [Notice]

    static func seed() -> AppState {
        guard let url = Bundle.main.url(forResource: "seed", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let s = try? JSONDecoder().decode(AppState.self, from: data) else {
            fatalError("seed.json missing from bundle")
        }
        return s
    }

    func org(_ id: String) -> Org? { orgs.first { $0.id == id } }
    func user(_ id: String) -> User? { users.first { $0.id == id } }
    func expense(_ id: String) -> Expense? { expenses.first { $0.id == id } }
}

// MARK: - Wire actions

struct WireAction: Encodable {
    var type: String
    var expense: Expense?
    var id: String?
    var status: String?
    var note: String?
    var by: String?
    var at: String?
    var image: String?
    var orgId: String?
    var requested: Double?
    var allocation: Allocation?
    var announcement: Announcement?
    var userId: String?
    var ids: [String]?
    var user: User?
    var patch: Patch?

    struct Patch: Encodable {
        var role: String?
        var active: Bool?
        var name: String?
        var title: String?
        var orgIds: [String]?
        var advisorId: String?
    }
}

struct AssistantReply: Codable, Hashable {
    struct Draft: Codable, Hashable { var to: String; var subject: String; var body: String }
    var text: String
    var sources: [String]
    var draft: Draft?
    var suggestions: [String]?
    var engine: String
}

struct ChatMessage: Codable, Hashable {
    var role: String
    var text: String
}
