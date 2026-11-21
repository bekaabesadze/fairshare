import { useEffect, useId, useRef, useState, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import {
  ForkKnife,
  Gift,
  Printer,
  Package,
  Van,
  Wrench,
  DotsThreeCircle,
  CheckCircle,
  Clock,
  WarningCircle,
  XCircle,
  X,
  Bell,
  Info,
  Megaphone,
  CurrencyCircleDollar,
  PaperPlaneTilt,
  IdentificationCard,
  type Icon,
} from '@phosphor-icons/react';
import type { CategoryId, ExpenseStatus, Notice } from '../../../shared/types.ts';
import { STATUS_LABEL, usd } from '../../../shared/money.ts';
import { useIsMobile, useStore, type Toast } from '../store.tsx';

export function LogoMark({ size = 32, radius }: { size?: number; radius?: number }) {
  return (
    <span
      aria-hidden="true"
      style={{
        width: size, height: size, flexShrink: 0, display: 'grid', placeItems: 'center',
        borderRadius: size * ((radius ?? 22.5) / 100), background: '#fff', boxShadow: 'inset 0 0 0 1px var(--hairline)',
      }}
    >
      <img src="/brand-emblem.png" alt="" width={size * 0.74} height={size * 0.74} draggable={false} />
    </span>
  );
}

export function Wordmark({ size = 30 }: { size?: number }) {
  return (
    <span className="row" style={{ gap: 10 }}>
      <LogoMark size={size} />
      <span style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: size * 0.62, letterSpacing: '-0.02em' }}>FairShare</span>
    </span>
  );
}

export const CATEGORY_ICON: Record<CategoryId, Icon> = {
  food: ForkKnife,
  prizes: Gift,
  printing: Printer,
  supplies: Package,
  transport: Van,
  equipment: Wrench,
  other: DotsThreeCircle,
};

export function CategoryIcon({ id, size = 42 }: { id: CategoryId; size?: number }) {
  const I = CATEGORY_ICON[id];
  return (
    <span className="cat-icon" style={{ width: size, height: size, borderRadius: size * 0.29 }}>
      <I size={size * 0.48} weight="regular" />
    </span>
  );
}

const STATUS_ICON: Record<ExpenseStatus, Icon> = {
  approved: CheckCircle,
  pending: Clock,
  needs_info: WarningCircle,
  rejected: XCircle,
};

export function StatusPill({ status, short }: { status: ExpenseStatus; short?: boolean }) {
  const I = STATUS_ICON[status];
  const label = short && status === 'needs_info' ? 'Needs info' : short && status === 'pending' ? 'Pending' : STATUS_LABEL[status];
  return (
    <span className={`pill pill-${status}`}>
      <I size={14} weight="fill" />
      {label}
    </span>
  );
}

const PHOTOS: Record<string, string> = {
  'abessa01@luther.edu': '/people/abessa01.jpg',
  'abesbe01@luther.edu': '/people/abesbe01.jpg',
};

const ORG_LOGOS: Record<string, string> = {
  uptous: '/orgs/uptous.png',
};

export function Avatar({ name, email, size = 36 }: { name: string; email?: string; size?: number }) {
  const photo = email ? PHOTOS[email.trim().toLowerCase()] : undefined;
  const initials = name
    .replace(/^(Prof\.|Dr\.)\s+/, '')
    .split(' ')
    .map((p) => p[0])
    .slice(0, 2)
    .join('');
  return (
    <span className="avatar" style={{ width: size, height: size, fontSize: size * 0.36 }}>
      {photo ? <img className="avatar-img" src={photo} alt={name} draggable={false} /> : initials}
    </span>
  );
}

export function OrgBadge({ id, initials, size = 42 }: { id?: string; initials: string; size?: number }) {
  const logo = id ? ORG_LOGOS[id] : undefined;
  return (
    <span
      className={logo ? 'org-badge org-badge-logo' : 'org-badge'}
      style={{ width: size, height: size, borderRadius: size * 0.31, fontSize: size * 0.33 }}
    >
      {logo ? <img src={logo} alt="" draggable={false} /> : initials}
    </span>
  );
}

export function AnimatedNumber({ value, format = (n: number) => usd(n), duration = 900 }: { value: number; format?: (n: number) => string; duration?: number }) {
  const [shown, setShown] = useState(value);
  const from = useRef(value);
  const raf = useRef(0);
  useEffect(() => {
    const start = performance.now();
    const a = from.current;
    const b = value;
    if (a === b) return;
    cancelAnimationFrame(raf.current);
    const tick = (t: number) => {
      const p = Math.min(1, (t - start) / duration);
      const e = 1 - Math.pow(1 - p, 4);
      const v = a + (b - a) * e;
      setShown(v);
      from.current = v;
      if (p < 1) raf.current = requestAnimationFrame(tick);
      else from.current = b;
    };
    raf.current = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf.current);
  }, [value, duration]);
  return <span className="num">{format(Math.round(shown * 100) / 100)}</span>;
}

export function BudgetRing({
  allocated,
  approved,
  pending,
  size = 260,
  stroke = 18,
  children,
}: {
  allocated: number;
  approved: number;
  pending: number;
  size?: number;
  stroke?: number;
  children?: ReactNode;
}) {
  const id = useId().replace(/:/g, '');
  const r = (size - stroke) / 2;
  const C = 2 * Math.PI * r;
  const total = Math.max(allocated, 0.01);
  const available = Math.max(0, allocated - approved - pending);
  const pendingVis = Math.max(0, Math.min(pending, allocated - approved));
  const fA = available / total;
  const fP = pendingVis / total;
  const cap = ((stroke / 2) / C) * 100;
  const gap = (3 / C) * 100;
  const low = allocated > 0 && available / allocated < 0.15;

  const seg = (start: number, frac: number) => {
    const len = Math.max(0, frac * 100 - 2 * cap - gap);
    return {
      strokeDasharray: `${len} ${100 - len}`,
      strokeDashoffset: -(start * 100 + cap + gap / 2),
      opacity: frac * 100 > gap + 0.2 ? 1 : 0,
    };
  };

  return (
    <div style={{ position: 'relative', width: size, height: size }}>
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ transform: 'rotate(-90deg)', display: 'block' }} role="img" aria-label={`${usd(allocated - approved)} remaining of ${usd(allocated)}; ${usd(pending)} pending`}>
        <defs>
          <pattern id={`hatch-${id}`} width="6" height="6" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
            <rect width="6" height="6" fill="var(--amber)" opacity="0.55" />
            <rect width="3" height="6" fill="var(--amber)" />
          </pattern>
        </defs>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--ring-track)" strokeWidth={stroke} />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          pathLength={100}
          stroke={`url(#hatch-${id})`}
          strokeWidth={stroke}
          strokeLinecap="round"
          style={{ ...seg(fA, fP), transition: 'stroke-dasharray 900ms var(--ease), stroke-dashoffset 900ms var(--ease), opacity 300ms' }}
        />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          pathLength={100}
          stroke={low ? 'var(--red)' : 'var(--accent)'}
          strokeWidth={stroke}
          strokeLinecap="round"
          style={{ ...seg(0, fA), transition: 'stroke-dasharray 900ms var(--ease), stroke-dashoffset 900ms var(--ease), stroke 300ms' }}
        />
      </svg>
      <div style={{ position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', textAlign: 'center' }}>{children}</div>
    </div>
  );
}

export function RingLegend({ available, pending, approved }: { available: number; pending: number; approved: number }) {
  const item = (swatch: ReactNode, label: string, value: number, hint: string) => (
    <div className="col gap-4" style={{ minWidth: 0 }}>
      <span className="row gap-8 t-cap muted" style={{ gap: 7 }}>
        {swatch}
        {label}
      </span>
      <span className="t-head num">{usd(value)}</span>
      <span className="t-cap faint">{hint}</span>
    </div>
  );
  const dot = (bg: string, hatch = false) => (
    <span
      style={{
        width: 10,
        height: 10,
        borderRadius: 3,
        background: hatch ? `repeating-linear-gradient(45deg, var(--amber) 0 2px, color-mix(in srgb, var(--amber) 55%, transparent) 2px 4px)` : bg,
        flexShrink: 0,
      }}
    />
  );
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, minmax(0,1fr))', gap: 12 }}>
      {item(dot('var(--accent)'), 'Safe to spend', available, 'After pending')}
      {item(dot('', true), 'Pending', pending, 'Waiting for review')}
      {item(dot('var(--ring-track)'), 'Spent', approved, 'Approved')}
    </div>
  );
}

export function CategoryBars({ rows }: { rows: { id: CategoryId; label: string; approved: number; pending: number }[] }) {
  const max = Math.max(1, ...rows.map((r) => r.approved + r.pending));
  const [hover, setHover] = useState<string | null>(null);
  const visible = rows.filter((r) => r.approved + r.pending > 0).sort((a, b) => b.approved + b.pending - (a.approved + a.pending));
  if (!visible.length) return <p className="t-cap muted">No spending yet this term. Expenses you add will show up here by category.</p>;
  return (
    <div className="col" style={{ gap: 14 }}>
      {visible.map((r, i) => {
        const I = CATEGORY_ICON[r.id];
        return (
          <div key={r.id} onMouseEnter={() => setHover(r.id)} onMouseLeave={() => setHover(null)} style={{ position: 'relative' }}>
            <div className="row between t-cap" style={{ marginBottom: 6 }}>
              <span className="row" style={{ gap: 8 }}>
                <I size={16} className="muted" />
                <span className="w-500">{r.label}</span>
              </span>
              <span className="num w-600">
                {r.approved > 0 ? usd(r.approved) : null}
                {r.pending > 0 && (
                  <span className="w-500" style={{ color: 'var(--amber-text)' }}>
                    {r.approved > 0 ? ' + ' : ''}
                    {usd(r.pending)} pending
                  </span>
                )}
              </span>
            </div>
            <div className="bar-track" style={{ height: 10, background: 'transparent', gap: 2 }}>
              {r.approved > 0 && <div className="bar-fill" style={{ width: `${(r.approved / max) * 100}%`, background: i === 0 ? 'var(--accent)' : 'var(--text-3)', borderRadius: 4 }} />}
              {r.pending > 0 && (
                <div
                  className="bar-fill"
                  style={{
                    width: `${(r.pending / max) * 100}%`,
                    background: 'repeating-linear-gradient(45deg, var(--amber) 0 3px, color-mix(in srgb, var(--amber) 55%, transparent) 3px 6px)',
                    borderRadius: 4,
                  }}
                />
              )}
              <div style={{ flex: 1, background: 'var(--ring-track)', borderRadius: 4, opacity: 0.6 }} />
            </div>
            {hover === r.id && (
              <div className="tooltip" style={{ left: '50%', top: 0 }}>
                {r.label}: {usd(r.approved)} approved{r.pending ? `, ${usd(r.pending)} pending` : ''}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

export function MonthlyColumns({ data, height = 160 }: { data: { key: string; label: string; total: number }[]; height?: number }) {
  const max = Math.max(1, ...data.map((d) => d.total));
  const [hover, setHover] = useState<string | null>(null);
  const last = data[data.length - 1]?.key;
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', gap: 16, height: height + 40, paddingTop: 20 }}>
      {data.map((d) => (
        <div key={d.key} className="col" style={{ flex: 1, alignItems: 'center', gap: 8, position: 'relative' }} onMouseEnter={() => setHover(d.key)} onMouseLeave={() => setHover(null)}>
          <span className="t-cap num w-600" style={{ color: d.key === last ? 'var(--text)' : 'var(--text-2)' }}>
            {usd(d.total, { cents: false })}
          </span>
          <div
            style={{
              width: '100%',
              maxWidth: 24,
              height: Math.max(4, (d.total / max) * height),
              background: d.key === last ? 'var(--accent)' : 'var(--surface-3)',
              borderRadius: '4px 4px 0 0',
              transition: 'height 700ms var(--ease)',
            }}
          />
          <span className="t-cap faint">{d.label}</span>
          {hover === d.key && (
            <div className="tooltip" style={{ left: '50%', top: 0 }}>
              {d.label}: {usd(d.total)} approved
            </div>
          )}
        </div>
      ))}
    </div>
  );
}

export function Overlay({
  open,
  onClose,
  title,
  subtitle,
  children,
  footer,
  wide,
  labelledBy,
}: {
  open: boolean;
  onClose: () => void;
  title?: ReactNode;
  subtitle?: ReactNode;
  children: ReactNode;
  footer?: ReactNode;
  wide?: boolean;
  labelledBy?: string;
}) {
  const mobile = useIsMobile();
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      window.removeEventListener('keydown', onKey);
      document.body.style.overflow = prev;
    };
  }, [open, onClose]);
  if (!open) return null;
  return createPortal(
    <>
      <div className="scrim" onClick={onClose} />
      <div className={mobile ? 'sheet' : `modal ${wide ? 'modal-wide' : ''}`} role="dialog" aria-modal="true" aria-labelledby={labelledBy}>
        {mobile && <div className="sheet-grabber" />}
        {(title || subtitle) && (
          <div className="modal-head">
            <div className="grow">
              {title && (
                <h2 className="t-title" id={labelledBy}>
                  {title}
                </h2>
              )}
              {subtitle && <p className="t-cap muted" style={{ marginTop: 2 }}>{subtitle}</p>}
            </div>
            <button className="icon-btn" onClick={onClose} aria-label="Close">
              <X size={20} />
            </button>
          </div>
        )}
        <div className="modal-body">{children}</div>
        {footer && (
          <div style={{ padding: '0 24px 24px', display: 'flex', gap: 10, justifyContent: 'flex-end', flexWrap: 'wrap' }}>{footer}</div>
        )}
      </div>
    </>,
    document.body,
  );
}

const TOAST_STYLE: Record<Toast['tone'], { icon: Icon; bg: string; fg: string }> = {
  approved: { icon: CheckCircle, bg: 'var(--green-soft)', fg: 'var(--green-text)' },
  rejected: { icon: XCircle, bg: 'var(--red-soft)', fg: 'var(--red-text)' },
  needs_info: { icon: WarningCircle, bg: 'var(--accent-soft)', fg: 'var(--accent-text)' },
  submitted: { icon: PaperPlaneTilt, bg: 'var(--amber-soft)', fg: 'var(--amber-text)' },
  announcement: { icon: Megaphone, bg: 'var(--accent-soft)', fg: 'var(--accent-text)' },
  budget: { icon: CurrencyCircleDollar, bg: 'var(--green-soft)', fg: 'var(--green-text)' },
  funding: { icon: Bell, bg: 'var(--accent-soft)', fg: 'var(--accent-text)' },
  access: { icon: IdentificationCard, bg: 'var(--accent-soft)', fg: 'var(--accent-text)' },
  info: { icon: Info, bg: 'var(--surface-2)', fg: 'var(--text-2)' },
};

export function Toasts({ onOpen }: { onOpen?: (t: Toast) => void }) {
  const { toasts, dismissToast } = useStore();
  return (
    <div className="toasts" aria-live="polite">
      {toasts.map((t) => {
        const s = TOAST_STYLE[t.tone] ?? TOAST_STYLE.info;
        const I = s.icon;
        return (
          <button
            key={t.id}
            className="toast"
            onClick={() => {
              onOpen?.(t);
              dismissToast(t.id);
            }}
            style={{ textAlign: 'left' }}
          >
            <span className="toast-icon" style={{ background: s.bg, color: s.fg }}>
              <I size={20} weight="fill" />
            </span>
            <span className="grow">
              <span className="t-head" style={{ display: 'block', fontSize: 15 }}>
                {t.title}
              </span>
              {t.body && (
                <span className="t-cap muted" style={{ display: 'block', marginTop: 1 }}>
                  {t.body}
                </span>
              )}
            </span>
          </button>
        );
      })}
    </div>
  );
}

export const noticeTone = (n: Notice): Toast['tone'] => n.kind;

export function NoticeIcon({ kind }: { kind: Notice['kind'] }) {
  const s = TOAST_STYLE[kind] ?? TOAST_STYLE.info;
  const I = s.icon;
  return (
    <span className="toast-icon" style={{ background: s.bg, color: s.fg }}>
      <I size={18} weight="fill" />
    </span>
  );
}

export function Stat({ label, value, hint, tone }: { label: string; value: ReactNode; hint?: ReactNode; tone?: 'accent' | 'amber' | 'green' | 'red' }) {
  const color = tone === 'amber' ? 'var(--amber-text)' : tone === 'green' ? 'var(--green-text)' : tone === 'red' ? 'var(--red-text)' : tone === 'accent' ? 'var(--accent-text)' : 'var(--text)';
  return (
    <div className="card card-pad">
      <div className="t-micro">{label}</div>
      <div className="t-large num" style={{ marginTop: 8, fontSize: 28, color }}>
        {value}
      </div>
      {hint && <div className="t-cap muted" style={{ marginTop: 4 }}>{hint}</div>}
    </div>
  );
}

export function Empty({ icon: I, title, body, action }: { icon: Icon; title: string; body: string; action?: ReactNode }) {
  return (
    <div className="empty">
      <span className="cat-icon" style={{ margin: '0 auto 14px', width: 52, height: 52, borderRadius: 16 }}>
        <I size={24} />
      </span>
      <div className="t-head" style={{ color: 'var(--text)' }}>
        {title}
      </div>
      <p className="t-cap" style={{ marginTop: 4, maxWidth: 320, marginInline: 'auto' }}>
        {body}
      </p>
      {action && <div style={{ marginTop: 16 }}>{action}</div>}
    </div>
  );
}

export function RichText({ text }: { text: string }) {
  const parts = text.split(/(\*\*[^*]+\*\*)/g);
  return (
    <>
      {parts.map((p, i) =>
        p.startsWith('**') && p.endsWith('**') ? (
          <strong key={i} className="w-600">
            {p.slice(2, -2)}
          </strong>
        ) : (
          <span key={i}>{p}</span>
        ),
      )}
    </>
  );
}
