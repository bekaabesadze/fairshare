import SwiftUI

struct AssistantView: View {
    @Environment(AppStore.self) private var store
    @Environment(ShellState.self) private var shell
    @State private var turns: [ChatTurn] = []
    @State private var input = ""
    @State private var generation: Task<Void, Never>?
    @State private var follow = true
    @State private var userScrolling = false
    @FocusState private var focused: Bool
    private let inbox = AssistantInbox.shared

    private var busy: Bool { generation != nil }

    var body: some View {
        NavigationStack {
            if let org = store.officerOrg {
                VStack(spacing: 0) {
                    header
                    ZStack {
                        if turns.isEmpty {
                            emptyState.transition(.opacity)
                        } else {
                            conversation(orgId: org.id).transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar(orgId: org.id) }
                .background(Color.fsBackground)
                .toolbar(.hidden, for: .navigationBar)
                .onAppear { consumeInbox(orgId: org.id) }
                .onChange(of: inbox.pending) { _, _ in consumeInbox(orgId: org.id) }
            }
        }
    }

    // MARK: Top bar

    private var header: some View {
        HStack(spacing: 0) {
            Button {
                focused = false
                shell.selected = shell.previous
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: ds(18), weight: .semibold))
                    .foregroundStyle(Color.fsText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Back")
            Spacer()
            Text("Ask FairShare").font(.fs(ds(17), .semibold)).foregroundStyle(Color.fsText)
            Spacer()
            Button(action: newChat) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: ds(18), weight: .medium))
                    .foregroundStyle(turns.isEmpty ? Color.fsText3 : Color.fsText)
                    .frame(width: 44, height: 44)
            }
            .disabled(turns.isEmpty)
            .accessibilityLabel("New chat")
        }
        .padding(.horizontal, ds(8))
        .padding(.bottom, 2)
        .background(Color.fsBackground)
    }

    // MARK: Empty state

    private var emptyState: some View {
        Text("What can I help with?")
            .font(.fs(ds(24), .semibold))
            .tracking(-0.4)
            .foregroundStyle(Color.fsText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { focused = false }
    }

    private static let starters: [(lead: String, rest: String)] = [
        ("How much money", "do we have left?"),
        ("Can we afford", "a $150 event next week?"),
        ("How do I print", "posters at Luther?"),
        ("How much did we spend", "on food this semester?"),
        ("Where should I buy", "drinks for our next event?"),
        ("What documentation", "do I need to submit?"),
    ]

    private func starterCards(orgId: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Self.starters, id: \.lead) { s in
                    Button { send("\(s.lead) \(s.rest)", orgId: orgId) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.lead).font(.fs(ds(15), .semibold)).foregroundStyle(Color.fsText)
                            Text(s.rest).font(.fs(ds(14.5))).foregroundStyle(Color.fsText2)
                        }
                        .lineLimit(1)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 12)
                        .background(Color.fsSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.fsHairline, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, ds(14))
        }
        .scrollClipDisabled()
    }

    // MARK: Conversation

    private func conversation(orgId: String) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: ds(24)) {
                    ForEach(turns) { t in
                        if t.role == .user {
                            UserBubble(text: t.text)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            AssistantMessage(
                                turn: t,
                                isLast: t.id == turns.last?.id,
                                onFeedback: { v in setFeedback(t.id, v) },
                                onRegenerate: { regenerate(t.id, orgId: orgId) },
                                onFollowUp: { q in send(q, orgId: orgId) }
                            )
                        }
                    }
                    Color.clear.frame(height: 1).id("end")
                }
                .padding(.horizontal, ds(18))
                .padding(.top, 10)
                .padding(.bottom, 18)
            }
            .scrollDismissesKeyboard(.interactively)
            .onScrollPhaseChange { _, phase in
                userScrolling = phase == .interacting || phase == .tracking || phase == .decelerating
            }
            .onScrollGeometryChange(for: Bool.self) { g in
                g.contentOffset.y >= g.contentSize.height - g.containerSize.height + g.contentInsets.bottom - 80
            } action: { _, atBottom in
                if userScrolling { follow = atBottom }
            }
            .onChange(of: turns.count) { _, _ in
                follow = true
                withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("end", anchor: .bottom) }
            }
            .onChange(of: turns.last?.shown.count) { _, _ in
                if follow && !userScrolling { proxy.scrollTo("end", anchor: .bottom) }
            }
            .onChange(of: turns.last?.phase) { _, _ in
                guard follow && !userScrolling else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(60))
                    withAnimation(.easeOut(duration: 0.35)) { proxy.scrollTo("end", anchor: .bottom) }
                }
            }
        }
    }

    // MARK: Composer

    private func bottomBar(orgId: String) -> some View {
        VStack(spacing: 12) {
            if turns.isEmpty && !focused {
                starterCards(orgId: orgId).transition(.move(edge: .bottom).combined(with: .opacity))
            }
            composer(orgId: orgId).padding(.horizontal, ds(14))
        }
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(Color.fsBackground)
        .animation(fsSpring, value: focused)
        .animation(fsSpring, value: turns.isEmpty)
    }

    private func composer(orgId: String) -> some View {
        let empty = input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(alignment: .bottom, spacing: 4) {
            Menu {
                Button { shell.addStart = .receipt; shell.selected = 2 } label: { Label("Scan a receipt", systemImage: "doc.text.viewfinder") }
                Button { shell.addStart = .check; shell.selected = 2 } label: { Label("Add a check", systemImage: "building.columns") }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: ds(19), weight: .regular))
                    .foregroundStyle(Color.fsText)
                    .frame(width: 40, height: 40)
            }
            .padding(.bottom, 3)
            .accessibilityLabel("Add a receipt or check")

            TextField("Ask anything", text: $input, axis: .vertical)
                .lineLimit(1...6)
                .focused($focused)
                .font(.fs(ds(16.5)))
                .padding(.vertical, 12)
                .onSubmit { send(input, orgId: orgId) }

            Button {
                if busy { stop() } else { send(input, orgId: orgId) }
            } label: {
                Image(systemName: busy ? "stop.fill" : "arrow.up")
                    .font(.system(size: busy ? 13 : 16, weight: .bold))
                    .foregroundStyle(Color.fsBackground)
                    .frame(width: 36, height: 36)
                    .background(Color.fsText, in: Circle())
                    .opacity(!busy && empty ? 0.25 : 1)
                    .contentTransition(.symbolEffect(.replace))
            }
            .disabled(!busy && empty)
            .padding(.bottom, 5)
            .accessibilityLabel(busy ? "Stop" : "Send")
        }
        .padding(.leading, 4)
        .padding(.trailing, 6)
        .background(Color.fsSurface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.fsHairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
    }

    // MARK: Generation

    private func consumeInbox(orgId: String) {
        if let q = inbox.pending {
            inbox.pending = nil
            send(q, orgId: orgId)
        }
    }

    private func history(before index: Int) -> [ChatMessage] {
        turns.prefix(index).compactMap { t in
            switch t.role {
            case .user: ChatMessage(role: "user", text: t.text)
            case .assistant: t.shown.isEmpty ? nil : ChatMessage(role: "assistant", text: t.shown)
            }
        }
    }

    private func send(_ text: String, orgId: String) {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !busy else { return }
        input = ""
        withAnimation(fsSpring) { turns.append(ChatTurn(role: .user, text: q)) }
        generate(messages: history(before: turns.count), orgId: orgId, replacing: nil)
    }

    private func regenerate(_ id: UUID, orgId: String) {
        guard !busy, let i = turns.firstIndex(where: { $0.id == id }) else { return }
        generate(messages: history(before: i), orgId: orgId, replacing: id)
    }

    private func generate(messages: [ChatMessage], orgId: String, replacing: UUID?) {
        let turn = ChatTurn(role: .assistant, text: "", phase: .thinking, steps: ["Thinking"])
        let id = turn.id
        if let replacing, let i = turns.firstIndex(where: { $0.id == replacing }) {
            turns[i] = turn
        } else {
            withAnimation(fsSpring) { turns.append(turn) }
        }
        generation = Task {
            let started = Date()
            let reply = await store.ask(orgId: orgId, messages: messages)
            if Task.isCancelled { return }

            let steps = Self.steps(for: reply)
            update(id) { $0.reply = reply; $0.text = reply.text }
            for i in steps.indices {
                withAnimation(.easeInOut(duration: 0.3)) { update(id) { $0.steps = Array(steps.prefix(i + 1)); $0.step = i } }
                try? await Task.sleep(for: .milliseconds(620))
                if Task.isCancelled { return }
            }
            let seconds = max(1, Int(Date().timeIntervalSince(started).rounded()))
            withAnimation(.easeInOut(duration: 0.2)) { update(id) { $0.thought = seconds; $0.phase = .streaming } }

            let tokens = reply.text.matches(of: #/\s*\S+/#).map { String($0.output) }
            var i = 0
            while i < tokens.count {
                if Task.isCancelled { return }
                let n = Int.random(in: 1...3)
                let chunk = tokens[i..<min(tokens.count, i + n)].joined()
                i += n
                update(id) { $0.shown += chunk }
                try? await Task.sleep(for: .milliseconds(Int.random(in: 24...52)))
            }
            if Task.isCancelled { return }
            withAnimation(fsSpring) { update(id) { $0.phase = .done } }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            generation = nil
        }
    }

    private func stop() {
        generation?.cancel()
        generation = nil
        guard let i = turns.lastIndex(where: { $0.role == .assistant }), turns[i].phase != .done else { return }
        withAnimation(fsSpring) {
            if turns[i].shown.isEmpty {
                turns.remove(at: i)
            } else {
                turns[i].phase = .done
                turns[i].stopped = true
            }
        }
    }

    private func newChat() {
        generation?.cancel()
        generation = nil
        focused = false
        input = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.25)) { turns = [] }
    }

    private func update(_ id: UUID, _ change: (inout ChatTurn) -> Void) {
        guard let i = turns.firstIndex(where: { $0.id == id }) else { return }
        change(&turns[i])
    }

    private func setFeedback(_ id: UUID, _ value: Int) {
        update(id) { $0.feedback = $0.feedback == value ? 0 : value }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func steps(for reply: AssistantReply) -> [String] {
        var steps = reply.sources.map { s -> String in
            switch s {
            case "Your budget": "Reading your budget"
            case "Your transactions": "Going through your transactions"
            case "Purchasing Guide": "Checking Luther’s Purchasing Guide"
            case "Document Center": "Looking up the Document Center"
            case "Receipt deadline": "Checking the receipt rules"
            case "Student Accounts announcement": "Reading Student Accounts announcements"
            case "FairShare guidance": "Comparing places to shop"
            default: "Checking \(s)"
            }
        }
        if steps.isEmpty { steps = ["Thinking it through"] }
        steps.append("Writing the answer")
        return Array(steps.prefix(4))
    }
}

// MARK: - Model

struct ChatTurn: Identifiable {
    enum Role { case user, assistant }
    enum Phase { case thinking, streaming, done }
    let id = UUID()
    var role: Role
    var text: String
    var shown = ""
    var phase: Phase = .done
    var reply: AssistantReply?
    var steps: [String] = []
    var step = 0
    var thought = 0
    var feedback = 0
    var stopped = false
}

// MARK: - Messages

private struct UserBubble: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.fs(ds(16.5)))
            .foregroundStyle(Color.fsText)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Color.fsSurface3, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, ds(56))
            .textSelection(.enabled)
    }
}

private struct AssistantMessage: View {
    let turn: ChatTurn
    let isLast: Bool
    let onFeedback: (Int) -> Void
    let onRegenerate: () -> Void
    let onFollowUp: (String) -> Void
    @State private var copied = false
    @State private var showSteps = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if turn.phase == .thinking {
                ThinkingRow(text: turn.steps.indices.contains(turn.step) ? turn.steps[turn.step] : "Thinking")
            } else {
                thoughtSummary
                MarkdownText(source: turn.shown, streaming: turn.phase == .streaming)
                if turn.stopped {
                    Text("Stopped").font(.fs(ds(13), .medium)).foregroundStyle(Color.fsText3)
                }
                if turn.phase == .done {
                    if let d = turn.reply?.draft, !turn.stopped { DraftCard(draft: d).transition(.opacity.combined(with: .move(edge: .bottom))) }
                    if let src = turn.reply?.sources, !src.isEmpty, !turn.stopped { sources(src) }
                    actions
                    if isLast, !turn.stopped, let next = turn.reply?.suggestions, !next.isEmpty { followUps(next) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var thoughtSummary: some View {
        if turn.thought > 0 {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(fsSpring) { showSteps.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text("Thought for \(turn.thought)s")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .rotationEffect(.degrees(showSteps ? 90 : 0))
                    }
                    .font(.fs(ds(14), .medium))
                    .foregroundStyle(Color.fsText3)
                }
                .buttonStyle(.plain)
                if showSteps {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(turn.steps, id: \.self) { s in
                            Label(s, systemImage: "checkmark.circle")
                                .font(.fs(ds(14)))
                                .foregroundStyle(Color.fsText2)
                        }
                    }
                    .padding(.leading, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func sources(_ list: [String]) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(list, id: \.self) { s in
                Label(s, systemImage: "book.closed")
                    .font(.fs(12, .semibold))
                    .foregroundStyle(Color.fsText2)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Color.fsSurface2, in: Capsule())
                    .fixedSize()
            }
        }
        .transition(.opacity)
    }

    private var actions: some View {
        HStack(spacing: 0) {
            icon(copied ? "checkmark" : "doc.on.doc", label: "Copy") {
                UIPasteboard.general.string = turn.shown
                withAnimation { copied = true }
                Task { try? await Task.sleep(for: .seconds(1.6)); withAnimation { copied = false } }
            }
            icon(turn.feedback == 1 ? "hand.thumbsup.fill" : "hand.thumbsup", label: "Good answer") { onFeedback(1) }
            icon(turn.feedback == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown", label: "Bad answer") { onFeedback(-1) }
            if isLast { icon("arrow.clockwise", label: "Regenerate", action: onRegenerate) }
        }
        .padding(.leading, -10)
        .transition(.opacity)
    }

    private func icon(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: ds(15), weight: .medium))
                .foregroundStyle(Color.fsText2)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 38, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func followUps(_ list: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(list.enumerated()), id: \.offset) { i, q in
                if i > 0 { Divider() }
                Button { onFollowUp(q) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.turn.down.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.fsText3)
                        Text(q).font(.fs(ds(15), .medium)).foregroundStyle(Color.fsText).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
            }
        }
        .transition(.opacity)
    }
}

private struct ThinkingRow: View {
    let text: String
    @State private var pulse = false
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.fsText)
                .frame(width: 11, height: 11)
                .scaleEffect(pulse ? 1 : 0.62)
                .animation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }
            Text(text)
                .font(.fs(ds(15), .medium))
                .foregroundStyle(Color.fsText2)
                .id(text)
                .transition(.blurReplace)
        }
        .frame(height: 28)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("FairShare is working: \(text)")
    }
}

// MARK: - Markdown answers

struct MarkdownText: View {
    let source: String
    var streaming = false

    enum Block {
        case heading(String)
        case paragraph(String)
        case bullets([String])
        case numbered([(Int, String)])
    }

    var body: some View {
        let blocks = Self.blocks(source)
        VStack(alignment: .leading, spacing: ds(12)) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { i, b in
                let last = streaming && i == blocks.count - 1
                switch b {
                case .heading(let t):
                    Text(rich: t + (last ? " ●" : "")).font(.fs(ds(17), .semibold)).padding(.top, i == 0 ? 0 : 4)
                case .paragraph(let t):
                    Text(rich: t + (last ? " ●" : "")).font(.fs(ds(16.5))).lineSpacing(4)
                case .bullets(let items):
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(items.enumerated()), id: \.offset) { j, item in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("•").font(.fs(ds(16.5), .bold))
                                Text(rich: item + (last && j == items.count - 1 ? " ●" : "")).font(.fs(ds(16.5))).lineSpacing(3)
                            }
                        }
                    }
                    .padding(.leading, 4)
                case .numbered(let items):
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(items.enumerated()), id: \.offset) { j, item in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(item.0).").font(.fs(ds(16.5), .semibold)).monospacedDigit()
                                Text(rich: item.1 + (last && j == items.count - 1 ? " ●" : "")).font(.fs(ds(16.5))).lineSpacing(3)
                            }
                        }
                    }
                    .padding(.leading, 2)
                }
            }
        }
        .foregroundStyle(Color.fsText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    static func blocks(_ text: String) -> [Block] {
        var out: [Block] = []
        var para: [String] = []
        var bullets: [String] = []
        var numbers: [(Int, String)] = []
        func flushPara() { if !para.isEmpty { out.append(.paragraph(para.joined(separator: "\n"))); para = [] } }
        func flushLists() {
            if !bullets.isEmpty { out.append(.bullets(bullets)); bullets = [] }
            if !numbers.isEmpty { out.append(.numbered(numbers)); numbers = [] }
        }
        for raw in text.components(separatedBy: "\n") {
            let line = balanced(raw.trimmingCharacters(in: .whitespaces))
            if line.isEmpty { flushPara(); flushLists(); continue }
            if line.hasPrefix("#") {
                flushPara(); flushLists()
                out.append(.heading(String(line.drop { $0 == "#" }).trimmingCharacters(in: .whitespaces)))
            } else if line.range(of: #"^\*\*[^*]+\*\*:?$"#, options: .regularExpression) != nil {
                flushPara(); flushLists()
                out.append(.heading(line.replacingOccurrences(of: "**", with: "")))
            } else if line.hasPrefix("- ") || line.hasPrefix("• ") || line.hasPrefix("* ") {
                flushPara()
                if !numbers.isEmpty { out.append(.numbered(numbers)); numbers = [] }
                bullets.append(String(line.dropFirst(2)))
            } else if let m = line.firstMatch(of: #/^(\d+)[.)]\s+(.*)$/#) {
                flushPara()
                if !bullets.isEmpty { out.append(.bullets(bullets)); bullets = [] }
                numbers.append((Int(m.1) ?? numbers.count + 1, String(m.2)))
            } else {
                flushLists()
                para.append(line)
            }
        }
        flushPara(); flushLists()
        return out
    }

    private static func balanced(_ line: String) -> String {
        let parts = line.components(separatedBy: "**")
        guard parts.count % 2 == 0, let r = line.range(of: "**", options: .backwards) else { return line }
        return line.replacingCharacters(in: r, with: "")
    }
}

// MARK: - Draft email card

private struct DraftCard: View {
    let draft: AssistantReply.Draft
    @Environment(\.openURL) private var openURL
    @State private var copied = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Draft email", systemImage: "envelope").font(.fs(12, .semibold)).foregroundStyle(Color.fsText2)
            Text("To \(draft.to)").font(.fsCaption).foregroundStyle(Color.fsText2)
            Text(draft.subject).font(.fs(14, .semibold))
            Text(draft.body).font(.fsCaption).padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.fsSurface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .lineLimit(8)
            HStack(spacing: 8) {
                Button {
                    var c = URLComponents()
                    c.scheme = "mailto"
                    c.path = draft.to
                    c.queryItems = [URLQueryItem(name: "subject", value: draft.subject), URLQueryItem(name: "body", value: draft.body)]
                    if let url = c.url { openURL(url) }
                } label: { Label("Open in Mail", systemImage: "envelope.fill") }
                    .buttonStyle(FSButtonStyle(kind: .primary, height: 40))
                Button {
                    UIPasteboard.general.string = "To: \(draft.to)\nSubject: \(draft.subject)\n\n\(draft.body)"
                    copied = true
                } label: { Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc") }
                    .buttonStyle(FSButtonStyle(kind: .secondary, height: 40))
            }
        }
        .card(padding: 14)
    }
}
