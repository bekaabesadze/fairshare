import { useMemo, useState } from 'react';
import { Plus, ArrowRight, Sparkle, MagnifyingGlass, Receipt as ReceiptIcon, FileText, Link as LinkIcon, ClipboardText, Scroll } from '@phosphor-icons/react';
import { navigate, useIsMobile, useStore } from '../store.tsx';
import { orgSummary, usd, CATEGORIES, longDate, shortDate } from '../../../shared/money.ts';
import type { ExpenseStatus, Org } from '../../../shared/types.ts';
import { AnimatedNumber, Avatar, BudgetRing, CategoryBars, Empty, OrgBadge, RingLegend } from '../ui/kit.tsx';
import { CboardCard, ExpenseDetail, ExpenseRow, FundingCard, FundingSheet, ReportButtons, SectionCard } from './common.tsx';
import { PageHeader } from '../app/Shell.tsx';
import { SUGGESTED_QUESTIONS } from '../../../shared/assistant.ts';

export function useOfficerOrg(): Org {
  const { user, state } = useStore();
  return state.orgs.find((o) => o.id === user!.orgIds[0])!;
}

const greeting = () => {
  const h = new Date().getHours();
  return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
};

export function OfficerHome() {
  const { state, user } = useStore();
  const org = useOfficerOrg();
  const mobile = useIsMobile();
  const s = orgSummary(state, org.id);
  const [funding, setFunding] = useState(false);
  const exps = state.expenses.filter((e) => e.orgId === org.id).sort((a, b) => b.submittedAt.localeCompare(a.submittedAt));
  const needsInfo = exps.filter((e) => e.status === 'needs_info');
  const first = user!.name.split(' ')[0];

  const ring = (
    <section className="card" style={{ padding: mobile ? '24px 20px' : 28 }}>
      <div className="row between" style={{ marginBottom: mobile ? 12 : 4 }}>
        <div>
          <div className="t-micro">{org.term} budget</div>
          <div className="t-cap muted" style={{ marginTop: 2 }}>
            {usd(s.allocated)} allocated by Student Accounts
          </div>
        </div>
      </div>
      <div style={{ display: 'grid', placeItems: 'center', padding: '12px 0 20px' }}>
        <BudgetRing allocated={s.allocated} approved={s.approved} pending={s.pending} size={mobile ? 248 : 272} stroke={mobile ? 18 : 20}>
          <div>
            <div className="t-cap muted w-500">Remaining</div>
            <div className="num" style={{ fontFamily: 'var(--font-display)', fontSize: mobile ? 40 : 44, fontWeight: 700, letterSpacing: '-0.035em', lineHeight: 1.1, marginTop: 2 }}>
              <AnimatedNumber value={s.remaining} />
            </div>
            <div className="t-cap muted" style={{ marginTop: 4 }}>
              of {usd(s.allocated, { cents: false })}
            </div>
          </div>
        </BudgetRing>
      </div>
      <RingLegend available={s.available} pending={s.pending} approved={s.approved} />
      {s.pending > 0 && (
        <p className="t-cap muted" style={{ marginTop: 16, paddingTop: 14, borderTop: '1px solid var(--hairline)' }}>
          <span className="w-600" style={{ color: 'var(--text)' }}>
            Plan with {usd(s.available)}.
          </span>{' '}
          {usd(s.pending)} is waiting for approval, so it isn’t counted as available.
        </p>
      )}
    </section>
  );

  const recent = (
    <SectionCard
      title="Recent activity"
      action={
        <button className="btn btn-ghost btn-sm" onClick={() => navigate('/activity')}>
          See all <ArrowRight size={14} />
        </button>
      }
    >
      {exps.length ? (
        <div className="list" style={{ margin: '0 -4px' }}>
          {exps.slice(0, 5).map((e) => (
            <ExpenseRow key={e.id} e={e} onClick={() => navigate(`/activity/${e.id}`)} />
          ))}
        </div>
      ) : (
        <Empty icon={ReceiptIcon} title="No expenses yet" body="When you buy something for an event, add the receipt here." action={<button className="btn btn-primary" onClick={() => navigate('/add')}>Add expense</button>} />
      )}
    </SectionCard>
  );

  const categories = (
    <SectionCard title="Spending by category">
      <CategoryBars rows={s.byCategory.map((c) => ({ ...c, label: CATEGORIES.find((x) => x.id === c.id)!.label }))} />
    </SectionCard>
  );

  const ask = (
    <section className="card card-pad">
      <div className="row" style={{ gap: 10, marginBottom: 12 }}>
        <Sparkle size={20} weight="fill" color="var(--accent)" />
        <h2 className="t-head">Ask FairShare</h2>
      </div>
      <div className="row wrap" style={{ gap: 8 }}>
        {SUGGESTED_QUESTIONS.slice(0, 3).map((q) => (
          <button key={q} className="chip" onClick={() => navigate(`/ask?q=${encodeURIComponent(q)}`)}>
            {q}
          </button>
        ))}
      </div>
    </section>
  );

  const actions = (
    <>
      <FundingCard org={org} onOpen={() => setFunding(true)} />
      {needsInfo.map((e) => (
        <button key={e.id} className="notice-banner" style={{ width: '100%', textAlign: 'left' }} onClick={() => navigate(`/activity/${e.id}`)}>
          <span className="toast-icon" style={{ background: 'var(--surface)', color: 'var(--accent)', width: 40, height: 40, borderRadius: 12 }}>
            <FileText size={22} weight="fill" />
          </span>
          <span className="grow">
            <span className="t-micro" style={{ color: 'var(--accent-text)' }}>
              Your turn
            </span>
            <span className="w-600" style={{ display: 'block', marginTop: 2 }}>
              Add a document for {e.vendor} · {usd(e.amount)}
            </span>
            <span className="t-cap muted">{e.reviewNote}</span>
          </span>
          <ArrowRight size={18} className="muted" />
        </button>
      ))}
    </>
  );

  if (mobile) {
    return (
      <div className="m-page stack-16 rise">
        <div style={{ padding: '6px 0 4px' }}>
          <h1 className="t-large">Hi, {first}</h1>
          <p className="muted" style={{ marginTop: 2 }}>
            Here’s where {org.name} stands today.
          </p>
        </div>
        {ring}
        {actions}
        {recent}
        {categories}
        <CboardCard org={org} />
        {ask}
        <FundingSheet org={org} open={funding} onClose={() => setFunding(false)} />
      </div>
    );
  }

  return (
    <div className="page rise">
      <PageHeader
        title={`${greeting()}, ${first}`}
        subtitle={`Here’s where ${org.name} stands today, ${longDate(new Date().toISOString())}.`}
        actions={
          <button className="btn btn-primary btn-lg" onClick={() => navigate('/add')}>
            <Plus size={20} weight="bold" /> Add expense
          </button>
        }
      />
      <div className="home-grid">
        <div className="stack-16">
          {ring}
          <CboardCard org={org} />
        </div>
        <div className="stack-16">
          {actions}
          {recent}
          {categories}
          {ask}
        </div>
      </div>
      <FundingSheet org={org} open={funding} onClose={() => setFunding(false)} />
    </div>
  );
}

const FILTERS: { key: 'all' | ExpenseStatus; label: string }[] = [
  { key: 'all', label: 'All' },
  { key: 'pending', label: 'Pending' },
  { key: 'needs_info', label: 'Needs info' },
  { key: 'approved', label: 'Approved' },
  { key: 'rejected', label: 'Rejected' },
];

export function ActivityPage({ openId }: { openId?: string }) {
  const { state, user } = useStore();
  const mobile = useIsMobile();
  const orgIds = user!.role === 'officer' || user!.role === 'advisor' ? user!.orgIds : state.orgs.map((o) => o.id);
  const [filter, setFilter] = useState<'all' | ExpenseStatus>('all');
  const [q, setQ] = useState('');
  const all = state.expenses.filter((e) => orgIds.includes(e.orgId));
  const list = useMemo(
    () =>
      all
        .filter((e) => filter === 'all' || e.status === filter)
        .filter((e) => !q || `${e.vendor} ${e.description} ${e.amount}`.toLowerCase().includes(q.toLowerCase()))
        .sort((a, b) => b.date.localeCompare(a.date) || b.submittedAt.localeCompare(a.submittedAt)),
    [all, filter, q],
  );
  const groups = useMemo(() => {
    const m = new Map<string, typeof list>();
    for (const e of list) {
      const k = new Date(e.date + 'T12:00:00').toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
      m.set(k, [...(m.get(k) ?? []), e]);
    }
    return [...m.entries()];
  }, [list]);
  const multiOrg = orgIds.length > 1;

  const body = (
    <>
      <div className="row wrap" style={{ gap: 10, marginBottom: 16 }}>
        <div style={{ overflowX: 'auto', maxWidth: '100%', scrollbarWidth: 'none' }}>
          <div className="segmented">
            {FILTERS.map((f) => {
              const n = f.key === 'all' ? all.length : all.filter((e) => e.status === f.key).length;
              return (
                <button key={f.key} aria-pressed={filter === f.key} onClick={() => setFilter(f.key)}>
                  {f.label}
                  <span className="faint num" style={{ marginLeft: 5 }}>
                    {n}
                  </span>
                </button>
              );
            })}
          </div>
        </div>
        <div className="grow" />
        <label className="row" style={{ position: 'relative', width: mobile ? '100%' : 260 }}>
          <MagnifyingGlass size={18} className="faint" style={{ position: 'absolute', left: 13 }} />
          <input className="input" style={{ height: 40, paddingLeft: 38 }} placeholder="Search vendor or note" value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search transactions" />
        </label>
      </div>
      {groups.length ? (
        <div className="stack-16">
          {groups.map(([month, items]) => (
            <section key={month} className="card" style={{ padding: '14px 16px' }}>
              <div className="row between" style={{ padding: '2px 4px 6px' }}>
                <span className="t-micro">{month}</span>
                <span className="t-cap faint num">{usd(items.filter((e) => e.status === 'approved').reduce((s, e) => s + e.amount, 0))} approved</span>
              </div>
              <div className="list">
                {items.map((e) => (
                  <ExpenseRow key={e.id} e={e} showOrg={multiOrg} onClick={() => navigate(`/activity/${e.id}`)} />
                ))}
              </div>
            </section>
          ))}
        </div>
      ) : (
        <div className="card">
          <Empty icon={ReceiptIcon} title="Nothing here" body={q ? 'No transactions match your search.' : 'No transactions with this status.'} />
        </div>
      )}
      <ExpenseDetail id={openId ?? null} onClose={() => navigate('/activity')} />
    </>
  );

  if (mobile)
    return (
      <div className="m-page rise">
        <h1 className="t-large" style={{ margin: '6px 0 16px' }}>
          Activity
        </h1>
        {body}
      </div>
    );
  return (
    <div className="page rise">
      <PageHeader
        title="Activity"
        subtitle={multiOrg ? 'Every transaction for the organizations you supervise.' : 'Every expense your organization has submitted, and where it stands.'}
        actions={
          user!.role === 'officer' && (
            <button className="btn btn-primary" onClick={() => navigate('/add')}>
              <Plus size={18} weight="bold" /> Add expense
            </button>
          )
        }
      />
      {body}
    </div>
  );
}

export function ClubPage() {
  const { state } = useStore();
  const org = useOfficerOrg();
  const mobile = useIsMobile();
  const [funding, setFunding] = useState(false);
  const [doc, setDoc] = useState<string | null>(null);
  const officers = state.users.filter((u) => u.role === 'officer' && u.orgIds.includes(org.id));
  const advisor = state.users.find((u) => u.id === org.advisorId);
  const allocations = state.allocations.filter((a) => a.orgId === org.id);
  const docs = state.documents.filter((d) => d.audience === 'all' || d.audience.includes(org.id));
  const DOC_ICON = { form: ClipboardText, policy: Scroll, guide: FileText, template: LinkIcon } as const;
  const openDoc = state.documents.find((d) => d.id === doc);

  return (
    <div className={mobile ? 'm-page stack-16 rise' : 'page rise'}>
      <div className="row" style={{ gap: 16, marginBottom: mobile ? 4 : 28, alignItems: 'center' }}>
        <OrgBadge id={org.id} initials={org.initials} size={mobile ? 56 : 64} />
        <div style={{ minWidth: 0 }}>
          <h1 className="t-large">{org.name}</h1>
          <p className="muted" style={{ marginTop: 2 }}>
            {org.mission}
          </p>
        </div>
      </div>
      <div className={mobile ? 'stack-16' : 'grid-2'} style={{ alignItems: 'start' }}>
        <div className="stack-16">
          <CboardCard org={org} />
          <FundingCard org={org} onOpen={() => setFunding(true)} />
          <SectionCard title="People">
            <div className="list" style={{ margin: '0 -4px' }}>
              {officers.map((u) => (
                <div key={u.id} className="list-row">
                  <Avatar name={u.name} email={u.email} size={42} />
                  <span className="col grow">
                    <span className="w-600">{u.name}</span>
                    <span className="t-cap muted">{u.title.split(' · ')[0]}</span>
                  </span>
                  <a className="t-cap" href={`mailto:${u.email}`}>
                    Email
                  </a>
                </div>
              ))}
              {advisor && (
                <div className="list-row">
                  <Avatar name={advisor.name} email={advisor.email} size={42} />
                  <span className="col grow">
                    <span className="w-600">{advisor.name}</span>
                    <span className="t-cap muted">Faculty advisor · can view reports</span>
                  </span>
                  <a className="t-cap" href={`mailto:${advisor.email}`}>
                    Email
                  </a>
                </div>
              )}
            </div>
          </SectionCard>
        </div>
        <div className="stack-16">
          <SectionCard title="Budget history">
            <div className="list" style={{ margin: '0 -4px' }}>
              {allocations.map((a) => (
                <div key={a.id} className="list-row" style={{ minHeight: 52 }}>
                  <span className="col grow">
                    <span className="w-500">{a.note}</span>
                    <span className="t-cap muted">{longDate(a.at)}</span>
                  </span>
                  <span className="w-600 num" style={{ color: a.amount >= 0 ? 'var(--green-text)' : 'var(--red-text)' }}>
                    {a.amount >= 0 ? '+' : '−'}
                    {usd(Math.abs(a.amount))}
                  </span>
                </div>
              ))}
            </div>
          </SectionCard>
          <SectionCard title="Financial report" action={<ReportButtons org={org} size="sm" />}>
            <p className="t-cap muted">A complete report of your budget, expenses by category and every transaction — the same one your advisor and Student Accounts see.</p>
          </SectionCard>
          <SectionCard title="Documents from Student Accounts">
            <div className="list" style={{ margin: '0 -4px' }}>
              {docs.map((d) => {
                const I = DOC_ICON[d.kind];
                return (
                  <button key={d.id} className="list-row" onClick={() => (d.url ? window.open(d.url, '_blank', 'noopener') : setDoc(d.id))}>
                    <span className="cat-icon">
                      <I size={20} />
                    </span>
                    <span className="col grow" style={{ minWidth: 0 }}>
                      <span className="w-600 ellipsis">{d.title}</span>
                      <span className="t-cap muted ellipsis">{d.summary}</span>
                    </span>
                    <span className="t-cap faint">{shortDate(d.updatedAt)}</span>
                  </button>
                );
              })}
            </div>
          </SectionCard>
        </div>
      </div>
      <FundingSheet org={org} open={funding} onClose={() => setFunding(false)} />
      {openDoc && <DocumentReader title={openDoc.title} summary={openDoc.summary} onClose={() => setDoc(null)} />}
    </div>
  );
}

import { KNOWLEDGE } from '../../../shared/knowledge.ts';
import { Overlay } from '../ui/kit.tsx';

function DocumentReader({ title, summary, onClose }: { title: string; summary: string; onClose: () => void }) {
  const entries = KNOWLEDGE.filter((k) => /purchas|guide|eligible|document|print/i.test(`${k.source} ${k.title}`));
  return (
    <Overlay open onClose={onClose} title={title} subtitle={summary}>
      <div className="stack-16">
        {entries.map((k) => (
          <div key={k.id}>
            <div className="t-head">{k.title}</div>
            <p className="muted" style={{ marginTop: 4 }}>
              {k.body}
            </p>
          </div>
        ))}
      </div>
    </Overlay>
  );
}
