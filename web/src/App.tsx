import { useEffect } from 'react';
import { navigate, useRoute, useStore } from './store.tsx';
import { Shell } from './app/Shell.tsx';
import { LoginPage } from './app/Login.tsx';
import { Landing } from './app/Landing.tsx';
import { homeFor, NAV } from './app/nav.ts';
import { ActivityPage, ClubPage, OfficerHome } from './pages/officer.tsx';
import { AddExpensePage } from './pages/AddExpense.tsx';
import { AssistantPage } from './pages/Assistant.tsx';
import { AccountsOverview, AnnouncementsPage, OrgDetailPage, OrgsPage, ReportsPage, ReviewPage } from './pages/accounts.tsx';
import { AdvisorHome, SettingsPage, UsersPage } from './pages/other.tsx';
import type { Role } from '../../shared/types.ts';

const ALLOWED: Record<Role, string[]> = {
  officer: ['home', 'activity', 'add', 'ask', 'club', 'settings'],
  accounts: ['overview', 'review', 'orgs', 'people', 'reports', 'announce', 'settings'],
  advisor: ['advisor', 'activity', 'reports', 'orgs', 'settings'],
  platform: ['users', 'orgs', 'settings'],
};

export function App() {
  const { user } = useStore();
  const { path } = useRoute();
  const page = path[0] ?? '';

  useEffect(() => {
    if (!user) return;
    if (!ALLOWED[user.role].includes(page)) navigate(`/${homeFor(user.role)}`);
  }, [user, page]);

  useEffect(() => {
    const titles: Record<string, string> = Object.fromEntries(Object.values(NAV).flat().map((n) => [n.key, n.title]));
    document.title = user && titles[page] ? `${titles[page]} · FairShare` : 'FairShare';
  }, [user, page]);

  if (!user) return page === 'login' ? <LoginPage /> : <Landing />;
  if (!ALLOWED[user.role].includes(page)) return null;

  const id = path[1];
  let content: React.ReactNode = null;
  switch (page) {
    case 'home':
      content = <OfficerHome />;
      break;
    case 'activity':
      content = <ActivityPage openId={id} />;
      break;
    case 'add':
      content = <AddExpensePage />;
      break;
    case 'ask':
      content = <AssistantPage />;
      break;
    case 'club':
      content = <ClubPage />;
      break;
    case 'overview':
      content = <AccountsOverview />;
      break;
    case 'review':
      content = <ReviewPage openId={id} />;
      break;
    case 'orgs':
      content = id ? <OrgDetailPage id={id} /> : <OrgsPage />;
      break;
    case 'reports':
      content = <ReportsPage />;
      break;
    case 'announce':
      content = <AnnouncementsPage />;
      break;
    case 'advisor':
      content = <AdvisorHome />;
      break;
    case 'users':
    case 'people':
      content = <UsersPage />;
      break;
    case 'settings':
      content = <SettingsPage />;
      break;
  }
  const active = page === 'orgs' && user.role === 'advisor' ? 'advisor' : page;
  return (
    <Shell active={active} hideTabBar={page === 'add'}>
      {content}
    </Shell>
  );
}
