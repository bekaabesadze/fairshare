import SwiftUI
import LocalAuthentication
import PhotosUI

// MARK: - Expense row

struct ExpenseRow: View {
    @Environment(AppStore.self) private var store
    let expense: Expense
    var showOrg = false

    var body: some View {
        HStack(spacing: 14) {
            CategoryBadge(category: expense.category)
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.vendor).font(.fs(ds(16), .semibold)).foregroundStyle(Color.fsText).lineLimit(1)
                Text(showOrg ? "\(store.state.org(expense.orgId)?.name ?? "") · \(Fmt.shortDate(expense.date))" : "\(expense.category.short) · \(Fmt.shortDate(expense.date))")
                    .font(.fsCaption).foregroundStyle(Color.fsText2).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 5) {
                Text(Fmt.usd(expense.amount))
                    .font(.fs(ds(16), .semibold)).monospacedDigit()
                    .strikethrough(expense.status == .rejected)
                    .foregroundStyle(expense.status == .rejected ? Color.fsText3 : Color.fsText)
                    .contentTransition(.numericText())
                StatusPill(status: expense.status, short: true)
            }
        }
        .padding(.vertical, ds(10))
        .contentShape(Rectangle())
    }
}

// MARK: - Category bars

struct CategoryBars: View {
    let summary: OrgSummary
    var body: some View {
        let rows = summary.byCategory.filter { $0.approved + $0.pending > 0 }.sorted { $0.approved + $0.pending > $1.approved + $1.pending }
        let maxV = max(1, rows.map { $0.approved + $0.pending }.max() ?? 1)
        if rows.isEmpty {
            Text("No spending yet this term. Expenses you add will show up here by category.").font(.fsCaption).foregroundStyle(Color.fsText2)
        } else {
            VStack(spacing: ds(16)) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                    VStack(spacing: 7) {
                        HStack {
                            Label(r.id.label, systemImage: r.id.symbol).font(.fs(ds(14), .medium)).labelStyle(.titleAndIcon)
                            Spacer()
                            if r.approved > 0 { Text(Fmt.usd(r.approved)).font(.fs(ds(14), .semibold)).monospacedDigit() }
                            if r.pending > 0 {
                                Text("\(r.approved > 0 ? "+ " : "")\(Fmt.usd(r.pending)) pending").font(.fs(ds(14), .medium)).foregroundStyle(Color.fsAmberText).monospacedDigit()
                            }
                        }
                        GeometryReader { g in
                            HStack(spacing: 2) {
                                if r.approved > 0 {
                                    RoundedRectangle(cornerRadius: 4).fill(i == 0 ? Color.fsAccent : Color.fsText3).frame(width: g.size.width * r.approved / maxV)
                                }
                                if r.pending > 0 {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.fsAmber.opacity(0.75)).frame(width: max(4, g.size.width * r.pending / maxV - 2))
                                }
                                RoundedRectangle(cornerRadius: 4).fill(Color.fsTrack)
                            }
                        }
                        .frame(height: ds(9))
                    }
                }
            }
        }
    }
}

struct RingLegend: View {
    let summary: OrgSummary
    @Environment(\.copy) private var t
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            item(swatch: AnyView(RoundedRectangle(cornerRadius: 3).fill(Color.fsAccent)), t("Safe to spend"), summary.available)
            item(swatch: AnyView(RoundedRectangle(cornerRadius: 3).fill(Color.fsAmber)), t("Pending"), summary.pending)
            item(swatch: AnyView(RoundedRectangle(cornerRadius: 3).fill(Color.fsTrack)), t("Spent"), summary.approved)
        }
    }

    private func item(swatch: AnyView, _ label: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                swatch.frame(width: 10, height: 10)
                Text(label).font(.fsCaption).foregroundStyle(Color.fsText2).lineLimit(1).minimumScaleFactor(0.8)
            }
            Text(Fmt.usd(value)).font(.fs(ds(17), .semibold)).monospacedDigit().contentTransition(.numericText(value: value))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Expense detail

struct ExpenseDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let expenseId: String
    @State private var note = ""
    @State private var zoom = false
    @State private var photo: PhotosPickerItem?
    @State private var showNoteHint = false

    var body: some View {
        NavigationStack {
            if let e = store.state.expense(expenseId), let org = store.state.org(e.orgId), let user = store.user {
                let s = store.state.summary(org.id)
                let isAccounts = user.role == .accounts
                let canDecide = isAccounts && (e.status == .pending || e.status == .needsInfo)
                ScrollView {
                    VStack(alignment: .leading, spacing: ds(20)) {
                        Button { zoom = true } label: {
                            ReceiptImage(path: e.image)
                                .frame(maxWidth: .infinity)
                                .frame(height: ds(300))
                                .padding(16)
                                .background(Color.fsSurface2, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(alignment: .bottomTrailing) {
                                    if e.image != nil {
                                        Label("Tap to zoom", systemImage: "plus.magnifyingglass").font(.fs(12, .medium))
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(.regularMaterial, in: Capsule()).padding(10)
                                    }
                                }
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(e.image == nil)

                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Fmt.usd(e.amount)).font(.fsHero).monospacedDigit()
                                Text(e.description).font(.fsHead).foregroundStyle(Color.fsText)
                            }
                            Spacer()
                            StatusPill(status: e.status)
                        }

                        if let n = e.reviewNote, e.status != .approved {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: e.status == .rejected ? "xmark.circle.fill" : "exclamationmark.circle.fill")
                                    .font(.system(size: 20)).foregroundStyle(e.status == .rejected ? Color.fsRed : Color.fsAccent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(e.status == .rejected ? "Why it wasn’t approved" : "Student Accounts needs").font(.fs(14, .semibold))
                                    Text(n).font(.fsCaption)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(e.status == .rejected ? Color.fsRedSoft : Color.fsAccentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        VStack(spacing: 0) {
                            InfoRow(label: "Date", value: Fmt.longDate(e.date))
                            Divider()
                            InfoRow(label: "Category", value: e.category.label)
                            Divider()
                            InfoRow(label: e.docType == .check ? "Payee" : "Vendor", value: e.vendor)
                            Divider()
                            InfoRow(label: "Document", value: e.docType == .check ? "Check\(e.checkNumber.map { " #\($0)" } ?? "")" : "Receipt")
                            if let m = e.memo { Divider(); InfoRow(label: "Memo", value: m) }
                            if let t = e.tax { Divider(); InfoRow(label: "Tax", value: Fmt.usd(t)) }
                            Divider()
                            InfoRow(label: "Submitted by", value: "\(store.state.user(e.submittedBy)?.name ?? "—") · \(Fmt.shortDate(e.submittedAt))")
                            if let items = e.items, !items.isEmpty {
                                Divider()
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Items").font(.fsCaption).foregroundStyle(Color.fsText2)
                                    ForEach(items, id: \.self) { it in
                                        HStack { Text(it.name); Spacer(); Text(Fmt.usd(it.amount)).monospacedDigit() }.font(.fsCaption)
                                    }
                                }
                                .padding(.vertical, 10)
                            }
                        }
                        .padding(.horizontal, 16)
                        .background(Color.fsSurface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        if let scanned = e.scanned, !scanned.isEmpty {
                            Label("\(scanned.count) details scanned", systemImage: "sparkles")
                                .font(.fsCaption).foregroundStyle(Color.fsText2)
                        }

                        if isAccounts {
                            VStack(alignment: .leading, spacing: 8) {
                                MicroLabel(text: "Budget impact · \(org.name)")
                                HStack { Text("Remaining now").foregroundStyle(Color.fsText2); Spacer(); Text(Fmt.usd(s.remaining)).fontWeight(.semibold).monospacedDigit() }
                                if canDecide {
                                    HStack { Text("After approving").foregroundStyle(Color.fsText2); Spacer(); Text(Fmt.usd(s.remaining - e.amount)).fontWeight(.semibold).monospacedDigit().foregroundStyle(s.remaining - e.amount < 0 ? Color.fsRedText : Color.fsAccentText) }
                                }
                            }
                            .font(.fsCaption)
                            .card(padding: 16)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            MicroLabel(text: "History")
                            ForEach(Array(e.history.enumerated()), id: \.offset) { _, ev in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: eventIcon(ev.action)).foregroundStyle(eventColor(ev.action)).font(.system(size: 18))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(eventLabel(ev.action)).font(.fs(14, .semibold))
                                        Text("\(store.state.user(ev.by)?.name ?? "Someone") · \(Fmt.relative(ev.at))").font(.fsCaption).foregroundStyle(Color.fsText2)
                                        if let n = ev.note { Text("“\(n)”").font(.fsCaption).padding(8).background(Color.fsSurface2, in: RoundedRectangle(cornerRadius: 10)) }
                                    }
                                }
                            }
                            if e.status == .pending {
                                HStack(spacing: 12) {
                                    Image(systemName: "clock.fill").foregroundStyle(Color.fsAmber).font(.system(size: 18))
                                    Text("Waiting for Student Accounts").font(.fs(14, .semibold))
                                }
                            }
                        }

                        if canDecide {
                            VStack(spacing: 10) {
                                TextField("Note to the organization", text: $note, axis: .vertical)
                                    .lineLimit(2...4)
                                    .padding(14)
                                    .background(Color.fsSurface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                if showNoteHint { Text("Add a short note first.").font(.fsCaption).foregroundStyle(Color.fsRedText) }
                                Button { decide(e, "approved") } label: { Label("Approve \(Fmt.usd(e.amount))", systemImage: "checkmark.circle.fill") }
                                    .buttonStyle(FSButtonStyle(kind: .approve))
                                HStack(spacing: 10) {
                                    Button("Request documents") { decide(e, "needs_info") }.buttonStyle(FSButtonStyle(kind: .tonal, height: ds(48)))
                                    Button("Decline") { decide(e, "rejected") }.buttonStyle(FSButtonStyle(kind: .danger, height: ds(48)))
                                }
                            }
                        }

                        if user.role == .officer && e.status == .needsInfo && user.orgIds.contains(org.id) {
                            PhotosPicker(selection: $photo, matching: .images) {
                                Label("Add the missing document", systemImage: "paperclip")
                            }
                            .buttonStyle(FSButtonStyle())
                            .onChange(of: photo) { _, item in attach(item, e) }
                        }
                        if user.role == .advisor {
                            Label("Read-only", systemImage: "eye").font(.fsCaption).foregroundStyle(Color.fsText3)
                        }
                    }
                    .padding(20)
                }
                .background(Color.fsBackground)
                .navigationTitle(isAccounts ? "Review expense" : org.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
                .fullScreenCover(isPresented: $zoom) { ZoomView(path: e.image) }
            } else {
                ContentUnavailableView("Expense not found", systemImage: "doc.questionmark")
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func decide(_ e: Expense, _ status: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if status != "approved" && trimmed.isEmpty {
            withAnimation { showNoteHint = true }
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        store.dispatch(WireAction(type: "expense/review", id: e.id, status: status, note: trimmed.isEmpty ? nil : trimmed, by: store.userId, at: Fmt.nowISO()))
        UINotificationFeedbackGenerator().notificationOccurred(status == "approved" ? .success : .warning)
        dismiss()
    }

    private func attach(_ item: PhotosPickerItem?, _ e: Expense) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data), let url = img.dataURL() else { return }
            store.dispatch(WireAction(type: "expense/document", id: e.id, by: store.userId, image: url))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        }
    }

    private func eventIcon(_ a: String) -> String {
        switch a {
        case "approved": "checkmark.circle.fill"
        case "rejected": "xmark.circle.fill"
        case "needs_info": "exclamationmark.circle.fill"
        case "documented": "paperclip.circle.fill"
        default: "paperplane.circle.fill"
        }
    }
    private func eventColor(_ a: String) -> Color {
        switch a {
        case "approved": .fsGreen
        case "rejected": .fsRed
        case "needs_info": .fsAccent
        default: .fsText2
        }
    }
    private func eventLabel(_ a: String) -> String {
        switch a {
        case "approved": "Approved"
        case "rejected": "Not approved"
        case "needs_info": "More documentation requested"
        case "documented": "Documentation added"
        default: "Submitted"
        }
    }
}

struct ZoomView: View {
    @Environment(\.dismiss) private var dismiss
    let path: String?
    @State private var scale: CGFloat = 1
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            ReceiptImage(path: path)
                .scaleEffect(scale)
                .gesture(MagnifyGesture().onChanged { scale = max(1, $0.magnification) }.onEnded { _ in withAnimation(fsSpring) { scale = 1 } })
                .padding()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 40, height: 40).background(.white.opacity(0.15), in: Circle())
            }
            .padding()
            .accessibilityLabel("Close")
        }
    }
}

// MARK: - C-board number

struct CboardCard: View {
    @Environment(AppStore.self) private var store
    let org: Org
    @State private var revealed = false
    @State private var failed = false

    var body: some View {
        if let u = store.user, Permissions.canSeeCboard(u, org) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    MicroLabel(text: "C-board number")
                    Spacer()
                    Image(systemName: "lock.fill").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.fsText3)
                        .accessibilityLabel("Officers only")
                }
                HStack {
                    Text(revealed ? org.cboard : "•••\(org.cboard.suffix(2))")
                        .font(.system(size: ds(28), weight: .semibold, design: .monospaced))
                        .tracking(4)
                        .contentTransition(.numericText())
                    Spacer()
                    Button {
                        if revealed { withAnimation(fsSpring) { revealed = false } } else { authenticate() }
                    } label: {
                        Label(revealed ? "Hide" : "Reveal", systemImage: revealed ? "eye.slash" : "faceid")
                            .font(.fs(14, .semibold))
                            .padding(.horizontal, 14).frame(height: 36)
                            .background(Color.fsAccentSoft, in: Capsule())
                            .foregroundStyle(Color.fsAccentText)
                    }
                    .buttonStyle(PressableStyle())
                }
                if failed { Text("Couldn’t verify it’s you. Try again.").font(.fsCaption).foregroundStyle(Color.fsRedText) }
            }
            .card()
        }
    }

    private func authenticate() {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            reveal()
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Show \(org.name)’s C-board number") { ok, _ in
            Task { @MainActor in
                if ok { reveal() } else { failed = true }
            }
        }
    }

    private func reveal() {
        failed = false
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(fsSpring) { revealed = true }
        Task {
            try? await Task.sleep(for: .seconds(20))
            withAnimation(fsSpring) { revealed = false }
        }
    }
}

// MARK: - Notifications

struct NotificationsView: View {
    @Environment(AppStore.self) private var store
    @Environment(ShellState.self) private var shell
    @Environment(\.dismiss) private var dismiss
    let user: User

    var body: some View {
        NavigationStack {
            let list = store.state.notices(for: user)
            List {
                if list.isEmpty {
                    ContentUnavailableView("You’re all caught up", systemImage: "bell")
                }
                ForEach(list.prefix(30)) { n in
                    Button {
                        if let ref = n.ref, ref.hasPrefix("ex_") {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { shell.openExpense = ref }
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: icon(n.kind)).font(.system(size: 17, weight: .semibold)).foregroundStyle(color(n.kind))
                                .frame(width: 36, height: 36).background(color(n.kind).opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(n.title).font(.fs(15, .semibold)).foregroundStyle(Color.fsText)
                                    Spacer()
                                    Text(Fmt.relative(n.at)).font(.fs(12)).foregroundStyle(Color.fsText3)
                                }
                                Text(n.body).font(.fsCaption).foregroundStyle(Color.fsText2)
                            }
                            if !n.readBy.contains(user.id) { Circle().fill(Color.fsAccent).frame(width: 8, height: 8).padding(.top, 6) }
                        }
                    }
                    .listRowBackground(Color.fsSurface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.fsBackground)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
            .onAppear {
                let unread = list.filter { !$0.readBy.contains(user.id) }.map(\.id)
                if !unread.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        store.dispatch(WireAction(type: "notice/read", userId: user.id, ids: unread))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func icon(_ k: String) -> String {
        switch k {
        case "approved", "budget": "checkmark.circle.fill"
        case "rejected": "xmark.circle.fill"
        case "needs_info": "exclamationmark.circle.fill"
        case "submitted": "paperplane.fill"
        case "announcement": "megaphone.fill"
        case "access": "person.crop.circle.badge.questionmark"
        default: "bell.fill"
        }
    }
    private func color(_ k: String) -> Color {
        switch k {
        case "approved", "budget": .fsGreen
        case "rejected": .fsRed
        case "submitted": .fsAmber
        default: .fsAccent
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            SettingsContent()
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
        }
    }
}

struct SettingsContent: View {
    @Environment(AppStore.self) private var store
    @State private var confirmReset = false
    @State private var server = ""

    var body: some View {
        @Bindable var store = store
        Form {
            if let u = store.user {
                Section {
                    HStack(spacing: 14) {
                        AvatarView(name: u.name, email: u.email, size: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(u.name).font(.fsHead)
                            Text(u.email).font(.fsCaption).foregroundStyle(Color.fsText2)
                            Text(u.role.label).font(.fsCaption).foregroundStyle(Color.fsText3)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            Section("Appearance") {
                Picker("Appearance", selection: $store.appearance) {
                    Text("Match device").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }
            Section {
                Menu {
                    ForEach(demoAccounts) { a in
                        Button { store.signIn(a.id) } label: { Label("\(a.role.label) — \(a.who)", systemImage: a.symbol) }
                    }
                } label: {
                    Label("Switch demo account", systemImage: "arrow.left.arrow.right")
                }
            }
            Section {
                HStack {
                    Label(store.sync == .live ? "Live sync" : store.sync == .connecting ? "Connecting…" : "Offline demo", systemImage: store.sync == .live ? "dot.radiowaves.left.and.right" : "wifi.slash")
                    Spacer()
                    Circle().fill(store.sync == .live ? Color.fsGreen : Color.fsText3).frame(width: 8, height: 8)
                }
                if let active = store.activeServer, store.sync == .live {
                    LabeledContent("Connected to", value: active.host() ?? active.absoluteString)
                        .font(.fs(14))
                }
                if !store.outbox.isEmpty {
                    LabeledContent("Waiting to send", value: "\(store.outbox.count)")
                        .font(.fs(14))
                }
                TextField("Server address (optional)", text: $server)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .onSubmit { store.serverURL = server; Task { await store.connect() } }
                Button("Reconnect") { store.serverURL = server; Task { await store.connect() } }
            } header: {
                Text("Sync")
            } footer: {
                if store.sync != .live { Text("Paste the https address shown on the Mac, then tap Reconnect.") }
            }
            Section {
                Button("Reset demo data", role: .destructive) { confirmReset = true }
                Button("Sign out", role: .destructive) { store.signOut() }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.fsBackground)
        .onAppear { server = store.serverURL }
        .confirmationDialog("Reset demo data?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset for everyone", role: .destructive) { store.resetDemo() }
        } message: {
            Text("Every expense, approval and announcement made during the demo will be removed on all connected devices.")
        }
    }
}

// MARK: - Reports

enum ReportExporter {
    @MainActor
    static func pdf(state: AppState, org: Org, preparedFor: String?) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(org.name.replacingOccurrences(of: " ", with: "-"))-\(org.term.replacingOccurrences(of: " ", with: "-"))-report.pdf")
        let renderer = ImageRenderer(content: ReportPage(state: state, org: org, preparedFor: preparedFor).frame(width: 612).environment(\.colorScheme, .light))
        renderer.proposedSize = .init(width: 612, height: nil)
        var ok = false
        renderer.render { size, draw in
            var box = CGRect(x: 0, y: 0, width: 612, height: max(792, size.height))
            guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            ctx.beginPDFPage(nil)
            ctx.translateBy(x: 0, y: box.height - size.height)
            draw(ctx)
            ctx.endPDFPage()
            ctx.closePDF()
            ok = true
        }
        return ok ? url : nil
    }

    static func csv(state: AppState, org: Org) -> URL? {
        var rows = ["Date,Vendor,Category,Description,Document,Status,Amount"]
        for e in state.expenses.filter({ $0.orgId == org.id }).sorted(by: { $0.date > $1.date }) {
            let cols = [e.date, e.vendor, e.category.label, e.description, e.docType == .check ? "Check \(e.checkNumber ?? "")" : "Receipt", e.status.label, String(format: "%.2f", e.amount)]
            rows.append(cols.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ","))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(org.name.replacingOccurrences(of: " ", with: "-"))-transactions.csv")
        return (try? rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)) != nil ? url : nil
    }
}

struct ReportPage: View {
    let state: AppState
    let org: Org
    let preparedFor: String?

    var body: some View {
        let s = state.summary(org.id)
        let txns = state.expenses.filter { $0.orgId == org.id }.sorted { $0.date > $1.date }
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                LogoMark(size: 26)
                Text("FairShare").font(.fs(14, .bold))
                Spacer()
                VStack(alignment: .trailing) {
                    Text("FINANCIAL REPORT").font(.fs(8, .semibold)).tracking(1)
                    Text("\(state.institution.name) · Student Accounts").font(.fs(8))
                }
                .foregroundStyle(Color(hex: 0x6E6E74))
            }
            Divider()
            Text("\(org.name) — \(org.term)").font(.fs(24, .bold))
            Text("Generated \(Fmt.longDate(Fmt.nowISO()))\(preparedFor.map { " · Prepared for \($0)" } ?? "")").font(.fs(10)).foregroundStyle(Color(hex: 0x6E6E74))
            HStack(spacing: 10) {
                tile("Original budget", s.allocated, Color(hex: 0x151517))
                tile("Approved expenses", s.approved, Color(hex: 0x151517))
                tile("Remaining balance", s.remaining, Color(hex: 0x2453E6))
                tile("Pending review", s.pending, Color(hex: 0x8F6400))
            }
            Text("Expense breakdown").font(.fs(13, .bold)).padding(.top, 6)
            VStack(spacing: 0) {
                ForEach(s.byCategory.filter { $0.approved + $0.pending > 0 }, id: \.id) { c in
                    HStack {
                        Text(c.id.label)
                        Spacer()
                        Text(Fmt.usd(c.approved)).frame(width: 80, alignment: .trailing)
                        Text(c.pending > 0 ? Fmt.usd(c.pending) : "—").frame(width: 80, alignment: .trailing).foregroundStyle(Color(hex: 0x8F6400))
                    }
                    .font(.fs(10))
                    .padding(.vertical, 6)
                    Divider()
                }
            }
            Text("Transaction history").font(.fs(13, .bold)).padding(.top, 6)
            VStack(spacing: 0) {
                ForEach(txns) { e in
                    HStack(alignment: .top) {
                        Text(Fmt.shortDate(e.date)).frame(width: 50, alignment: .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(e.vendor).fontWeight(.semibold)
                            Text(e.description).foregroundStyle(Color(hex: 0x6E6E74))
                        }
                        Spacer()
                        Text(e.status.label).frame(width: 110, alignment: .leading)
                        Text(Fmt.usd(e.amount)).frame(width: 70, alignment: .trailing)
                    }
                    .font(.fs(9))
                    .padding(.vertical, 5)
                    Divider()
                }
            }
            Text("Generated automatically by FairShare from approved Student Accounts records. Pending amounts are not yet approved.")
                .font(.fs(8)).foregroundStyle(Color(hex: 0x6E6E74)).padding(.top, 8)
        }
        .foregroundStyle(Color(hex: 0x151517))
        .padding(40)
        .background(Color.white)
    }

    private func tile(_ label: String, _ v: Double, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.fs(7, .semibold)).foregroundStyle(Color(hex: 0x6E6E74))
            Text(Fmt.usd(v)).font(.fs(15, .bold)).foregroundStyle(c)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xF5F5F3), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct ReportShareButtons: View {
    @Environment(AppStore.self) private var store
    let org: Org
    @State private var pdfURL: URL?
    @State private var csvURL: URL?

    var body: some View {
        HStack(spacing: 10) {
            if let pdfURL {
                ShareLink(item: pdfURL) { Label("PDF report", systemImage: "doc.richtext") }
                    .buttonStyle(FSButtonStyle(kind: .secondary, height: ds(46)))
            }
            if let csvURL {
                ShareLink(item: csvURL) { Label("Spreadsheet", systemImage: "tablecells") }
                    .buttonStyle(FSButtonStyle(kind: .secondary, height: ds(46)))
            }
        }
        .task(id: store.state.version) {
            let preparedFor = store.user.map { $0.role == .advisor ? $0.name : $0.role == .accounts ? "Student Accounts" : $0.name }
            pdfURL = ReportExporter.pdf(state: store.state, org: org, preparedFor: preparedFor)
            csvURL = ReportExporter.csv(state: store.state, org: org)
        }
    }
}
