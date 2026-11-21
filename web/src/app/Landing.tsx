import {
  ArrowRight,
  EnvelopeSimple,
  Receipt,
  ChartPieSlice,
  Scan,
  CheckCircle,
  FileArrowDown,
  Wallet,
  Student,
  Bank,
  ChalkboardTeacher,
  Sparkle,
  Check,
  Minus,
  X,
  DeviceMobile,
  Desktop,
} from '@phosphor-icons/react';
import { navigate, useIsMobile, useStore } from '../store.tsx';
import { BudgetRing, Wordmark } from '../ui/kit.tsx';
import { orgSummary, usd } from '../../../shared/money.ts';

export function Landing() {
  const { state } = useStore();
  const mobile = useIsMobile();
  const up = orgSummary(state, 'uptous');
  const W = { maxWidth: 1120, margin: '0 auto', padding: mobile ? '0 20px' : '0 32px' };

  const Section = ({ id, kicker, title, sub, children }: { id?: string; kicker: string; title: string; sub?: string; children: React.ReactNode }) => (
    <section id={id} style={{ ...W, padding: `${mobile ? 64 : 96}px ${mobile ? 20 : 32}px 0` }}>
      <div className="t-micro" style={{ color: 'var(--accent-text)' }}>
        {kicker}
      </div>
      <h2 className="t-large" style={{ marginTop: 8, maxWidth: 720, fontSize: mobile ? 30 : 38 }}>
        {title}
      </h2>
      {sub && (
        <p className="muted" style={{ marginTop: 10, maxWidth: 640, fontSize: 17 }}>
          {sub}
        </p>
      )}
      <div style={{ marginTop: 36 }}>{children}</div>
    </section>
  );

  return (
    <div style={{ paddingBottom: 80 }}>
      <header className="topbar" style={{ padding: 0 }}>
        <div className="row" style={{ ...W, width: '100%' }}>
          <Wordmark size={30} />
          <div className="grow" />
          {!mobile && (
            <nav className="row" style={{ gap: 4 }}>
              <a className="btn btn-ghost btn-sm" href="#how">
                How it works
              </a>
              <a className="btn btn-ghost btn-sm" href="#colleges">
                For colleges
              </a>
            </nav>
          )}
          <button className="btn btn-primary btn-sm" onClick={() => navigate('/login')}>
            Sign in
          </button>
        </div>
      </header>

      <section style={{ ...W, display: 'grid', gridTemplateColumns: mobile ? '1fr' : '1.1fr 0.9fr', gap: 48, alignItems: 'center', paddingTop: mobile ? 32 : 72 }}>
        <div className="rise">
          <span className="pill pill-needs_info" style={{ height: 28, padding: '0 12px' }}>
            <Sparkle size={14} weight="fill" /> Built for {state.institution.name} student organizations
          </span>
          <h1 className="t-hero" style={{ marginTop: 20, fontSize: mobile ? 42 : 60 }}>
            Club money,
            <br />
            without the email chains.
          </h1>
          <p className="muted" style={{ marginTop: 18, fontSize: 18, maxWidth: 520 }}>
            FairShare gives every student organization a live budget, receipt scanning and one-tap approvals — and gives Student Accounts and advisors one place to see it all.
          </p>
          <div className="row wrap" style={{ gap: 12, marginTop: 28 }}>
            <button className="btn btn-primary btn-lg" onClick={() => navigate('/login')}>
              Open the demo <ArrowRight size={18} />
            </button>
            <a className="btn btn-secondary btn-lg" href="#how">
              See how it works
            </a>
          </div>
          <div className="row wrap t-cap muted" style={{ gap: 18, marginTop: 24 }}>
            <span className="row" style={{ gap: 6 }}>
              <Desktop size={16} /> Web
            </span>
            <span className="row" style={{ gap: 6 }}>
              <DeviceMobile size={16} /> iPhone app
            </span>
            <span className="row" style={{ gap: 6 }}>
              <CheckCircle size={16} /> Live sync between both
            </span>
          </div>
        </div>
        <div style={{ position: 'relative', display: 'grid', placeItems: 'center', padding: mobile ? '8px 0 24px' : 0 }}>
          <div className="card" style={{ padding: 28, width: mobile ? '100%' : 380, boxShadow: 'var(--shadow-3)', borderRadius: 28 }}>
            <div className="row between">
              <div>
                <div className="t-micro">Up to Us · Fall 2026</div>
                <div className="t-cap muted" style={{ marginTop: 2 }}>
                  Live from the demo
                </div>
              </div>
              <span className="sync-chip" style={{ height: 26 }}>
                <span className="sync-dot" /> Live
              </span>
            </div>
            <div style={{ display: 'grid', placeItems: 'center', margin: '22px 0 18px' }}>
              <BudgetRing allocated={up.allocated} approved={up.approved} pending={up.pending} size={230} stroke={18}>
                <div>
                  <div className="t-cap muted">Remaining</div>
                  <div className="num" style={{ fontSize: 38, fontWeight: 700, letterSpacing: '-0.035em', fontFamily: 'var(--font-display)' }}>
                    {usd(up.remaining)}
                  </div>
                  <div className="t-cap muted">of {usd(up.allocated, { cents: false })}</div>
                </div>
              </BudgetRing>
            </div>
            <div className="row between t-cap">
              <span className="muted">Safe to spend</span>
              <span className="w-600 num">{usd(up.available)}</span>
            </div>
            <div className="row between t-cap" style={{ marginTop: 6 }}>
              <span className="muted">Pending review</span>
              <span className="w-600 num" style={{ color: 'var(--amber-text)' }}>
                {usd(up.pending)}
              </span>
            </div>
          </div>
          <div className="toast" style={{ position: 'absolute', bottom: mobile ? -16 : -28, left: mobile ? 12 : -36, width: 300, animation: 'toast-in 600ms 400ms var(--ease) both' }}>
            <span className="toast-icon" style={{ background: 'var(--green-soft)', color: 'var(--green-text)' }}>
              <CheckCircle size={20} weight="fill" />
            </span>
            <span>
              <span className="w-600" style={{ display: 'block', fontSize: 14 }}>
                $52.00 approved
              </span>
              <span className="t-cap muted">Luther Book Shop · Prizes</span>
            </span>
          </div>
        </div>
      </section>

      <Section kicker="The problem" title="Managing a club’s money still runs on email, paper and guesswork." sub="Every official organization at Luther gets a budget. Keeping track of it is the hard part — for students and for Student Accounts.">
        <div className="grid-3">
          {[
            [EnvelopeSimple, 'Checking a balance means an email', 'Officers write to Student Accounts and wait for a reply just to learn how much is left.'],
            [Receipt, 'Receipts and checks travel on paper', 'Documentation is dropped off or emailed, then matched by hand to the right organization.'],
            [ChartPieSlice, 'Nobody has the full picture', 'Officers keep their own spreadsheets, advisors have no dashboard, and pending purchases get counted as money still available.'],
          ].map(([I, t, d]) => {
            const Ico = I as typeof Receipt;
            return (
              <div key={t as string} className="card card-pad-lg">
                <span className="cat-icon">
                  <Ico size={22} />
                </span>
                <h3 className="t-head" style={{ marginTop: 16 }}>
                  {t as string}
                </h3>
                <p className="muted t-cap" style={{ marginTop: 6, fontSize: 14 }}>
                  {d as string}
                </p>
              </div>
            );
          })}
        </div>
      </Section>

      <Section id="how" kicker="How it works" title="From purchase to approved — in one flow." sub="This exact flow is what the demo shows, end to end, on the web and on iPhone.">
        <div style={{ display: 'grid', gridTemplateColumns: mobile ? '1fr' : 'repeat(4, 1fr)', gap: 16 }}>
          {[
            [Wallet, 'Budget is allocated', 'Student Accounts sets each organization’s budget. Officers see it instantly — no email needed.'],
            [Scan, 'Snap the receipt', 'On-device OCR reads the store, date, items and total. Receipts and checks are handled separately.'],
            [CheckCircle, 'One-tap approval', 'Student Accounts reviews the original image next to the numbers and approves — the balance updates live.'],
            [FileArrowDown, 'Reports write themselves', 'Advisors download a PDF or Excel report any time, generated from approved records.'],
          ].map(([I, t, d], i) => {
            const Ico = I as typeof Wallet;
            return (
              <div key={t as string} className="card card-pad-lg">
                <div className="row between">
                  <span className="cat-icon" style={{ background: i === 1 ? 'var(--accent)' : undefined, color: i === 1 ? 'var(--on-accent)' : undefined }}>
                    <Ico size={22} weight={i === 1 ? 'fill' : 'regular'} />
                  </span>
                  <span className="t-micro num">0{i + 1}</span>
                </div>
                <h3 className="t-head" style={{ marginTop: 16 }}>
                  {t as string}
                </h3>
                <p className="muted t-cap" style={{ marginTop: 6, fontSize: 14 }}>
                  {d as string}
                </p>
              </div>
            );
          })}
        </div>
      </Section>

      <Section kicker="Three roles, one source of truth" title="Everyone sees exactly what they should — and nothing more.">
        <div className="grid-3">
          {[
            [Student, 'Organization officers', 'Budget ring, transactions, receipt scanning, protected C-board number, funding requests and the AI assistant.'],
            [Bank, 'Student Accounts', 'Review queue with the original receipt, budgets, announcements and campus-wide reports. Adds people, sets their roles and turns clubs on or off.'],
            [ChalkboardTeacher, 'Faculty advisors', 'Read-only view of the organizations they supervise, with one-click PDF and Excel reports.'],
          ].map(([I, t, d]) => {
            const Ico = I as typeof Bank;
            return (
              <div key={t as string} className="card card-pad-lg row" style={{ alignItems: 'flex-start', gap: 16 }}>
                <span className="cat-icon">
                  <Ico size={22} />
                </span>
                <div>
                  <h3 className="t-head">{t as string}</h3>
                  <p className="muted t-cap" style={{ marginTop: 6, fontSize: 14 }}>
                    {d as string}
                  </p>
                </div>
              </div>
            );
          })}
        </div>
      </Section>

      <Section kicker="Our difference" title="An assistant that actually knows your budget." sub="It answers from your organization’s live books and Luther’s procedures — and says “I don’t know” instead of inventing prices or rules.">
        <div className="card" style={{ padding: mobile ? 20 : 32, maxWidth: 760 }}>
          <div className="chat">
            <div className="bubble bubble-user">Can we afford a $150 event next week?</div>
            <div className="bubble bubble-ai">
              Yes. You can safely spend <strong>{usd(up.available)}</strong> right now (that already sets aside {usd(up.pending)} pending review). A $150.00 event would leave <strong>{usd(up.available - 150)}</strong>.
            </div>
            <div className="bubble bubble-user">How do I print posters at Luther?</div>
            <div className="bubble bubble-ai">
              Posters are printed by the <strong>Luther Document Center</strong>. Email your file to <strong>documentcenter@luther.edu</strong> with size, quantity and your C-board number — I drafted the email for you.
            </div>
          </div>
        </div>
      </Section>

      <Section id="colleges" kicker="Market & business model" title="Free for students. Colleges pay a simple annual subscription." sub="Luther is the pilot. Every college with student organizations has the same problem — especially small liberal arts colleges without custom finance software.">
        <div className="grid-3">
          {[
            ['Starter', '$2,400', 'per year', 'Up to 50 organizations', ['Budgets, receipts & approvals', 'iPhone + web apps', 'PDF & Excel reports']],
            ['Campus', '$5,900', 'per year', 'Up to 200 organizations', ['Everything in Starter', 'AI financial assistant', 'Advisor dashboards & analytics'], true],
            ['Network', 'Custom', '', 'Multi-campus systems', ['Everything in Campus', 'Finance system integrations', 'Single sign-on & audit exports']],
          ].map(([name, price, per, scope, feats, featured]) => (
            <div key={name as string} className="card card-pad-lg" style={{ borderColor: featured ? 'var(--accent)' : undefined, borderWidth: featured ? 1.5 : 1 }}>
              <div className="row between">
                <span className="t-head">{name as string}</span>
                {featured && <span className="pill pill-needs_info">Pilot plan</span>}
              </div>
              <div className="row" style={{ alignItems: 'baseline', gap: 6, marginTop: 14 }}>
                <span className="t-large num">{price as string}</span>
                <span className="t-cap muted">{per as string}</span>
              </div>
              <div className="t-cap muted">{scope as string}</div>
              <hr className="divider" style={{ margin: '18px 0' }} />
              <div className="col" style={{ gap: 10 }}>
                {(feats as string[]).map((f) => (
                  <span key={f} className="row t-cap" style={{ gap: 8 }}>
                    <Check size={15} weight="bold" color="var(--green)" /> {f}
                  </span>
                ))}
              </div>
            </div>
          ))}
        </div>
        <p className="t-cap faint" style={{ marginTop: 14 }}>
          Proposed pricing for discussion. Pricing scales with the number of registered organizations.
        </p>
      </Section>

      <Section kicker="Competition" title="Built for student organizations — not adapted to them.">
        <div className="card" style={{ padding: '16px 8px', overflowX: 'auto' }}>
          <table className="table" style={{ minWidth: 640 }}>
            <thead>
              <tr>
                <th></th>
                <th>Email + spreadsheets</th>
                <th>Corporate expense apps</th>
                <th>Campus engagement suites</th>
                <th style={{ color: 'var(--accent-text)' }}>FairShare</th>
              </tr>
            </thead>
            <tbody>
              {[
                ['Live balance for officers', 0, 1, 1, 2],
                ['Receipt & check scanning', 0, 2, 0, 2],
                ['Campus approval workflow (Student Accounts)', 0, 1, 1, 2],
                ['Pending vs. approved shown separately', 0, 1, 0, 2],
                ['Advisor read-only reports', 0, 0, 1, 2],
                ['AI assistant grounded in the club’s budget', 0, 0, 0, 2],
                ['Priced for small colleges', 2, 0, 1, 2],
              ].map(([label, ...v]) => (
                <tr key={label as string}>
                  <td className="w-500">{label as string}</td>
                  {(v as number[]).map((x, i) => (
                    <td key={i}>{x === 2 ? <Check size={18} weight="bold" color="var(--green)" /> : x === 1 ? <Minus size={18} className="faint" /> : <X size={16} className="faint" />}</td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Section>

      <Section kicker="Timeline" title="A realistic path from hackathon to campus.">
        <div style={{ display: 'grid', gridTemplateColumns: mobile ? '1fr' : 'repeat(4, 1fr)', gap: 16 }}>
          {[
            ['Now', 'Working prototype', 'Web + iPhone, live sync, OCR, approvals, reports, AI assistant.'],
            ['Spring 2027', 'Luther pilot', '10–15 organizations with Student Accounts. Real SSO, hosted database.'],
            ['Fall 2027', 'All of Luther', 'Every registered organization; annual funding cycle runs in FairShare.'],
            ['2028', 'More colleges', 'Three to five liberal arts colleges; finance-system integrations.'],
          ].map(([when, t, d], i) => (
            <div key={when} className="card card-pad-lg" style={{ borderColor: i === 0 ? 'var(--accent)' : undefined }}>
              <div className="t-micro" style={{ color: i === 0 ? 'var(--accent-text)' : undefined }}>
                {when}
              </div>
              <h3 className="t-head" style={{ marginTop: 8 }}>
                {t}
              </h3>
              <p className="muted t-cap" style={{ marginTop: 6, fontSize: 14 }}>
                {d}
              </p>
            </div>
          ))}
        </div>
      </Section>

      <Section kicker="Tech stack" title="Simple, proven technology — chosen so a student team can run it.">
        <div className="row wrap" style={{ gap: 10 }}>
          {['React + TypeScript (web)', 'SwiftUI (iPhone)', 'Node.js sync server', 'Server-Sent Events for live updates', 'Apple Vision OCR on iPhone', 'Tesseract OCR in the browser', 'Claude for the AI assistant', 'PDF & Excel report generation', 'Role-based access control'].map((t) => (
            <span key={t} className="chip" style={{ cursor: 'default' }}>
              {t}
            </span>
          ))}
        </div>
      </Section>

      <section style={{ ...W, paddingTop: 96 }}>
        <div className="card" style={{ padding: mobile ? 28 : 48, textAlign: 'center', background: 'var(--surface)' }}>
          <h2 className="t-large">See it work in two minutes.</h2>
          <p className="muted" style={{ marginTop: 8 }}>
            Sign in as an officer, scan a receipt, then approve it as Student Accounts.
          </p>
          <button className="btn btn-primary btn-lg" style={{ marginTop: 22 }} onClick={() => navigate('/login')}>
            Open the demo <ArrowRight size={18} />
          </button>
        </div>
        <p className="t-cap faint" style={{ textAlign: 'center', marginTop: 28 }}>
          FairShare · A Luther College hackathon project · Demo data only
        </p>
      </section>
    </div>
  );
}
