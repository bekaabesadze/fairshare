import { useEffect, useMemo, useState } from 'react';
import { ArrowRight, CheckCircle, Plus, Tray, Megaphone, DownloadSimple, Minus, FileText, CaretRight, CalendarBlank, LinkSimple, UsersThree } from '@phosphor-icons/react';
import type { Announcement, DocumentItem, Expense, Org, User } from '../../../shared/types.ts';
import { campusSummary, CATEGORIES, monthlySpend, orgSummary, usd, uid, longDate, shortDate, relativeTime, categoryById, ROLE_LABEL } from '../../../shared/money.ts';
import { navigate, todayISO, useIsMobile, useStore } from '../store.tsx';
import { AnimatedNumber, Avatar, BudgetRing, CategoryBars, CategoryIcon, Empty, MonthlyColumns, OrgBadge, Overlay, RingLegend, Stat, StatusPill } from '../ui/kit.tsx';
import { CboardCard, DocumentPreview, ExpenseDetail, ExpenseRow, ReportButtons, SectionCard } from './common.tsx';
import { PageHeader } from '../app/Shell.tsx';
import { PersonModal, Toggle } from './other.tsx';
import { downloadCampusXlsx } from '../lib/reports.ts';

export function AccountsOverview() {
  const { state, user } = useStore();
  const mobile = useIsMobile();
  const c = campusSummary(state);
  const months = monthlySpend(state.expenses, todayISO(), 3);
  const queue = [...c.queue].sort((a, b) => b.submittedAt.localeCompare(a.submittedAt));
  const first = user!.name.split(' ')[0];

  return (
    <div className={mobile ? 'm-page stack-16 rise' : 'page rise'}>
      {mobile ? (
        <div style={{ padding: '6px 0 4px' }}>
          <h1 className="t-large">Overview</h1>
          <p className="muted">{state.institution.term} · {c.orgCount} organizations</p>
        </div>
      ) : (
        <PageHeader
          title={`Welcome back, ${first}`}
          subtitle={`${state.institution.term} · ${c.orgCount} registered organizations`}
          actions={
            <button className="btn btn-primary btn-lg" onClick={() => navigate('/review')}>
              <Tray size={20} weight="fill" /> Review {queue.length} pending
            </button>
          }
        />
      )}
      <div className="grid-4" style={{ marginBottom: 20 }}>
        <Stat label="Allocated" value={<AnimatedNumber value={c.allocated} format={(n) => usd(n, { cents: false })} />} hint="Across all organizations" />
        <Stat label="Approved spending" value={<AnimatedNumber value={c.approved} format={(n) => usd(n, { cents: false })} />} hint={`${Math.round((c.approved / Math.max(1, c.allocated)) * 100)}% of allocations`} />
        <Stat label="Waiting on you" value={queue.length} tone="amber" hint={`${usd(queue.reduce((s, e) => s + e.amount, 0))} pending review`} />
        <Stat label="Funding requests" value={`${c.fundingSubmitted}/${c.orgCount}`} tone="accent" hint="Submitted for 2027–28" />
      </div>
      <div className={mobile ? 'stack-16' : 'home-grid'} style={{ marginBottom: 20 }}>
        <SectionCard
          title="Review queue"
          action={
            <button className="btn btn-ghost btn-sm" onClick={() => navigate('/review')}>
              Open queue <ArrowRight size={14} />
            </button>
          }
        >
          {queue.length ? (
            <div className="list" style={{ margin: '0 -4px' }}>
              {queue.slice(0, 5).map((e) => (
                <ExpenseRow key={e.id} e={e} showOrg onClick={() => navigate(`/review/${e.id}`)} />
              ))}
            </div>
          ) : (
            <Empty icon={CheckCircle} title="All caught up" body="Every submitted expense has been reviewed." />
          )}
        </SectionCard>
        <div className="stack-16">
          <SectionCard title="Approved spending by month">
            <MonthlyColumns data={months} height={120} />
          </SectionCard>
          <SectionCard title="Campus spending by category">
            <CategoryBars rows={c.byCategory.map((r) => ({ ...r, pending: 0, label: categoryById(r.id).label }))} />
          </SectionCard>
        </div>
      </div>
      <OrgTable />
    </div>
  );
}

export function OrgTable({ title = 'Organizations' }: { title?: string }) {
  const { state } = useStore();
  const mobile = useIsMobile();
  const c = campusSummary(state);
  const rows = [...c.orgs].sort((a, b) => a.org.name.localeCompare(b.org.name));
  if (mobile) {
    return (
      <SectionCard title={title}>
        <div className="list" style={{ margin: '0 -4px' }}>
          {rows.map(({ org, s }) => (
            <button key={org.id} className="list-row" onClick={() => navigate(`/orgs/${org.id}`)}>
              <OrgBadge id={org.id} initials={org.initials} size={40} />
              <span className="col grow" style={{ minWidth: 0, gap: 6 }}>
                <span className="w-600 ellipsis">{org.name}</span>
                <span className="bar-track" style={{ height: 6 }}>
                  <span className="bar-fill" style={{ width: `${s.usedPct * 100}%`, background: 'var(--text-2)' }} />
                  {s.pending > 0 && <span className="bar-fill" style={{ width: `${s.pendingPct * 100}%`, background: 'var(--amber)' }} />}
                </span>
              </span>
              <span className="col" style={{ alignItems: 'flex-end' }}>
                <span className="w-600 num">{usd(s.remaining, { cents: false })}</span>
                <span className="t-cap faint">left</span>
              </span>
            </button>
          ))}
        </div>
      </SectionCard>
    );
  }
  return (
    <section className="card" style={{ padding: '20px 8px 8px' }}>
      <div className="section-head" style={{ padding: '0 12px' }}>
        <h2 className="t-head">{title}</h2>
        <button className="btn btn-ghost btn-sm" onClick={() => downloadCampusXlsx(state)}>
          <DownloadSimple size={16} /> Export all
        </button>
      </div>
      <table className="table">
        <thead>
          <tr>
            <th>Organization</th>
            <th className="r">Allocated</th>
            <th style={{ width: '22%' }}>Spent</th>
            <th className="r">Pending</th>
            <th className="r">Remaining</th>
            <th>Funding request</th>
          </tr>
        </thead>
        <tbody>
          {rows.map(({ org, s }) => (
            <tr key={org.id} className="clickable" onClick={() => navigate(`/orgs/${org.id}`)}>
              <td>
                <span className="row" style={{ gap: 12 }}>
                  <OrgBadge id={org.id} initials={org.initials} size={34} />
                  <span className="col">
                    <span className="w-600">{org.name}</span>
                    <span className="t-cap faint mono">C-board {org.cboard}</span>
                  </span>
                </span>
              </td>
              <td className="r num">{usd(s.allocated, { cents: false })}</td>
              <td>
                <span className="row" style={{ gap: 10 }}>
                  <span className="bar-track grow" style={{ height: 6 }}>
                    <span className="bar-fill" style={{ width: `${s.usedPct * 100}%`, background: 'var(--text-2)' }} />
                    {s.pending > 0 && <span className="bar-fill" style={{ width: `${s.pendingPct * 100}%`, background: 'var(--amber)' }} />}
                  </span>
                  <span className="t-cap num faint" style={{ width: 34, textAlign: 'right' }}>
                    {Math.round(s.usedPct * 100)}%
                  </span>
                </span>
              </td>
              <td className="r num" style={{ color: s.pending ? 'var(--amber-text)' : 'var(--text-3)' }}>
                {s.pending ? usd(s.pending) : '—'}
              </td>
              <td className="r num w-600">{usd(s.remaining)}</td>
              <td>
                <FundingPill org={org} />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}

export function FundingPill({ org }: { org: Org }) {
  if (org.funding.status === 'approved') return <span className="pill pill-approved">Approved</span>;
  if (org.funding.status === 'submitted') return <span className="pill pill-needs_info">Submitted</span>;
  return <span className="pill pill-neutral">Not yet</span>;
}

export function ReviewPage({ openId }: { openId?: string }) {
  const { state, user, dispatch, toast } = useStore();
  const mobile = useIsMobile();
  const [tab, setTab] = useState<'pending' | 'needs_info' | 'done'>('pending');
  const [note, setNote] = useState('');
  const list = useMemo(() => {
    const all = state.expenses;
    if (tab === 'pending') return all.filter((e) => e.status === 'pending').sort((a, b) => b.submittedAt.localeCompare(a.submittedAt));
    if (tab === 'needs_info') return all.filter((e) => e.status === 'needs_info');
    return all.filter((e) => e.status === 'approved' || e.status === 'rejected').sort((a, b) => (b.reviewedAt ?? '').localeCompare(a.reviewedAt ?? '')).slice(0, 25);
  }, [state.expenses, tab]);
  const selected = state.expenses.find((e) => e.id === openId) ?? (mobile ? undefined : list[0]);

  useEffect(() => setNote(''), [selected?.id]);

  const decide = (e: Expense, status: 'approved' | 'rejected' | 'needs_info') => {
    if (status !== 'approved' && !note.trim()) {
      toast({ title: 'Add a short note first', body: 'Tell the organization what is missing or why.', tone: 'info' });
      return;
    }
    const org = state.orgs.find((o) => o.id === e.orgId)!;
    const idx = list.findIndex((x) => x.id === e.id);
    dispatch({ type: 'expense/review', id: e.id, status, note: note.trim() || undefined, by: user!.id });
    toast({ title: status === 'approved' ? `Approved ${usd(e.amount)}` : status === 'needs_info' ? 'Documentation requested' : 'Expense declined', body: `${org.name} · ${e.vendor}`, tone: status });
    const next = list[idx + 1] ?? list[idx - 1];
    navigate(next && next.id !== e.id ? `/review/${next.id}` : '/review');
  };

  useEffect(() => {
    if (mobile) return;
    const onKey = (ev: KeyboardEvent) => {
      if ((ev.target as HTMLElement).closest('input,textarea,select')) return;
      if (!selected) return;
      const i = list.findIndex((x) => x.id === selected.id);
      if (ev.key === 'j' && list[i + 1]) navigate(`/review/${list[i + 1].id}`);
      if (ev.key === 'k' && list[i - 1]) navigate(`/review/${list[i - 1].id}`);
      if (ev.key === 'a' && (selected.status === 'pending' || selected.status === 'needs_info')) decide(selected, 'approved');
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  const tabs = (
    <div className="segmented" style={{ marginBottom: 16 }}>
      {(
        [
          ['pending', 'Pending', state.expenses.filter((e) => e.status === 'pending').length],
          ['needs_info', 'Waiting on org', state.expenses.filter((e) => e.status === 'needs_info').length],
          ['done', 'Reviewed', null],
        ] as const
      ).map(([k, label, n]) => (
        <button key={k} aria-pressed={tab === k} onClick={() => setTab(k)}>
          {label}
          {n !== null && <span className="faint num" style={{ marginLeft: 5 }}>{n}</span>}
        </button>
      ))}
    </div>
  );

  const listEl = list.length ? (
    <div className="list">
      {list.map((e) => {
        const org = state.orgs.find((o) => o.id === e.orgId)!;
        const on = selected?.id === e.id && !mobile;
        return (
          <button key={e.id} className="list-row" style={{ background: on ? 'var(--accent-soft)' : undefined, padding: '12px 12px' }} onClick={() => navigate(`/review/${e.id}`)}>
            <CategoryIcon id={e.category} size={38} />
            <span className="col grow" style={{ minWidth: 0 }}>
              <span className="w-600 ellipsis">{org.name}</span>
              <span className="t-cap muted ellipsis">
                {e.docType === 'check' ? `Check #${e.checkNumber ?? '—'} · ` : ''}
                {e.vendor} · {relativeTime(e.submittedAt)}
              </span>
            </span>
            <span className="w-600 num">{usd(e.amount)}</span>
          </button>
        );
      })}
    </div>
  ) : (
    <Empty icon={CheckCircle} title={tab === 'pending' ? 'Queue is clear' : 'Nothing here'} body={tab === 'pending' ? 'New expenses appear here the moment an organization submits them.' : 'No expenses in this list.'} />
  );

  if (mobile) {
    return (
      <div className="m-page rise">
        <h1 className="t-large" style={{ margin: '6px 0 16px' }}>
          Review
        </h1>
        {tabs}
        <div className="card" style={{ padding: 8 }}>
          {listEl}
        </div>
        <ExpenseDetail id={openId ?? null} onClose={() => navigate('/review')} />
      </div>
    );
  }

  const org = selected ? state.orgs.find((o) => o.id === selected.orgId)! : null;
  const s = org ? orgSummary(state, org.id) : null;
  const canDecide = selected && (selected.status === 'pending' || selected.status === 'needs_info');

  return (
    <div className="page rise" style={{ maxWidth: 1320 }}>
      <PageHeader
        title="Review queue"
        subtitle="Approve receipts and checks — each decision updates the organization’s balance instantly."
        actions={
          <span className="t-cap faint row" style={{ gap: 6 }}>
            <span className="kbd">J</span>
            <span className="kbd">K</span> move · <span className="kbd">A</span> approve
          </span>
        }
      />
      <div className="review-grid">
        <div className="card" style={{ padding: 12, position: 'sticky', top: 84 }}>
          {tabs}
          <div style={{ maxHeight: 'calc(100dvh - 260px)', overflow: 'auto', margin: '0 -4px' }}>{listEl}</div>
        </div>
        {selected && org && s ? (
          <div className="card" style={{ padding: 24 }} key={selected.id}>
            <div className="row between" style={{ marginBottom: 20, alignItems: 'flex-start' }}>
              <div className="row" style={{ gap: 14 }}>
                <OrgBadge id={org.id} initials={org.initials} size={46} />
                <div>
                  <div className="t-title">{org.name}</div>
                  <div className="t-cap muted">
                    Submitted by {state.users.find((u) => u.id === selected.submittedBy)?.name} · {relativeTime(selected.submittedAt)}
                  </div>
                </div>
              </div>
              <StatusPill status={selected.status} />
            </div>
            <div className="review-detail-grid">
              <DocumentPreview src={selected.image} height={520} />
              <div className="col" style={{ gap: 18 }}>
                <div>
                  <div className="t-micro">{selected.docType === 'check' ? `Check${selected.checkNumber ? ` #${selected.checkNumber}` : ''}` : 'Receipt'}</div>
                  <div className="t-hero num" style={{ marginTop: 6 }}>
                    {usd(selected.amount)}
                  </div>
                  <div className="t-head" style={{ marginTop: 4 }}>
                    {selected.vendor}
                  </div>
                  <div className="muted t-cap" style={{ marginTop: 2 }}>
                    {selected.description}
                  </div>
                </div>
                <div className="inset" style={{ padding: '4px 14px' }}>
                  {[
                    ['Date', longDate(selected.date)],
                    ['Category', categoryById(selected.category).label],
                    ...(selected.tax !== undefined ? [['Tax', usd(selected.tax)]] : []),
                    ...(selected.memo ? [['Memo', selected.memo]] : []),
                    ['Read by OCR', selected.scanned?.length ? `${selected.scanned.length} fields` : 'Typed by officer'],
                  ].map(([k, v]) => (
                    <div key={k} className="row between" style={{ padding: '9px 0', borderBottom: '1px solid var(--hairline)' }}>
                      <span className="t-cap muted">{k}</span>
                      <span className="t-cap w-500">{v}</span>
                    </div>
                  ))}
                  {selected.items?.map((it, i) => (
                    <div key={i} className="row between" style={{ padding: '6px 0' }}>
                      <span className="t-cap">{it.name}</span>
                      <span className="t-cap num">{usd(it.amount)}</span>
                    </div>
                  ))}
                </div>
                <div className="card card-pad" style={{ boxShadow: 'none' }}>
                  <div className="t-micro">Budget impact</div>
                  <div className="row between" style={{ marginTop: 10 }}>
                    <span className="t-cap muted">{org.name} remaining</span>
                    <span className="w-600 num">{usd(s.remaining)}</span>
                  </div>
                  {canDecide && (
                    <div className="row between" style={{ marginTop: 6 }}>
                      <span className="t-cap muted">After approval</span>
                      <span className="w-600 num" style={{ color: s.remaining - selected.amount < 0 ? 'var(--red-text)' : 'var(--accent-text)' }}>
                        {usd(s.remaining - selected.amount)}
                      </span>
                    </div>
                  )}
                </div>
                {selected.reviewNote && (
                  <div className="t-cap inset" style={{ padding: 12 }}>
                    <span className="w-600">Note: </span>
                    {selected.reviewNote}
                  </div>
                )}
                {canDecide ? (
                  <div className="col" style={{ gap: 10, marginTop: 'auto' }}>
                    <textarea className="textarea" rows={2} placeholder="Note to the organization (needed to request documents or decline)" value={note} onChange={(e) => setNote(e.target.value)} />
                    <button className="btn btn-approve btn-lg btn-block" onClick={() => decide(selected, 'approved')}>
                      <CheckCircle size={20} weight="fill" /> Approve {usd(selected.amount)}
                    </button>
                    <div className="row" style={{ gap: 8 }}>
                      <button className="btn btn-tonal grow" onClick={() => decide(selected, 'needs_info')}>
                        Request documents
                      </button>
                      <button className="btn btn-danger grow" onClick={() => decide(selected, 'rejected')}>
                        Decline
                      </button>
                    </div>
                  </div>
                ) : (
                  <p className="t-cap muted">
                    Reviewed {selected.reviewedAt ? relativeTime(selected.reviewedAt) : ''} by {state.users.find((u) => u.id === selected.reviewedBy)?.name ?? 'Student Accounts'}.
                  </p>
                )}
              </div>
            </div>
          </div>
        ) : (
          <div className="card">
            <Empty icon={Tray} title="Select an expense" body="Pick something from the queue to see the receipt and decide." />
          </div>
        )}
      </div>
    </div>
  );
}

export function OrgsPage() {
  const { user } = useStore();
  const mobile = useIsMobile();
  const [creating, setCreating] = useState(false);
  return (
    <div className={mobile ? 'm-page stack-16 rise' : 'page rise'}>
      {mobile ? (
        <div className="row between" style={{ padding: '6px 0 4px' }}>
          <h1 className="t-large">Organizations</h1>
          <button className="btn btn-primary btn-sm" onClick={() => setCreating(true)}>
            <Plus size={16} weight="bold" /> New
          </button>
        </div>
      ) : (
        <PageHeader
          title="Organizations"
          subtitle="Budgets, balances and funding requests for every registered organization."
          actions={
            <button className="btn btn-primary" onClick={() => setCreating(true)}>
              <Plus size={18} weight="bold" /> New organization
            </button>
          }
        />
      )}
      {user!.role === 'platform' ? <PlatformOrgList /> : <OrgTable title="All organizations" />}
      {user!.role === 'accounts' && <TurnedOffOrgs />}
      <NewOrgModal open={creating} onClose={() => setCreating(false)} />
    </div>
  );
}

function TurnedOffOrgs() {
  const { state, dispatch, toast } = useStore();
  const off = state.orgs.filter((o) => !o.active).sort((a, b) => a.name.localeCompare(b.name));
  if (!off.length) return null;
  return (
    <div style={{ marginTop: 20 }}>
      <SectionCard title="Turned off">
        <div className="list" style={{ margin: '0 -4px' }}>
          {off.map((o) => (
            <div key={o.id} className="list-row" style={{ cursor: 'default' }}>
              <button className="row grow" style={{ gap: 12, minWidth: 0, opacity: 0.55, textAlign: 'left' }} onClick={() => navigate(`/orgs/${o.id}`)}>
                <OrgBadge id={o.id} initials={o.initials} size={40} />
                <span className="w-600 ellipsis">{o.name}</span>
              </button>
              <button
                className="btn btn-tonal btn-sm"
                onClick={() => {
                  dispatch({ type: 'org/update', id: o.id, patch: { active: true } });
                  toast({ title: `${o.name} is on again`, tone: 'info' });
                }}
              >
                Turn on
              </button>
            </div>
          ))}
        </div>
      </SectionCard>
    </div>
  );
}

function PlatformOrgList() {
  const { state, dispatch } = useStore();
  return (
    <section className="card" style={{ padding: '20px 8px 8px', overflowX: 'auto' }}>
      <table className="table">
        <thead>
          <tr>
            <th>Organization</th>
            <th>Login email</th>
            <th>Officers</th>
            <th>Advisor</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {state.orgs.map((o) => (
            <tr key={o.id}>
              <td>
                <span className="row" style={{ gap: 12 }}>
                  <OrgBadge id={o.id} initials={o.initials} size={34} />
                  <span className="w-600">{o.name}</span>
                </span>
              </td>
              <td className="t-cap">{o.email}</td>
              <td className="t-cap">{state.users.filter((u) => u.role === 'officer' && u.orgIds.includes(o.id)).map((u) => u.name).join(', ') || '—'}</td>
              <td className="t-cap">{state.users.find((u) => u.id === o.advisorId)?.name ?? '—'}</td>
              <td>
                <button className={`pill ${o.active ? 'pill-approved' : 'pill-neutral'}`} onClick={() => dispatch({ type: 'org/update', id: o.id, patch: { active: !o.active } })} title="Toggle access">
                  {o.active ? 'Active' : 'Suspended'}
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}

function NewOrgModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { state, dispatch, user, toast } = useStore();
  const advisors = state.users.filter((u) => u.role === 'advisor');
  const [f, setF] = useState({ name: '', email: '', cboard: '', advisorId: advisors[0]?.id ?? '', budget: '' });
  const [tried, setTried] = useState(false);
  const emailOk = f.email.toLowerCase().endsWith(`@${state.institution.domain}`);
  const valid = f.name.trim().length > 2 && emailOk && /^\d{5}$/.test(f.cboard);
  const create = () => {
    setTried(true);
    if (!valid) return;
    const id = f.name.toLowerCase().replace(/[^a-z0-9]+/g, '').slice(0, 12) + Math.random().toString(36).slice(2, 5);
    const initials = f.name.split(/\s+/).filter((w) => /^[A-Z]/.test(w)).map((w) => w[0]).join('').slice(0, 2) || f.name.slice(0, 2).toUpperCase();
    const org: Org = { id, name: f.name.trim(), initials, email: f.email.trim().toLowerCase(), cboard: f.cboard, advisorId: f.advisorId, term: state.institution.term, mission: 'Newly registered organization.', active: true, funding: { status: 'not_started' } };
    const amt = parseFloat(f.budget);
    dispatch({ type: 'org/create', org, allocation: amt > 0 ? { id: uid('al'), orgId: id, amount: amt, note: `${state.institution.term} allocation`, at: new Date().toISOString(), by: user!.id } : undefined });
    toast({ title: `${org.name} registered`, body: amt > 0 ? `${usd(amt)} allocated` : 'No budget allocated yet', tone: 'budget' });
    setF({ name: '', email: '', cboard: '', advisorId: advisors[0]?.id ?? '', budget: '' });
    setTried(false);
    onClose();
  };
  return (
    <Overlay
      open={open}
      onClose={onClose}
      title="Register an organization"
      subtitle="The organization signs in with its authorized Luther email."
      footer={
        <>
          <button className="btn btn-secondary" onClick={onClose}>
            Cancel
          </button>
          <button className="btn btn-primary" onClick={create}>
            Create organization
          </button>
        </>
      }
    >
      <div className="col" style={{ gap: 14 }}>
        <div className="field">
          <label className="field-label">Name</label>
          <input className="input" value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} placeholder="e.g. Photography Club" />
        </div>
        <div className="field">
          <label className="field-label">Organization email</label>
          <input className="input" value={f.email} onChange={(e) => setF({ ...f, email: e.target.value })} placeholder={`club@${state.institution.domain}`} />
          {tried && !emailOk && <span className="t-cap" style={{ color: 'var(--red-text)' }}>Must be a @{state.institution.domain} address.</span>}
        </div>
        <div className="grid-2" style={{ gap: 14 }}>
          <div className="field">
            <label className="field-label">C-board number</label>
            <input className="input mono" value={f.cboard} maxLength={5} onChange={(e) => setF({ ...f, cboard: e.target.value.replace(/\D/g, '') })} placeholder="48XXX" />
            {tried && !/^\d{5}$/.test(f.cboard) && <span className="t-cap" style={{ color: 'var(--red-text)' }}>Five digits.</span>}
          </div>
          <div className="field">
            <label className="field-label">Initial budget</label>
            <input className="input num" inputMode="decimal" value={f.budget} onChange={(e) => setF({ ...f, budget: e.target.value.replace(/[^0-9.]/g, '') })} placeholder="$0.00" />
          </div>
        </div>
        <div className="field">
          <label className="field-label">Faculty advisor</label>
          <select className="select" value={f.advisorId} onChange={(e) => setF({ ...f, advisorId: e.target.value })}>
            {advisors.map((a) => (
              <option key={a.id} value={a.id}>
                {a.name}
              </option>
            ))}
          </select>
        </div>
      </div>
    </Overlay>
  );
}

export function OrgDetailPage({ id }: { id: string }) {
  const { state, user, dispatch, toast } = useStore();
  const mobile = useIsMobile();
  const org = state.orgs.find((o) => o.id === id);
  const [adjust, setAdjust] = useState(false);
  const [open, setOpen] = useState<string | null>(null);
  const [amt, setAmt] = useState('');
  const [sign, setSign] = useState<1 | -1>(1);
  const [why, setWhy] = useState('');
  const [person, setPerson] = useState<User | 'new' | null>(null);
  if (!org) return <div className="page">Organization not found.</div>;
  const s = orgSummary(state, org.id);
  const exps = state.expenses.filter((e) => e.orgId === org.id).sort((a, b) => b.date.localeCompare(a.date));
  const isAccounts = user!.role === 'accounts';
  const officers = state.users.filter((u) => u.role === 'officer' && u.orgIds.includes(org.id));
  const advisor = state.users.find((u) => u.id === org.advisorId);

  const saveAdjust = () => {
    const v = parseFloat(amt);
    if (!(v > 0) || why.trim().length < 3) return;
    dispatch({ type: 'budget/adjust', allocation: { id: uid('al'), orgId: org.id, amount: sign * v, note: why.trim(), at: new Date().toISOString(), by: user!.id } });
    toast({ title: `${sign > 0 ? 'Added' : 'Removed'} ${usd(v)}`, body: `${org.name} now has ${usd(s.remaining + sign * v)} remaining`, tone: 'budget' });
    setAdjust(false);
    setAmt('');
    setWhy('');
  };

  return (
    <div className={mobile ? 'm-page stack-16 rise' : 'page rise'}>
      <button className="btn btn-ghost btn-sm" style={{ marginLeft: -12, marginBottom: 8 }} onClick={() => navigate(user!.role === 'advisor' ? '/advisor' : '/orgs')}>
        ← {user!.role === 'advisor' ? 'My organizations' : 'Organizations'}
      </button>
      <div className="row wrap" style={{ gap: 16, marginBottom: 24, justifyContent: 'space-between' }}>
        <div className="row" style={{ gap: 16 }}>
          <OrgBadge id={org.id} initials={org.initials} size={56} />
          <div>
            <h1 className="t-large">{org.name}</h1>
            <p className="muted">
              {org.term} · {officers.map((o) => o.name).join(', ')}
              {advisor ? ` · Advisor ${advisor.name}` : ''}
            </p>
          </div>
        </div>
        <div className="row wrap" style={{ gap: 8 }}>
          {user!.role === 'advisor' && <span className="pill pill-neutral">Read-only</span>}
          <ReportButtons org={org} />
          {isAccounts && (
            <button className="btn btn-primary" onClick={() => setAdjust(true)}>
              Adjust budget
            </button>
          )}
        </div>
      </div>
      <div className={mobile ? 'stack-16' : 'home-grid'}>
        <div className="stack-16">
          <section className="card card-pad-lg">
            <div style={{ display: 'grid', placeItems: 'center', paddingBottom: 20 }}>
              <BudgetRing allocated={s.allocated} approved={s.approved} pending={s.pending} size={230} stroke={17}>
                <div>
                  <div className="t-cap muted">Remaining</div>
                  <div className="num" style={{ fontSize: 36, fontWeight: 700, letterSpacing: '-0.03em', fontFamily: 'var(--font-display)' }}>
                    <AnimatedNumber value={s.remaining} />
                  </div>
                  <div className="t-cap muted">of {usd(s.allocated, { cents: false })}</div>
                </div>
              </BudgetRing>
            </div>
            <RingLegend available={s.available} pending={s.pending} approved={s.approved} />
          </section>
          {isAccounts && (
            <>
              <section className="card card-pad row between" style={{ gap: 12 }}>
                <span className="w-600">{org.active ? 'Club is on' : 'Club is off'}</span>
                <Toggle
                  on={org.active}
                  label="Club is on"
                  onChange={(v) => {
                    dispatch({ type: 'org/update', id: org.id, patch: { active: v } });
                    toast({ title: v ? `${org.name} is on` : `${org.name} is turned off`, tone: 'info' });
                  }}
                />
              </section>
              <SectionCard
                title="People"
                action={
                  <button className="btn btn-ghost btn-sm" onClick={() => setPerson('new')}>
                    <Plus size={14} weight="bold" /> Add
                  </button>
                }
              >
                <div className="list" style={{ margin: '0 -4px' }}>
                  {state.users
                    .filter((u) => u.active && u.role !== 'platform' && u.orgIds.includes(org.id))
                    .sort((a, b) => Number(a.role === 'advisor') - Number(b.role === 'advisor') || a.name.localeCompare(b.name))
                    .map((u) => (
                      <button key={u.id} className="list-row" onClick={() => setPerson(u)}>
                        <Avatar name={u.name} email={u.email} />
                        <span className="col grow" style={{ minWidth: 0 }}>
                          <span className="w-600 ellipsis">{u.name}</span>
                          <span className="t-cap muted ellipsis">{u.role === 'officer' ? u.title.split(' · ')[0] : ROLE_LABEL[u.role]}</span>
                        </span>
                        <CaretRight size={16} className="faint" />
                      </button>
                    ))}
                </div>
              </SectionCard>
              <PersonModal key={person === 'new' ? 'new' : person?.id ?? 'none'} person={person} presetOrg={org.id} onClose={() => setPerson(null)} />
            </>
          )}
          <CboardCard org={org} />
          <SectionCard title="Funding request">
            <div className="row between">
              <span className="t-cap muted">2027–28 annual request</span>
              <FundingPill org={org} />
            </div>
            {org.funding.requested && <p className="t-cap" style={{ marginTop: 8 }}>Requested {usd(org.funding.requested)} · {org.funding.submittedAt ? longDate(org.funding.submittedAt) : ''}</p>}
          </SectionCard>
        </div>
        <div className="stack-16">
          <SectionCard title="Spending by category">
            <CategoryBars rows={s.byCategory.map((c) => ({ ...c, label: categoryById(c.id).label }))} />
          </SectionCard>
          <SectionCard title={`Transactions (${exps.length})`}>
            <div className="list" style={{ margin: '0 -4px' }}>
              {exps.map((e) => (
                <ExpenseRow key={e.id} e={e} onClick={() => setOpen(e.id)} />
              ))}
              {!exps.length && <p className="t-cap muted">No transactions yet.</p>}
            </div>
          </SectionCard>
        </div>
      </div>
      <ExpenseDetail id={open} onClose={() => setOpen(null)} />
      <Overlay
        open={adjust}
        onClose={() => setAdjust(false)}
        title="Adjust budget"
        subtitle={`${org.name} · currently ${usd(s.allocated)} allocated`}
        footer={
          <>
            <button className="btn btn-secondary" onClick={() => setAdjust(false)}>
              Cancel
            </button>
            <button className="btn btn-primary" onClick={saveAdjust} disabled={!(parseFloat(amt) > 0) || why.trim().length < 3}>
              {sign > 0 ? 'Add funds' : 'Remove funds'}
            </button>
          </>
        }
      >
        <div className="col" style={{ gap: 14 }}>
          <div className="segmented" style={{ alignSelf: 'flex-start' }}>
            <button aria-pressed={sign === 1} onClick={() => setSign(1)}>
              <Plus size={13} weight="bold" /> Add funds
            </button>
            <button aria-pressed={sign === -1} onClick={() => setSign(-1)}>
              <Minus size={13} weight="bold" /> Remove funds
            </button>
          </div>
          <input className="input input-money" inputMode="decimal" placeholder="$0.00" value={amt ? `$${amt}` : ''} onChange={(e) => setAmt(e.target.value.replace(/[^0-9.]/g, ''))} autoFocus />
          <div className="field">
            <label className="field-label">Reason (the organization sees this)</label>
            <input className="input" value={why} onChange={(e) => setWhy(e.target.value)} placeholder="e.g. Supplemental funding — Spring speaker" />
          </div>
          {parseFloat(amt) > 0 && (
            <p className="t-cap muted">
              New remaining balance: <span className="w-600 num" style={{ color: 'var(--text)' }}>{usd(s.remaining + sign * parseFloat(amt))}</span>
            </p>
          )}
        </div>
      </Overlay>
    </div>
  );
}

export function ReportsPage() {
  const { state, user } = useStore();
  const mobile = useIsMobile();
  const orgs = user!.role === 'accounts' ? state.orgs : state.orgs.filter((o) => user!.orgIds.includes(o.id));
  const [orgId, setOrgId] = useState(orgs[0]?.id);
  const org = orgs.find((o) => o.id === orgId) ?? orgs[0];
  if (!org) return null;
  const s = orgSummary(state, org.id);
  const exps = state.expenses.filter((e) => e.orgId === org.id);

  return (
    <div className={mobile ? 'm-page stack-16 rise' : 'page rise'}>
      {mobile ? (
        <h1 className="t-large" style={{ margin: '6px 0 4px' }}>
          Reports
        </h1>
      ) : (
        <PageHeader
          title="Financial reports"
          subtitle="Generated automatically from approved records. Download as PDF for sharing or Excel for analysis."
          actions={
            user!.role === 'accounts' && (
              <button className="btn btn-secondary" onClick={() => downloadCampusXlsx(state)}>
                <DownloadSimple size={18} /> Campus-wide Excel
              </button>
            )
          }
        />
      )}
      <div style={{ display: 'grid', gridTemplateColumns: mobile ? '1fr' : '300px minmax(0,1fr)', gap: 20, alignItems: 'start' }}>
        <div className="card" style={{ padding: 8 }}>
          {orgs.map((o) => (
            <button key={o.id} className="list-row" style={{ minHeight: 56, padding: '8px 10px', background: o.id === org.id ? 'var(--accent-soft)' : undefined }} onClick={() => setOrgId(o.id)}>
              <OrgBadge id={o.id} initials={o.initials} size={34} />
              <span className="w-600 grow ellipsis">{o.name}</span>
              <CaretRight size={16} className="faint" />
            </button>
          ))}
        </div>
        <div className="card" style={{ padding: mobile ? 20 : 32 }}>
          <div className="row between wrap" style={{ gap: 12, marginBottom: 24 }}>
            <div>
              <div className="t-micro">Report preview</div>
              <h2 className="t-title" style={{ marginTop: 4 }}>
                {org.name} — {org.term}
              </h2>
              <p className="t-cap muted">As of {longDate(new Date().toISOString())}</p>
            </div>
            <ReportButtons org={org} />
          </div>
          <div className="grid-4" style={{ gap: 12 }}>
            {[
              ['Original budget', s.allocated],
              ['Approved expenses', s.approved],
              ['Remaining balance', s.remaining],
              ['Pending review', s.pending],
            ].map(([k, v]) => (
              <div key={k as string} className="inset" style={{ padding: 14 }}>
                <div className="t-micro">{k}</div>
                <div className="t-title num" style={{ marginTop: 6, color: k === 'Remaining balance' ? 'var(--accent-text)' : k === 'Pending review' ? 'var(--amber-text)' : undefined }}>
                  {usd(v as number)}
                </div>
              </div>
            ))}
          </div>
          <h3 className="t-head" style={{ margin: '28px 0 12px' }}>
            Expense breakdown
          </h3>
          <table className="table">
            <thead>
              <tr>
                <th>Category</th>
                <th className="r">Approved</th>
                <th className="r">Pending</th>
              </tr>
            </thead>
            <tbody>
              {s.byCategory
                .filter((c) => c.approved + c.pending > 0)
                .map((c) => (
                  <tr key={c.id}>
                    <td>{categoryById(c.id).label}</td>
                    <td className="r num">{usd(c.approved)}</td>
                    <td className="r num faint">{c.pending ? usd(c.pending) : '—'}</td>
                  </tr>
                ))}
            </tbody>
          </table>
          <h3 className="t-head" style={{ margin: '28px 0 12px' }}>
            Transactions
          </h3>
          <div className="list" style={{ margin: '0 -4px' }}>
            {exps.slice(0, 6).map((e) => (
              <ExpenseRow key={e.id} e={e} />
            ))}
          </div>
          {exps.length > 6 && <p className="t-cap muted" style={{ marginTop: 8 }}>+ {exps.length - 6} more in the full report</p>}
        </div>
      </div>
    </div>
  );
}

export function AnnouncementsPage() {
  const { state, user, dispatch, toast } = useStore();
  const mobile = useIsMobile();
  const [compose, setCompose] = useState(false);
  const [docOpen, setDocOpen] = useState(false);
  const [a, setA] = useState({ title: '', body: '', kind: 'info' as Announcement['kind'], audience: 'all' as 'all' | string[], dueDate: '', link: '', requiresAction: false });
  const [d, setD] = useState({ title: '', kind: 'form' as DocumentItem['kind'], summary: '', url: '' });

  const publish = () => {
    if (a.title.trim().length < 4 || a.body.trim().length < 4) return;
    const ann: Announcement = {
      id: uid('an'),
      title: a.title.trim(),
      body: a.body.trim(),
      kind: a.kind,
      audience: a.audience,
      dueDate: a.dueDate || undefined,
      link: a.link || undefined,
      linkLabel: a.link ? 'Open link' : undefined,
      requiresAction: a.requiresAction,
      createdAt: new Date().toISOString(),
      by: user!.id,
    };
    dispatch({ type: 'announcement/publish', announcement: ann });
    toast({ title: 'Announcement published', body: a.audience === 'all' ? 'Sent to every organization' : `Sent to ${a.audience.length} organization(s)`, tone: 'announcement' });
    setCompose(false);
    setA({ title: '', body: '', kind: 'info', audience: 'all', dueDate: '', link: '', requiresAction: false });
  };

  const addDoc = () => {
    if (d.title.trim().length < 3) return;
    dispatch({ type: 'document/add', document: { id: uid('doc'), title: d.title.trim(), kind: d.kind, summary: d.summary.trim() || 'Shared by Student Accounts', url: d.url || undefined, updatedAt: todayISO(), audience: 'all' } });
    toast({ title: 'Document shared', body: 'Every organization can see it in their Club tab.', tone: 'announcement' });
    setDocOpen(false);
    setD({ title: '', kind: 'form', summary: '', url: '' });
  };

  return (
    <div className={mobile ? 'm-page stack-16 rise' : 'page rise'}>
      {mobile ? (
        <div className="row between" style={{ padding: '6px 0 4px' }}>
          <h1 className="t-large">Announcements</h1>
          <button className="btn btn-primary btn-sm" onClick={() => setCompose(true)}>
            <Plus size={16} weight="bold" /> New
          </button>
        </div>
      ) : (
        <PageHeader
          title="Announcements"
          subtitle="Publish deadlines, funding forms and documents to every organization — or just the ones that need it."
          actions={
            <>
              <button className="btn btn-secondary" onClick={() => setDocOpen(true)}>
                <FileText size={18} /> Share document
              </button>
              <button className="btn btn-primary" onClick={() => setCompose(true)}>
                <Megaphone size={18} weight="fill" /> New announcement
              </button>
            </>
          }
        />
      )}
      <div className={mobile ? 'stack-16' : 'grid-2'} style={{ alignItems: 'start' }}>
        <SectionCard title="Published">
          <div className="list" style={{ margin: '0 -4px' }}>
            {state.announcements.map((x) => (
              <div key={x.id} className="list-row" style={{ alignItems: 'flex-start' }}>
                <span className="cat-icon">{x.kind === 'funding' ? <CalendarBlank size={20} /> : <Megaphone size={20} />}</span>
                <span className="col grow" style={{ minWidth: 0 }}>
                  <span className="w-600">{x.title}</span>
                  <span className="t-cap muted">{x.body}</span>
                  <span className="row wrap t-cap faint" style={{ gap: 10, marginTop: 6 }}>
                    <span className="row" style={{ gap: 4 }}>
                      <UsersThree size={13} /> {x.audience === 'all' ? 'All organizations' : `${x.audience.length} organizations`}
                    </span>
                    {x.dueDate && <span>Due {shortDate(x.dueDate)}</span>}
                    <span>{relativeTime(x.createdAt)}</span>
                  </span>
                </span>
              </div>
            ))}
          </div>
        </SectionCard>
        <div className="stack-16">
          <SectionCard title="Funding request progress">
            {state.orgs.map((o) => (
              <div key={o.id} className="row between" style={{ padding: '8px 0', borderBottom: '1px solid var(--hairline)' }}>
                <span className="row" style={{ gap: 10 }}>
                  <OrgBadge id={o.id} initials={o.initials} size={28} />
                  <span className="t-cap w-500">{o.name}</span>
                </span>
                <FundingPill org={o} />
              </div>
            ))}
          </SectionCard>
          <SectionCard title="Shared documents">
            <div className="list" style={{ margin: '0 -4px' }}>
              {state.documents.map((x) => (
                <div key={x.id} className="list-row" style={{ minHeight: 52 }}>
                  <span className="cat-icon" style={{ width: 36, height: 36 }}>
                    {x.url ? <LinkSimple size={18} /> : <FileText size={18} />}
                  </span>
                  <span className="col grow" style={{ minWidth: 0 }}>
                    <span className="w-600 ellipsis">{x.title}</span>
                    <span className="t-cap muted ellipsis">{x.summary}</span>
                  </span>
                </div>
              ))}
            </div>
          </SectionCard>
        </div>
      </div>

      <Overlay
        open={compose}
        onClose={() => setCompose(false)}
        title="New announcement"
        subtitle="Officers get a notification right away."
        footer={
          <>
            <button className="btn btn-secondary" onClick={() => setCompose(false)}>
              Cancel
            </button>
            <button className="btn btn-primary" onClick={publish} disabled={a.title.trim().length < 4 || a.body.trim().length < 4}>
              Publish
            </button>
          </>
        }
      >
        <div className="col" style={{ gap: 14 }}>
          <div className="segmented" style={{ alignSelf: 'flex-start' }}>
            {(
              [
                ['info', 'Update'],
                ['deadline', 'Deadline'],
                ['funding', 'Funding form'],
              ] as const
            ).map(([k, l]) => (
              <button key={k} aria-pressed={a.kind === k} onClick={() => setA({ ...a, kind: k, requiresAction: k !== 'info' })}>
                {l}
              </button>
            ))}
          </div>
          <div className="field">
            <label className="field-label">Title</label>
            <input className="input" value={a.title} onChange={(e) => setA({ ...a, title: e.target.value })} placeholder="e.g. Spring receipts due December 12" />
          </div>
          <div className="field">
            <label className="field-label">Message</label>
            <textarea className="textarea" value={a.body} onChange={(e) => setA({ ...a, body: e.target.value })} placeholder="What do organizations need to know or do?" />
          </div>
          <div className="grid-2" style={{ gap: 14 }}>
            <div className="field">
              <label className="field-label">Due date (optional)</label>
              <input type="date" className="input" value={a.dueDate} onChange={(e) => setA({ ...a, dueDate: e.target.value })} />
            </div>
            <div className="field">
              <label className="field-label">Link (optional)</label>
              <input className="input" value={a.link} onChange={(e) => setA({ ...a, link: e.target.value })} placeholder="https://forms.google.com/…" />
            </div>
          </div>
          <div className="field">
            <span className="field-label">Send to</span>
            <div className="row wrap" style={{ gap: 8 }}>
              <button className="chip" aria-pressed={a.audience === 'all'} onClick={() => setA({ ...a, audience: 'all' })}>
                All organizations
              </button>
              {state.orgs.map((o) => {
                const on = a.audience !== 'all' && a.audience.includes(o.id);
                return (
                  <button
                    key={o.id}
                    className="chip"
                    aria-pressed={on}
                    onClick={() => {
                      const cur = a.audience === 'all' ? [] : a.audience;
                      const next = on ? cur.filter((x) => x !== o.id) : [...cur, o.id];
                      setA({ ...a, audience: next.length ? next : 'all' });
                    }}
                  >
                    {o.name}
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      </Overlay>

      <Overlay
        open={docOpen}
        onClose={() => setDocOpen(false)}
        title="Share a document"
        subtitle="Forms, policies and guides appear in every organization’s Club tab."
        footer={
          <>
            <button className="btn btn-secondary" onClick={() => setDocOpen(false)}>
              Cancel
            </button>
            <button className="btn btn-primary" onClick={addDoc} disabled={d.title.trim().length < 3}>
              Share
            </button>
          </>
        }
      >
        <div className="col" style={{ gap: 14 }}>
          <div className="field">
            <label className="field-label">Title</label>
            <input className="input" value={d.title} onChange={(e) => setD({ ...d, title: e.target.value })} placeholder="e.g. Spring 2027 reimbursement form" />
          </div>
          <div className="field">
            <label className="field-label">Type</label>
            <select className="select" value={d.kind} onChange={(e) => setD({ ...d, kind: e.target.value as DocumentItem['kind'] })}>
              <option value="form">Form</option>
              <option value="policy">Policy</option>
              <option value="guide">Guide</option>
              <option value="template">Template</option>
            </select>
          </div>
          <div className="field">
            <label className="field-label">Short description</label>
            <input className="input" value={d.summary} onChange={(e) => setD({ ...d, summary: e.target.value })} />
          </div>
          <div className="field">
            <label className="field-label">Link to the file or Google Form</label>
            <input className="input" value={d.url} onChange={(e) => setD({ ...d, url: e.target.value })} placeholder="https://…" />
          </div>
        </div>
      </Overlay>
    </div>
  );
}

export { DocumentPreview, RingLegend, CATEGORIES };
