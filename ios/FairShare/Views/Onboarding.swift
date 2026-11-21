import SwiftUI

struct OnboardingFlow: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    enum Step: Int { case welcome, role, email, org, notify, done }
    @State private var step: Step = .welcome
    @State private var role: Role?
    @State private var email = ""
    @State private var error: String?
    @State private var errorShakes = 0
    @State private var signingIn = false
    @State private var forward = true
    @State private var wrongAccount = false
    @State private var wrongAccountOutcome: WrongAccountSheet.Outcome = .none
    @FocusState private var emailFocused: Bool

    @State private var intro = Intro()
    @State private var introTask: Task<Void, Never>?

    struct Intro {
        var centerName = false
        var centerLine = false
        var droop: CGFloat = 0
        var headerName = false
        var headerLine = false
        var content = false
        var started = false
    }

    private var progress: Double {
        switch step {
        case .welcome: 0
        case .role: 0.2
        case .email: 0.4
        case .org: 0.6
        case .notify: 0.8
        case .done: 1
        }
    }

    private var asksQuestion: Bool { step != .welcome && step != .done }
    private var t: Copy { Copy(language: AppLanguage(rawValue: store.language) ?? .en) }

    private var droopStage: CGFloat {
        switch step {
        case .welcome: intro.droop
        case .done: 3
        default: 2
        }
    }

    var body: some View {
        GeometryReader { g in
            let screenHeight = g.size.height + g.safeAreaInsets.top + g.safeAreaInsets.bottom
            let droopBottom = DroopShape.lowest * screenHeight - g.safeAreaInsets.top
            ZStack {
                WelcomeBackdrop(intro: intro,
                                stage: droopStage,
                                onWelcome: step == .welcome,
                                bandBase: g.safeAreaInsets.top + 60)
                    .onTapGesture(perform: skipIntro)
                    .allowsHitTesting(step == .welcome && !intro.content)
                VStack(spacing: 0) {
                    header
                    ZStack(alignment: .top) {
                        page(droopBottom: droopBottom)
                            .id(step)
                            .transition(pageTransition)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    bottomBar
                }
                if step == .welcome {
                    WelcomeHeader(intro: intro,
                                  language: Binding(get: { store.language }, set: { store.language = $0 }),
                                  isDark: colorScheme == .dark,
                                  toggleTheme: toggleTheme)
                        .padding(.top, max(ds(24), 60 - g.safeAreaInsets.top))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .transition(.opacity)
                }
            }
        }
        .environment(\.copy, t)
        .background(Color.fsBackground)
        .statusBarHidden(true)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : Motion.page, value: step)
        .onAppear {
            guard !intro.started else { return }
            intro.started = true
            introTask = Task { await playIntro() }
        }
        .sheet(isPresented: $wrongAccount, onDismiss: finishWrongAccount) {
            if let u = store.user {
                WrongAccountSheet(user: u, linkedTo: linkedTo(u), outcome: $wrongAccountOutcome) {
                    store.dispatch(WireAction(type: "access/report", userId: u.id))
                }
            }
        }
    }

    // MARK: Chrome that stays between screens

    private var header: some View {
        HStack(spacing: 14) {
            Button(action: goBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(t("Back"))
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.2))
                    Capsule().fill(Color.fsAccent).frame(width: g.size.width * progress)
                }
            }
            .frame(height: 8)
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : Motion.progress, value: progress)
            .accessibilityElement()
            .accessibilityLabel(t.f("Step %d of 5", step.rawValue))
        }
        .padding(.leading, 12)
        .padding(.trailing, 24)
        .padding(.top, 6)
        .opacity(asksQuestion ? 1 : 0)
        .allowsHitTesting(asksQuestion)
    }

    private var barShown: Bool { step != .welcome || intro.content }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Button(action: primaryTapped) {
                Text(primaryTitle).contentTransition(.opacity)
            }
            .buttonStyle(FSButtonStyle())
            .disabled(!primaryEnabled)
            .opacity(barShown ? 1 : 0)
            .offset(y: barShown || reduceMotion ? 0 : 14)
            .animation(.easeOut(duration: 0.45).delay(0.12), value: barShown)

            if let title = secondaryTitle {
                if step == .welcome {
                    Button(title, action: secondaryTapped)
                        .buttonStyle(FSButtonStyle(kind: .secondary))
                        .opacity(barShown ? 1 : 0)
                        .offset(y: barShown || reduceMotion ? 0 : 14)
                        .animation(.easeOut(duration: 0.45).delay(0.2), value: barShown)
                        .transition(.opacity)
                } else {
                    Button(action: secondaryTapped) {
                        Text(title)
                            .contentTransition(.opacity)
                            .font(.fs(ds(16), .semibold))
                            .foregroundStyle(Color.fsText2)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .allowsHitTesting(barShown)
    }

    private var pageTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .offset(x: forward ? 56 : -56).combined(with: .opacity),
            removal: .offset(x: forward ? -56 : 56).combined(with: .opacity).animation(.easeIn(duration: 0.16))
        )
    }

    // MARK: Pages

    @ViewBuilder private func page(droopBottom: CGFloat) -> some View {
        switch step {
        case .welcome: welcome(droopBottom: droopBottom)
        case .role: rolePicker
        case .email: emailStep
        case .org: orgStep
        case .notify: QuestionPage(title: t("Know the moment money moves")) { NoticeFeed() }
        case .done: DonePage()
        }
    }

    private func welcome(droopBottom: CGFloat) -> some View {
        ZStack {
            if intro.content {
                MoneyMorph()
                    .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 12)).animation(.easeOut(duration: 0.5)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, max(0, droopBottom - 50 + 8))
    }

    // MARK: Intro

    private func pause(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled
    }

    private func playIntro() async {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) { finishedIntro() }
            return
        }
        guard await pause(0.35) else { return }
        withAnimation(.easeOut(duration: 0.42)) { intro.centerName = true }
        guard await pause(0.13) else { return }
        withAnimation(.easeOut(duration: 0.6)) { intro.centerLine = true }
        guard await pause(1.55) else { return }
        withAnimation(.easeIn(duration: 0.15)) { intro.centerName = false }
        withAnimation(.easeIn(duration: 0.24)) { intro.centerLine = false }
        guard await pause(0.28) else { return }
        withAnimation(.spring(response: 0.8, dampingFraction: 1)) { intro.droop = 1 }
        guard await pause(0.5) else { return }
        withAnimation(.easeOut(duration: 0.36)) { intro.headerName = true }
        guard await pause(0.07) else { return }
        withAnimation(.easeOut(duration: 0.5)) { intro.headerLine = true }
        guard await pause(0.16) else { return }
        intro.content = true
    }

    private func skipIntro() {
        guard !intro.content else { return }
        introTask?.cancel()
        withAnimation(.spring(response: 0.5, dampingFraction: 1)) { finishedIntro() }
    }

    private func toggleTheme() {
        let next = colorScheme == .dark ? "light" : "dark"
        UISelectionFeedbackGenerator().selectionChanged()
        ThemeTransition.roll(reduceMotion: reduceMotion) { store.appearance = next }
    }

    private func finishedIntro() {
        intro.centerName = false
        intro.centerLine = false
        intro.droop = 1
        intro.headerName = true
        intro.headerLine = true
        intro.content = true
    }

    private var rolePicker: some View {
        QuestionPage(title: t("Who are you?")) {
            VStack(spacing: 12) {
                ForEach(demoAccounts) { a in
                    ChoiceTile(symbol: a.symbol, title: roleTitle(a.role), selected: role == a.role, boxed: false) {
                        withAnimation(fsSpring) { role = a.role }
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
            }
        }
    }

    private var emailStep: some View {
        QuestionPage(title: t("Sign in with your Luther email")) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("you@\(store.state.institution.domain)", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($emailFocused)
                    .font(.fs(ds(17)))
                    .padding(.horizontal, 16)
                    .frame(height: ds(56))
                    .background(Color.fsSurface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(error != nil ? Color.fsRed : emailFocused ? Color.fsAccent : Color.fsHairline, lineWidth: emailFocused || error != nil ? 1.5 : 1))
                    .modifier(Shake(travel: reduceMotion ? 0 : 6, animatableData: CGFloat(errorShakes)))
                    .onSubmit(signIn)
                    .onChange(of: email) { if error != nil { withAnimation(fsSpring) { error = nil } } }
                if let error {
                    Text(error).font(.fsCaption).foregroundStyle(Color.fsRedText)
                        .transition(.opacity)
                }
                MicroLabel(text: t("Demo accounts")).padding(.top, 18)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(demoAccounts) { a in
                            Button { email = a.email } label: {
                                Text(a.email).font(.fs(ds(13.5), .medium)).foregroundStyle(Color.fsText)
                                    .padding(.horizontal, 12).frame(height: ds(34))
                                    .background(Color.fsSurface2, in: Capsule())
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
                .scrollClipDisabled()
            }
            .sensoryFeedback(.error, trigger: errorShakes)
        }
    }

    @ViewBuilder private var orgStep: some View {
        if let u = store.user {
            let orgs = store.state.orgs.filter { u.orgIds.contains($0.id) }
            QuestionPage(title: u.role == .officer ? t("Is this your organization?") : u.role == .advisor ? t("You advise these organizations") : t.f("Welcome, %@", u.firstName)) {
                VStack(spacing: 12) {
                    if orgs.isEmpty {
                        MatchCard(badge: .symbol(u.role == .accounts ? "building.columns.fill" : "lock.shield.fill"),
                                  title: u.role.label, detail: t.f("%d organizations", store.state.orgs.count), delay: 0.2)
                    }
                    ForEach(Array(orgs.enumerated()), id: \.element.id) { i, o in
                        MatchCard(badge: .org(id: o.id, initials: o.initials), title: o.name,
                                  detail: u.role == .officer ? (u.title.components(separatedBy: " · ").first ?? "") : t("Read-only"),
                                  delay: 0.2 + Double(i) * 0.08)
                    }
                }
            }
        }
    }

    // MARK: Bottom bar

    private var primaryTitle: String {
        switch step {
        case .welcome: t("Get started")
        case .role: t("Continue")
        case .email: signingIn ? t("Signing in…") : t("Continue with Luther SSO")
        case .org: store.user?.role == .officer ? t("Yes, that’s us") : t("Continue")
        case .notify: t("Turn on notifications")
        case .done: t("Start using FairShare")
        }
    }

    private var primaryEnabled: Bool {
        switch step {
        case .role: role != nil
        case .email: !email.isEmpty && !signingIn
        default: true
        }
    }

    private var secondaryTitle: String? {
        switch step {
        case .welcome: t("I already have an account")
        case .org:
            switch store.user?.role {
            case .officer: t("No, it’s not")
            case .advisor: t("That’s not right")
            default: t("Not you?")
            }
        case .notify: t("Not now")
        default: nil
        }
    }

    private func primaryTapped() {
        switch step {
        case .welcome: go(to: .role)
        case .role:
            if let r = role, let demo = demoAccounts.first(where: { $0.role == r }) { email = demo.email }
            go(to: .email)
        case .email: signIn()
        case .org: go(to: .notify)
        case .notify:
            Task {
                _ = await store.requestNotifications()
                go(to: .done)
            }
        case .done:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            store.hasOnboarded = true
        }
    }

    private func secondaryTapped() {
        switch step {
        case .welcome: role = nil; go(to: .email)
        case .org: wrongAccountOutcome = .none; wrongAccount = true
        case .notify: go(to: .done)
        default: break
        }
    }

    // MARK: Logic

    private func signIn() {
        let v = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard v.hasSuffix("@\(store.state.institution.domain)") else {
            fail(t.f("Use your @%@ email address.", store.state.institution.domain))
            return
        }
        guard let u = store.state.users.first(where: { $0.email == v }) else {
            fail(t("We couldn’t find an account for that email. Ask your organization’s president or Student Accounts to add you."))
            return
        }
        guard u.active else {
            fail(t("This account was removed. Ask Student Accounts to restore it."))
            return
        }
        error = nil
        emailFocused = false
        signingIn = true
        Task {
            try? await Task.sleep(for: .seconds(0.8))
            signingIn = false
            store.signIn(u.id)
            go(to: .org)
        }
    }

    private func fail(_ message: String) {
        withAnimation(fsSpring) { error = message }
        withAnimation(.easeInOut(duration: 0.3)) { errorShakes += 1 }
    }

    private func linkedTo(_ u: User) -> String {
        let names = store.state.orgs.filter { u.orgIds.contains($0.id) }.map(\.name)
        return names.isEmpty ? t.f("%@ access", u.role.label) : names.joined(separator: t(" and "))
    }

    private func finishWrongAccount() {
        switch wrongAccountOutcome {
        case .none: return
        case .differentEmail:
            store.signOut()
            email = ""
            error = nil
            forward = false
            step = .email
            Task {
                try? await Task.sleep(for: .seconds(0.45))
                emailFocused = true
            }
        case .reported:
            store.signOut()
            email = ""
            role = nil
            forward = false
            step = .welcome
        }
        wrongAccountOutcome = .none
    }

    private func go(to s: Step) {
        forward = true
        step = s
    }

    private func goBack() {
        forward = false
        switch step {
        case .role: step = .welcome
        case .email: step = role == nil ? .welcome : .role
        case .org: step = .email
        case .notify: step = .org
        default: step = .welcome
        }
    }

    private func roleTitle(_ r: Role) -> String {
        switch r {
        case .officer: t("I run a student organization")
        case .accounts: t("I work in Student Accounts")
        case .advisor: t("I advise an organization")
        case .platform: t("I manage FairShare")
        }
    }
}

private enum Motion {
    static let page = Animation.spring(response: 0.42, dampingFraction: 0.9)
    static let progress = Animation.spring(response: 0.55, dampingFraction: 0.86)
    static let morph = Animation.spring(response: 0.8, dampingFraction: 0.9)
    static let droop = Animation.spring(response: 0.8, dampingFraction: 1)
}

// MARK: - Welcome droop

private extension Color {
    static let fsDroop = Color(light: Color(hex: 0x0A0A0B), dark: Color(hex: 0x000000))
    static let fsWelcomePage = Color(light: Color(hex: 0xF3F3F1), dark: Color(hex: 0x161618))
    static let fsWelcomePaper = Color(light: Color(hex: 0xFCFCFB), dark: Color(hex: 0x1F1F22))
    static let fsDroopLine = Color.white.opacity(0.52)
}

private struct WelcomeBackdrop: View {
    let intro: OnboardingFlow.Intro
    let stage: CGFloat
    let onWelcome: Bool
    let bandBase: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.copy) private var t

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .topLeading) {
                onWelcome ? Color.fsWelcomePage : Color.fsBackground
                DroopShape(stage: stage, bandBase: bandBase)
                    .fill(Color.fsDroop)
                    .animation(reduceMotion ? .easeInOut(duration: 0.3) : Motion.droop, value: stage)

                VStack(spacing: 12) {
                    Wordmark(size: 30)
                        .opacity(intro.centerName ? 1 : 0)
                        .offset(y: intro.centerName || reduceMotion ? 0 : 7)
                    tagline
                        .opacity(intro.centerLine ? 1 : 0)
                }
                .frame(width: g.size.width)
                .position(x: g.size.width / 2, y: g.size.height * 0.48)

            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(intro.content || !onWelcome)
        .accessibilityLabel("FairShare. " + t("Your club’s money, clear and simple."))
    }

    private var tagline: some View {
        Text(t("Your club’s money, clear and simple."))
            .font(.fs(15))
            .tracking(0.3)
            .foregroundStyle(Color.fsDroopLine)
    }
}

private struct WelcomeControls: View {
    @Binding var language: String
    let isDark: Bool
    let toggleTheme: () -> Void
    @Environment(\.copy) private var t

    var body: some View {
        HStack(spacing: 2) {
            Button(action: toggleTheme) {
                Image(systemName: isDark ? "moon" : "sun.max")
                    .font(.system(size: 19, weight: .regular))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(isDark ? t("Switch to light mode") : t("Switch to dark mode"))

            Menu {
                Picker(t("Language"), selection: $language.animation(.smooth(duration: 0.35))) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.name).tag(lang.rawValue)
                    }
                }
            } label: {
                Image(systemName: "globe")
                    .font(.system(size: 19, weight: .regular))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .menuOrder(.fixed)
            .accessibilityLabel(t("Language"))
        }
        .foregroundStyle(.white.opacity(0.92))
        .tint(.white)
    }
}

private struct WelcomeHeader: View {
    let intro: OnboardingFlow.Intro
    @Binding var language: String
    let isDark: Bool
    let toggleTheme: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.copy) private var t

    private var slide: CGFloat { intro.headerName || reduceMotion ? 0 : -18 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 12) {
                Wordmark(size: 28)
                    .opacity(intro.headerName ? 1 : 0)
                    .offset(x: slide)
                    .allowsHitTesting(false)
                Spacer(minLength: 0)
                WelcomeControls(language: $language, isDark: isDark, toggleTheme: toggleTheme)
                    .opacity(intro.headerName ? 1 : 0)
                    .allowsHitTesting(intro.content)
            }
            Text(t("Your club’s money, clear and simple."))
                .font(.fs(15))
                .tracking(0.3)
                .foregroundStyle(Color.fsDroopLine)
                .opacity(intro.headerLine ? 1 : 0)
                .offset(x: slide)
                .allowsHitTesting(false)
        }
        .padding(.leading, 26)
        .padding(.trailing, 12)
    }
}

private struct Wordmark: View {
    let size: CGFloat
    var body: some View {
        Text("FAIRSHARE")
            .font(.fs(size, .medium))
            .tracking(size * 0.24)
            .foregroundStyle(.white)
    }
}

struct DroopShape: Shape {
    var stage: CGFloat
    var bandBase: CGFloat = 120

    static let lowest: CGFloat = 0.297
    private static let left = CGPoint(x: 0, y: 0.2392)
    private static let control1 = CGPoint(x: 0.3768, y: 0.3421)
    private static let control2 = CGPoint(x: 0.70, y: 0.30)
    private static let right = CGPoint(x: 1, y: 0.17)

    private static let bandLeft = CGPoint(x: 0, y: 10)
    private static let bandControl1 = CGPoint(x: 0.38, y: 44)
    private static let bandControl2 = CGPoint(x: 0.70, y: 30)
    private static let bandRight = CGPoint(x: 1, y: 0)
    static let bandDepth: CGFloat = 30

    var animatableData: CGFloat {
        get { stage }
        set { stage = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let s = max(stage, 0)
        let edge: (right: CGPoint, c2: CGPoint, c1: CGPoint, left: CGPoint)
        if s <= 1 {
            let p = s
            let sag = 1 + 0.6 * (1 - p)
            let start = 1 + sag * (Self.lowest - Self.right.y)
            let base = start + (Self.lowest - start) * p
            func point(_ q: CGPoint) -> CGPoint {
                CGPoint(x: rect.minX + q.x * rect.width,
                        y: rect.minY + (base + sag * (q.y - Self.lowest)) * rect.height)
            }
            edge = (point(Self.right), point(Self.control2), point(Self.control1), point(Self.left))
        } else {
            let t = min(s - 1, 1)
            let lift = max(0, min(s, 3) - 2) * (bandBase + Self.bandDepth + 24)
            func full(_ q: CGPoint) -> CGPoint { CGPoint(x: rect.minX + q.x * rect.width, y: rect.minY + q.y * rect.height) }
            func band(_ q: CGPoint) -> CGPoint { CGPoint(x: rect.minX + q.x * rect.width, y: rect.minY + bandBase + q.y) }
            func mix(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
                CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t - lift)
            }
            edge = (mix(full(Self.right), band(Self.bandRight)),
                    mix(full(Self.control2), band(Self.bandControl2)),
                    mix(full(Self.control1), band(Self.bandControl1)),
                    mix(full(Self.left), band(Self.bandLeft)))
        }
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY - 2))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY - 2))
        path.addLine(to: edge.right)
        path.addCurve(to: edge.left, control1: edge.c2, control2: edge.c1)
        path.closeSubpath()
        return path
    }
}

// MARK: - Pages

private struct QuestionPage<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.fs(ds(30), .bold))
                    .tracking(-0.5)
                    .fixedSize(horizontal: false, vertical: true)
                content.padding(.top, 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 10 + DroopShape.bandDepth + 22)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct MatchCard: View {
    enum Badge { case org(id: String, initials: String), symbol(String) }
    let badge: Badge
    let title: String
    let detail: String
    let delay: Double
    @State private var shown = false

    var body: some View {
        HStack(spacing: 14) {
            switch badge {
            case .org(let id, let s): OrgBadge(orgId: id, initials: s, size: ds(52))
            case .symbol(let s):
                Image(systemName: s)
                    .font(.system(size: ds(21)))
                    .foregroundStyle(.white)
                    .frame(width: ds(52), height: ds(52))
                    .background(Color.fsText, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.fsHead)
                Text(detail).font(.fsCaption).foregroundStyle(Color.fsText2)
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.fsAccent)
                .scaleEffect(shown ? 1 : 0.3)
                .opacity(shown ? 1 : 0)
        }
        .card(padding: 16)
        .task {
            try? await Task.sleep(for: .seconds(delay))
            withAnimation(.spring(response: 0.38, dampingFraction: 0.55)) { shown = true }
        }
        .sensoryFeedback(.selection, trigger: shown)
    }
}

private struct NoticeFeed: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.copy) private var t
    private struct Item: Identifiable, Equatable { let id: Int }
    @State private var items: [Item] = []

    private static let samples: [(icon: String, tint: Color, title: String, detail: String)] = [
        ("checkmark.circle.fill", .fsGreen, "$52.00 approved", "Luther Book Shop · Prizes"),
        ("exclamationmark.circle.fill", .fsAccent, "One more document needed", "Document Center · $35.00"),
        ("dollarsign.circle.fill", .fsGreen, "$150.00 added to your budget", "Student Accounts"),
        ("megaphone.fill", .fsAccent, "Annual funding request is open", "Due December 11"),
    ]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let s = Self.samples[item.id % Self.samples.count]
                PreviewNotice(icon: s.icon, tint: s.tint, title: t(s.title), detail: t(s.detail))
                    .scaleEffect(1 - CGFloat(index) * 0.035)
                    .opacity(1 - Double(index) * 0.3)
                    .transition(.asymmetric(insertion: .offset(y: -22).combined(with: .scale(scale: 0.96, anchor: .top)).combined(with: .opacity), removal: .opacity))
            }
        }
        .frame(height: 3 * 68 + 20, alignment: .top)
        .padding(.top, 4)
        .task {
            if reduceMotion {
                items = [Item(id: 0), Item(id: 1), Item(id: 2)].reversed()
                return
            }
            var next = 0
            try? await Task.sleep(for: .seconds(0.35))
            while !Task.isCancelled {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    items.insert(Item(id: next), at: 0)
                    if items.count > 3 { items.removeLast() }
                }
                next += 1
                try? await Task.sleep(for: .seconds(next < 3 ? 0.8 : 2.4))
            }
        }
    }
}

private struct PreviewNotice: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String
    @Environment(\.copy) private var t

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 38, height: 38).background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.fs(15, .semibold)).lineLimit(1)
                Text(detail).font(.fs(13)).foregroundStyle(Color.fsText2).lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(t("now")).font(.fs(12)).foregroundStyle(Color.fsText3)
        }
        .padding(14)
        .frame(height: 68)
        .background(Color.fsSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.fsHairline, lineWidth: 1))
    }
}

// MARK: - Welcome hero

private struct MoneyMorph: View {
    enum Form { case ring, sheet, receipt }
    private let summary = OrgSummary(allocated: 600, approved: 0, pending: 120,
                                     pendingCount: 1, needsInfoCount: 1, byCategory: [])
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.copy) private var t
    @State private var form: Form = .ring
    @State private var caption: Form = .ring
    @State private var row = 0
    @State private var scan = 0.0
    @State private var fill = 0.0

    private static let canvas = CGSize(width: 320, height: 280)

    var body: some View {
        VStack(spacing: ds(8)) {
            ZStack {
                Text(captionText(caption))
                    .font(.fs(ds(18), .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(Color.fsText)
                    .multilineTextAlignment(.center)
                    .id(caption)
                    .transition(.blurReplace(.upUp))
            }
            .frame(maxWidth: .infinity)
            .frame(height: ds(26))
            .padding(.top, ds(80))
            GeometryReader { g in
                let scale = min(1.12, g.size.width / Self.canvas.width, g.size.height / Self.canvas.height)
                MorphObject(params: params, summary: summary, row: row)
                    .frame(width: Self.canvas.width, height: Self.canvas.height)
                    .scaleEffect(scale)
                    .frame(width: g.size.width, height: g.size.height)
            }
            .padding(.bottom, ds(10))
        }
        .task { await cycle() }
        .accessibilityElement()
        .accessibilityLabel("\(Fmt.usd(summary.remaining)) remaining")
    }

    private var params: MorphParams {
        var p: MorphParams
        switch form {
        case .ring: p = MorphParams(w: 212, h: 212, r: 106, teeth: 0, line: 13, ring: 1, sheet: 0, receipt: 0)
        case .sheet: p = MorphParams(w: 306, h: 198, r: 14, teeth: 0, line: 2.5, ring: 0, sheet: 1, receipt: 0)
        case .receipt: p = MorphParams(w: 214, h: 266, r: 7, teeth: 1, line: 2.5, ring: 0, sheet: 0, receipt: 1)
        }
        p.scan = scan
        p.fill = form == .ring ? fill : 1
        return p
    }

    private func captionText(_ f: Form) -> String {
        switch f {
        case .ring: t("See exactly what’s left")
        case .sheet: t("No more spreadsheets")
        case .receipt: t("Snap a receipt, we read it")
        }
    }

    private func show(_ next: Form) {
        withAnimation(Motion.morph) {
            form = next
            if next == .ring { fill = 0.04 }
        }
        withAnimation(.smooth(duration: 0.55)) { caption = next }
    }

    private static let fillCurve = Animation.timingCurve(0.2, 0.9, 0.25, 1, duration: 1.4)

    private func cycle() async {
        guard !reduceMotion else {
            fill = 1
            return
        }
        try? await Task.sleep(for: .seconds(0.35))
        while !Task.isCancelled {
            withAnimation(Self.fillCurve) {
                fill = 1
                scan = 0
                row = 0
            }
            try? await Task.sleep(for: .seconds(1.75))
            show(.sheet)
            try? await Task.sleep(for: .seconds(1.3))
            for r in 1...2 {
                withAnimation(.snappy(duration: 0.22)) { row = r }
                try? await Task.sleep(for: .seconds(0.8))
            }
            try? await Task.sleep(for: .seconds(0.3))
            show(.receipt)
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeInOut(duration: 1.1)) { scan = 1 }
            try? await Task.sleep(for: .seconds(1.7))
            show(.ring)
            try? await Task.sleep(for: .seconds(0.75))
        }
    }
}

private struct MorphParams: VectorArithmetic {
    var w = 0.0, h = 0.0, r = 0.0, teeth = 0.0, line = 0.0
    var ring = 0.0, sheet = 0.0, receipt = 0.0, scan = 0.0, fill = 1.0

    init() {}
    init(w: Double, h: Double, r: Double, teeth: Double, line: Double, ring: Double, sheet: Double, receipt: Double) {
        self.w = w; self.h = h; self.r = r; self.teeth = teeth; self.line = line
        self.ring = ring; self.sheet = sheet; self.receipt = receipt
    }

    private var values: [Double] { [w, h, r, teeth, line, ring, sheet, receipt, scan, fill] }
    private init(_ v: [Double]) {
        w = v[0]; h = v[1]; r = v[2]; teeth = v[3]; line = v[4]
        ring = v[5]; sheet = v[6]; receipt = v[7]; scan = v[8]; fill = v[9]
    }

    static var zero: MorphParams { MorphParams(Array(repeating: 0, count: 10)) }
    static func + (a: MorphParams, b: MorphParams) -> MorphParams { MorphParams(zip(a.values, b.values).map(+)) }
    static func - (a: MorphParams, b: MorphParams) -> MorphParams { MorphParams(zip(a.values, b.values).map(-)) }
    mutating func scale(by rhs: Double) { self = MorphParams(values.map { $0 * rhs }) }
    var magnitudeSquared: Double { values.reduce(0) { $0 + $1 * $1 } }
}

private struct MorphObject: View, Animatable {
    var params: MorphParams
    let summary: OrgSummary
    let row: Int

    @Environment(\.copy) private var t

    var animatableData: MorphParams {
        get { params }
        set { params = newValue }
    }

    private func settle(_ x: Double) -> Double { let c = min(max(x, 0), 1); return c * c * c }

    var body: some View {
        let p = params
        let line = CGFloat(p.line)
        let size = CGSize(width: max(1, p.w - p.line), height: max(1, p.h - p.line))
        let shape = MorphFrame(radius: CGFloat(max(0, p.r - p.line / 2)), teeth: CGFloat(p.teeth))
        let paper = min(1, p.sheet + p.receipt)

        let total = max(summary.allocated, 0.01)
        let fA = max(0, summary.allocated - summary.approved - summary.pending) / total
        let fP = max(0, min(summary.pending, summary.allocated - summary.approved)) / total
        let perimeter = 2 * (size.width + size.height) - (8 - 2 * .pi) * shape.clampedRadius(in: size)
        let gap = (line + 4) / max(perimeter, 1)
        let pFrom = fA + gap / 2
        let pTo = max(pFrom, fA + fP - gap / 2)

        return ZStack {
            shape
                .fill(Color.fsWelcomePaper)
                .opacity(paper)
                .shadow(color: .black.opacity(0.07 * paper), radius: 14, y: 6)
                .frame(width: size.width, height: size.height)

            ZStack {
                shape.stroke(Color.fsTrack, lineWidth: line)
                if fP > gap {
                    shape.trim(from: pFrom, to: pTo)
                        .stroke(Color.fsAmber.opacity(0.5), style: StrokeStyle(lineWidth: line, lineCap: .round))
                    shape.trim(from: pFrom, to: pTo)
                        .stroke(Color.fsAmber, style: StrokeStyle(lineWidth: line, lineCap: .butt, dash: [2.5, 3]))
                        .mask(shape.trim(from: pFrom, to: pTo).stroke(style: StrokeStyle(lineWidth: line, lineCap: .round)))
                }
                if fA > 0.002 {
                    shape.trim(from: gap / 2, to: gap / 2 + max(0.001, fA - gap) * min(max(p.fill, 0), 1))
                        .stroke(Color.fsAccent, style: StrokeStyle(lineWidth: line, lineCap: .round))
                }
            }
            .frame(width: size.width, height: size.height)

            ZStack {
                SheetContent(row: row)
                    .frame(width: 305, height: 197)
                    .opacity(settle(p.sheet))
                ReceiptContent(scan: p.scan)
                    .frame(width: 213, height: 265)
                    .opacity(settle(p.receipt))
            }
            .frame(width: size.width, height: size.height)
            .clipShape(shape)

            Capsule()
                .fill(Color.fsAccent)
                .frame(width: size.width + 20, height: 3)
                .offset(y: -size.height / 2 + 12 + CGFloat(p.scan) * (size.height - 30))
                .opacity(sin(.pi * p.scan) * settle(p.receipt))

            VStack(spacing: 2) {
                Text(t("Remaining")).font(.fs(13.5)).foregroundStyle(Color.fsText2)
                Text(Fmt.usd(summary.remaining)).font(.fs(26, .bold)).monospacedDigit()
            }
            .opacity(settle(p.ring))
        }
    }
}

private struct MorphFrame: Shape {
    var radius: CGFloat
    var teeth: CGFloat

    func clampedRadius(in size: CGSize) -> CGFloat { min(radius, size.width / 2, size.height / 2) }

    func path(in rect: CGRect) -> Path {
        let r = clampedRadius(in: rect.size)
        let br = r * (1 - teeth)
        let depth = 6 * teeth
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        p.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        if depth > 0.05 {
            let n = 13
            let start = rect.maxX - br
            let step = (start - (rect.minX + br)) / CGFloat(n)
            for i in 0..<n {
                p.addLine(to: CGPoint(x: start - step * (CGFloat(i) + 0.5), y: rect.maxY - depth))
                p.addLine(to: CGPoint(x: start - step * CGFloat(i + 1), y: rect.maxY))
            }
        } else {
            p.addLine(to: CGPoint(x: rect.minX + br, y: rect.maxY))
        }
        p.addArc(center: CGPoint(x: rect.minX + br, y: rect.maxY - br), radius: br, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}

private struct SheetContent: View {
    let row: Int

    private let rows: [(String, String, String)] = [
        ("Date", "Item", "Amount"),
        ("11/10", "Posters", "35.00"),
        ("11/15", "Pizza", "85.00"),
        ("11/18", "Prizes", "52.00"),
        ("", "Left", "428.00"),
    ]
    private let widths: [CGFloat] = [24, 58, 118, 105]
    private let rowHeight: CGFloat = 23
    private let top: CGFloat = 28 + 1 + 20 + 1
    private var selected: Int { row + 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("fx").font(.fs(12, .semibold)).foregroundStyle(Color.fsText3)
                Rectangle().fill(Color.fsHairline).frame(width: 1, height: 14)
                Text(rows[selected].2.replacingOccurrences(of: ".00", with: ""))
                    .font(.fs(12)).monospacedDigit()
                    .contentTransition(.opacity)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            rule
            HStack(spacing: 0) {
                cell("", 0, header: true)
                cell("A", 1, header: true)
                cell("B", 2, header: true)
                cell("C", 3, header: true, active: true)
            }
            .frame(height: 20)
            .background(Color.fsSurface2)
            rule
            ForEach(rows.indices, id: \.self) { i in
                HStack(spacing: 0) {
                    cell("\(i + 1)", 0, header: true, active: i == selected)
                        .background(Color.fsSurface2)
                    cell(rows[i].0, 1, dim: true)
                    cell(rows[i].1, 2, bold: i == 0 || i == 4)
                    cell(rows[i].2, 3, bold: i == 0 || i == 4, trailing: i > 0)
                }
                .frame(height: rowHeight)
                rule
            }
            Spacer(minLength: 0)
            rule
            HStack(spacing: 12) {
                Image(systemName: "plus").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.fsText3)
                Image(systemName: "line.3.horizontal").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.fsText3)
                Text("Budget")
                    .font(.fs(11, .semibold))
                    .foregroundStyle(Color.fsAccentText)
                    .padding(.horizontal, 9)
                    .frame(height: 19)
                    .background(Color.fsAccentSoft, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
        }
        .overlay(alignment: .topLeading) {
            Rectangle()
                .strokeBorder(Color.fsAccent, lineWidth: 2)
                .frame(width: widths[3] + 1, height: rowHeight + 2)
                .overlay(alignment: .bottomTrailing) {
                    Rectangle().fill(Color.fsAccent)
                        .frame(width: 6, height: 6)
                        .overlay(Rectangle().stroke(Color.fsSurface, lineWidth: 1.5))
                        .offset(x: 3, y: 3)
                }
                .offset(x: widths[0] + widths[1] + widths[2] - 1, y: top + CGFloat(selected) * (rowHeight + 1) - 1)
        }
    }

    private var rule: some View { Rectangle().fill(Color.fsHairline).frame(height: 1) }

    private func cell(_ text: String, _ col: Int, header: Bool = false, active: Bool = false, dim: Bool = false, bold: Bool = false, trailing: Bool = false) -> some View {
        Text(text)
            .font(.fs(header ? 10.5 : 12, bold ? .semibold : header ? .medium : .regular))
            .monospacedDigit()
            .foregroundStyle(active ? Color.fsAccentText : header || dim ? Color.fsText3 : Color.fsText)
            .lineLimit(1)
            .padding(.horizontal, header ? 0 : 7)
            .frame(width: widths[col], alignment: header ? .center : trailing ? .trailing : .leading)
            .frame(maxHeight: .infinity)
            .background(active ? Color.fsAccentSoft : .clear)
            .overlay(alignment: .trailing) { Rectangle().fill(Color.fsHairline).frame(width: 1) }
    }
}

private struct ReceiptContent: View {
    let scan: Double

    var body: some View {
        let found = min(max((scan - 0.82) / 0.18, 0), 1)
        VStack(spacing: 0) {
            Text("LUTHER BOOK SHOP")
                .font(.fs(13, .bold)).tracking(0.6)
                .background(mark(found))
                .padding(.top, 18)
            Text("11/18/2026   2:14 PM")
                .font(.fs(10.5)).monospacedDigit()
                .foregroundStyle(Color.fsText2)
                .background(mark(found))
                .padding(.top, 5)
            dashes
            line("Water Bottle x2", "25.90")
            line("Sticker Pack x4", "10.00")
            line("Lanyard x2", "12.70")
            dashes
            line("Subtotal", "48.60")
            line("Tax 7%", "3.40")
            line("TOTAL", "$52.00", bold: true)
                .background(mark(found))
                .padding(.top, 2)
            dashes
            Text("Thank you! Go Norse!")
                .font(.fs(10))
                .foregroundStyle(Color.fsText3)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
    }

    private var dashes: some View {
        HLine()
            .stroke(Color.fsText3, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(height: 1)
            .padding(.vertical, 9)
    }

    private func line(_ label: String, _ amount: String, bold: Bool = false) -> some View {
        HStack {
            Text(label)
            Spacer(minLength: 8)
            Text(amount)
        }
        .font(.fs(bold ? 12.5 : 11, bold ? .bold : .regular)).monospacedDigit()
        .foregroundStyle(Color.fsText)
        .frame(height: bold ? 19 : 16)
    }

    private func mark(_ amount: Double) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.fsAccentSoft)
            .padding(.horizontal, -5)
            .padding(.vertical, -2)
            .opacity(amount)
    }
}

private struct HLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

// MARK: - Finish

private struct DonePage: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.copy) private var t
    @State private var shown = false
    @State private var check = 0.0
    @State private var open = 0.0
    @State private var fill = 0.0
    @State private var amount = 0.0
    @State private var details = false

    var body: some View {
        let s = scope
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ReadyRing(check: check, open: open, fill: fill, amount: amount, summary: s, flowing: details)
                .frame(width: ds(252), height: ds(252))
                .scaleEffect(shown || reduceMotion ? 1 : 0.7)
                .opacity(shown ? 1 : 0)
                .accessibilityElement()
                .accessibilityLabel("\(Fmt.usd(s.remaining)) \(t("Remaining"))")
            Text.tightApostrophes(headline, size: ds(32))
                .font(.fsLarge)
                .tracking(-0.4)
                .multilineTextAlignment(.center)
                .padding(.top, ds(30))
                .opacity(shown ? 1 : 0)
                .offset(y: shown || reduceMotion ? 0 : 10)
            Text.tightApostrophes(subline, size: ds(16))
                .font(.fsBody)
                .foregroundStyle(Color.fsText2)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .opacity(details ? 1 : 0)
                .offset(y: details || reduceMotion ? 0 : 8)
            RingLegend(summary: s)
                .padding(.top, ds(30))
                .opacity(details ? 1 : 0)
                .offset(y: details || reduceMotion ? 0 : 12)
                .animation(.spring(response: 0.55, dampingFraction: 0.9).delay(0.1), value: details)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.success, trigger: check >= 1)
        .task { await play(s) }
    }

    private var headline: String {
        guard let name = store.user?.firstName else { return t("You’re all set") }
        return t.f("You’re all set, %@", name)
    }

    private var subline: String {
        switch store.user?.role {
        case .officer: t.f("Here’s %@ today.", store.officerOrg?.name ?? "")
        case .advisor: t("Here’s what you advise today.")
        default: t("Here’s every organization today.")
        }
    }

    private var scope: OrgSummary {
        guard let u = store.user else { return store.state.summary("uptous") }
        switch u.role {
        case .officer: return store.state.summary(u.orgIds.first ?? "")
        case .advisor: return combined(u.orgIds)
        default: return combined(store.state.orgs.map(\.id))
        }
    }

    private func combined(_ ids: [String]) -> OrgSummary {
        let parts = ids.map { store.state.summary($0) }
        return OrgSummary(allocated: parts.reduce(0) { $0 + $1.allocated },
                          approved: parts.reduce(0) { $0 + $1.approved },
                          pending: parts.reduce(0) { $0 + $1.pending },
                          pendingCount: parts.reduce(0) { $0 + $1.pendingCount },
                          needsInfoCount: parts.reduce(0) { $0 + $1.needsInfoCount },
                          byCategory: [])
    }

    private func play(_ s: OrgSummary) async {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.25)) {
                shown = true; check = 1; open = 1; fill = 1; amount = s.remaining; details = true
            }
            return
        }
        try? await Task.sleep(for: .seconds(0.16))
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { shown = true }
        try? await Task.sleep(for: .seconds(0.2))
        withAnimation(.easeOut(duration: 0.34)) { check = 1 }
        try? await Task.sleep(for: .seconds(0.85))
        withAnimation(.spring(response: 0.75, dampingFraction: 1)) { open = 1 }
        try? await Task.sleep(for: .seconds(0.3))
        withAnimation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 1.4)) {
            fill = 1
            amount = s.remaining
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.9)) { details = true }
    }
}

private struct ReadyRing: View, Animatable {
    var check: Double
    var open: Double
    var fill: Double
    var amount: Double
    let summary: OrgSummary
    let flowing: Bool
    @Environment(\.copy) private var t
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<Double, Double>> {
        get { AnimatablePair(AnimatablePair(check, open), AnimatablePair(fill, amount)) }
        set {
            check = newValue.first.first
            open = newValue.first.second
            fill = newValue.second.first
            amount = newValue.second.second
        }
    }

    var body: some View {
        GeometryReader { g in
            let side = min(g.size.width, g.size.height)
            let ring = ds(14)
            let o = min(max(open, 0), 1)
            let width = side / 2 + (ring - side / 2) * o
            let total = max(summary.allocated, 0.01)
            let fA = max(0, summary.allocated - summary.approved - summary.pending) / total
            let fP = max(0, min(summary.pending, summary.allocated - summary.approved)) / total
            let gap = (ring + 4) / (.pi * (side - ring))
            let pFrom = fA + gap / 2
            let pTo = max(pFrom, fA + fP - gap / 2)
            ZStack {
                Circle().strokeBorder(Color.fsTrack, lineWidth: width).opacity(o)
                Circle().strokeBorder(Color.fsGreen, lineWidth: width).opacity(1 - o)

                ZStack {
                    if fP > gap {
                        Circle().trim(from: pFrom, to: pTo)
                            .stroke(Color.fsAmber.opacity(0.5), style: StrokeStyle(lineWidth: ring, lineCap: .round))
                        PendingStripes(from: pFrom, to: pTo, width: ring, flowing: flowing && !reduceMotion)
                    }
                    if fA > 0.002 {
                        Circle().trim(from: gap / 2, to: gap / 2 + max(0.001, fA - gap) * min(max(fill, 0), 1))
                            .stroke(Color.fsAccent, style: StrokeStyle(lineWidth: ring, lineCap: .round))
                    }
                }
                .padding(ring / 2)
                .rotationEffect(.degrees(-90))
                .opacity(o * o)

                CheckShape()
                    .trim(from: 0, to: check)
                    .stroke(.white, style: StrokeStyle(lineWidth: side * 0.085, lineCap: .round, lineJoin: .round))
                    .frame(width: side * 0.4, height: side * 0.3)
                    .offset(x: -side * 0.01, y: side * 0.01)
                    .scaleEffect(1 - 0.4 * o)
                    .opacity(1 - min(1, o * 2))

                VStack(spacing: 2) {
                    Text(t("Remaining")).font(.fsCaption).foregroundStyle(Color.fsText2)
                    Text(Fmt.usd(amount)).font(.fs(ds(30), .bold)).monospacedDigit()
                }
                .opacity(max(0, o * 2 - 1))
                .scaleEffect(0.92 + 0.08 * o)
            }
            .frame(width: side, height: side)
            .position(x: g.size.width / 2, y: g.size.height / 2)
        }
    }
}

private struct PendingStripes: View {
    let from: Double
    let to: Double
    let width: CGFloat
    let flowing: Bool

    var body: some View {
        TimelineView(.animation(paused: !flowing)) { ctx in
            let period = 1.6
            let phase = flowing ? -CGFloat(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period * 5.5) : 0
            Circle().trim(from: from, to: to)
                .stroke(Color.fsAmber, style: StrokeStyle(lineWidth: width, lineCap: .butt, dash: [2.5, 3], dashPhase: phase))
                .mask(Circle().trim(from: from, to: to).stroke(style: StrokeStyle(lineWidth: width, lineCap: .round)))
        }
    }
}

private struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.52))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

// MARK: - Wrong organization

struct WrongAccountSheet: View {
    enum Outcome { case none, differentEmail, reported }
    let user: User
    let linkedTo: String
    @Binding var outcome: Outcome
    let report: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.copy) private var t

    private var studentAccountsFixesIt: Bool { user.role == .officer || user.role == .advisor }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if outcome == .reported {
                sent.transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                options.transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, 12)
        .presentationDetents([.height(ds(300))])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.success, trigger: outcome == .reported)
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(t("Let’s fix that")).font(.fs(ds(26), .bold)).tracking(-0.4)
            Text(t.f("%@ is linked to %@.", user.email, linkedTo))
                .font(.fsBody)
                .foregroundStyle(Color.fsText2)
                .padding(.top, 6)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 10) {
                row(symbol: "paperplane.fill", title: t(studentAccountsFixesIt ? "Ask Student Accounts to fix it" : "Ask the FairShare admin to fix it")) {
                    report()
                    withAnimation(fsSpring) { outcome = .reported }
                }
                row(symbol: "envelope.fill", title: t("Use a different email")) {
                    outcome = .differentEmail
                    dismiss()
                }
            }
            .padding(.top, 22)
        }
    }

    private var sent: some View {
        VStack(spacing: 0) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: ds(50)))
                .foregroundStyle(Color.fsGreen)
                .symbolEffect(.bounce, value: outcome == .reported)
            Text(t(studentAccountsFixesIt ? "Sent to Student Accounts" : "Sent to the FairShare admin")).font(.fsTitle).padding(.top, 14)
            Text(t("You can sign in once they’ve fixed it."))
                .font(.fsBody)
                .foregroundStyle(Color.fsText2)
                .padding(.top, 4)
            Spacer(minLength: 16)
            Button(t("Done")) { dismiss() }.buttonStyle(FSButtonStyle())
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private func row(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: ds(17), weight: .semibold))
                    .foregroundStyle(Color.fsAccent)
                    .frame(width: ds(40), height: ds(40))
                    .background(Color.fsAccentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(title).font(.fsHead).foregroundStyle(Color.fsText)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.fsText3)
            }
            .padding(14)
            .background(Color.fsSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.fsHairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Shared pieces

struct ChoiceTile: View {
    let symbol: String
    let title: String
    var subtitle: String? = nil
    let selected: Bool
    var boxed = true
    let action: () -> Void
    @State private var pops = 0

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: ds(21)))
                    .foregroundStyle(boxed ? (selected ? Color.white : Color.fsText) : (selected ? Color.fsAccent : Color.fsText))
                    .symbolEffect(.bounce, value: pops)
                    .frame(width: boxed ? ds(48) : ds(30), height: ds(48))
                    .background(boxed ? (selected ? Color.fsAccent : Color.fsSurface2) : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.fsHead).foregroundStyle(Color.fsText)
                    if let subtitle {
                        Text(subtitle).font(.fsCaption).foregroundStyle(Color.fsText2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(selected ? Color.fsAccentSoft : Color.fsSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(selected ? Color.fsAccent : Color.fsHairline, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .onChange(of: selected) { _, now in if now { pops += 1 } }
    }
}

private struct Shake: GeometryEffect {
    var travel: CGFloat
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let damp = 1 - (animatableData - animatableData.rounded(.down))
        return ProjectionTransform(CGAffineTransform(translationX: travel * damp * sin(animatableData * .pi * 6), y: 0))
    }
}
