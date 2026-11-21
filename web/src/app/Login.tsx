import { useState } from 'react';
import { ArrowRight, Student, Bank, ChalkboardTeacher, ShieldCheck, CircleNotch, ArrowLeft } from '@phosphor-icons/react';
import { navigate, useIsMobile, useStore } from '../store.tsx';
import { DEMO_ACCOUNTS } from '../../../shared/seed.ts';
import { homeFor } from './nav.ts';
import { BudgetRing, LogoMark, Wordmark } from '../ui/kit.tsx';
import { orgSummary, usd } from '../../../shared/money.ts';

const ROLE_ICON = { officer: Student, accounts: Bank, advisor: ChalkboardTeacher, platform: ShieldCheck } as const;

export function LoginPage() {
  const { state, signIn } = useStore();
  const mobile = useIsMobile();
  const [email, setEmail] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  const go = (userId: string) => {
    setBusy(userId);
    setTimeout(() => {
      const u = state.users.find((x) => x.id === userId)!;
      signIn(userId);
      navigate(`/${homeFor(u.role)}`);
    }, 650);
  };

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    const v = email.trim().toLowerCase();
    if (!v.endsWith(`@${state.institution.domain}`)) {
      setError(`Use your @${state.institution.domain} email address.`);
      return;
    }
    const u = state.users.find((x) => x.email === v);
    if (!u) {
      setError('We couldn’t find an account for that email. Ask your organization’s president or Student Accounts to add you.');
      return;
    }
    if (!u.active) {
      setError('This account was removed. Ask Student Accounts to restore it.');
      return;
    }
    setError(null);
    go(u.id);
  };

  const up = orgSummary(state, 'uptous');

  return (
    <div style={{ minHeight: '100dvh', display: 'grid', gridTemplateColumns: mobile ? '1fr' : '1fr 1fr' }}>
      {!mobile && (
        <aside style={{ background: 'var(--surface-2)', padding: 48, display: 'flex', flexDirection: 'column', justifyContent: 'space-between', borderRight: '1px solid var(--hairline)' }}>
          <button onClick={() => navigate('/')} style={{ alignSelf: 'flex-start' }}>
            <Wordmark size={32} />
          </button>
          <div style={{ display: 'grid', placeItems: 'center' }}>
            <div className="card" style={{ padding: 28, width: 340, boxShadow: 'var(--shadow-2)' }}>
              <div className="t-micro">Up to Us · Fall 2026</div>
              <div style={{ display: 'grid', placeItems: 'center', margin: '18px 0 6px' }}>
                <BudgetRing allocated={up.allocated} approved={up.approved} pending={up.pending} size={200} stroke={15}>
                  <div>
                    <div className="t-cap muted">Remaining</div>
                    <div className="num" style={{ fontSize: 32, fontWeight: 700, letterSpacing: '-0.03em' }}>
                      {usd(up.remaining)}
                    </div>
                  </div>
                </BudgetRing>
              </div>
            </div>
          </div>
          <div>
            <h2 className="t-large" style={{ maxWidth: 440 }}>
              Know what your club has left — without emailing anyone.
            </h2>
            <p className="muted" style={{ marginTop: 10, maxWidth: 440 }}>
              Live budgets, receipt scanning and approvals for every student organization at {state.institution.name}.
            </p>
          </div>
        </aside>
      )}
      <main style={{ display: 'grid', placeItems: 'center', padding: mobile ? '32px 20px' : 48 }}>
        <div style={{ width: '100%', maxWidth: 420 }} className="rise">
          {mobile && (
            <button className="icon-btn" onClick={() => navigate('/')} aria-label="Back" style={{ marginLeft: -8, marginBottom: 12 }}>
              <ArrowLeft size={22} />
            </button>
          )}
          <LogoMark size={52} />
          <h1 className="t-large" style={{ marginTop: 20 }}>
            Sign in to FairShare
          </h1>
          <p className="muted" style={{ marginTop: 6 }}>
            Use your {state.institution.name} email. We’ll take you to the right dashboard.
          </p>
          <form onSubmit={submit} className="col" style={{ gap: 12, marginTop: 28 }}>
            <label className="field">
              <span className="field-label">Luther email</span>
              <input
                className="input"
                type="email"
                autoComplete="email"
                placeholder={`you@${state.institution.domain}`}
                value={email}
                onChange={(e) => {
                  setEmail(e.target.value);
                  setError(null);
                }}
              />
            </label>
            {error && (
              <p className="t-cap" style={{ color: 'var(--red-text)' }} role="alert">
                {error}
              </p>
            )}
            <button className="btn btn-primary btn-lg btn-block" type="submit" disabled={!email || !!busy}>
              {busy && !DEMO_ACCOUNTS.some((d) => d.userId === busy) ? <CircleNotch size={20} className="spin" /> : null}
              Continue with Luther SSO <ArrowRight size={18} />
            </button>
          </form>

          <div className="row" style={{ gap: 12, margin: '32px 0 14px' }}>
            <hr className="divider grow" />
            <span className="t-micro">Or try a demo account</span>
            <hr className="divider grow" />
          </div>
          <div className="col" style={{ gap: 10 }}>
            {DEMO_ACCOUNTS.map((a) => {
              const I = ROLE_ICON[a.role];
              return (
                <button key={a.userId} className="choice" style={{ padding: 14 }} onClick={() => go(a.userId)} disabled={!!busy}>
                  <span className="choice-icon" style={{ width: 42, height: 42, borderRadius: 12 }}>
                    <I size={22} />
                  </span>
                  <span className="col grow" style={{ minWidth: 0 }}>
                    <span className="w-600">{a.label}</span>
                    <span className="t-cap muted ellipsis">{a.who}</span>
                  </span>
                  {busy === a.userId ? <CircleNotch size={20} className="spin" /> : <ArrowRight size={18} className="faint" />}
                </button>
              );
            })}
          </div>
          <p className="t-cap faint" style={{ marginTop: 20 }}>
            Demo data only — no real Luther financial information. Open a second window to sign in as someone else and watch changes sync live.
          </p>
        </div>
      </main>
      <style>{`.spin{animation:spin .9s linear infinite}@keyframes spin{to{transform:rotate(360deg)}}`}</style>
    </div>
  );
}
