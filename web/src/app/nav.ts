import { House, Receipt, PlusCircle, Sparkle, UsersThree, Tray, Buildings, ChartBar, Megaphone, Users, GearSix, type Icon } from '@phosphor-icons/react';
import type { Role } from '../../../shared/types.ts';

export interface NavItem {
  key: string;
  label: string;
  title: string;
  icon: Icon;
}

export const NAV: Record<Role, NavItem[]> = {
  officer: [
    { key: 'home', label: 'Home', title: 'Home', icon: House },
    { key: 'activity', label: 'Activity', title: 'Activity', icon: Receipt },
    { key: 'add', label: 'Add expense', title: 'Add expense', icon: PlusCircle },
    { key: 'ask', label: 'Ask FairShare', title: 'Ask FairShare', icon: Sparkle },
    { key: 'club', label: 'Club', title: 'Club', icon: UsersThree },
  ],
  accounts: [
    { key: 'overview', label: 'Overview', title: 'Overview', icon: House },
    { key: 'review', label: 'Review queue', title: 'Review', icon: Tray },
    { key: 'orgs', label: 'Organizations', title: 'Organizations', icon: Buildings },
    { key: 'people', label: 'People', title: 'People', icon: Users },
    { key: 'reports', label: 'Reports', title: 'Reports', icon: ChartBar },
    { key: 'announce', label: 'Announcements', title: 'Announcements', icon: Megaphone },
  ],
  advisor: [
    { key: 'advisor', label: 'My organizations', title: 'My organizations', icon: House },
    { key: 'activity', label: 'Activity', title: 'Activity', icon: Receipt },
    { key: 'reports', label: 'Reports', title: 'Reports', icon: ChartBar },
  ],
  platform: [
    { key: 'users', label: 'Users & roles', title: 'Users', icon: Users },
    { key: 'orgs', label: 'Organizations', title: 'Organizations', icon: Buildings },
    { key: 'settings', label: 'Platform settings', title: 'Settings', icon: GearSix },
  ],
};

export const homeFor = (role: Role) => NAV[role][0].key;
