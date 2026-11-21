import Foundation

enum LocalAssistant {
    static let suggestions = [
        "How much money do we have left?",
        "Can we afford a $150 event next week?",
        "How much did we spend on food this semester?",
        "How do I print posters at Luther?",
        "Where should I buy drinks for our next event?",
        "What documentation do I need to submit?",
    ]

    private static let categoryWords: [CategoryId: [String]] = [
        .food: ["food", "pizza", "snack", "snacks", "drink", "drinks", "refreshment", "refreshments", "catering", "cookies", "meal"],
        .prizes: ["prize", "prizes", "giveaway", "giveaways", "gift", "raffle", "swag", "shirts"],
        .printing: ["print", "printing", "poster", "posters", "flyer", "flyers", "promo", "promotion", "banner"],
        .supplies: ["supplies", "supply", "decoration", "decorations", "plates", "cups"],
        .transport: ["transport", "transportation", "travel", "van", "bus", "gas", "trip"],
        .equipment: ["equipment", "materials", "gear", "kits", "tools"],
    ]

    private static func has(_ q: String, _ words: [String]) -> Bool {
        words.contains { w in q.range(of: "\\b\(NSRegularExpression.escapedPattern(for: w))\\b", options: [.regularExpression, .caseInsensitive]) != nil }
    }

    private static func amount(in q: String) -> Double? {
        let s = q.replacingOccurrences(of: ",", with: "")
        if let r = s.range(of: "\\$\\s?(\\d+(\\.\\d{1,2})?)", options: .regularExpression) {
            return Double(s[r].replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces))
        }
        if let r = s.range(of: "(\\d+(\\.\\d{1,2})?)\\s?(dollars|usd|bucks)", options: [.regularExpression, .caseInsensitive]) {
            return Double(s[r].components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined())
        }
        return nil
    }

    private static func category(in q: String) -> CategoryId? {
        CategoryId.allCases.first { c in has(q, categoryWords[c] ?? []) }
    }

    static func answer(state: AppState, orgId: String, question: String) -> AssistantReply {
        let q = question.lowercased()
        guard let org = state.org(orgId) else { return AssistantReply(text: "I couldn’t find your organization.", sources: [], engine: "local") }
        let s = state.summary(orgId)
        let exps = state.expenses.filter { $0.orgId == orgId }
        func reply(_ t: String, _ src: [String], draft: AssistantReply.Draft? = nil, next: [String]? = nil) -> AssistantReply {
            AssistantReply(text: t, sources: src, draft: draft, suggestions: next, engine: "local")
        }

        if has(q, ["c-board", "cboard", "c board"]) {
            return reply("""
            I can’t show your C-board number in chat — it’s protected. 🔒

            **Here’s how to see it**
            1. Open the **Club** tab
            2. Tap **Reveal** on the C-board card
            3. Confirm it’s you with Face ID

            Give that number at campus spots like **Luther Book Shop** so the purchase is charged to \(org.name).
            """, ["Purchasing Guide"])
        }

        if has(q, ["print", "printing", "poster", "posters", "flyer", "flyers", "banner"]) {
            let body = "Hello Document Center team,\n\n\(org.name) would like to request printing for an upcoming event.\n\n• File: attached (print-ready PDF)\n• Size: 11 × 17 in poster\n• Paper: glossy, color\n• Quantity: 25\n• Needed by: [date]\n• C-board number: [your C-board number]\n\nPlease let us know if you need anything else from us. Thank you!\n\nBest,\n[Your name]\n\(org.name)"
            return reply("""
            Posters are printed by the **Luther Document Center**. 🖨️

            **Email them**
            - Your print-ready file
            - Size, paper and quantity
            - The date you need it by
            - Your C-board number, so it’s charged to \(org.name)

            **Send it to:** documentcenter@luther.edu

            When the invoice arrives, upload it here as the receipt. I drafted the email for you 👇
            """,
                         ["Document Center", "Purchasing Guide"],
                         draft: .init(to: "documentcenter@luther.edu", subject: "Print request — \(org.name)", body: body),
                         next: ["What documentation do I need to submit?"])
        }

        if let amt = amount(in: q), has(q, ["afford", "enough", "spend", "budget", "cover", "pay"]) {
            let after = (s.available - amt).rounded2
            if after >= 0 {
                let share = s.allocated > 0 ? Int((amt / s.allocated * 100).rounded()) : 0
                return reply("""
                **Yes — you can afford it.** ✅

                **The math**
                - Safe to spend now: **\(Fmt.usd(s.available))**
                - This event: −\(Fmt.usd(amt))
                - Left after: **\(Fmt.usd(after))**

                That’s about \(share)% of your \(Fmt.usd(s.allocated, cents: false)) budget\(s.pending > 0 ? ", and the \(Fmt.usd(s.pending)) pending review is already set aside" : "").

                💡 **Tip:** keep itemized receipts and upload them within two weeks.
                """, ["Your budget", "Receipt deadline"], next: ["How can we organize an event while staying within budget?", "Where should I buy drinks for our next event?"])
            }
            return reply("""
            **Not right now.** ⚠️

            A \(Fmt.usd(amt)) event is **\(Fmt.usd(abs(after))) more** than you can safely spend (\(Fmt.usd(s.available))).

            **A few options**
            - Trim the plan to fit \(Fmt.usd(s.available))
            - Split the cost with another organization
            - Ask Student Accounts about supplemental funding
            """, ["Your budget"], next: ["How can we organize an event while staying within budget?"])
        }

        if has(q, ["left", "remaining", "balance", "how much money", "available", "have"]) && category(in: q) == nil {
            var lines = ["- ✅ Approved so far: \(Fmt.usd(s.approved))"]
            if s.pending > 0 { lines.append("- ⏳ Pending review: \(Fmt.usd(s.pending))") }
            lines.append("- 💵 Safe to spend: **\(Fmt.usd(s.available))**")
            let bottom = s.pending > 0
                ? "**Bottom line:** plan with \(Fmt.usd(s.available)) — pending money isn’t yours to spend yet."
                : "**Bottom line:** all \(Fmt.usd(s.remaining)) is yours to plan with."
            return reply("""
            \(org.name) has **\(Fmt.usd(s.remaining))** left of its \(Fmt.usd(s.allocated, cents: false)) \(org.term) budget.

            **Breakdown**
            \(lines.joined(separator: "\n"))

            \(bottom)
            """, ["Your budget"], next: ["Can we afford a $150 event next week?", "What is our biggest expense category?"])
        }

        if let c = category(in: q), has(q, ["spend", "spent", "spending", "cost", "much", "total"]) {
            let row = s.byCategory.first { $0.id == c }!
            let list = exps.filter { $0.category == c && $0.status != .rejected }.prefix(4)
            let items = list.map { "- \($0.vendor) — \(Fmt.usd($0.amount)) · \($0.status == .approved ? "approved" : "pending")" }.joined(separator: "\n")
            return reply("""
            This semester \(org.name) spent **\(Fmt.usd(row.approved))** on \(c.label.lowercased())\(row.pending > 0 ? ", plus \(Fmt.usd(row.pending)) waiting for review" : "").
            \(items.isEmpty ? "" : "\n**Purchases**\n\(items)")
            """, ["Your transactions"], next: ["What is our biggest expense category?"])
        }

        if has(q, ["biggest", "largest", "most", "top"]) {
            let sorted = s.byCategory.filter { $0.approved + $0.pending > 0 }.sorted { $0.approved + $0.pending > $1.approved + $1.pending }
            guard let top = sorted.first else { return reply("\(org.name) hasn’t recorded any spending yet this term.", ["Your transactions"]) }
            let ranking = sorted.prefix(4).enumerated().map { "\($0.offset + 1). \($0.element.id.label) — \(Fmt.usd($0.element.approved + $0.element.pending))" }.joined(separator: "\n")
            return reply("""
            Your biggest category is **\(top.id.label)** — \([top.approved > 0 ? "\(Fmt.usd(top.approved)) approved" : nil, top.pending > 0 ? "\(Fmt.usd(top.pending)) pending" : nil].compactMap { $0 }.joined(separator: " and ")). 📊

            **Top categories**
            \(ranking)
            """, ["Your transactions"], next: ["How much money do we have left?"])
        }

        if has(q, ["pending", "waiting", "review", "status"]) {
            let waiting = exps.filter { $0.status == .pending || $0.status == .needsInfo }
            if waiting.isEmpty { return reply("Nothing is waiting for review — every expense has been processed. ✅", ["Your transactions"]) }
            let list = waiting.map { "- \($0.vendor) — \(Fmt.usd($0.amount)) · \($0.status == .needsInfo ? "needs a document from you" : "pending review")" }.joined(separator: "\n")
            return reply("""
            **\(waiting.count) expense\(waiting.count > 1 ? "s are" : " is") waiting** — \(Fmt.usd(s.pending)) in total. ⏳

            \(list)
            """, ["Your transactions"])
        }

        if has(q, ["buy", "where", "cheap", "cheaper", "cheapest", "store", "price", "prices", "compare"]) {
            return reply("""
            I don’t have live store prices, so I won’t guess them. Here’s where to compare: 🛒

            - **Walmart** in Decorah
            - **Fareway** — local grocery store
            - **Oneota Community Food Co-op** — local grocery store
            - **Luther Dining Services** — on-campus delivery

            💡 **Tip:** compare the price per can or per ounce, and buy in bulk.

            You can safely spend **\(Fmt.usd(s.available))** right now.
            """, ["FairShare guidance", "Your budget"], next: ["Can we afford a $150 event next week?"])
        }

        if has(q, ["document", "documentation", "receipt", "receipts", "proof", "invoice", "submit"]) {
            return reply("""
            Here’s what Student Accounts needs. 🧾

            **Paid with a card or cash**
            - An **itemized** receipt: vendor, date, items and total
            - A card slip with only the total isn’t enough

            **Paid by check**
            - The check or payment document
            - The check number

            **Every time**
            - One line about what it was for
            - Submit within **two weeks** of the purchase
            """, ["Purchasing Guide", "Receipt deadline"])
        }

        if has(q, ["funding", "annual", "request", "form", "next year"]) {
            let status = org.funding.status == "not_started" ? "hasn’t been submitted yet" : org.funding.status == "submitted" ? "was submitted — Student Accounts is reviewing it" : "has been approved"
            var lines: [String] = []
            if let due = state.fundingAnnouncement?.dueDate {
                lines = ["- **Due:** \(Fmt.longDate(due))", "- **Time left:** \(Fmt.daysUntil(due)) days"]
            }
            return reply("""
            \(org.name)’s 2027–28 funding request **\(status)**. 📅
            \(lines.isEmpty ? "" : "\n" + lines.joined(separator: "\n"))
            \(org.funding.status == "not_started" ? "\nOpen the funding banner on **Home** to fill out the form." : "")
            """, ["Student Accounts announcement"])
        }

        if has(q, ["plan", "organize", "event", "within"]) {
            let b = s.available
            func part(_ p: Double) -> String { Fmt.usd((b * p).rounded(.down), cents: false) }
            return reply("""
            With **\(Fmt.usd(b))** safe to spend, here’s a simple split that keeps you on budget: 🎯

            - 🍕 Food & drinks — about \(part(0.5))
            - 🎁 Prizes or giveaways — about \(part(0.2))
            - 🖨️ Printing & promotion — about \(part(0.1))
            - 🛟 Buffer for surprises — about \(part(0.2))

            **Bottom line:** keep the buffer — it covers the things you forget.
            """, ["Your budget"], next: ["Where should I buy drinks for our next event?", "How do I print posters at Luther?"])
        }

        return reply("""
        I don’t know that one, and I’d rather not guess. 🤔

        **I can help with**
        - Your budget and spending
        - Receipts and documentation
        - Printing at Luther
        - Funding requests

        For anything else, Student Accounts is the best place to ask.
        """, [], next: ["How much money do we have left?"])
    }
}
