import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { Bell, Moon, Sun, SignOut, GearSix, ArrowsLeftRight, CaretUpDown, Check, WifiSlash } from '@phosphor-icons/react';
import { navigate, useIsMobile, useStore } from '../store.tsx';
import { NAV } from './nav.ts';
import { Avatar, LogoMark, NoticeIcon, Overlay, OrgBadge, Toasts, Wordmark } from '../ui/kit.tsx';
import { GlassTabBar, useMinimizeOnScroll } from '../ui/GlassTabBar.tsx';
import { noticesFor } from '../../../shared/reducer.ts';
import { ROLE_LABEL, relativeTime } from '../../../shared/money.ts';
import { DEMO_ACCOUNTS } from '../../../shared/seed.ts';
import type { Notice } from '../../../shared/types.ts';

export function Shell({ active, children, hideTabBar }: { active: string; children: ReactNode; hideTabBar?: boolean }) {
  const { user, state } = useStore();
  const mobile = useIsMobile();
  const [notifOpen, setNotifOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const items = NAV[user!.role];
  const queueCount = state.expenses.filter((e) => e.status === 'pending').length;
  const badges: Record<string, number> = user!.role === 'accounts' ? { review: queueCount } : {};
  const { minimized, leadIn, restore } = useMinimizeOnScroll(active);

  useEffect(() => {
    window.scrollTo({ top: 0 });
  }, [active]);

  const openNotice = (n: { ref?: string }) => {
    if (!n.ref) return;
    if (n.ref.startsWith('ex_')) navigate(user!.role === 'accounts' ? `/review/${n.ref}` : `/activity/${n.ref}`);
    else if (n.ref.startsWith('an_')) navigate(user!.role === 'officer' ? '/home' : '/announce');
  };

  if (mobile) {
    const idx = Math.max(0, items.findIndex((i) => i.key === active));
    return (
      <div className="m-shell">
        <header className="m-header">
          <MobileIdentity />
          <div className="grow" />
          <SyncChip compact />
          <NotifButton onClick={() => setNotifOpen(true)} />
          <button className="icon-btn" aria-label="Account" onClick={() => setMenuOpen(true)}>
            <Avatar name={user!.name} email={user!.email} size={32} />
          </button>
        </header>
        <main>{children}</main>
        <GlassTabBar
          items={items.map((i) => ({ key: i.key, label: i.label, icon: i.icon, badge: badges[i.key] }))}
          selectedIndex={items.some((i) => i.key === active) ? idx : -1}
          onSelect={(i) => navigate(`/${items[i].key}`)}
          minimized={minimized}
          leadIn={leadIn}
          onInteraction={restore}
          hidden={hideTabBar}
        />
        <Overlay open={notifOpen} onClose={() => setNotifOpen(false)} title="Notifications">
          <NotificationList
            onOpen={(n) => {
              setNotifOpen(false);
              openNotice(n);
            }}
          />
        </Overlay>
        <Overlay open={menuOpen} onClose={() => setMenuOpen(false)} title={user!.name} subtitle={`${user!.title} · ${user!.email}`}>
          <AccountMenu onDone={() => setMenuOpen(false)} />
        </Overlay>
        <Toasts onOpen={openNotice} />
      </div>
    );
  }

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="sidebar-brand">
          <Wordmark size={30} />
        </div>
        <OrgSwitcherCard />
        <nav className="col" style={{ gap: 2, marginTop: 8 }} aria-label="Main">
          {items.map((i) => {
            const I = i.icon;
            const on = i.key === active;
            return (
              <button key={i.key} className="nav-item" aria-current={on ? 'page' : undefined} onClick={() => navigate(`/${i.key}`)}>
                <I size={21} weight={on ? 'fill' : 'regular'} />
                {i.label}
                {!!badges[i.key] && <span className="count num">{badges[i.key]}</span>}
              </button>
            );
          })}
        </nav>
        <div className="grow" />
        <div style={{ position: 'relative' }}>
          <button className="nav-item" style={{ height: 56, gap: 10 }} onClick={() => setMenuOpen((v) => !v)} aria-expanded={menuOpen}>
            <Avatar name={user!.name} email={user!.email} size={34} />
            <span className="col grow" style={{ minWidth: 0, lineHeight: 1.25 }}>
              <span className="w-600 ellipsis" style={{ color: 'var(--text)', fontSize: 14 }}>
                {user!.name}
              </span>
              <span className="t-cap faint ellipsis">{ROLE_LABEL[user!.role]}</span>
            </span>
            <CaretUpDown size={16} />
          </button>
          {menuOpen && (
            <>
              <div style={{ position: 'fixed', inset: 0, zIndex: 40 }} onClick={() => setMenuOpen(false)} />
              <div className="card" style={{ position: 'absolute', bottom: 62, left: 0, right: 0, zIndex: 41, padding: 8, boxShadow: 'var(--shadow-3)' }}>
                <AccountMenu onDone={() => setMenuOpen(false)} />
              </div>
            </>
          )}
        </div>
      </aside>
      <div className="main">
        <header className="topbar">
          <div className="grow" />
          <SyncChip />
          <ThemeButton />
          <div style={{ position: 'relative' }}>
            <NotifButton onClick={() => setNotifOpen((v) => !v)} />
            {notifOpen && (
              <>
                <div style={{ position: 'fixed', inset: 0, zIndex: 40 }} onClick={() => setNotifOpen(false)} />
                <div className="card" style={{ position: 'absolute', right: 0, top: 48, width: 400, maxHeight: 520, overflow: 'auto', zIndex: 41, padding: '14px 10px', boxShadow: 'var(--shadow-3)' }}>
                  <div className="row between" style={{ padding: '0 10px 8px' }}>
                    <span className="t-head">Notifications</span>
                  </div>
                  <NotificationList
                    onOpen={(n) => {
                      setNotifOpen(false);
                      openNotice(n);
                    }}
                  />
                </div>
              </>
            )}
          </div>
        </header>
        <main>{children}</main>
      </div>
      <Toasts onOpen={openNotice} />
    </div>
  );
}

function MobileIdentity() {
  const { user, state } = useStore();
  const org = user!.role === 'officer' ? state.orgs.find((o) => o.id === user!.orgIds[0]) : null;
  return (
    <span className="row" style={{ gap: 10, minWidth: 0 }}>
      {org ? <OrgBadge id={org.id} initials={org.initials} size={32} /> : <LogoMark size={30} radius={26} />}
      <span className="w-600 ellipsis" style={{ fontSize: 15 }}>
        {org ? org.name : 'FairShare'}
      </span>
    </span>
  );
}

function OrgSwitcherCard() {
  const { user, state } = useStore();
  if (user!.role !== 'officer') {
    return (
      <div className="inset row" style={{ padding: 12, gap: 10, margin: '0 2px' }}>
        <span className="t-micro" style={{ color: 'var(--text-2)' }}>
          {state.institution.name}
        </span>
        <span className="grow" />
        <span className="t-cap faint">{state.institution.term}</span>
      </div>
    );
  }
  const org = state.orgs.find((o) => o.id === user!.orgIds[0])!;
  return (
    <button className="inset row" style={{ padding: 12, gap: 12, margin: '0 2px', textAlign: 'left' }} onClick={() => navigate('/club')}>
      <OrgBadge id={org.id} initials={org.initials} size={38} />
      <span className="col grow" style={{ minWidth: 0, lineHeight: 1.25 }}>
        <span className="w-600 ellipsis">{org.name}</span>
        <span className="t-cap faint">{org.term}</span>
      </span>
    </button>
  );
}

export function SyncChip({ compact }: { compact?: boolean }) {
  const { sync, reconnect } = useStore();
  if (compact) {
    if (sync === 'live') return null;
    return (
      <button className="icon-btn" aria-label="Offline demo mode — tap to reconnect" onClick={reconnect} title="Offline demo mode">
        <WifiSlash size={20} />
      </button>
    );
  }
  return (
    <button className="sync-chip" onClick={sync === 'offline' ? reconnect : undefined} title={sync === 'live' ? 'Changes sync instantly across every device' : 'No sync server — changes stay in this browser'}>
      <span className={`sync-dot ${sync === 'live' ? '' : 'off'}`} />
      {sync === 'live' ? 'Live' : sync === 'connecting' ? 'Connecting…' : 'Offline demo · Reconnect'}
    </button>
  );
}

function ThemeButton() {
  const { theme, setTheme } = useStore();
  const dark = theme === 'dark' || (theme === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches);
  return (
    <button className="icon-btn" aria-label={dark ? 'Switch to light mode' : 'Switch to dark mode'} onClick={() => setTheme(dark ? 'light' : 'dark')}>
      {dark ? <Sun size={20} /> : <Moon size={20} />}
    </button>
  );
}

function NotifButton({ onClick }: { onClick: () => void }) {
  const { user, state } = useStore();
  const unread = useMemo(() => noticesFor(state, user!).filter((n) => !n.readBy.includes(user!.id)).length, [state, user]);
  return (
    <button className="icon-btn" aria-label={`Notifications${unread ? `, ${unread} unread` : ''}`} onClick={onClick}>
      <Bell size={21} />
      {unread > 0 && <span className="badge-dot num">{unread}</span>}
    </button>
  );
}

function NotificationList({ onOpen }: { onOpen: (n: Notice) => void }) {
  const { user, state, dispatch } = useStore();
  const list = noticesFor(state, user!).slice(0, 20);
  const unreadIds = list.filter((n) => !n.readBy.includes(user!.id)).map((n) => n.id);
  const marked = useRef(false);
  useEffect(() => {
    if (marked.current || !unreadIds.length) return;
    marked.current = true;
    const t = setTimeout(() => dispatch({ type: 'notice/read', userId: user!.id, ids: unreadIds }), 1200);
    return () => clearTimeout(t);
  }, [unreadIds, dispatch, user]);
  if (!list.length) return <p className="t-cap muted" style={{ padding: 16 }}>You’re all caught up.</p>;
  return (
    <div className="list">
      {list.map((n) => {
        const unread = !n.readBy.includes(user!.id);
        return (
          <button key={n.id} className="list-row" style={{ alignItems: 'flex-start', padding: '12px 10px' }} onClick={() => onOpen(n)}>
            <NoticeIcon kind={n.kind} />
            <span className="col grow" style={{ minWidth: 0 }}>
              <span className="row between" style={{ gap: 8 }}>
                <span className="w-600" style={{ fontSize: 14 }}>
                  {n.title}
                </span>
                <span className="t-cap faint" style={{ flexShrink: 0 }}>
                  {relativeTime(n.at)}
                </span>
              </span>
              <span className="t-cap muted" style={{ marginTop: 2 }}>
                {n.body}
              </span>
            </span>
            {unread && <span style={{ width: 8, height: 8, borderRadius: 4, background: 'var(--accent)', marginTop: 6, flexShrink: 0 }} aria-label="Unread" />}
          </button>
        );
      })}
    </div>
  );
}

function AccountMenu({ onDone }: { onDone: () => void }) {
  const { user, signIn, signOut, theme, setTheme } = useStore();
  const [switching, setSwitching] = useState(false);
  if (switching) {
    return (
      <div className="col" style={{ gap: 4 }}>
        <div className="t-micro" style={{ padding: '6px 10px' }}>
          Demo accounts
        </div>
        {DEMO_ACCOUNTS.map((a) => (
          <button
            key={a.userId}
            className="nav-item"
            style={{ height: 'auto', padding: '10px 12px' }}
            onClick={() => {
              signIn(a.userId);
              navigate('/');
              onDone();
            }}
          >
            <span className="col grow" style={{ lineHeight: 1.3 }}>
              <span className="w-600" style={{ color: 'var(--text)' }}>
                {a.label}
              </span>
              <span className="t-cap faint">{a.who}</span>
            </span>
            {a.userId === user!.id && <Check size={18} color="var(--accent)" />}
          </button>
        ))}
      </div>
    );
  }
  return (
    <div className="col" style={{ gap: 2 }}>
      <div className="segmented" style={{ margin: '4px 4px 8px', display: 'flex' }}>
        {(['system', 'light', 'dark'] as const).map((t) => (
          <button key={t} aria-pressed={theme === t} onClick={() => setTheme(t)} style={{ flex: 1 }}>
            {t === 'system' ? 'Auto' : t === 'light' ? 'Light' : 'Dark'}
          </button>
        ))}
      </div>
      <button
        className="nav-item"
        onClick={() => {
          navigate('/settings');
          onDone();
        }}
      >
        <GearSix size={19} /> Settings
      </button>
      <button className="nav-item" onClick={() => setSwitching(true)}>
        <ArrowsLeftRight size={19} /> Switch demo account
      </button>
      <button
        className="nav-item"
        onClick={() => {
          onDone();
          signOut();
        }}
      >
        <SignOut size={19} /> Sign out
      </button>
    </div>
  );
}

export function PageHeader({ title, subtitle, actions }: { title: ReactNode; subtitle?: ReactNode; actions?: ReactNode }) {
  return (
    <div className="page-header">
      <div style={{ minWidth: 0 }}>
        <h1 className="t-large">{title}</h1>
        {subtitle && (
          <p className="muted" style={{ marginTop: 4 }}>
            {subtitle}
          </p>
        )}
      </div>
      {actions && <div className="row wrap" style={{ gap: 10 }}>{actions}</div>}
    </div>
  );
}
