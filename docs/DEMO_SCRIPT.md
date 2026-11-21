# FairShare — Presentation & Demo Script

About 6–7 minutes. Each section notes which judging criterion it answers.

---

## Before you go on stage (2 minutes)

1. In a terminal: `npm run dev`
2. Laptop browser, **window 1**: http://localhost:5173 → *Open the demo* → **Organization officer** (Alex Rivera · Up to Us)
3. Laptop browser, **window 2** (a new window, side by side): http://localhost:5173/#/login → **Student Accounts** (Jordan Lee)
4. iPhone simulator (or a real iPhone): open FairShare. If it shows the welcome screen, go through onboarding as the officer. Home should show **Live** and **$600.00 remaining**.
5. If anything was clicked during rehearsal: Settings → **Reset demo data** (it resets every device at once).

Starting numbers for **Up to Us**: $600 allocated · $0 approved · $120 pending (pizza $85 + posters $35) · **$480 safe to spend**.

---

## 1. The problem — 45 seconds  *(Realism)*

> "Every official organization at Luther gets a budget. But if I want to know how much money Up to Us has left, I have to email Student Accounts and wait. We track purchases in our own spreadsheets, drop off receipts on paper, and our advisor has no dashboard at all. Student Accounts answers the same questions from dozens of clubs, by hand."

Optional: show the landing page's **The problem** section.

## 2. The officer's home — 45 seconds  *(Prototype, Presentation)*

On the iPhone (or window 1):

> "This is FairShare. The first thing an officer sees is what's left: **$600 remaining**."

Point at the ring:

> "Blue is money we can actually use. The striped amber part is **$120 still waiting for approval**. We deliberately never count pending money as available, so a treasurer plans with **$480**, not $600. That's the most common mistake clubs make, and the app makes it impossible."

Point out the **funding request deadline** card (21 days left) and the **Your turn** card (Student Accounts asked for an itemized invoice).

## 3. Scan a receipt — 1 minute  *(Feasibility, Tech stack)*

On the iPhone: tap **Receipt** on Home (or **＋** → **A receipt**) → *Try a sample* (on a real phone, tap **Take a photo** and scan a real receipt).

> "We bought $52 of prizes at Luther Book Shop. I snap the receipt…"

While it scans:

> "…and OCR reads it **on the phone itself** with Apple's Vision framework. Nothing leaves the device during the scan."

On the review screen:

> "It found the store, the date, the three items, the tax and the $52 total, and guessed the category, Prizes. Every field it filled is tagged *Scanned* so I know what to double-check. Receipts and checks are separate flows, because Student Accounts handles them differently. If I upload a check as a receipt, it notices."

Type *Prizes for the Up to Us Day of Action* → **Submit for review**.

> "It's now pending, so the ring already sets it aside: safe to spend drops to $428, but our official balance is still $600."

## 4. Student Accounts approves — 1 minute  *(the "wow" moment)*

Switch to laptop **window 2** (Student Accounts). The new expense is already at the top of **Review queue**, with a toast.

> "Student Accounts sees it instantly, with the original receipt right next to the numbers and the budget impact: $600 now, $548 after approval."

Press **A**, or click **Approve $52.00**. Then **look at the phone**:

> "And on the officer's phone, without refreshing anything: '$52.00 approved', and the balance rolls from **$600 to $548**."

*(This is the moment — pause and let it land.)*

## 5. Ask FairShare — 45 seconds  *(Differentiation)*

On the phone: **✦ Ask** → *Can we afford a $150 event next week?*

> "It answers from our real books: yes, we can safely spend $428 after pending items."

Then: *How do I print posters at Luther?*

> "It knows the Document Center process, gives us documentcenter@luther.edu, and drafts the email for us. And it never invents prices or rules. Ask it something it doesn't know and it says so."

## 6. Advisor report — 30 seconds  *(Prototype)*

Window 2 → **Reports** → Up to Us → **PDF**. (Or sign in as the faculty advisor: *My organizations* → PDF.)

> "Advisors get read-only access and a report that writes itself: original budget, approved, remaining, pending, a breakdown by category, and every transaction. PDF for sharing, Excel for analysis."

## 7. Market, model, competition, timeline — 1 minute  *(Market, Competition, Timeline)*

Use the landing page sections (scroll down at http://localhost:5173):

- **Market:** Luther is the pilot; every college with student organizations has this problem, especially small liberal arts colleges with no custom finance tools.
- **Model:** free for students; the college pays an annual subscription priced by the number of organizations (proposed: $2,400 for up to 50 orgs, $5,900 for up to 200).
- **Competition:** email + spreadsheets (no live balance); corporate expense apps like Ramp or Expensify (built for company cards, not campus allocations); campus engagement suites (finance is a side module). FairShare is the only one built around a club's budget, with campus approval and an AI that knows the books.
- **Timeline:** working prototype now → Luther pilot with 10–15 organizations in Spring 2027 → all of Luther in Fall 2027 → more colleges and finance-system integrations in 2028.

## 8. Close — 15 seconds

> "FairShare turns 'email Student Accounts and wait' into a number on your phone that's always right. It's built, it works on the web and on iPhone, and it's ready for a pilot."

---

## Likely judge questions

**"Is the OCR real?"** Yes. Tesseract (WebAssembly) in the browser and Apple Vision on iPhone. Try a real receipt with the phone camera.

**"Where's the data stored?"** One sync server holds the state as JSON plus receipt files; both apps push changes and receive updates live over Server-Sent Events. For production we'd move to a hosted database (e.g. Postgres) and Luther single sign-on, which is a configuration change, not a redesign.

**"How do you stop clubs from seeing each other's money?"** Every screen and query goes through role permissions: officers see only their organization, advisors are read-only on the organizations they're assigned, the C-board number needs Face ID, and the AI refuses to reveal it.

**"What if it matches someone to the wrong organization?"** Onboarding asks "Is this your organization?" and offers **No, it's not**. That signs the person out right away (so they never see another club's books) and either lets them try a different email or sends Student Accounts a live notice to fix their access.

**"Does it connect to Luther's finance system?"** Not yet, and we didn't assume access during the hackathon. Student Accounts approves in FairShare; integration with the college's finance system is the 2028 milestone.

**"What does the AI use?"** Claude, when an API key is configured; otherwise a deterministic engine. Both answer only from the organization's books and a small knowledge base of Luther procedures, and both say "I don't know" instead of guessing.

**"Why is the tab bar icon-only?"** It's the floating glass tab bar people already know from Instagram, with tuned spring physics. Every tab has a VoiceOver label, every page starts with a large, clear title, and onboarding introduces the three key actions.
