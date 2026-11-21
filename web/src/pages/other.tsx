import { useState } from 'react';
import { ArrowRight, Plus, ShieldCheck, ArrowCounterClockwise, Sparkle, Globe, Database, MagnifyingGlass, CaretRight, Check } from '@phosphor-icons/react';
import type { AppState, Role, User } from '../../../shared/types.ts';
import { orgSummary, ROLE_LABEL, usd, uid, relativeTime } from '../../../shared/money.ts';
import { navigate, useIsMobile, useStore } from '../store.tsx';
import { Avatar, BudgetRing, OrgBadge, Overlay } from '../ui/kit.tsx';
import { ExpenseRow, ReportButtons, SectionCard } from './common.tsx';
import { PageHeader, SyncChip } from '../app/Shell.tsx';

export function AdvisorHome() {
  const { state, user } = useStore();
  const mobile = useIsMobile();
  const orgs = state.orgs.filter((o) => user!.orgIds.includes(o.id));
  const recent = state.expenses.filter((e) => user!.orgIds.includes(e.orgId)).sort((a, b) => b.submittedAt.localeCompare(a.submittedAt)).slice(0, 6);
  return (
    <div className={mobile ? 'm-page stack-16 rise' : 'page rise'}>
      {mobile ? (
        <div style={{ padding: '6px 0 4px' }}>
          <h1 className="t-large">My organizations</h1>
          <p className="muted">Read-only · {orgs.length} organizations</p>
        </div>
      ) : (
        <PageHeader title={`Hello, ${user!.name.replace(/^(Prof\.|Dr\.)\s+/, '').split(' ')[0]}`} subtitle={`You advise ${orgs.length} organizations. You can see their budgets, receipts and reports — only Student Accounts can approve spending.`} />
      )}
      <div className={mobile ? 'stack-16' : 'grid-2'} style={{ marginBottom: 20 }}>
        {orgs.map((o) => {
          const s = orgSummary(state, o.id);
          return (
            <section key={o.id} className="card card-pad-lg">
              <div className="row between">
                <div className="row" style={{ gap: 12 }}>
                  <OrgBadge id={o.id} initials={o.initials} />
                  <div>
                    <div className="t-head">{o.name}</div>
                    <div className="t-cap muted">{o.term}</div>
                  </div>
                </div>
                <span className="pill pill-neutral">Read-only</span>
              </div>
              <div className="row" style={{ gap: 24, marginTop: 20, alignItems: 'center' }}>
                <BudgetRing allocated={s.allocated} approved={s.approved} pending={s.pending} size={128} stroke={12}>
                  <div className="t-cap w-600 num">{Math.round((s.remaining / Math.max(1, s.allocated)) * 100)}%</div>
                </BudgetRing>
                <div className="col grow" style={{ gap: 8 }}>
                  {[
                    ['Remaining', usd(s.remaining), 'var(--text)'],
                    ['Approved', usd(s.approved), 'var(--text-2)'],
                    ['Pending', usd(s.pending), 'var(--amber-text)'],
                  ].map(([k, v, c]) => (
                    <div key={k} className="row between">
                      <span className="t-cap muted">{k}</span>
                      <span className="w-600 num" style={{ color: c }}>
                        {v}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
              <div className="row between wrap" style={{ marginTop: 20, gap: 10 }}>
                <ReportButtons org={o} size="sm" />
                <button className="btn btn-tonal btn-sm" onClick={() => navigate(`/orgs/${o.id}`)}>
                  Open <ArrowRight size={14} />
                </button>
              </div>
            </section>
          );
        })}
      </div>
      <SectionCard title="Latest activity">
        <div className="list" style={{ margin: '0 -4px' }}>
          {recent.map((e) => (
            <ExpenseRow key={e.id} e={e} showOrg onClick={() => navigate(`/activity/${e.id}`)} />
          ))}
        </div>
      </SectionCard>
    </div>
  );
}

const ASSIGNABLE: Role[] = ['officer', 'advisor', 'accounts'];
const ROLE_SHORT: Record<Role, string> = { officer: 'Officer', advisor: 'Advisor', accounts: 'Student Accounts', platform: 'Admin' };
const ROLE_PLURAL: Record<Role, string> = { officer: 'Officers', advisor: 'Advisors', accounts: 'Student Accounts', platform: 'Admins' };
const ROLE_PILL: Record<Role, string> = { officer: 'pill-neutral', accounts: 'pill-needs_info', advisor: 'pill-pending', platform: 'pill-approved' };

const clubsOf = (state: AppState, u: User) =>
  u.orgIds.map((id) => state.orgs.find((o) => o.id === id)?.name).filter(Boolean).join(', ');

const personLine = (state: AppState, u: User) => {
  const clubs = clubsOf(state, u);
  if (u.role === 'officer') return [u.title.split(' · ')[0] || 'Officer', clubs].filter(Boolean).join(' · ');
  if (u.role === 'advisor') return clubs ? `Advisor · ${clubs}` : 'Advisor';
  return ROLE_SHORT[u.role];
};

export function UsersPage() {
  const { state, dispatch, toast } = useStore();
  const mobile = useIsMobile();
  const [editing, setEditing] = useState<User | 'new' | null>(null);
  const [q, setQ] = useState('');
  const [filter, setFilter] = useState<Role | 'all'>('all');
  const people = state.users.filter((u) => u.role !== 'platform');
  const current = people.filter((u) => u.active);
  const removed = people.filter((u) => !u.active).sort((a, b) => a.name.localeCompare(b.name));
  const list = current
    .filter((u) => filter === 'all' || u.role === filter)
    .filter((u) => !q || `${u.name} ${u.email} ${clubsOf(state, u)}`.toLowerCase().includes(q.toLowerCase()))
    .sort((a, b) => a.name.localeCompare(b.name));

  const restore = (u: User) => {
    dispatch({ type: 'user/update', id: u.id, patch: { active: true } });
    toast({ title: `${u.name} can sign in again`, tone: 'info' });
  };

  const addButton = (
    <button className={`btn btn-primary${mobile ? ' btn-sm' : ''}`} onClick={() => setEditing('new')}>
      <Plus size={mobile ? 16 : 18} weight="bold" /> Add person
    </button>
  );

  return (
    <div className={mobile ? 'm-page stack-16 rise' : 'page rise'}>
      {mobile ? (
        <div className="row between" style={{ padding: '6px 0 4px' }}>
          <h1 className="t-large">People</h1>
          {addButton}
        </div>
      ) : (
        <PageHeader title="People" actions={addButton} />
      )}

      <div className="row wrap" style={{ gap: 10, marginBottom: mobile ? 0 : 16 }}>
        <div style={{ overflowX: 'auto', maxWidth: '100%', scrollbarWidth: 'none' }}>
          <div className="segmented">
            {(['all', ...ASSIGNABLE] as const).map((r) => (
              <button key={r} aria-pressed={filter === r} onClick={() => setFilter(r)}>
                {r === 'all' ? 'All' : ROLE_PLURAL[r]}
                <span className="faint num" style={{ marginLeft: 5 }}>
                  {r === 'all' ? current.length : current.filter((u) => u.role === r).length}
                </span>
              </button>
            ))}
          </div>
        </div>
        <div className="grow" />
        <label className="row" style={{ position: 'relative', width: mobile ? '100%' : 260 }}>
          <MagnifyingGlass size={18} className="faint" style={{ position: 'absolute', left: 13 }} />
          <input className="input" style={{ height: 40, paddingLeft: 38 }} placeholder="Search people or clubs" value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search people" />
        </label>
      </div>

      {mobile ? (
        <SectionCard title={`${list.length} ${list.length === 1 ? 'person' : 'people'}`}>
          <div className="list" style={{ margin: '0 -4px' }}>
            {list.map((u) => (
              <button key={u.id} className="list-row" onClick={() => setEditing(u)}>
                <Avatar name={u.name} email={u.email} />
                <span className="col grow" style={{ minWidth: 0 }}>
                  <span className="w-600 ellipsis">{u.name}</span>
                  <span className="t-cap muted ellipsis">{personLine(state, u)}</span>
                </span>
                <CaretRight size={16} className="faint" />
              </button>
            ))}
          </div>
        </SectionCard>
      ) : (
        <section className="card" style={{ padding: '12px 8px 8px', overflowX: 'auto' }}>
          <table className="table">
            <thead>
              <tr>
                <th>Person</th>
                <th>Role</th>
                <th>Club</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {list.map((u) => (
                <tr key={u.id} className="clickable" onClick={() => setEditing(u)}>
                  <td>
                    <span className="row" style={{ gap: 12 }}>
                      <Avatar name={u.name} email={u.email} />
                      <span className="col" style={{ minWidth: 0 }}>
                        <span className="w-600">{u.name}</span>
                        <span className="t-cap faint">{u.email}</span>
                      </span>
                    </span>
                  </td>
                  <td>
                    <span className={`pill ${ROLE_PILL[u.role]}`}>{ROLE_SHORT[u.role]}</span>
                  </td>
                  <td className="t-cap">{u.role === 'officer' ? personLine(state, u) : clubsOf(state, u) || '—'}</td>
                  <td className="r">
                    <span className="btn btn-ghost btn-sm">Edit</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {!list.length && <p className="t-cap muted" style={{ padding: '12px 16px' }}>No one matches.</p>}
        </section>
      )}

      {removed.length > 0 && (
        <div style={{ marginTop: mobile ? 0 : 20 }}>
          <SectionCard title="Removed">
            <div className="list" style={{ margin: '0 -4px' }}>
              {removed.map((u) => (
                <div key={u.id} className="list-row" style={{ cursor: 'default' }}>
                  <span style={{ opacity: 0.5 }}>
                    <Avatar name={u.name} email={u.email} />
                  </span>
                  <span className="col grow" style={{ minWidth: 0, opacity: 0.55 }}>
                    <span className="w-600 ellipsis">{u.name}</span>
                    <span className="t-cap muted ellipsis">{personLine(state, u)}</span>
                  </span>
                  <button className="btn btn-tonal btn-sm" onClick={() => restore(u)}>
                    Restore
                  </button>
                </div>
              ))}
            </div>
          </SectionCard>
        </div>
      )}

      <PersonModal key={editing === 'new' ? 'new' : editing?.id ?? 'none'} person={editing} onClose={() => setEditing(null)} />
    </div>
  );
}

const POSITIONS = ['President', 'Treasurer', 'Vice President', 'Secretary', 'Officer'];

export function PersonModal({ person, presetOrg, onClose }: { person: User | 'new' | null; presetOrg?: string; onClose: () => void }) {
  const { state, user: me, dispatch, toast } = useStore();
  const existing = person && person !== 'new' ? person : null;
  const firstOrg = presetOrg ?? state.orgs[0]?.id ?? '';
  const [f, setF] = useState(() => ({
    name: existing?.name ?? '',
    email: existing?.email ?? '',
    role: (existing && existing.role !== 'platform' ? existing.role : 'officer') as Role,
    orgId: existing?.role === 'officer' ? existing.orgIds[0] ?? firstOrg : firstOrg,
    title: existing?.role === 'officer' ? existing.title.split(' · ')[0] || 'Officer' : 'Treasurer',
    advises: existing?.role === 'advisor' ? existing.orgIds : presetOrg ? [presetOrg] : [],
  }));
  const [tried, setTried] = useState(false);
  const [confirmRemove, setConfirmRemove] = useState(false);
  const isSelf = existing?.id === me?.id;
  const email = f.email.trim().toLowerCase();
  const emailOk = !!existing || (email.endsWith(`@${state.institution.domain}`) && email.length > state.institution.domain.length + 1);
  const exists = !existing && state.users.some((u) => u.email.toLowerCase() === email);
  const valid = f.name.trim().length >= 3 && emailOk && !exists && (f.role !== 'officer' || !!f.orgId) && (f.role !== 'advisor' || f.advises.length > 0);

  const save = () => {
    setTried(true);
    if (!valid) return;
    const orgIds = f.role === 'officer' ? [f.orgId] : f.role === 'advisor' ? state.orgs.map((o) => o.id).filter((id) => f.advises.includes(id)) : [];
    const org = state.orgs.find((o) => o.id === f.orgId);
    const title = f.role === 'officer' ? `${f.title} · ${org?.name ?? ''}` : f.role === 'advisor' ? 'Faculty advisor' : 'Student Accounts';
    const id = existing?.id ?? uid('u');
    if (existing) {
      dispatch({ type: 'user/update', id, patch: { name: f.name.trim(), role: f.role, title, orgIds } });
      toast({ title: `Saved ${f.name.trim()}`, body: ROLE_SHORT[f.role], tone: 'info' });
    } else {
      dispatch({ type: 'user/create', user: { id, name: f.name.trim(), email, role: f.role, title, orgIds, active: true } });
      toast({ title: `Added ${f.name.trim()}`, body: `${ROLE_SHORT[f.role]}${org && f.role === 'officer' ? ` · ${org.name}` : ''}`, tone: 'info' });
    }
    if (f.role === 'advisor') {
      for (const orgId of orgIds) {
        if (state.orgs.find((o) => o.id === orgId)?.advisorId !== id) dispatch({ type: 'org/update', id: orgId, patch: { advisorId: id } });
      }
    }
    onClose();
  };

  const remove = () => {
    if (!existing) return;
    dispatch({ type: 'user/update', id: existing.id, patch: { active: false } });
    toast({ title: `${existing.name} was removed`, body: 'Restore them any time from the Removed list.', tone: 'info' });
    setConfirmRemove(false);
    onClose();
  };

  return (
    <Overlay
      open={!!person}
      onClose={onClose}
      title={existing ? 'Edit person' : 'Add person'}
      footer={
        <>
          {existing && !isSelf && (
            <button className="btn btn-danger" style={{ marginRight: 'auto' }} onClick={() => (confirmRemove ? remove() : setConfirmRemove(true))}>
              {confirmRemove ? 'Yes, remove' : 'Remove'}
            </button>
          )}
          <button className="btn btn-secondary" onClick={onClose}>
            Cancel
          </button>
          <button className="btn btn-primary" onClick={save}>
            {existing ? 'Save' : 'Add'}
          </button>
        </>
      }
    >
      <div className="col" style={{ gap: 14 }}>
        <div className="field">
          <label className="field-label">Full name</label>
          <input className="input" value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} />
          {tried && f.name.trim().length < 3 && <span className="t-cap" style={{ color: 'var(--red-text)' }}>Enter their full name.</span>}
        </div>
        <div className="field">
          <label className="field-label">Luther email</label>
          {existing ? (
            <span className="muted" style={{ padding: '4px 0' }}>
              {existing.email}
            </span>
          ) : (
            <>
              <input className="input" value={f.email} onChange={(e) => setF({ ...f, email: e.target.value })} placeholder={`name@${state.institution.domain}`} />
              {tried && !emailOk && <span className="t-cap" style={{ color: 'var(--red-text)' }}>Use a @{state.institution.domain} address.</span>}
              {tried && exists && <span className="t-cap" style={{ color: 'var(--red-text)' }}>That person already has an account.</span>}
            </>
          )}
        </div>
        <div className="field">
          <span className="field-label">Role</span>
          <div className="segmented" style={{ flexWrap: 'wrap' }}>
            {ASSIGNABLE.map((r) => (
              <button key={r} aria-pressed={f.role === r} disabled={isSelf} onClick={() => setF({ ...f, role: r })}>
                {ROLE_SHORT[r]}
              </button>
            ))}
          </div>
        </div>
        {f.role === 'officer' && (
          <div className="grid-2" style={{ gap: 14 }}>
            <div className="field">
              <label className="field-label">Club</label>
              <select className="select" value={f.orgId} onChange={(e) => setF({ ...f, orgId: e.target.value })}>
                {state.orgs.map((o) => (
                  <option key={o.id} value={o.id}>
                    {o.name}
                  </option>
                ))}
              </select>
            </div>
            <div className="field">
              <label className="field-label">Position</label>
              <select className="select" value={f.title} onChange={(e) => setF({ ...f, title: e.target.value })}>
                {(POSITIONS.includes(f.title) ? POSITIONS : [f.title, ...POSITIONS]).map((t) => (
                  <option key={t}>{t}</option>
                ))}
              </select>
            </div>
          </div>
        )}
        {f.role === 'advisor' && (
          <div className="field">
            <span className="field-label">Advises</span>
            <div className="row wrap" style={{ gap: 8 }}>
              {state.orgs.map((o) => {
                const on = f.advises.includes(o.id);
                return (
                  <button key={o.id} className="chip" aria-pressed={on} onClick={() => setF({ ...f, advises: on ? f.advises.filter((x) => x !== o.id) : [...f.advises, o.id] })}>
                    {on && <Check size={14} weight="bold" />} {o.name}
                  </button>
                );
              })}
            </div>
            {tried && !f.advises.length && <span className="t-cap" style={{ color: 'var(--red-text)' }}>Pick at least one club.</span>}
          </div>
        )}
      </div>
    </Overlay>
  );
}

export function SettingsPage() {
  const { state, user, theme, setTheme, dispatch, sync, aiEngine, signOut, toast } = useStore();
  const mobile = useIsMobile();
  const [confirm, setConfirm] = useState(false);
  const isPlatform = user!.role === 'accounts' || user!.role === 'platform';
  return (
    <div className={mobile ? 'm-page stack-16 rise' : 'page page-narrow rise'}>
      {mobile ? <h1 className="t-large" style={{ margin: '6px 0 4px' }}>Settings</h1> : <PageHeader title="Settings" subtitle={isPlatform ? 'Your account and FairShare settings for Luther College.' : 'Your account and preferences.'} />}
      <div className="stack-16">
        <SectionCard title="Account">
          <div className="row" style={{ gap: 14 }}>
            <Avatar name={user!.name} email={user!.email} size={52} />
            <div className="col grow">
              <span className="t-head">{user!.name}</span>
              <span className="t-cap muted">
                {user!.email} · {ROLE_LABEL[user!.role]}
              </span>
            </div>
            <button className="btn btn-secondary btn-sm" onClick={signOut}>
              Sign out
            </button>
          </div>
        </SectionCard>
        <SectionCard title="Appearance">
          <div className="segmented">
            {(['system', 'light', 'dark'] as const).map((t) => (
              <button key={t} aria-pressed={theme === t} onClick={() => setTheme(t)}>
                {t === 'system' ? 'Match device' : t === 'light' ? 'Light' : 'Dark'}
              </button>
            ))}
          </div>
        </SectionCard>
        {isPlatform && (
          <SectionCard title="Institution">
            <div className="col" style={{ gap: 12 }}>
              {[
                [Globe, 'Sign-in domain', `@${state.institution.domain} · Luther single sign-on`],
                [ShieldCheck, 'Data isolation', 'Each organization can only see its own finances'],
                [Database, 'Term', state.institution.term],
              ].map(([I, k, v]) => {
                const Ico = I as typeof Globe;
                return (
                  <div key={k as string} className="row" style={{ gap: 12 }}>
                    <span className="cat-icon" style={{ width: 38, height: 38 }}>
                      <Ico size={18} />
                    </span>
                    <span className="col">
                      <span className="w-600" style={{ fontSize: 14 }}>
                        {k as string}
                      </span>
                      <span className="t-cap muted">{v as string}</span>
                    </span>
                  </div>
                );
              })}
              <label className="row between" style={{ padding: '10px 0', borderTop: '1px solid var(--hairline)' }}>
                <span className="row" style={{ gap: 12 }}>
                  <span className="cat-icon" style={{ width: 38, height: 38 }}>
                    <Sparkle size={18} />
                  </span>
                  <span className="col">
                    <span className="w-600" style={{ fontSize: 14 }}>
                      AI financial assistant
                    </span>
                    <span className="t-cap muted">Officers can ask questions about their budget</span>
                  </span>
                </span>
                <Toggle on={state.institution.aiEnabled} onChange={(v) => dispatch({ type: 'settings/update', patch: { aiEnabled: v } })} label="AI assistant" />
              </label>
            </div>
          </SectionCard>
        )}
        <SectionCard title="Sync & demo data">
          <div className="row between wrap" style={{ gap: 10 }}>
            <span className="t-cap muted" style={{ maxWidth: 420 }}>
              {sync === 'live'
                ? `Connected to the FairShare server. Changes appear instantly on every device. Assistant: ${aiEngine === 'claude' ? 'Claude' : 'offline engine'}.`
                : 'Running without the sync server — data stays in this browser and syncs between its tabs.'}
            </span>
            <SyncChip />
          </div>
          <hr className="divider" style={{ margin: '16px 0' }} />
          <div className="row between wrap" style={{ gap: 10 }}>
            <span className="t-cap muted">Restore the original demo data (Up to Us at $600, nothing approved).</span>
            <button className="btn btn-danger btn-sm" onClick={() => setConfirm(true)}>
              <ArrowCounterClockwise size={16} /> Reset demo
            </button>
          </div>
          <p className="t-cap faint" style={{ marginTop: 10 }}>Last change {relativeTime(state.updatedAt)} · version {state.version}</p>
        </SectionCard>
      </div>
      <Overlay
        open={confirm}
        onClose={() => setConfirm(false)}
        title="Reset demo data?"
        subtitle="Every expense, approval and announcement made during the demo will be removed for all connected devices."
        footer={
          <>
            <button className="btn btn-secondary" onClick={() => setConfirm(false)}>
              Cancel
            </button>
            <button
              className="btn btn-danger"
              onClick={() => {
                dispatch({ type: 'demo/reset' });
                setConfirm(false);
                toast({ title: 'Demo data restored', tone: 'info' });
              }}
            >
              Reset
            </button>
          </>
        }
      >
        <span />
      </Overlay>
    </div>
  );
}

export function Toggle({ on, onChange, label }: { on: boolean; onChange: (v: boolean) => void; label: string }) {
  return (
    <button
      role="switch"
      aria-checked={on}
      aria-label={label}
      onClick={() => onChange(!on)}
      style={{ width: 51, height: 31, borderRadius: 16, background: on ? 'var(--green)' : 'var(--surface-3)', position: 'relative', transition: 'background-color 200ms', flexShrink: 0 }}
    >
      <span style={{ position: 'absolute', top: 2, left: on ? 22 : 2, width: 27, height: 27, borderRadius: 14, background: '#fff', boxShadow: '0 2px 6px rgba(0,0,0,0.2)', transition: 'left 240ms var(--ease)' }} />
    </button>
  );
}
