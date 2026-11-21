import SwiftUI

// MARK: - Overview

struct AccountsOverviewView: View {
    @Environment(AppStore.self) private var store
    @Environment(ShellState.self) private var shell

    var body: some View {
        NavigationStack {
            let st = store.state
            let orgs = st.orgs.filter(\.active)
            let sums = orgs.map { ($0, st.summary($0.id)) }
            let allocated = sums.reduce(0) { $0 + $1.1.allocated }
            let approved = sums.reduce(0) { $0 + $1.1.approved }
            let queue = st.expenses.filter { $0.status == .pending }.sorted { $0.submittedAt > $1.submittedAt }
            let funding = orgs.filter { $0.funding.status != "not_started" }.count
            ScrollView {
                VStack(alignment: .leading, spacing: ds(16)) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        stat("Allocated", Fmt.usd(allocated, cents: false), nil, .fsText)
                        stat("Approved", Fmt.usd(approved, cents: false), "\(Int((approved / max(1, allocated) * 100).rounded()))% of budgets", .fsText)
                        stat("Waiting on you", "\(queue.count)", "\(Fmt.usd(queue.reduce(0) { $0 + $1.amount })) pending", .fsAmberText)
                        stat("Funding requests", "\(funding)/\(orgs.count)", nil, .fsAccentText)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        SectionHeader(title: "Review queue", action: "Open") { shell.selected = 1 }
                        if queue.isEmpty {
                            Label("All caught up", systemImage: "checkmark.circle.fill").foregroundStyle(Color.fsGreenText).padding(.vertical, 12)
                        }
                        ForEach(Array(queue.prefix(4).enumerated()), id: \.element.id) { i, e in
                            if i > 0 { Divider().padding(.leading, ds(58)) }
                            Button { shell.openExpense = e.id } label: { ExpenseRow(expense: e, showOrg: true) }.buttonStyle(PressableStyle())
                        }
                    }
                    .card()
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Organizations", action: "All") { shell.selected = 2 }
                        ForEach(sums.sorted { $0.0.name < $1.0.name }, id: \.0.id) { org, s in
                            NavigationLink(value: org.id) { OrgBudgetRow(org: org, summary: s) }.buttonStyle(PressableStyle())
                        }
                    }
                    .card()
                    BarClearance()
                }
                .padding(.horizontal, ds(20))
                .padding(.top, ds(4))
            }
            .fsMinimizesBar()
            .refreshable { await store.connect() }
            .fsPage(title: "Overview")
            .navigationDestination(for: String.self) { OrgDetailView(orgId: $0) }
        }
    }

    private func stat(_ label: String, _ value: String, _ hint: String?, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MicroLabel(text: label)
            Text(value).font(.fs(ds(26), .bold)).monospacedDigit().foregroundStyle(color).contentTransition(.numericText())
            if let hint { Text(hint).font(.fs(ds(12))).foregroundStyle(Color.fsText2).lineLimit(1) }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .card(padding: 16)
    }
}

struct OrgBudgetRow: View {
    let org: Org
    let summary: OrgSummary
    var body: some View {
        HStack(spacing: 12) {
            OrgBadge(orgId: org.id, initials: org.initials, size: ds(40))
            VStack(alignment: .leading, spacing: 6) {
                Text(org.name).font(.fs(ds(15), .semibold)).foregroundStyle(Color.fsText).lineLimit(1)
                GeometryReader { g in
                    let used = summary.allocated > 0 ? summary.approved / summary.allocated : 0
                    let pend = summary.allocated > 0 ? min(1 - used, summary.pending / summary.allocated) : 0
                    HStack(spacing: 2) {
                        if used > 0 { Capsule().fill(Color.fsText2).frame(width: g.size.width * used) }
                        if pend > 0 { Capsule().fill(Color.fsAmber).frame(width: max(3, g.size.width * pend - 2)) }
                        Capsule().fill(Color.fsTrack)
                    }
                }
                .frame(height: 6)
            }
            VStack(alignment: .trailing, spacing: 1) {
                Text(Fmt.usd(summary.remaining, cents: false)).font(.fs(ds(15), .semibold)).monospacedDigit().foregroundStyle(Color.fsText)
                Text("left").font(.fs(11)).foregroundStyle(Color.fsText3)
            }
            .frame(width: ds(70), alignment: .trailing)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

// MARK: - Review queue

struct ReviewQueueView: View {
    @Environment(AppStore.self) private var store
    @Environment(ShellState.self) private var shell
    @State private var tab = 0

    var body: some View {
        NavigationStack {
            let st = store.state
            let list: [Expense] = {
                switch tab {
                case 0: return st.expenses.filter { $0.status == .pending }.sorted { $0.submittedAt > $1.submittedAt }
                case 1: return st.expenses.filter { $0.status == .needsInfo }
                default: return st.expenses.filter { $0.status == .approved || $0.status == .rejected }.sorted { ($0.reviewedAt ?? "") > ($1.reviewedAt ?? "") }.prefix(25).map { $0 }
                }
            }()
            ScrollView {
                VStack(alignment: .leading, spacing: ds(16)) {
                    Picker("Queue", selection: $tab) {
                        Text("Pending \(st.expenses.filter { $0.status == .pending }.count)").tag(0)
                        Text("Waiting on org").tag(1)
                        Text("Reviewed").tag(2)
                    }
                    .pickerStyle(.segmented)
                    if list.isEmpty {
                        ContentUnavailableView(tab == 0 ? "Queue is clear" : "Nothing here", systemImage: "tray")
                            .padding(.top, 40)
                    }
                    ForEach(list) { e in
                        Button { shell.openExpense = e.id } label: { ReviewCard(expense: e) }.buttonStyle(PressableStyle())
                    }
                    BarClearance()
                }
                .padding(.horizontal, ds(20))
                .animation(fsSpring, value: list.map(\.id))
            }
            .fsMinimizesBar()
            .refreshable { await store.connect() }
            .fsPage(title: "Review")
        }
    }
}

private struct ReviewCard: View {
    @Environment(AppStore.self) private var store
    let expense: Expense
    var body: some View {
        let org = store.state.org(expense.orgId)
        HStack(spacing: 14) {
            ReceiptImage(path: expense.image, contentMode: .fill, compact: true)
                .frame(width: ds(64), height: ds(80))
                .background(Color.fsSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.fsHairline, lineWidth: 1))
            VStack(alignment: .leading, spacing: 4) {
                Text(org?.name ?? "").font(.fs(ds(15.5), .semibold)).foregroundStyle(Color.fsText).lineLimit(1)
                Text("\(expense.docType == .check ? "Check #\(expense.checkNumber ?? "—") · " : "")\(expense.vendor)").font(.fsCaption).foregroundStyle(Color.fsText2).lineLimit(1)
                HStack(spacing: 6) {
                    StatusPill(status: expense.status, short: true)
                    Text(Fmt.relative(expense.submittedAt)).font(.fs(12)).foregroundStyle(Color.fsText3)
                }
            }
            Spacer(minLength: 4)
            Text(Fmt.usd(expense.amount)).font(.fs(ds(17), .semibold)).monospacedDigit().foregroundStyle(Color.fsText)
        }
        .card(padding: 14)
    }
}

// MARK: - Organizations

struct OrgsListView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        NavigationStack {
            let orgs = store.state.orgs.sorted { $0.name < $1.name }
            let off = orgs.filter { !$0.active }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(orgs.filter(\.active)) { org in
                        NavigationLink(value: org.id) {
                            OrgBudgetRow(org: org, summary: store.state.summary(org.id)).card(padding: 14)
                        }
                        .buttonStyle(PressableStyle())
                    }
                    if !off.isEmpty {
                        MicroLabel(text: "Turned off").padding(.top, 10).padding(.leading, 4)
                        ForEach(off) { org in
                            NavigationLink(value: org.id) {
                                OrgBudgetRow(org: org, summary: store.state.summary(org.id)).opacity(0.5).card(padding: 14)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    BarClearance()
                }
                .padding(.horizontal, ds(20))
                .padding(.top, ds(4))
            }
            .fsMinimizesBar()
            .fsPage(title: "Organizations")
            .navigationDestination(for: String.self) { OrgDetailView(orgId: $0) }
        }
    }
}

struct OrgDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(ShellState.self) private var shell
    let orgId: String
    @State private var adjust = false
    @State private var addPerson = false
    @State private var editing: User?

    var body: some View {
        if let org = store.state.org(orgId), let user = store.user {
            let s = store.state.summary(org.id)
            let exps = store.state.expenses.filter { $0.orgId == org.id }.sorted { $0.date > $1.date }
            ScrollView {
                VStack(alignment: .leading, spacing: ds(16)) {
                    VStack(spacing: 18) {
                        BudgetRing(allocated: s.allocated, approved: s.approved, pending: s.pending, lineWidth: ds(16)) {
                            VStack(spacing: 2) {
                                Text("Remaining").font(.fsCaption).foregroundStyle(Color.fsText2)
                                Text(Fmt.usd(s.remaining)).font(.fs(ds(32), .bold)).monospacedDigit().contentTransition(.numericText(value: s.remaining))
                                Text("of \(Fmt.usd(s.allocated, cents: false))").font(.fsCaption).foregroundStyle(Color.fsText2)
                            }
                        }
                        .frame(width: ds(210), height: ds(210))
                        RingLegend(summary: s)
                    }
                    .card()
                    if user.role == .accounts {
                        Button { adjust = true } label: { Label("Adjust budget", systemImage: "plusminus") }.buttonStyle(FSButtonStyle())

                        HStack(spacing: 12) {
                            Image(systemName: "power")
                                .font(.system(size: ds(16), weight: .semibold))
                                .foregroundStyle(org.active ? Color.fsGreenText : Color.fsText3)
                                .frame(width: ds(36), height: ds(36))
                                .background(org.active ? Color.fsGreenSoft : Color.fsSurface2, in: Circle())
                            Text(org.active ? "Club is on" : "Club is off").font(.fs(ds(16), .semibold))
                            Spacer()
                            Toggle("Club is on", isOn: Binding(
                                get: { org.active },
                                set: { v in
                                    store.dispatch(WireAction(type: "org/update", id: org.id, patch: .init(active: v)))
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }
                            ))
                            .labelsHidden()
                            .tint(Color.fsGreen)
                        }
                        .card(padding: 14)

                        let members = store.state.users.filter { $0.active && $0.role != .platform && $0.orgIds.contains(org.id) }
                            .sorted { ($0.role == .advisor ? 1 : 0, $0.name) < ($1.role == .advisor ? 1 : 0, $1.name) }
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "People", action: "Add") { addPerson = true }
                                .padding(.bottom, 4)
                            ForEach(Array(members.enumerated()), id: \.element.id) { i, m in
                                if i > 0 { Divider().padding(.leading, ds(54)) }
                                Button { editing = m } label: { PersonRow(user: m) }.buttonStyle(PressableStyle())
                            }
                        }
                        .card(padding: 16)
                    }
                    CboardCard(org: org)
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Financial report")
                        ReportShareButtons(org: org)
                    }
                    .card()
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Spending by category")
                        CategoryBars(summary: s)
                    }
                    .card()
                    VStack(alignment: .leading, spacing: 4) {
                        SectionHeader(title: "Transactions (\(exps.count))")
                        ForEach(Array(exps.enumerated()), id: \.element.id) { i, e in
                            if i > 0 { Divider().padding(.leading, ds(58)) }
                            Button { shell.openExpense = e.id } label: { ExpenseRow(expense: e) }.buttonStyle(PressableStyle())
                        }
                    }
                    .card()
                    BarClearance()
                }
                .padding(.horizontal, ds(20))
            }
            .background(Color.fsBackground)
            .navigationTitle(org.name)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $adjust) { AdjustBudgetSheet(org: org) }
            .sheet(isPresented: $addPerson) { PersonSheet(user: nil, presetOrg: org.id) }
            .sheet(item: $editing) { PersonSheet(user: $0) }
        }
    }
}

struct AdjustBudgetSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let org: Org
    @State private var add = true
    @State private var amount = ""
    @State private var reason = ""

    var body: some View {
        NavigationStack {
            let s = store.state.summary(org.id)
            let v = Double(amount) ?? 0
            Form {
                Picker("Change", selection: $add) {
                    Text("Add funds").tag(true)
                    Text("Remove funds").tag(false)
                }
                .pickerStyle(.segmented)
                Section("Amount") {
                    TextField("$0.00", text: $amount).keyboardType(.decimalPad).font(.fs(28, .semibold)).monospacedDigit()
                }
                Section {
                    TextField("e.g. Supplemental funding — Spring speaker", text: $reason)
                } header: { Text("Reason") }
                if v > 0 {
                    Section { HStack { Text("New remaining balance"); Spacer(); Text(Fmt.usd(s.remaining + (add ? v : -v))).fontWeight(.semibold).monospacedDigit() } }
                }
            }
            .navigationTitle("Adjust \(org.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let al = Allocation(id: newId("al"), orgId: org.id, amount: add ? v : -v, note: reason, at: Fmt.nowISO(), by: store.userId ?? "")
                        store.dispatch(WireAction(type: "budget/adjust", allocation: al))
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                    .disabled(v <= 0 || reason.trimmingCharacters(in: .whitespaces).count < 3)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Announcements

struct AnnouncementsView: View {
    @Environment(AppStore.self) private var store
    @State private var compose = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ds(16)) {
                    Button { compose = true } label: { Label("New announcement", systemImage: "megaphone.fill") }.buttonStyle(FSButtonStyle())
                    VStack(alignment: .leading, spacing: 4) {
                        SectionHeader(title: "Published")
                        ForEach(store.state.announcements) { a in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(a.title).font(.fs(15.5, .semibold))
                                Text(a.body).font(.fsCaption).foregroundStyle(Color.fsText2).lineLimit(2)
                                HStack(spacing: 10) {
                                    Label(a.audience == .all ? "All organizations" : "Selected organizations", systemImage: "person.3")
                                    if let d = a.dueDate { Label("Due \(Fmt.shortDate(d))", systemImage: "calendar") }
                                }
                                .font(.fs(12)).foregroundStyle(Color.fsText3).padding(.top, 2)
                            }
                            .padding(.vertical, 10)
                            Divider()
                        }
                    }
                    .card()
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Funding requests")
                        ForEach(store.state.orgs) { o in
                            HStack {
                                OrgBadge(orgId: o.id, initials: o.initials, size: 30)
                                Text(o.name).font(.fs(14.5, .medium)).lineLimit(1)
                                Spacer()
                                Text(o.funding.status == "not_started" ? "Not yet" : o.funding.status == "submitted" ? "Submitted" : "Approved")
                                    .font(.fs(12, .semibold))
                                    .foregroundStyle(o.funding.status == "not_started" ? Color.fsText2 : o.funding.status == "submitted" ? Color.fsAccentText : Color.fsGreenText)
                                    .padding(.horizontal, 9).frame(height: 24)
                                    .background(o.funding.status == "not_started" ? Color.fsSurface2 : o.funding.status == "submitted" ? Color.fsAccentSoft : Color.fsGreenSoft, in: Capsule())
                            }
                            .padding(.vertical, 3)
                        }
                    }
                    .card()
                    BarClearance()
                }
                .padding(.horizontal, ds(20))
                .padding(.top, ds(4))
            }
            .fsMinimizesBar()
            .fsPage(title: "Announcements")
            .sheet(isPresented: $compose) { ComposeAnnouncement() }
        }
    }
}

private struct ComposeAnnouncement: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var message = ""
    @State private var kind = "info"
    @State private var hasDue = false
    @State private var due = Date().addingTimeInterval(14 * 86400)

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) {
                    Text("Update").tag("info")
                    Text("Deadline").tag("deadline")
                    Text("Funding form").tag("funding")
                }
                .pickerStyle(.segmented)
                Section("Title") { TextField("e.g. Spring receipts due December 12", text: $title) }
                Section("Message") { TextField("What do organizations need to know or do?", text: $message, axis: .vertical).lineLimit(3...8) }
                Section {
                    Toggle("Due date", isOn: $hasDue)
                    if hasDue { DatePicker("Due", selection: $due, displayedComponents: .date) }
                }
            }
            .navigationTitle("New announcement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publish") {
                        let a = Announcement(id: newId("an"), title: title, body: message, kind: kind, audience: .all, dueDate: hasDue ? Fmt.dayString(due) : nil, link: nil, linkLabel: nil, requiresAction: kind != "info", createdAt: Fmt.nowISO(), by: store.userId ?? "")
                        store.dispatch(WireAction(type: "announcement/publish", announcement: a))
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                    .disabled(title.count < 4 || message.count < 4)
                }
            }
        }
    }
}
