import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import {
  CheckCircle,
  Clock,
  WarningCircle,
  XCircle,
  PaperPlaneTilt,
  Paperclip,
  LockSimple,
  Eye,
  ArrowSquareOut,
  FilePdf,
  FileXls,
  CalendarBlank,
  MagnifyingGlassPlus,
  Receipt as ReceiptIcon,
  Money,
  Sparkle,
  CircleNotch,
} from '@phosphor-icons/react';
import type { Expense, ExpenseEvent, Org } from '../../../shared/types.ts';
import { categoryById, daysUntil, longDate, orgSummary, relativeTime, shortDate, usd, canSeeCboard } from '../../../shared/money.ts';
import { navigate, todayISO, useIsMobile, useStore } from '../store.tsx';
import { CategoryIcon, Overlay, StatusPill } from '../ui/kit.tsx';
import { downscale, isPdf } from '../lib/image.ts';
import { downloadPdf, downloadXlsx } from '../lib/reports.ts';

export function ExpenseRow({ e, showOrg, onClick }: { e: Expense; showOrg?: boolean; onClick?: () => void }) {
  const { state } = useStore();
  const org = showOrg ? state.orgs.find((o) => o.id === e.orgId) : null;
  return (
    <button className="list-row" onClick={onClick}>
      <CategoryIcon id={e.category} />
      <span className="col grow" style={{ minWidth: 0 }}>
        <span className="w-600 ellipsis">{e.vendor}</span>
        <span className="t-cap muted ellipsis">
          {org ? `${org.name} · ` : ''}
          {e.description}
        </span>
      </span>
      <span className="col" style={{ alignItems: 'flex-end', gap: 4, flexShrink: 0 }}>
        <span className="w-600 num" style={{ textDecoration: e.status === 'rejected' ? 'line-through' : undefined, color: e.status === 'rejected' ? 'var(--text-3)' : undefined }}>
          {usd(e.amount)}
        </span>
        <span className="row" style={{ gap: 6 }}>
          <span className="t-cap faint hide-mobile">{shortDate(e.date)}</span>
          <StatusPill status={e.status} short />
        </span>
      </span>
    </button>
  );
}

export function DocumentPreview({ src, height = 420, scanning }: { src?: string; height?: number | string; scanning?: boolean }) {
  const [zoom, setZoom] = useState(false);
  if (!src)
    return (
      <div className="receipt-frame" style={{ height, color: 'var(--text-3)' }}>
        <div className="col" style={{ alignItems: 'center', gap: 8 }}>
          <ReceiptIcon size={32} />
          <span className="t-cap">No document attached</span>
        </div>
      </div>
    );
  if (isPdf(src))
    return (
      <div className="receipt-frame" style={{ height }}>
        <object data={src} type="application/pdf" style={{ width: '100%', height: '100%' }}>
          <a href={src} target="_blank" rel="noreferrer" className="btn btn-secondary">
            Open PDF
          </a>
        </object>
      </div>
    );
  return (
    <>
      <div className="receipt-frame" style={{ height, padding: 16, cursor: 'zoom-in' }} onClick={() => setZoom(true)}>
        <img src={src} alt="Uploaded document" style={{ maxHeight: '100%', borderRadius: 6 }} />
        {scanning && <div className="scan-line" />}
        {!scanning && (
          <span className="row t-cap" style={{ position: 'absolute', right: 10, bottom: 10, gap: 4, background: 'var(--surface)', padding: '4px 8px', borderRadius: 8, boxShadow: 'var(--shadow-1)' }}>
            <MagnifyingGlassPlus size={14} /> Zoom
          </span>
        )}
      </div>
      {zoom && createPortal(
        <>
          <div className="scrim" style={{ zIndex: 500 }} onClick={() => setZoom(false)} />
          <img
            src={src}
            alt="Document full size"
            onClick={() => setZoom(false)}
            style={{ position: 'fixed', zIndex: 501, inset: 0, margin: 'auto', maxWidth: '92vw', maxHeight: '92dvh', borderRadius: 10, boxShadow: 'var(--shadow-3)', cursor: 'zoom-out', animation: 'pop 300ms var(--ease)' }}
          />
        </>,
        document.body,
      )}
    </>
  );
}

const EVENT_META: Record<ExpenseEvent['action'], { label: string; icon: typeof CheckCircle; color: string }> = {
  submitted: { label: 'Submitted', icon: PaperPlaneTilt, color: 'var(--text-2)' },
  approved: { label: 'Approved', icon: CheckCircle, color: 'var(--green)' },
  rejected: { label: 'Not approved', icon: XCircle, color: 'var(--red)' },
  needs_info: { label: 'More documentation requested', icon: WarningCircle, color: 'var(--accent)' },
  documented: { label: 'Documentation added', icon: Paperclip, color: 'var(--text-2)' },
  edited: { label: 'Edited', icon: Clock, color: 'var(--text-2)' },
};

function Timeline({ e }: { e: Expense }) {
  const { state } = useStore();
  const events = [...e.history];
  return (
    <div className="col" style={{ gap: 0 }}>
      {events.map((ev, i) => {
        const m = EVENT_META[ev.action];
        const I = m.icon;
        const who = state.users.find((u) => u.id === ev.by)?.name ?? 'Someone';
        return (
          <div key={i} className="row" style={{ alignItems: 'flex-start', gap: 12, paddingBottom: 14, position: 'relative' }}>
            <span style={{ color: m.color, marginTop: 1, position: 'relative', zIndex: 1, background: 'var(--surface)' }}>
              <I size={20} weight="fill" />
            </span>
            {(i < events.length - 1 || e.status === 'pending') && <span style={{ position: 'absolute', left: 9.5, top: 22, bottom: 0, width: 1, background: 'var(--hairline-2)' }} />}
            <span className="col grow">
              <span className="w-600" style={{ fontSize: 14 }}>
                {m.label}
              </span>
              <span className="t-cap muted">
                {who} · {relativeTime(ev.at)}
              </span>
              {ev.note && (
                <span className="t-cap" style={{ marginTop: 6, padding: '8px 10px', background: 'var(--surface-2)', borderRadius: 10 }}>
                  “{ev.note}”
                </span>
              )}
            </span>
          </div>
        );
      })}
      {e.status === 'pending' && (
        <div className="row" style={{ gap: 12 }}>
          <span style={{ color: 'var(--amber)' }}>
            <Clock size={20} weight="fill" />
          </span>
          <span className="col">
            <span className="w-600" style={{ fontSize: 14 }}>
              Waiting for Student Accounts
            </span>
            <span className="t-cap muted">Usually reviewed within 2 business days</span>
          </span>
        </div>
      )}
    </div>
  );
}

export function ExpenseDetail({ id, onClose }: { id: string | null; onClose: () => void }) {
  const { state, user, dispatch, toast } = useStore();
  const mobile = useIsMobile();
  const e = state.expenses.find((x) => x.id === id) ?? null;
  const [note, setNote] = useState('');
  const fileRef = useRef<HTMLInputElement>(null);
  useEffect(() => setNote(''), [id]);
  if (!e) return null;
  const org = state.orgs.find((o) => o.id === e.orgId)!;
  const cat = categoryById(e.category);
  const submitter = state.users.find((u) => u.id === e.submittedBy);
  const s = orgSummary(state, org.id);
  const isAccounts = user!.role === 'accounts';
  const canDecide = isAccounts && (e.status === 'pending' || e.status === 'needs_info');
  const canDocument = user!.role === 'officer' && user!.orgIds.includes(org.id) && e.status === 'needs_info';

  const decide = (status: 'approved' | 'rejected' | 'needs_info') => {
    if (status !== 'approved' && !note.trim()) {
      toast({ title: 'Add a short note first', body: 'Tell the organization what is missing or why.', tone: 'info' });
      return;
    }
    dispatch({ type: 'expense/review', id: e.id, status, note: note.trim() || undefined, by: user!.id });
    toast({ title: status === 'approved' ? `Approved ${usd(e.amount)}` : status === 'rejected' ? 'Expense declined' : 'Documentation requested', body: `${org.name} · ${e.vendor}`, tone: status });
    onClose();
  };

  const attach = async (file: File) => {
    const img = file.type === 'application/pdf' ? await new Promise<string>((r) => { const fr = new FileReader(); fr.onload = () => r(String(fr.result)); fr.readAsDataURL(file); }) : await downscale(file);
    dispatch({ type: 'expense/document', id: e.id, image: img, by: user!.id, note: 'Itemized invoice attached' });
    toast({ title: 'Sent back to Student Accounts', body: 'Your expense is pending review again.', tone: 'submitted' });
    onClose();
  };

  const details: [string, string][] = [
    ['Date', longDate(e.date)],
    ['Category', cat.label],
    [e.docType === 'check' ? 'Payee' : 'Vendor', e.vendor],
    ['Document', e.docType === 'check' ? `Check${e.checkNumber ? ` #${e.checkNumber}` : ''}` : 'Receipt'],
    ...(e.memo ? ([['Memo', e.memo]] as [string, string][]) : []),
    ...(e.tax !== undefined ? ([['Tax', usd(e.tax)]] as [string, string][]) : []),
    ['Submitted by', `${submitter?.name ?? '—'} · ${shortDate(e.submittedAt)}`],
    ['Organization', org.name],
  ];

  return (
    <Overlay open onClose={onClose} wide title={isAccounts ? 'Review expense' : 'Expense'} subtitle={`${org.name} · ${e.id.toUpperCase()}`}>
      <div style={{ display: 'grid', gridTemplateColumns: mobile ? '1fr' : 'minmax(0, 1fr) minmax(0, 1fr)', gap: 24 }}>
        <div>
          <DocumentPreview src={e.image} height={mobile ? 300 : 560} />
          {e.scanned && e.scanned.length > 0 && (
            <p className="t-cap muted row" style={{ gap: 6, marginTop: 10 }}>
              <Sparkle size={14} weight="fill" color="var(--accent)" /> {e.scanned.length} details were read from this {e.docType} by OCR and confirmed by the officer.
            </p>
          )}
        </div>
        <div className="col" style={{ gap: 20 }}>
          <div>
            <div className="row between" style={{ alignItems: 'flex-start' }}>
              <div>
                <div className="t-hero num">{usd(e.amount)}</div>
                <div className="t-head" style={{ marginTop: 6 }}>
                  {e.description}
                </div>
              </div>
              <StatusPill status={e.status} />
            </div>
          </div>

          {e.reviewNote && e.status !== 'approved' && (
            <div className="notice-banner" style={{ background: e.status === 'rejected' ? 'var(--red-soft)' : 'var(--accent-soft)', alignItems: 'flex-start' }}>
              {e.status === 'rejected' ? <XCircle size={22} weight="fill" color="var(--red)" /> : <WarningCircle size={22} weight="fill" color="var(--accent)" />}
              <div>
                <div className="w-600" style={{ fontSize: 14 }}>
                  {e.status === 'rejected' ? 'Why it wasn’t approved' : 'Student Accounts needs'}
                </div>
                <div className="t-cap" style={{ marginTop: 2 }}>
                  {e.reviewNote}
                </div>
              </div>
            </div>
          )}

          <div className="inset" style={{ padding: '4px 16px' }}>
            {details.map(([k, v]) => (
              <div key={k} className="row between" style={{ padding: '10px 0', borderBottom: '1px solid var(--hairline)', gap: 16 }}>
                <span className="t-cap muted">{k}</span>
                <span className="t-cap w-500" style={{ textAlign: 'right' }}>
                  {v}
                </span>
              </div>
            ))}
            {e.items && e.items.length > 0 && (
              <div style={{ padding: '10px 0' }}>
                <span className="t-cap muted">Items</span>
                {e.items.map((it, i) => (
                  <div key={i} className="row between t-cap" style={{ marginTop: 6 }}>
                    <span>{it.name}</span>
                    <span className="num">{usd(it.amount)}</span>
                  </div>
                ))}
              </div>
            )}
          </div>

          {isAccounts && (
            <div className="card card-pad" style={{ boxShadow: 'none' }}>
              <div className="t-micro">Budget impact · {org.name}</div>
              <div className="row between" style={{ marginTop: 10 }}>
                <span className="t-cap muted">Remaining now</span>
                <span className="w-600 num">{usd(s.remaining)}</span>
              </div>
              <div className="row between" style={{ marginTop: 6 }}>
                <span className="t-cap muted">After approving this</span>
                <span className="w-600 num" style={{ color: s.remaining - e.amount < 0 ? 'var(--red-text)' : 'var(--text)' }}>
                  {e.status === 'approved' ? usd(s.remaining) : usd(s.remaining - e.amount)}
                </span>
              </div>
              {s.remaining - e.amount < 0 && e.status !== 'approved' && (
                <p className="t-cap" style={{ color: 'var(--red-text)', marginTop: 8 }}>
                  Approving this puts {org.name} over budget.
                </p>
              )}
            </div>
          )}

          <div>
            <div className="t-micro" style={{ marginBottom: 12 }}>
              History
            </div>
            <Timeline e={e} />
          </div>

          {canDecide && (
            <div className="col" style={{ gap: 10 }}>
              <textarea className="textarea" placeholder="Note to the organization (required to request documents or decline)" value={note} onChange={(ev) => setNote(ev.target.value)} rows={2} />
              <div className="row wrap" style={{ gap: 8 }}>
                <button className="btn btn-approve btn-lg grow" onClick={() => decide('approved')}>
                  <CheckCircle size={20} weight="fill" /> Approve {usd(e.amount)}
                </button>
                <button className="btn btn-tonal btn-lg" onClick={() => decide('needs_info')}>
                  Request documents
                </button>
                <button className="btn btn-danger btn-lg" onClick={() => decide('rejected')}>
                  Decline
                </button>
              </div>
            </div>
          )}

          {canDocument && (
            <div>
              <input ref={fileRef} type="file" accept="image/*,application/pdf" hidden onChange={(ev) => ev.target.files?.[0] && attach(ev.target.files[0])} />
              <button className="btn btn-primary btn-lg btn-block" onClick={() => fileRef.current?.click()}>
                <Paperclip size={20} /> Add the missing document
              </button>
            </div>
          )}

          {user!.role === 'advisor' && <p className="t-cap faint">Advisors have read-only access. Only Student Accounts can approve expenses.</p>}
        </div>
      </div>
    </Overlay>
  );
}

export function CboardCard({ org }: { org: Org }) {
  const { user } = useStore();
  const [revealed, setRevealed] = useState(false);
  const [holding, setHolding] = useState(false);
  const timer = useRef<number | undefined>(undefined);
  const hide = useRef<number | undefined>(undefined);
  useEffect(() => () => {
    clearTimeout(timer.current);
    clearTimeout(hide.current);
  }, []);
  if (!canSeeCboard(user!, org)) return null;

  const start = () => {
    if (revealed) return;
    setHolding(true);
    timer.current = window.setTimeout(() => {
      setHolding(false);
      setRevealed(true);
      hide.current = window.setTimeout(() => setRevealed(false), 20000);
    }, 700);
  };
  const cancel = () => {
    setHolding(false);
    clearTimeout(timer.current);
  };

  return (
    <div className="card card-pad">
      <div className="row between">
        <div className="t-micro">C-board number</div>
        <span className="row t-cap faint" style={{ gap: 4 }}>
          <LockSimple size={13} weight="fill" /> Officers only
        </span>
      </div>
      <div className="row between" style={{ marginTop: 14 }}>
        <span className="cboard num" aria-live="polite">
          {revealed ? org.cboard : `•••${org.cboard.slice(-2)}`}
        </span>
        <button
          className={`btn ${revealed ? 'btn-secondary' : 'btn-tonal'} btn-sm`}
          onPointerDown={start}
          onPointerUp={cancel}
          onPointerLeave={cancel}
          onKeyDown={(ev) => {
            if (ev.key === 'Enter' || ev.key === ' ') {
              setRevealed(true);
              hide.current = window.setTimeout(() => setRevealed(false), 20000);
            }
          }}
          onClick={() => revealed && setRevealed(false)}
          style={{ position: 'relative', overflow: 'hidden', minWidth: 132 }}
        >
          {holding && <span style={{ position: 'absolute', inset: 0, background: 'var(--accent-soft-2)', transformOrigin: 'left', animation: 'hold 700ms linear forwards' }} />}
          <span className="row" style={{ gap: 6, position: 'relative' }}>
            <Eye size={16} /> {revealed ? 'Hide' : 'Hold to reveal'}
          </span>
        </button>
      </div>
      <p className="t-cap muted" style={{ marginTop: 10 }}>
        Give this number at Luther Book Shop and other campus locations so purchases are charged to {org.name}. It hides itself after 20 seconds.
      </p>
      <style>{`@keyframes hold { from { transform: scaleX(0) } to { transform: scaleX(1) } }`}</style>
    </div>
  );
}

export function FundingCard({ org, onOpen }: { org: Org; onOpen: () => void }) {
  const { state } = useStore();
  const a = state.announcements.find((x) => x.kind === 'funding' && (x.audience === 'all' || x.audience.includes(org.id)));
  if (!a) return null;
  const days = a.dueDate ? daysUntil(a.dueDate, todayISO()) : null;
  if (org.funding.status !== 'not_started') {
    return (
      <button className="notice-banner" style={{ background: 'var(--green-soft)', width: '100%', textAlign: 'left' }} onClick={onOpen}>
        <CheckCircle size={26} weight="fill" color="var(--green)" />
        <span className="grow">
          <span className="w-600" style={{ display: 'block' }}>
            Funding request submitted
          </span>
          <span className="t-cap muted">
            {org.funding.requested ? `${usd(org.funding.requested)} requested · ` : ''}Student Accounts is reviewing it
          </span>
        </span>
      </button>
    );
  }
  return (
    <div className="notice-banner" style={{ alignItems: 'center', flexWrap: 'wrap' }}>
      <span className="toast-icon" style={{ background: 'var(--accent)', color: 'var(--on-accent)', width: 40, height: 40, borderRadius: 12 }}>
        <CalendarBlank size={22} weight="fill" />
      </span>
      <span className="grow" style={{ minWidth: 200 }}>
        <span className="t-micro" style={{ color: 'var(--accent-text)' }}>
          Important{days !== null ? ` · ${days > 0 ? `${days} days left` : days === 0 ? 'due today' : 'overdue'}` : ''}
        </span>
        <span className="w-600" style={{ display: 'block', marginTop: 2 }}>
          {a.title}
        </span>
        <span className="t-cap muted">Required to receive your budget for next year{a.dueDate ? ` · Due ${longDate(a.dueDate)}` : ''}</span>
      </span>
      <button className="btn btn-primary" onClick={onOpen}>
        Start request
      </button>
    </div>
  );
}

export function FundingSheet({ org, open, onClose }: { org: Org; open: boolean; onClose: () => void }) {
  const { state, dispatch, user, toast } = useStore();
  const [amount, setAmount] = useState('');
  const [opened, setOpened] = useState(false);
  const a = state.announcements.find((x) => x.kind === 'funding');
  if (!a) return null;
  const submitted = org.funding.status !== 'not_started';
  const steps = [
    { done: true, label: 'Agree on the amount with your officers', hint: `Last year’s budget was ${usd(orgSummary(state, org.id).allocated)}.` },
    { done: opened || submitted, label: 'Fill out the Google Form', hint: 'One submission per organization.' },
    { done: submitted, label: 'Confirm here that you submitted it', hint: 'So your officers and Student Accounts can see it’s done.' },
  ];
  return (
    <Overlay open={open} onClose={onClose} title="Annual funding request" subtitle={a.dueDate ? `Due ${longDate(a.dueDate)}` : undefined}>
      <div className="stack-24">
        <p className="muted">{a.body}</p>
        <div className="col" style={{ gap: 14 }}>
          {steps.map((s, i) => (
            <div key={i} className="row" style={{ alignItems: 'flex-start', gap: 12 }}>
              <span
                style={{
                  width: 26,
                  height: 26,
                  borderRadius: 13,
                  flexShrink: 0,
                  display: 'grid',
                  placeItems: 'center',
                  background: s.done ? 'var(--green)' : 'var(--surface-2)',
                  color: s.done ? '#fff' : 'var(--text-2)',
                  fontSize: 13,
                  fontWeight: 600,
                }}
              >
                {s.done ? <CheckCircle size={18} weight="bold" /> : i + 1}
              </span>
              <span className="col">
                <span className="w-600">{s.label}</span>
                <span className="t-cap muted">{s.hint}</span>
              </span>
            </div>
          ))}
        </div>
        {!submitted ? (
          <>
            <a className="btn btn-secondary btn-lg btn-block" href={a.link} target="_blank" rel="noreferrer" onClick={() => setOpened(true)}>
              {a.linkLabel ?? 'Open form'} <ArrowSquareOut size={18} />
            </a>
            <div className="field">
              <label className="field-label" htmlFor="req">
                Amount you requested (optional)
              </label>
              <input id="req" className="input num" inputMode="decimal" placeholder="$0.00" value={amount} onChange={(e) => setAmount(e.target.value.replace(/[^0-9.]/g, ''))} />
            </div>
            <button
              className="btn btn-primary btn-lg btn-block"
              onClick={() => {
                dispatch({ type: 'funding/submit', orgId: org.id, by: user!.id, requested: amount ? parseFloat(amount) : undefined });
                toast({ title: 'Funding request marked as submitted', body: 'Student Accounts has been notified.', tone: 'funding' });
                onClose();
              }}
            >
              I’ve submitted the form
            </button>
          </>
        ) : (
          <div className="notice-banner" style={{ background: 'var(--green-soft)' }}>
            <CheckCircle size={24} weight="fill" color="var(--green)" />
            <span>
              Submitted {org.funding.submittedAt ? relativeTime(org.funding.submittedAt) : ''}
              {org.funding.requested ? ` · ${usd(org.funding.requested)} requested` : ''}.
            </span>
          </div>
        )}
      </div>
    </Overlay>
  );
}

export function ReportButtons({ org, size = 'md' }: { org: Org; size?: 'sm' | 'md' }) {
  const { state, user } = useStore();
  const [busy, setBusy] = useState<'pdf' | 'xlsx' | null>(null);
  const run = async (kind: 'pdf' | 'xlsx') => {
    setBusy(kind);
    try {
      if (kind === 'pdf') await downloadPdf(state, org, { preparedFor: user!.role === 'advisor' ? user!.name : user!.role === 'accounts' ? 'Student Accounts' : undefined });
      else await downloadXlsx(state, org);
    } finally {
      setBusy(null);
    }
  };
  const cls = size === 'sm' ? 'btn btn-secondary btn-sm' : 'btn btn-secondary';
  return (
    <span className="row" style={{ gap: 8 }}>
      <button className={cls} onClick={() => run('pdf')} disabled={!!busy}>
        {busy === 'pdf' ? <CircleNotch size={16} className="spin" /> : <FilePdf size={18} />} PDF
      </button>
      <button className={cls} onClick={() => run('xlsx')} disabled={!!busy}>
        {busy === 'xlsx' ? <CircleNotch size={16} className="spin" /> : <FileXls size={18} />} Excel
      </button>
      <style>{`.spin{animation:spin 0.9s linear infinite}@keyframes spin{to{transform:rotate(360deg)}}`}</style>
    </span>
  );
}

export function SectionCard({ title, action, children, pad = true }: { title: string; action?: React.ReactNode; children: React.ReactNode; pad?: boolean }) {
  return (
    <section className="card" style={{ padding: pad ? 20 : 0 }}>
      <div className="section-head" style={{ padding: pad ? 0 : '20px 20px 0' }}>
        <h2 className="t-head">{title}</h2>
        {action}
      </div>
      {children}
    </section>
  );
}

export const goExpense = (role: string, id: string) => navigate(role === 'accounts' ? `/review/${id}` : `/activity/${id}`);
export { Money };
