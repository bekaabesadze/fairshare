import SwiftUI

// MARK: - People

extension Role {
    static let assignable: [Role] = [.officer, .advisor, .accounts]

    var short: String {
        switch self {
        case .officer: "Officer"
        case .advisor: "Advisor"
        case .accounts: "Student Accounts"
        case .platform: "Admin"
        }
    }

    var plural: String {
        switch self {
        case .officer: "Officers"
        case .advisor: "Advisors"
        case .accounts: "Student Accounts"
        case .platform: "Admins"
        }
    }
}

struct PeopleView: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""
    @State private var filter: Role?
    @State private var adding = false
    @State private var editing: User?

    var body: some View {
        NavigationStack {
            let st = store.state
            let people = st.users.filter { $0.role != .platform }
            let current = people.filter(\.active)
            let removed = people.filter { !$0.active }.sorted { $0.name < $1.name }
            let list = current
                .filter { filter == nil || $0.role == filter }
                .filter { query.isEmpty || "\($0.name) \($0.email) \(PersonRow.clubs(of: $0, in: st))".localizedCaseInsensitiveContains(query) }
                .sorted { $0.name < $1.name }
            ScrollView {
                VStack(alignment: .leading, spacing: ds(14)) {
                    FSSearchField(text: $query, prompt: "Search people or clubs")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            chip("All", current.count, filter == nil) { filter = nil }
                            ForEach(Role.assignable, id: \.self) { r in
                                chip(r.plural, current.filter { $0.role == r }.count, filter == r) { filter = r }
                            }
                        }
                        .padding(.horizontal, ds(20))
                    }
                    .padding(.horizontal, -ds(20))

                    Button { adding = true } label: { Label("Add person", systemImage: "person.badge.plus") }
                        .buttonStyle(FSButtonStyle())

                    if list.isEmpty {
                        ContentUnavailableView(query.isEmpty ? "No one here" : "No matches", systemImage: "person.2")
                            .padding(.top, 24)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(list.enumerated()), id: \.element.id) { i, u in
                                if i > 0 { Divider().padding(.leading, ds(54)) }
                                Button { editing = u } label: { PersonRow(user: u) }
                                    .buttonStyle(PressableStyle())
                            }
                        }
                        .card(padding: 16)
                    }

                    if !removed.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "Removed").padding(.bottom, 4)
                            ForEach(Array(removed.enumerated()), id: \.element.id) { i, u in
                                if i > 0 { Divider().padding(.leading, ds(54)) }
                                HStack(spacing: 8) {
                                    PersonRow(user: u, showChevron: false).opacity(0.5)
                                    Button("Restore") { setActive(u, true) }
                                        .font(.fs(ds(14), .semibold))
                                        .foregroundStyle(Color.fsAccentText)
                                        .padding(.horizontal, 12).frame(height: ds(34))
                                        .background(Color.fsAccentSoft, in: Capsule())
                                        .buttonStyle(PressableStyle())
                                }
                            }
                        }
                        .card(padding: 16)
                    }
                    BarClearance()
                }
                .padding(.horizontal, ds(20))
                .padding(.top, ds(4))
                .animation(fsSpring, value: filter)
                .animation(fsSpring, value: removed.map(\.id))
            }
            .fsMinimizesBar()
            .scrollDismissesKeyboard(.immediately)
            .fsPage(title: "People")
            .sheet(isPresented: $adding) { PersonSheet(user: nil) }
            .sheet(item: $editing) { PersonSheet(user: $0) }
        }
    }

    private func setActive(_ u: User, _ active: Bool) {
        store.dispatch(WireAction(type: "user/update", id: u.id, patch: .init(active: active)))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func chip(_ label: String, _ count: Int, _ selected: Bool, action: @escaping () -> Void) -> some View {
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

struct PersonRow: View {
    @Environment(AppStore.self) private var store
    let user: User
    var showChevron = true

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: user.name, email: user.email, size: ds(42))
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name).font(.fs(ds(15.5), .semibold)).foregroundStyle(Color.fsText).lineLimit(1)
                Text(Self.subtitle(user, store.state)).font(.fsCaption).foregroundStyle(Color.fsText2).lineLimit(1)
            }
            Spacer(minLength: 8)
            if showChevron {
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.fsText3)
            }
        }
        .padding(.vertical, ds(9))
        .contentShape(Rectangle())
    }

    static func clubs(of u: User, in st: AppState) -> String {
        st.orgs.filter { u.orgIds.contains($0.id) }.map(\.name).joined(separator: ", ")
    }

    static func subtitle(_ u: User, _ st: AppState) -> String {
        let clubs = clubs(of: u, in: st)
        switch u.role {
        case .officer:
            let position = u.title.components(separatedBy: " · ").first ?? "Officer"
            return clubs.isEmpty ? position : "\(position) · \(clubs)"
        case .advisor: return clubs.isEmpty ? "Advisor" : "Advisor · \(clubs)"
        case .accounts: return "Student Accounts"
        case .platform: return "Admin"
        }
    }
}

// MARK: - Add / edit a person

struct PersonSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let user: User?
    var presetOrg: String?

    @State private var name = ""
    @State private var email = ""
    @State private var role: Role = .officer
    @State private var position = ""
    @State private var club = ""
    @State private var advises: Set<String> = []
    @State private var confirmRemove = false
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            let st = store.state
            let domain = st.institution.domain
            let isSelf = user?.id == store.userId
            Form {
                Section("Person") {
                    TextField("Full name", text: $name).textContentType(.name)
                    if user == nil {
                        TextField("name@\(domain)", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        Text(email).foregroundStyle(Color.fsText2)
                    }
                }
                Section("Role") {
                    Picker("Role", selection: $role) {
                        ForEach(Role.assignable, id: \.self) { Text($0.short).tag($0) }
                    }
                    .disabled(isSelf)
                }
                if role == .officer {
                    Section("Club") {
                        Picker("Club", selection: $club) {
                            ForEach(st.orgs) { Text($0.name).tag($0.id) }
                        }
                        TextField("Position, e.g. Treasurer", text: $position)
                    }
                }
                if role == .advisor {
                    Section("Advises") {
                        ForEach(st.orgs) { o in
                            Button {
                                if advises.contains(o.id) { advises.remove(o.id) } else { advises.insert(o.id) }
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                HStack {
                                    Text(o.name).foregroundStyle(Color.fsText)
                                    Spacer()
                                    if advises.contains(o.id) { Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Color.fsAccent) }
                                }
                            }
                        }
                    }
                }
                if user != nil && !isSelf {
                    Section {
                        Button("Remove from FairShare", role: .destructive) { confirmRemove = true }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.fsBackground)
            .navigationTitle(user == nil ? "Add person" : "Edit person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(user == nil ? "Add" : "Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!valid(st))
                }
            }
            .confirmationDialog("Remove \(name)?", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Remove", role: .destructive, action: remove)
            } message: {
                Text("They lose access right away. You can restore them from the Removed list.")
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let firstOrg = presetOrg ?? store.state.orgs.first?.id ?? ""
        if let u = user {
            name = u.name
            email = u.email
            role = u.role == .platform ? .accounts : u.role
            position = u.role == .officer ? (u.title.components(separatedBy: " · ").first ?? "") : ""
            club = u.role == .officer ? (u.orgIds.first ?? firstOrg) : firstOrg
            advises = u.role == .advisor ? Set(u.orgIds) : (presetOrg.map { [$0] } ?? [])
        } else {
            club = firstOrg
            advises = presetOrg.map { [$0] } ?? []
        }
    }

    private func valid(_ st: AppState) -> Bool {
        guard name.trimmingCharacters(in: .whitespaces).count >= 3 else { return false }
        if role == .officer && club.isEmpty { return false }
        if role == .advisor && advises.isEmpty { return false }
        if user == nil {
            let e = email.trimmingCharacters(in: .whitespaces).lowercased()
            return e.hasSuffix("@\(st.institution.domain)") && e.count > st.institution.domain.count + 1 && !st.users.contains { $0.email == e }
        }
        return true
    }

    private func save() {
        let st = store.state
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        let orgIds: [String] = role == .officer ? [club] : role == .advisor ? st.orgs.map(\.id).filter(advises.contains) : []
        let title: String = {
            switch role {
            case .officer:
                let p = position.trimmingCharacters(in: .whitespaces)
                return "\(p.isEmpty ? "Officer" : p) · \(st.org(club)?.name ?? "")"
            case .advisor: return "Faculty advisor"
            default: return "Student Accounts"
            }
        }()

        let id: String
        if let u = user {
            id = u.id
            store.dispatch(WireAction(type: "user/update", id: u.id, patch: .init(role: role.rawValue, name: cleanName, title: title, orgIds: orgIds)))
        } else {
            id = newId("u")
            let u = User(id: id, name: cleanName, email: email.trimmingCharacters(in: .whitespaces).lowercased(), role: role, title: title, orgIds: orgIds, active: true)
            store.dispatch(WireAction(type: "user/create", user: u))
        }
        if role == .advisor {
            for orgId in orgIds where st.org(orgId)?.advisorId != id {
                store.dispatch(WireAction(type: "org/update", id: orgId, patch: .init(advisorId: id)))
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func remove() {
        guard let u = user else { return }
        store.dispatch(WireAction(type: "user/update", id: u.id, patch: .init(active: false)))
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        dismiss()
    }
}
