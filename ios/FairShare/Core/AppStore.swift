import SwiftUI
import UserNotifications

@Observable
@MainActor
final class AppStore {
    enum Sync: Equatable { case connecting, live, offline }

    struct Banner: Identifiable, Equatable {
        let id = UUID()
        var title: String
        var body: String
        var kind: String
        var ref: String?
    }

    var state: AppState
    var sync: Sync = .connecting
    var userId: String? { didSet { UserDefaults.standard.set(userId, forKey: "fs.user") } }
    var hasOnboarded: Bool { didSet { UserDefaults.standard.set(hasOnboarded, forKey: "fs.onboarded") } }
    var serverURL: String { didSet { UserDefaults.standard.set(serverURL, forKey: "fs.server") } }
    var appearance: String { didSet { UserDefaults.standard.set(appearance, forKey: "fs.appearance") } }
    var language: String { didSet { UserDefaults.standard.set(language, forKey: "fs.language") } }
    var banner: Banner?
    var aiEngine = "local"
    var pendingRoute: String?

    private var streamTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var seenNotices = Set<String>()
    private var seenFor: String?

    private(set) var activeServer: URL?
    private(set) var outbox: [WireAction] = []
    private(set) var deliveredExpenses = Set<String>()
    private var remoteVersion = -1
    private var staleCount = 0
    private var connecting = false
    private var flushing = false

    static let builtInServers = [
        "https://integrated-leonard-particle-comparisons.trycloudflare.com",
        "http://10.28.3.217:4000",
        "http://Bekas-Mac-Studio-94.local:4000",
        "http://localhost:4000",
    ]

    init() {
        let d = UserDefaults.standard
        state = AppStore.loadCache() ?? .seed()
        userId = d.string(forKey: "fs.user")
        hasOnboarded = d.bool(forKey: "fs.onboarded")
        serverURL = d.string(forKey: "fs.server") ?? ""
        appearance = d.string(forKey: "fs.appearance") ?? "system"
        language = d.string(forKey: "fs.language") ?? "en"
    }

    var user: User? { userId.flatMap { state.user($0) } }
    var officerOrg: Org? { user.flatMap { u in u.role == .officer ? state.org(u.orgIds.first ?? "") : nil } }
    var colorScheme: ColorScheme? { appearance == "light" ? .light : appearance == "dark" ? .dark : nil }

    // MARK: Sync

    func start() {
        Task { await connect() }
    }

    func resume() {
        Task { await connect() }
    }

    private var candidates: [URL] {
        if let only = ProcessInfo.processInfo.environment["FS_SERVER_ONLY"], let u = URL(string: only) { return [u] }
        let custom = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        var list: [String] = []
        if !custom.isEmpty { list.append(custom.contains("://") ? custom : "https://\(custom)") }
        list += Self.builtInServers
        var seen = Set<String>()
        return list.compactMap { s in
            let t = s.hasSuffix("/") ? String(s.dropLast()) : s
            guard seen.insert(t.lowercased()).inserted else { return nil }
            return URL(string: t)
        }
    }

    func connect() async {
        guard !connecting else { return }
        connecting = true
        defer { connecting = false }
        if sync != .live { sync = .connecting }
        guard let base = await probe() else {
            if activeServer == nil { goOffline() } else { sync = .offline }
            scheduleRetry()
            return
        }
        retryTask?.cancel()
        let switched = base != activeServer
        activeServer = base
        sync = .live
        if switched || streamTask == nil {
            streamTask?.cancel()
            streamTask = Task { await self.stream(base: base) }
        }
        pollTask?.cancel()
        pollTask = Task { await self.poll(base: base) }
        await pollOnce(base: base)
        flush()
    }

    private func probe() async -> URL? {
        let list = candidates
        return await withTaskGroup(of: URL?.self) { group in
            for base in list {
                group.addTask {
                    guard let health = URL(string: "/api/health", relativeTo: base) else { return nil }
                    var req = URLRequest(url: health)
                    req.timeoutInterval = 3
                    req.cachePolicy = .reloadIgnoringLocalCacheData
                    guard let (data, resp) = try? await URLSession.shared.data(for: req),
                          (resp as? HTTPURLResponse)?.statusCode == 200,
                          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          obj["ok"] as? Bool == true else { return nil }
                    if let ai = obj["ai"] as? [String: Any], let engine = ai["engine"] as? String {
                        await MainActor.run { self.aiEngine = engine }
                    }
                    return base
                }
            }
            for await result in group {
                if let result {
                    group.cancelAll()
                    return result
                }
            }
            return nil
        }
    }

    private func scheduleRetry() {
        retryTask?.cancel()
        retryTask = Task {
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { await self.connect() }
        }
    }

    private func goOffline() {
        sync = .offline
        aiEngine = "local"
    }

    private func stream(base: URL) async {
        guard let url = URL(string: "/api/events", relativeTo: base) else { return }
        while !Task.isCancelled {
            do {
                var req = URLRequest(url: url)
                req.timeoutInterval = 3600
                let (bytes, _) = try await URLSession.shared.bytes(for: req)
                for try await line in bytes.lines {
                    guard line.hasPrefix("data: ") else { continue }
                    let json = Data(line.dropFirst(6).utf8)
                    if let next = try? JSONDecoder().decode(AppState.self, from: json) {
                        receive(next)
                    }
                }
            } catch {
                if Task.isCancelled { return }
            }
            try? await Task.sleep(for: .seconds(2))
        }
    }

    private func poll(base: URL) async {
        var failures = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
            if await pollOnce(base: base) {
                failures = 0
            } else {
                failures += 1
                if failures >= 3 {
                    sync = .connecting
                    Task { await self.connect() }
                    return
                }
            }
        }
    }

    @discardableResult
    private func pollOnce(base: URL) async -> Bool {
        guard var comps = URLComponents(url: base.appendingPathComponent("api/state"), resolvingAgainstBaseURL: true) else { return false }
        comps.queryItems = [URLQueryItem(name: "since", value: String(remoteVersion))]
        guard let url = comps.url else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 5
        req.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200 || code == 204 else { return false }
            if sync != .live { sync = .live }
            if code == 200, let next = try? JSONDecoder().decode(AppState.self, from: data) { receive(next) }
            if !outbox.isEmpty { flush() }
            return true
        } catch {
            return false
        }
    }

    private func receive(_ next: AppState) {
        if next.version < remoteVersion {
            staleCount += 1
            if staleCount < 3 { return }
        }
        staleCount = 0
        remoteVersion = next.version
        var merged = next
        for action in outbox where !Self.alreadyApplied(action, in: next) { Reducer.apply(action, to: &merged) }
        sync = .live
        guard merged != state else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
            state = merged
        }
        saveCache()
        announceNewNotices()
    }

    private static func alreadyApplied(_ a: WireAction, in s: AppState) -> Bool {
        switch a.type {
        case "expense/submit": return s.expenses.contains { $0.id == a.expense?.id }
        case "expense/review": return s.expenses.contains { $0.id == a.id && $0.status.rawValue == a.status && $0.reviewedBy == a.by }
        default: return false
        }
    }

    // MARK: Actions

    func dispatch(_ action: WireAction) {
        var next = state
        Reducer.apply(action, to: &next)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
            state = next
        }
        saveCache()
        outbox.append(action)
        flush()
    }

    private struct ActionReply: Decodable { var ok: Bool?; var version: Int?; var state: AppState? }

    private func flush() {
        guard !flushing, !outbox.isEmpty, sync == .live, activeServer != nil else { return }
        flushing = true
        Task {
            while let action = self.outbox.first, let base = self.activeServer, let url = URL(string: "/api/action", relativeTo: base) {
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.timeoutInterval = 45
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try? JSONEncoder().encode(["action": action])
                do {
                    let (data, resp) = try await URLSession.shared.data(for: req)
                    let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                    if code >= 500 || code == 0 { throw URLError(.badServerResponse) }
                    if !self.outbox.isEmpty { self.outbox.removeFirst() }
                    if code == 200, let id = action.expense?.id { self.deliveredExpenses.insert(id) }
                    if let reply = try? JSONDecoder().decode(ActionReply.self, from: data), let s = reply.state {
                        self.receive(s)
                    }
                } catch {
                    try? await Task.sleep(for: .seconds(1.5))
                    if self.sync != .live {
                        self.flushing = false
                        Task { await self.connect() }
                        return
                    }
                }
            }
            self.flushing = false
        }
    }

    func ask(orgId: String, messages: [ChatMessage]) async -> AssistantReply {
        let started = Date()
        var reply: AssistantReply?
        if sync == .live, let base = activeServer, let url = URL(string: "/api/assistant", relativeTo: base) {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.timeoutInterval = 30
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            struct Body: Encodable { let orgId: String; let messages: [ChatMessage] }
            req.httpBody = try? JSONEncoder().encode(Body(orgId: orgId, messages: messages))
            if let (data, _) = try? await URLSession.shared.data(for: req) {
                reply = try? JSONDecoder().decode(AssistantReply.self, from: data)
            }
        }
        let answer = reply?.engine == "claude" ? reply! : LocalAssistant.answer(state: state, orgId: orgId, question: messages.last?.text ?? "")
        let elapsed = Date().timeIntervalSince(started)
        if elapsed < 0.7 { try? await Task.sleep(for: .seconds(0.7 - elapsed)) }
        return answer
    }

    // MARK: Session

    func signIn(_ id: String) {
        userId = id
        seenFor = nil
        announceNewNotices()
    }

    func signOut() {
        userId = nil
        hasOnboarded = false
    }

    func resetDemo() {
        dispatch(WireAction(type: "demo/reset"))
        if sync != .live { state = .seed() }
    }

    // MARK: Notifications

    private func announceNewNotices() {
        guard let u = user else { return }
        let mine = state.notices(for: u)
        if seenFor != u.id {
            seenFor = u.id
            seenNotices = Set(mine.map(\.id))
            return
        }
        let fresh = mine.filter { !seenNotices.contains($0.id) }
        guard !fresh.isEmpty else { return }
        fresh.forEach { seenNotices.insert($0.id) }
        let recent = fresh.filter { Date().timeIntervalSince(Fmt.date($0.at)) < 90 }
        guard !recent.isEmpty else { return }
        for n in recent.prefix(2) {
            show(n)
        }
    }

    private func show(_ n: Notice) {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(n.kind == "rejected" ? .error : n.kind == "needs_info" ? .warning : .success)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            banner = Banner(title: n.title, body: n.body, kind: n.kind, ref: n.ref)
        }
        let current = banner?.id
        Task {
            try? await Task.sleep(for: .seconds(5))
            if self.banner?.id == current { withAnimation(.easeOut(duration: 0.25)) { self.banner = nil } }
        }
        if UIApplication.shared.applicationState != .active {
            let content = UNMutableNotificationContent()
            content.title = n.title
            content.body = n.body
            content.sound = .default
            content.userInfo = ["ref": n.ref ?? ""]
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: n.id, content: content, trigger: nil))
        }
    }

    func requestNotifications() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    // MARK: Cache

    nonisolated private static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("fairshare-state.json")
    }

    nonisolated private static func loadCache() -> AppState? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(AppState.self, from: data)
    }

    private func saveCache() {
        let s = state
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(s) { try? data.write(to: AppStore.cacheURL, options: .atomic) }
        }
    }

    func fileURL(_ path: String) -> URL? {
        guard let base = activeServer ?? candidates.first else { return nil }
        return URL(string: path, relativeTo: base)
    }
}

// MARK: - Demo accounts

struct DemoAccount: Identifiable {
    let id: String
    let role: Role
    let who: String
    let email: String
    var symbol: String {
        switch role {
        case .officer: "person.crop.circle"
        case .accounts: "building.columns"
        case .advisor: "graduationcap"
        case .platform: "lock.shield"
        }
    }
}

let demoAccounts: [DemoAccount] = [
    DemoAccount(id: "u_alex", role: .officer, who: "Beka Abesadze · Up to Us", email: "abesbe01@luther.edu"),
    DemoAccount(id: "u_jordan", role: .accounts, who: "Sab Abesadze · Student Accounts", email: "abessa01@luther.edu"),
    DemoAccount(id: "u_olsen", role: .advisor, who: "Prof. Maren Olsen · 2 orgs", email: "maren.olsen@luther.edu"),
]
