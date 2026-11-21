import SwiftUI

// MARK: - Home

struct OfficerHomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(ShellState.self) private var shell
    @State private var showFunding = false

    var body: some View {
        NavigationStack {
            if let org = store.officerOrg, let user = store.user {
                let s = store.state.summary(org.id)
                let exps = store.state.expenses.filter { $0.orgId == org.id }.sorted { $0.submittedAt > $1.submittedAt }
                ScrollView {
                    VStack(alignment: .leading, spacing: ds(14)) {
                        BalanceCard(org: org, summary: s)
                        QuickActions(org: org)
                            .padding(.vertical, ds(4))

                        FundingBanner(org: org) { showFunding = true }

                        ForEach(exps.filter { $0.status == .needsInfo }) { e in
                            Button { shell.openExpense = e.id } label: {
                                ActionBanner(symbol: "doc.badge.plus", kicker: "Your turn", title: "Add a document for \(e.vendor) · \(Fmt.usd(e.amount))", detail: "")
                            }
                            .buttonStyle(PressableStyle())
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            SectionHeader(title: "Recent activity", action: "See all") { shell.selected = 1 }
                            ForEach(Array(exps.prefix(5).enumerated()), id: \.element.id) { i, e in
                                if i > 0 { Divider().padding(.leading, ds(58)) }
                                Button { shell.openExpense = e.id } label: { ExpenseRow(expense: e) }.buttonStyle(PressableStyle())
                            }
                        }
                        .card()

                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(title: "Spending by category")
                            CategoryBars(summary: s)
                        }
                        .card()

                        CboardCard(org: org)
                        BarClearance()
                    }
                    .padding(.horizontal, ds(20))
                    .padding(.top, ds(4))
                }
                .fsMinimizesBar()
                .refreshable { await store.connect() }
                .fsPage(title: "Hi, \(user.firstName)")
                .sheet(isPresented: $showFunding) { FundingSheet(org: org) }
            }
        }
    }
}

struct BalanceCard: View {
    @Environment(AppStore.self) private var store
    let org: Org
    let summary: OrgSummary

    var body: some View {
        let s = summary
        let pct = s.allocated > 0 ? Int((max(0, s.available) / s.allocated * 100).rounded()) : 0
        VStack(alignment: .leading, spacing: ds(16)) {
            HStack(alignment: .center, spacing: ds(14)) {
                VStack(alignment: .leading, spacing: ds(3)) {
                    HStack(spacing: 8) {
                        Text("Remaining").font(.fs(ds(14), .medium)).foregroundStyle(Color.fsText2)
                        if store.sync == .live {
                            HStack(spacing: 4) { Circle().fill(Color.fsGreen).frame(width: 6, height: 6); Text("Live").font(.fs(ds(12), .semibold)) }
                                .foregroundStyle(Color.fsText2)
                                .padding(.horizontal, 8).frame(height: ds(22))
                                .background(Color.fsSurface2, in: Capsule())
                        }
                    }
                    Text(Fmt.usd(s.remaining))
                        .font(.fs(ds(38), .bold))
                        .tracking(-1.1)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText(value: s.remaining))
                    Text("of \(Fmt.usd(s.allocated, cents: false)) · \(org.term)").font(.fsCaption).foregroundStyle(Color.fsText3)
                }
                Spacer(minLength: 0)
                BudgetRing(allocated: s.allocated, approved: s.approved, pending: s.pending, lineWidth: ds(11)) {
                    Text("\(pct)%").font(.fs(ds(16), .semibold)).monospacedDigit().contentTransition(.numericText(value: Double(pct)))
                }
                .frame(width: ds(92), height: ds(92))
            }
            Divider()
            RingLegend(summary: s)
        }
        .card()
    }
}

private struct QuickActions: View {
    @Environment(AppStore.self) private var store
    @Environment(ShellState.self) private var shell
    let org: Org
    @State private var pdf: URL?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Button { shell.addStart = .receipt; shell.selected = 2 } label: { label("Receipt", "doc.text.viewfinder") }
                .buttonStyle(PressableStyle())
            Button { shell.addStart = .check; shell.selected = 2 } label: { label("Check", "building.columns") }
                .buttonStyle(PressableStyle())
            Button { shell.selected = 3 } label: { label("Ask AI", "sparkles") }
                .buttonStyle(PressableStyle())
            if let pdf {
                ShareLink(item: pdf) { label("Report", "doc.richtext") }.buttonStyle(PressableStyle())
            } else {
                label("Report", "doc.richtext").opacity(0.4)
            }
        }
        .task(id: store.state.version) {
            pdf = ReportExporter.pdf(state: store.state, org: org, preparedFor: store.user?.name)
        }
    }

    private func label(_ title: String, _ symbol: String) -> some View {
        VStack(spacing: ds(7)) {
            Image(systemName: symbol)
                .font(.system(size: ds(20), weight: .medium))
                .foregroundStyle(Color.fsAccentText)
                .frame(width: ds(56), height: ds(56))
                .background(Color.fsAccentSoft, in: Circle())
            Text(title).font(.fs(ds(13), .medium)).foregroundStyle(Color.fsText)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

struct ActionBanner: View {
    let symbol: String
    let kicker: String
    let title: String
    let detail: String
    var tint: Color = .fsAccent

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: ds(19), weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: ds(40), height: ds(40))
                .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                MicroLabel(text: kicker, color: .fsAccentText)
                Text(title).font(.fs(ds(15.5), .semibold)).foregroundStyle(Color.fsText).multilineTextAlignment(.leading)
                if !detail.isEmpty { Text(detail).font(.fsCaption).foregroundStyle(Color.fsText2).multilineTextAlignment(.leading).lineLimit(2) }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.fsText3).frame(maxHeight: .infinity)
        }
        .padding(16)
        .background(Color.fsAccentSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct FundingBanner: View {
    @Environment(AppStore.self) private var store
    let org: Org
    let open: () -> Void
    var body: some View {
        if let a = store.state.fundingAnnouncement {
            Button(action: open) {
                if org.funding.status == "not_started" {
                    let days = a.dueDate.map(Fmt.daysUntil) ?? 0
                    ActionBanner(symbol: "calendar", kicker: "\(days) days left", title: a.title, detail: "")
                } else {
                    HStack(spacing: 14) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 26)).foregroundStyle(Color.fsGreen)
                        Text("Funding request submitted").font(.fs(ds(15.5), .semibold)).foregroundStyle(Color.fsText)
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.fsGreenSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
            .buttonStyle(PressableStyle())
        }
    }
}

struct FundingSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let org: Org
    @State private var opened = false
    @State private var amount = ""

    var body: some View {
        NavigationStack {
            if let a = store.state.fundingAnnouncement {
                let submitted = store.state.org(org.id)?.funding.status != "not_started"
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text(a.body).font(.fsBody).foregroundStyle(Color.fsText2)
                        VStack(alignment: .leading, spacing: 16) {
                            step(1, "Agree on the amount with your officers", done: true)
                            step(2, "Fill out the Google Form", done: opened || submitted)
                            step(3, "Confirm here that you submitted it", done: submitted)
                        }
                        if !submitted {
                            Button {
                                opened = true
                                if let link = a.link, let url = URL(string: link) { openURL(url) }
                            } label: { Label(a.linkLabel ?? "Open form", systemImage: "arrow.up.right.square") }
                                .buttonStyle(FSButtonStyle(kind: .secondary))
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Amount requested (optional)").font(.fs(13, .semibold)).foregroundStyle(Color.fsText2)
                                TextField("$0.00", text: $amount).keyboardType(.decimalPad)
                                    .padding(.horizontal, 14).frame(height: 50)
                                    .background(Color.fsSurface2, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            }
                            Button("I’ve submitted the form") {
                                store.dispatch(WireAction(type: "funding/submit", by: store.userId, orgId: org.id, requested: Double(amount)))
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                dismiss()
                            }
                            .buttonStyle(FSButtonStyle())
                        } else {
                            Label("Submitted", systemImage: "checkmark.circle.fill").foregroundStyle(Color.fsGreenText)
                        }
                    }
                    .padding(20)
                }
                .background(Color.fsBackground)
                .navigationTitle("Annual funding request")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
            }
        }
        .presentationDetents([.large])
    }

    private func step(_ n: Int, _ title: String, done: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle().fill(done ? Color.fsGreen : Color.fsSurface2).frame(width: 28, height: 28)
                if done { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white) } else { Text("\(n)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.fsText2) }
            }
            Text(title).font(.fs(15, .semibold))
        }
    }
}

// MARK: - Activity

struct ActivityView: View {
    @Environment(AppStore.self) private var store
    @Environment(ShellState.self) private var shell
    @State private var filter: ExpenseStatus?
    @State private var query = ""

    var body: some View {
        NavigationStack {
            let user = store.user!
            let orgIds = user.role == .accounts ? store.state.orgs.map(\.id) : user.orgIds
            let all = store.state.expenses.filter { orgIds.contains($0.orgId) }
            let list = all
                .filter { filter == nil || $0.status == filter }
                .filter { query.isEmpty || "\($0.vendor) \($0.description)".localizedCaseInsensitiveContains(query) }
                .sorted { $0.date == $1.date ? $0.submittedAt > $1.submittedAt : $0.date > $1.date }
            let groups = Dictionary(grouping: list) { Fmt.monthYear($0.date) }
            let order = list.map { Fmt.monthYear($0.date) }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            ScrollView {
                VStack(alignment: .leading, spacing: ds(14)) {
                    FSSearchField(text: $query, prompt: "Search vendor or note")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            chip("All", count: all.count, selected: filter == nil) { filter = nil }
                            ForEach([ExpenseStatus.pending, .needsInfo, .approved, .rejected], id: \.self) { s in
                                chip(s.short, count: all.filter { $0.status == s }.count, selected: filter == s) { filter = s }
                            }
                        }
                        .padding(.horizontal, ds(20))
                    }
                    .padding(.horizontal, -ds(20))
                    if list.isEmpty {
                        ContentUnavailableView(query.isEmpty ? "Nothing here" : "No matches", systemImage: "list.bullet.rectangle")
                            .padding(.top, 40)
                    }
                    ForEach(order, id: \.self) { month in
                        let items = groups[month] ?? []
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                MicroLabel(text: month)
                                Spacer()
                                Text("\(Fmt.usd(items.filter { $0.status == .approved }.reduce(0) { $0 + $1.amount })) approved").font(.fs(12)).foregroundStyle(Color.fsText3)
                            }
                            .padding(.bottom, 4)
                            ForEach(Array(items.enumerated()), id: \.element.id) { i, e in
                                if i > 0 { Divider().padding(.leading, ds(58)) }
                                Button { shell.openExpense = e.id } label: { ExpenseRow(expense: e, showOrg: orgIds.count > 1) }.buttonStyle(PressableStyle())
                            }
                        }
                        .card(padding: 16)
                    }
                    BarClearance()
                }
                .padding(.horizontal, ds(20))
                .padding(.top, ds(4))
                .animation(fsSpring, value: filter)
            }
            .fsMinimizesBar()
            .scrollDismissesKeyboard(.immediately)
            .fsPage(title: "Activity")
        }
    }

    private func chip(_ label: String, count: Int, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(fsSpring) { action() }
        } label: {
            HStack(spacing: 5) {
                Text(label).font(.fs(ds(14), .semibold))
                Text("\(count)").font(.fs(ds(13), .medium)).opacity(0.6)
            }
            .foregroundStyle(selected ? Color.fsBackground : Color.fsText)
            .padding(.horizontal, 14).frame(height: ds(36))
            .background(selected ? Color.fsText : Color.fsSurface, in: Capsule())
            .overlay(Capsule().stroke(Color.fsHairline, lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Club

struct ClubView: View {
    @Environment(AppStore.self) private var store
    @State private var showFunding = false

    var body: some View {
        NavigationStack {
            if let org = store.officerOrg {
                let officers = store.state.users.filter { $0.role == .officer && $0.orgIds.contains(org.id) }
                let advisor = store.state.user(org.advisorId)
                ScrollView {
                    VStack(alignment: .leading, spacing: ds(14)) {
                        CboardCard(org: org)
                        FundingBanner(org: org) { showFunding = true }

                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(title: "People")
                            ForEach(officers) { u in person(u.name, u.title.components(separatedBy: " · ").first ?? "", u.email) }
                            if let a = advisor { person(a.name, "Faculty advisor", a.email) }
                        }
                        .card()

                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(title: "Budget history")
                            ForEach(store.state.allocations.filter { $0.orgId == org.id }) { a in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(a.note).font(.fs(15, .medium))
                                        Text(Fmt.longDate(a.at)).font(.fsCaption).foregroundStyle(Color.fsText2)
                                    }
                                    Spacer()
                                    Text("\(a.amount >= 0 ? "+" : "−")\(Fmt.usd(abs(a.amount)))").font(.fs(15, .semibold)).monospacedDigit()
                                        .foregroundStyle(a.amount >= 0 ? Color.fsGreenText : Color.fsRedText)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                        .card()

                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Financial report")
                            ReportShareButtons(org: org)
                        }
                        .card()

                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(title: "Documents from Student Accounts")
                            ForEach(store.state.documents.filter { $0.audience.includes(org.id) }) { d in
                                Link(destination: URL(string: d.url ?? "https://www.luther.edu")!) {
                                    HStack(spacing: 12) {
                                        Image(systemName: d.kind == "form" ? "list.clipboard" : d.kind == "policy" ? "text.book.closed" : "doc.text")
                                            .font(.system(size: 17)).foregroundStyle(Color.fsText2)
                                            .frame(width: 40, height: 40).background(Color.fsSurface2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                        Text(d.title).font(.fs(15, .semibold)).foregroundStyle(Color.fsText).lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .card()
                        BarClearance()
                    }
                    .padding(.horizontal, ds(20))
                    .padding(.top, ds(4))
                }
                .fsMinimizesBar()
                .fsPage(title: org.name)
                .sheet(isPresented: $showFunding) { FundingSheet(org: org) }
            }
        }
    }

    private func person(_ name: String, _ role: String, _ email: String) -> some View {
        HStack(spacing: 12) {
            AvatarView(name: name, email: email, size: ds(42))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.fs(15, .semibold))
                Text(role).font(.fsCaption).foregroundStyle(Color.fsText2)
            }
            Spacer()
            Link(destination: URL(string: "mailto:\(email)")!) {
                Image(systemName: "envelope").font(.system(size: 15, weight: .medium)).frame(width: 36, height: 36).background(Color.fsSurface2, in: Circle())
            }
        }
        .padding(.vertical, 4)
    }
}

@Observable
final class AssistantInbox {
    static let shared = AssistantInbox()
    var pending: String?
}
