import SwiftUI

@Observable
final class ShellState {
    var selected = 0
    var previous = 0
    var addStart: DocType?
    var minimized = false
    var hideBar = false
    var addFocused = false
    var showNotifications = false
    var showSettings = false
    var openExpense: String?
}

struct TabSpec {
    let key: String
    let title: String
    let outline: String
    let filled: String
}

func tabs(for role: Role) -> [TabSpec] {
    switch role {
    case .officer:
        [TabSpec(key: "home", title: "Home", outline: "house", filled: "house.fill"),
         TabSpec(key: "activity", title: "Activity", outline: "list.bullet.rectangle", filled: "list.bullet.rectangle.fill"),
         TabSpec(key: "add", title: "Add expense", outline: "plus.circle", filled: "plus.circle.fill"),
         TabSpec(key: "ask", title: "Ask FairShare", outline: "sparkles", filled: "sparkles"),
         TabSpec(key: "club", title: "Club", outline: "person.3", filled: "person.3.fill")]
    case .accounts:
        [TabSpec(key: "overview", title: "Overview", outline: "house", filled: "house.fill"),
         TabSpec(key: "review", title: "Review queue", outline: "tray", filled: "tray.fill"),
         TabSpec(key: "orgs", title: "Organizations", outline: "building.2", filled: "building.2.fill"),
         TabSpec(key: "people", title: "People", outline: "person.2", filled: "person.2.fill"),
         TabSpec(key: "announce", title: "Announcements", outline: "megaphone", filled: "megaphone.fill")]
    case .advisor:
        [TabSpec(key: "advisor", title: "My organizations", outline: "house", filled: "house.fill"),
         TabSpec(key: "activity", title: "Activity", outline: "list.bullet.rectangle", filled: "list.bullet.rectangle.fill"),
         TabSpec(key: "profile", title: "Profile", outline: "person.crop.circle", filled: "person.crop.circle.fill")]
    case .platform:
        [TabSpec(key: "users", title: "Users", outline: "person.2", filled: "person.2.fill"),
         TabSpec(key: "orgs", title: "Organizations", outline: "building.2", filled: "building.2.fill"),
         TabSpec(key: "profile", title: "Settings", outline: "gearshape", filled: "gearshape.fill")]
    }
}

struct MainShell: View {
    @Environment(AppStore.self) private var store
    let user: User
    @State private var shell = ShellState()
    @State private var leadIn = FSTabBarLeadIn()
    @State private var metrics = FSTabBarMetrics()
    @State private var keyboardVisible = false

    var body: some View {
        let specs = tabs(for: user.role)
        ZStack {
            ForEach(Array(specs.enumerated()), id: \.offset) { index, spec in
                page(spec.key)
                    .opacity(shell.selected == index ? 1 : 0)
                    .allowsHitTesting(shell.selected == index)
                    .accessibilityHidden(shell.selected != index)
            }

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                tabBar(specs)
                    .offset(y: barHidden ? ds(160) : 0)
                    .opacity(barHidden ? 0 : 1)
                    .allowsHitTesting(!barHidden)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .ignoresSafeArea(.keyboard)
        }
        .environment(shell)
        .environment(leadIn)
        .environment(metrics)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: barHidden)
        .onChange(of: shell.selected) { old, new in
            if old != new { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            shell.previous = old
            shell.minimized = false
            shell.hideBar = false
            leadIn.value = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardVisible = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardVisible = false }
        .onChange(of: store.pendingRoute) { _, ref in
            guard let ref, ref.hasPrefix("ex_") else { return }
            store.pendingRoute = nil
            shell.openExpense = ref
        }
        .sheet(isPresented: $shell.showNotifications) { NotificationsView(user: user).environment(shell) }
        .sheet(isPresented: $shell.showSettings) { SettingsView() }
        .sheet(item: Binding(get: { shell.openExpense.map(IdentifiedString.init) }, set: { shell.openExpense = $0?.id })) { item in
            ExpenseDetailView(expenseId: item.id)
        }
    }

    private var barHidden: Bool {
        let specs = tabs(for: user.role)
        let key = specs.indices.contains(shell.selected) ? specs[shell.selected].key : ""
        return keyboardVisible || shell.hideBar || key == "ask" || (key == "add" && shell.addFocused)
    }

    @ViewBuilder
    private func page(_ key: String) -> some View {
        switch key {
        case "home": OfficerHomeView()
        case "activity": ActivityView()
        case "add": AddExpenseFlow()
        case "ask": AssistantView()
        case "club": ClubView()
        case "overview": AccountsOverviewView()
        case "review": ReviewQueueView()
        case "orgs": user.role == .platform ? AnyView(PlatformOrgsView()) : AnyView(OrgsListView())
        case "announce": AnnouncementsView()
        case "people": PeopleView()
        case "advisor": AdvisorHomeView()
        case "users": UsersView()
        case "profile": NavigationStack { SettingsContent().fsPage(title: user.role == .platform ? "Settings" : "Profile") }
        default: EmptyView()
        }
    }

    private func tabBar(_ specs: [TabSpec]) -> some View {
        GeometryReader { proxy in
            let safeBottom = proxy.safeAreaInsets.bottom
            let bottomPadding = FSGlassTabBar.bottomPadding(safeBottom: safeBottom)
            let queue = store.state.expenses.filter { $0.status == .pending }.count
            FSGlassTabBar(
                items: specs.map { s in
                    FSTabBarItem(glyph: .symbol(outline: s.outline, filled: s.filled), hint: s.title, badge: s.key == "review" ? queue : 0)
                },
                selectedIndex: shell.selected,
                isMinimized: shell.minimized,
                onSelect: { i in
                    if abs(i - shell.selected) <= 1 {
                        withAnimation(.snappy(duration: 0.32, extraBounce: 0)) { shell.selected = i }
                    } else {
                        shell.selected = i
                    }
                },
                onInteraction: { if shell.minimized { shell.minimized = false } }
            )
            .padding(.horizontal, FSGlassTabBar.horizontalMargin)
            .padding(.bottom, bottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(.container, edges: .bottom)
            .onAppear { metrics.bottomPadding = bottomPadding }
        }
        .frame(height: ds(138))
    }
}

struct IdentifiedString: Identifiable { let id: String }

// MARK: - Page scaffolding

extension View {
    func fsMinimizesBar() -> some View { modifier(MinimizesBar()) }

    func fsPage(title: String, large: Bool = true) -> some View {
        modifier(PageChrome(title: title, large: large))
    }
}

private struct MinimizesBar: ViewModifier {
    @Environment(ShellState.self) private var shell
    func body(content: Content) -> some View {
        @Bindable var shell = shell
        content.minimizeBarOnScroll($shell.minimized)
    }
}

private struct PageChrome: ViewModifier {
    let title: String
    let large: Bool
    @State private var scrolled = false

    func body(content: Content) -> some View {
        content
            .background(Color.fsBackground)
            .toolbar(.hidden, for: .navigationBar)
            .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > 2 } action: { _, now in
                if now != scrolled { withAnimation(.easeOut(duration: 0.18)) { scrolled = now } }
            }
            .safeAreaInset(edge: .top, spacing: 0) { FSPageHeader(title: title, scrolled: scrolled) }
    }
}

struct FSPageHeader: View {
    @Environment(AppStore.self) private var store
    @Environment(ShellState.self) private var shell
    let title: String
    var scrolled = false

    var body: some View {
        HStack(spacing: ds(4)) {
            Text.tightApostrophes(title, size: ds(28))
                .font(.fs(ds(28), .bold))
                .tracking(-0.7)
                .foregroundStyle(Color.fsText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: ds(8))
            if store.sync == .offline {
                Button { Task { await store.connect() } } label: {
                    Image(systemName: "wifi.slash").font(.system(size: ds(17), weight: .medium)).foregroundStyle(Color.fsText3)
                        .frame(width: ds(40), height: ds(40))
                }
                .accessibilityLabel("Offline demo mode. Tap to reconnect.")
            }
            Button { shell.showNotifications = true } label: {
                let unread = store.user.map { u in store.state.notices(for: u).filter { !$0.readBy.contains(u.id) }.count } ?? 0
                Image(systemName: unread > 0 ? "bell.badge" : "bell")
                    .font(.system(size: ds(19), weight: .medium))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(unread > 0 ? Color.fsRed : Color.fsText, Color.fsText)
                    .frame(width: ds(40), height: ds(40))
            }
            .accessibilityLabel("Notifications")
            Button { shell.showSettings = true } label: {
                AvatarView(name: store.user?.name ?? "", email: store.user?.email, size: ds(34))
            }
            .padding(.leading, ds(4))
            .accessibilityLabel("Account and settings")
        }
        .padding(.leading, ds(20))
        .padding(.trailing, ds(16))
        .padding(.top, ds(2))
        .padding(.bottom, ds(8))
        .background(Color.fsBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.fsHairline).frame(height: 1).opacity(scrolled ? 1 : 0)
        }
    }
}

struct BarClearance: View {
    var body: some View { Color.clear.frame(height: ds(120)) }
}
