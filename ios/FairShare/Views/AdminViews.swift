import SwiftUI

// MARK: - Advisor

struct AdvisorHomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(ShellState.self) private var shell

    var body: some View {
        NavigationStack {
            if let user = store.user {
                let orgs = store.state.orgs.filter { user.orgIds.contains($0.id) }
                let recent = store.state.expenses.filter { user.orgIds.contains($0.orgId) }.sorted { $0.submittedAt > $1.submittedAt }.prefix(5)
                ScrollView {
                    VStack(alignment: .leading, spacing: ds(16)) {
                        ForEach(orgs) { org in
                            let s = store.state.summary(org.id)
                            NavigationLink(value: org.id) {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack(spacing: 12) {
                                        OrgBadge(orgId: org.id, initials: org.initials)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(org.name).font(.fsHead).foregroundStyle(Color.fsText)
                                            Text(org.term).font(.fsCaption).foregroundStyle(Color.fsText2)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.fsText3)
                                    }
                                    HStack(spacing: 20) {
                                        BudgetRing(allocated: s.allocated, approved: s.approved, pending: s.pending, lineWidth: ds(11)) {
                                            Text("\(Int((s.remaining / max(1, s.allocated) * 100).rounded()))%").font(.fs(ds(17), .semibold)).monospacedDigit().foregroundStyle(Color.fsText)
                                        }
                                        .frame(width: ds(104), height: ds(104))
                                        VStack(spacing: 8) {
                                            row("Remaining", s.remaining, .fsText)
                                            row("Approved", s.approved, .fsText2)
                                            row("Pending", s.pending, .fsAmberText)
                                        }
                                    }
                                }
                                .card()
                            }
                            .buttonStyle(PressableStyle())
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            SectionHeader(title: "Latest activity")
                            ForEach(Array(recent.enumerated()), id: \.element.id) { i, e in
                                if i > 0 { Divider().padding(.leading, ds(58)) }
                                Button { shell.openExpense = e.id } label: { ExpenseRow(expense: e, showOrg: true) }.buttonStyle(PressableStyle())
                            }
                        }
                        .card()
                        BarClearance()
                    }
                    .padding(.horizontal, ds(20))
                }
                .fsMinimizesBar()
                .fsPage(title: "Hello, \(user.firstName)")
                .navigationDestination(for: String.self) { OrgDetailView(orgId: $0) }
            }
        }
    }

    private func row(_ label: String, _ v: Double, _ c: Color) -> some View {
        HStack {
            Text(label).font(.fsCaption).foregroundStyle(Color.fsText2)
            Spacer()
            Text(Fmt.usd(v)).font(.fs(ds(15), .semibold)).monospacedDigit().foregroundStyle(c)
        }
    }
}

// MARK: - Platform admin

struct UsersView: View {
    @Environment(AppStore.self) private var store
    @State private var invite = false
    @State private var query = ""

    var body: some View {
        NavigationStack {
            let users = store.state.users.filter { query.isEmpty || "\($0.name) \($0.email)".localizedCaseInsensitiveContains(query) }
            ScrollView {
                VStack(alignment: .leading, spacing: ds(16)) {
                    FSSearchField(text: $query, prompt: "Search people")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(Role.allCases) { r in
                            VStack(alignment: .leading, spacing: 4) {
                                MicroLabel(text: r.label)
                                Text("\(store.state.users.filter { $0.role == r }.count)").font(.fs(ds(26), .bold)).monospacedDigit()
                            }
                            .card(padding: 14)
                        }
                    }
                    Button { invite = true } label: { Label("Invite user", systemImage: "person.badge.plus") }.buttonStyle(FSButtonStyle())
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(users.enumerated()), id: \.element.id) { i, u in
                            if i > 0 { Divider().padding(.leading, 52) }
                            HStack(spacing: 12) {
                                AvatarView(name: u.name, email: u.email, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(u.name).font(.fs(15, .semibold)).foregroundStyle(u.active ? Color.fsText : Color.fsText3)
                                    Text(u.email).font(.fs(12.5)).foregroundStyle(Color.fsText2).lineLimit(1)
                                }
                                Spacer()
                                Menu {
                                    Section("Role") {
                                        ForEach(Role.allCases) { r in
                                            Button { store.dispatch(WireAction(type: "user/update", id: u.id, patch: .init(role: r.rawValue))) } label: {
                                                if u.role == r { Label(r.label, systemImage: "checkmark") } else { Text(r.label) }
                                            }
                                        }
                                    }
                                    Button(u.active ? "Disable access" : "Restore access", role: u.active ? .destructive : nil) {
                                        store.dispatch(WireAction(type: "user/update", id: u.id, patch: .init(active: !u.active)))
                                    }
                                } label: {
                                    Text(roleShort(u.role)).font(.fs(12, .semibold)).foregroundStyle(Color.fsText2)
                                        .padding(.horizontal, 10).frame(height: 28).background(Color.fsSurface2, in: Capsule())
                                }
                            }
                            .padding(.vertical, 10)
                        }
                    }
                    .card(padding: 16)
                    BarClearance()
                }
                .padding(.horizontal, ds(20))
            }
            .fsMinimizesBar()
            .scrollDismissesKeyboard(.immediately)
            .fsPage(title: "Users")
            .sheet(isPresented: $invite) { InviteSheet() }
        }
    }

    private func roleShort(_ r: Role) -> String {
        switch r {
        case .officer: "Officer"
        case .accounts: "Student Accounts"
        case .advisor: "Advisor"
        case .platform: "Admin"
        }
    }
}

private struct InviteSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var role: Role = .officer
    @State private var orgId = "uptous"

    var body: some View {
        NavigationStack {
            let domain = store.state.institution.domain
            let valid = name.count >= 3 && email.lowercased().hasSuffix("@\(domain)") && !store.state.users.contains { $0.email == email.lowercased() }
            Form {
                Section("Person") {
                    TextField("Full name", text: $name)
                    TextField("name@\(domain)", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section("Access") {
                    Picker("Role", selection: $role) { ForEach(Role.allCases) { Text($0.label).tag($0) } }
                    if role == .officer || role == .advisor {
                        Picker("Organization", selection: $orgId) { ForEach(store.state.orgs) { Text($0.name).tag($0.id) } }
                    }
                }
            }
            .navigationTitle("Invite user")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Invite") {
                        let org = store.state.org(orgId)
                        let u = User(id: newId("u"), name: name, email: email.lowercased(), role: role,
                                     title: role == .officer ? "Officer · \(org?.name ?? "")" : role.label,
                                     orgIds: role == .officer || role == .advisor ? [orgId] : [], active: true)
                        store.dispatch(WireAction(type: "user/create", user: u))
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                    .disabled(!valid)
                }
            }
        }
    }
}

struct PlatformOrgsView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(store.state.orgs) { o in
                        HStack(spacing: 12) {
                            OrgBadge(orgId: o.id, initials: o.initials, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(o.name).font(.fs(15, .semibold))
                                Text(o.email).font(.fs(12.5)).foregroundStyle(Color.fsText2)
                            }
                            Spacer()
                            Toggle("Active", isOn: Binding(get: { o.active }, set: { v in store.dispatch(WireAction(type: "org/update", id: o.id, patch: .init(active: v))) }))
                                .labelsHidden()
                                .tint(Color.fsGreen)
                        }
                        .card(padding: 14)
                    }
                    BarClearance()
                }
                .padding(.horizontal, ds(20))
            }
            .fsMinimizesBar()
            .fsPage(title: "Organizations")
        }
    }
}
