# FairShare

**The financial operating system for student organizations.**
Live budgets, receipt & check scanning, one-tap approvals, automatic reports and an AI assistant — on the web and on iPhone, sharing one set of books in real time.

Built for Luther College student organizations and Student Accounts. All data is demo data.

---

## Run it (2 commands)

Requires Node 22.18+ and (for the iPhone app) Xcode 26+.

```bash
npm install
```

```bash
npm run dev
```

- **Website:** http://localhost:5173
- **Sync server:** http://localhost:4000 (the "central database" both apps talk to)

**iPhone app:** open `ios/FairShare.xcodeproj` in Xcode → pick an iPhone simulator → ▶ Run.
The simulator connects to `http://localhost:4000` automatically. The app shows **Live** on Home when it's connected.

> On a **real iPhone**, open Settings (tap your avatar) → *Sync* → enter your Mac's address, e.g. `http://192.168.1.20:4000`, and tap Reconnect. The phone and Mac must be on the same Wi-Fi.

**No server?** Both apps still work. They fall back to an offline copy of the demo data (the web app also syncs between its own tabs), so the demo can't break.

### Optional: live AI with Claude

The assistant answers out of the box from an on-device engine that reads the organization's real numbers. To use Claude for free-form questions:

```bash
ANTHROPIC_API_KEY=sk-ant-... npm run dev
```

It uses `claude-opus-5-5` with server-side refusal fallbacks enabled. If the call fails for any reason, the offline engine answers instead.

### Reset the demo

In either app: **Settings → Reset demo data**. Or delete `server/data/` and restart.

---

## What's inside

| Role | Web | iPhone |
|---|---|---|
| **Organization officer** | Budget ring, activity, add expense (OCR), AI assistant, club page with C-board number, funding request, PDF/Excel report | Same, with Apple Vision OCR, document camera and Face ID–protected C-board |
| **Student Accounts** | Campus overview, review queue (keyboard shortcuts), organizations, budget adjustments, reports, announcements & documents | Overview, review queue with receipt viewer, org detail, budget adjustments, announcements |
| **Faculty advisor** | Read-only org dashboards, activity, PDF/Excel reports | Read-only org dashboards, PDF/CSV export |
| **Platform admin** | Users & roles, organization registration, AI toggle | Users & roles, organization access |

### The financial rule that matters most
`Remaining = allocated − approved`, and **`Safe to spend = remaining − pending`**.
Pending expenses are drawn as a striped amber arc and are never shown as available money, so an officer can't accidentally plan with money that's already claimed.

---

## Architecture

```
shared/          One domain core in TypeScript — used by the server and the web app,
                 mirrored field-for-field by the iOS app.
  types.ts         Data model (orgs, users, expenses, allocations, announcements…)
  money.ts         Budget math, permissions, formatting
  reducer.ts       Every state change (submit, approve, allocate, publish…)
  seed.ts          Demo data (also exported to ios/FairShare/Resources/seed.json)
  assistant.ts     Offline AI engine + the Claude system prompt
  knowledge.ts     Luther procedures the assistant may cite (and nothing else)
  ocr-parse.ts     Turns OCR text into vendor / date / items / tax / total, or check fields

server/          Plain Node HTTP server (no framework)
  index.ts         JSON state on disk, receipt files, POST /api/action, SSE /api/events
  ai.ts            Claude integration with an automatic offline fallback

web/             React + TypeScript + Vite
  src/ui/GlassTabBar.tsx   Port of the Norsify floating glass tab bar (phone widths)
  src/lib/ocr.ts           Tesseract OCR, served locally from /ocr (works offline)
  src/lib/reports.ts       PDF (jsPDF) and Excel (ExcelJS) reports

ios/FairShare    SwiftUI (iOS 18+, Liquid Glass on iOS 26+)
  Core/            Models, ledger math, offline reducer, live-sync store, Vision OCR
  UI/              Design system, budget ring, Norsify glass tab bar
  Views/           Onboarding, officer, Student Accounts, advisor and admin screens

brand/           Blue S emblem, raster asset renderer and app icons
                 Typeface: Plus Jakarta Sans (SIL OFL), in ios/FairShare/Resources/Fonts and web/public/fonts
docs/            Demo script and pitch notes
```

**Live sync:** every action is POSTed to the server, which applies the same reducer and pushes the new state to every open client over Server-Sent Events. Approving an expense on the laptop updates the iPhone's balance in under a second.

**Privacy & permissions:** organizations only ever see their own finances; advisors are read-only; the C-board number is hidden behind Face ID / press-and-hold and never shown by the assistant.

### Tests

```bash
npm run typecheck
```

```bash
node scripts/tests/ocr.test.ts
```

The OCR test runs Tesseract on the scan-flow samples in `web/public/samples/` and the fixtures in `scripts/tests/fixtures/`. It prints what the parser extracted.
