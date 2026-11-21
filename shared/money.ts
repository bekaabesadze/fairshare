import type { AppState, Category, CategoryId, Expense, ExpenseStatus, Org, Role, User } from './types.ts';

export const CATEGORIES: Category[] = [
  { id: 'food', label: 'Food & refreshments', short: 'Food', hint: 'Pizza, cookies, drinks' },
  { id: 'prizes', label: 'Prizes & giveaways', short: 'Prizes', hint: 'Raffles, gift cards, swag' },
  { id: 'printing', label: 'Printing & promotion', short: 'Printing', hint: 'Posters, flyers, banners' },
  { id: 'supplies', label: 'Event supplies', short: 'Supplies', hint: 'Decorations, plates, tape' },
  { id: 'transport', label: 'Transportation', short: 'Travel', hint: 'Vans, buses, gas' },
  { id: 'equipment', label: 'Equipment & materials', short: 'Equipment', hint: 'Tools, kits, gear' },
  { id: 'other', label: 'Other', short: 'Other', hint: 'Anything else' },
];

export const categoryById = (id: CategoryId): Category =>
  CATEGORIES.find((c) => c.id === id) ?? CATEGORIES[CATEGORIES.length - 1];

export const STATUS_LABEL: Record<ExpenseStatus, string> = {
  pending: 'Pending review',
  needs_info: 'Needs documentation',
  approved: 'Approved',
  rejected: 'Rejected',
};

export const ROLE_LABEL: Record<Role, string> = {
  officer: 'Organization officer',
  accounts: 'Student Accounts',
  advisor: 'Faculty advisor',
  platform: 'Platform admin',
};

const round2 = (n: number) => Math.round(n * 100) / 100;

export interface OrgSummary {
  allocated: number;
  approved: number;
  pending: number;
  pendingCount: number;
  needsInfoCount: number;
  remaining: number;
  available: number;
  byCategory: { id: CategoryId; approved: number; pending: number }[];
  usedPct: number;
  pendingPct: number;
}

export function orgSummary(state: AppState, orgId: string): OrgSummary {
  const allocated = round2(
    state.allocations.filter((a) => a.orgId === orgId).reduce((s, a) => s + a.amount, 0),
  );
  const exps = state.expenses.filter((e) => e.orgId === orgId);
  const approved = round2(exps.filter((e) => e.status === 'approved').reduce((s, e) => s + e.amount, 0));
  const pendingList = exps.filter((e) => e.status === 'pending' || e.status === 'needs_info');
  const pending = round2(pendingList.reduce((s, e) => s + e.amount, 0));
  const remaining = round2(allocated - approved);
  const available = round2(remaining - pending);
  const byCategory = CATEGORIES.map((c) => ({
    id: c.id,
    approved: round2(exps.filter((e) => e.category === c.id && e.status === 'approved').reduce((s, e) => s + e.amount, 0)),
    pending: round2(
      exps
        .filter((e) => e.category === c.id && (e.status === 'pending' || e.status === 'needs_info'))
        .reduce((s, e) => s + e.amount, 0),
    ),
  }));
  return {
    allocated,
    approved,
    pending,
    pendingCount: exps.filter((e) => e.status === 'pending').length,
    needsInfoCount: exps.filter((e) => e.status === 'needs_info').length,
    remaining,
    available,
    byCategory,
    usedPct: allocated > 0 ? Math.min(1, approved / allocated) : 0,
    pendingPct: allocated > 0 ? Math.min(1, pending / allocated) : 0,
  };
}

export function campusSummary(state: AppState) {
  const orgs = state.orgs.filter((o) => o.active);
  const per = orgs.map((o) => ({ org: o, s: orgSummary(state, o.id) }));
  const allocated = round2(per.reduce((s, p) => s + p.s.allocated, 0));
  const approved = round2(per.reduce((s, p) => s + p.s.approved, 0));
  const pending = round2(per.reduce((s, p) => s + p.s.pending, 0));
  const queue = state.expenses.filter((e) => e.status === 'pending');
  const waiting = state.expenses.filter((e) => e.status === 'needs_info');
  const byCategory = CATEGORIES.map((c) => ({
    id: c.id,
    approved: round2(
      state.expenses.filter((e) => e.category === c.id && e.status === 'approved').reduce((s, e) => s + e.amount, 0),
    ),
  }));
  const fundingSubmitted = orgs.filter((o) => o.funding.status !== 'not_started').length;
  return { orgs: per, allocated, approved, pending, remaining: round2(allocated - approved), queue, waiting, byCategory, fundingSubmitted, orgCount: orgs.length };
}

export function monthlySpend(expenses: Expense[], today: string, months = 4) {
  const end = new Date(today + 'T12:00:00');
  const out: { key: string; label: string; total: number }[] = [];
  for (let i = months - 1; i >= 0; i--) {
    const d = new Date(end.getFullYear(), end.getMonth() - i, 1);
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    out.push({ key, label: d.toLocaleString('en-US', { month: 'short' }), total: 0 });
  }
  for (const e of expenses) {
    if (e.status !== 'approved') continue;
    const k = e.date.slice(0, 7);
    const row = out.find((r) => r.key === k);
    if (row) row.total = round2(row.total + e.amount);
  }
  return out;
}

export function visibleOrgIds(state: AppState, user: User): string[] {
  if (user.role === 'accounts' || user.role === 'platform') return state.orgs.map((o) => o.id);
  return user.orgIds;
}

export function canSeeCboard(user: User, org: Org): boolean {
  if (user.role === 'accounts') return true;
  if (user.role === 'officer' || user.role === 'advisor') return user.orgIds.includes(org.id);
  return false;
}

export const can = {
  submitExpense: (u: User, orgId: string) => u.role === 'officer' && u.orgIds.includes(orgId),
  review: (u: User) => u.role === 'accounts',
  adjustBudget: (u: User) => u.role === 'accounts',
  publish: (u: User) => u.role === 'accounts',
  downloadReports: (u: User) => u.role !== 'platform',
  manageUsers: (u: User) => u.role === 'accounts' || u.role === 'platform',
  manageOrgs: (u: User) => u.role === 'platform' || u.role === 'accounts',
};

export const usd = (n: number, opts: { cents?: boolean } = {}) =>
  n.toLocaleString('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: opts.cents === false ? 0 : 2,
    maximumFractionDigits: opts.cents === false ? 0 : 2,
  });

export const shortDate = (iso: string) =>
  new Date(iso.length === 10 ? iso + 'T12:00:00' : iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });

export const longDate = (iso: string) =>
  new Date(iso.length === 10 ? iso + 'T12:00:00' : iso).toLocaleDateString('en-US', {
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  });

export function relativeTime(iso: string, now = new Date()) {
  const d = new Date(iso);
  const s = Math.round((now.getTime() - d.getTime()) / 1000);
  if (s < 45) return 'Just now';
  const m = Math.round(s / 60);
  if (m < 60) return `${m}m ago`;
  const h = Math.round(m / 60);
  if (h < 24) return `${h}h ago`;
  const days = Math.round(h / 24);
  if (days < 7) return `${days}d ago`;
  return shortDate(iso);
}

export function daysUntil(date: string, today: string) {
  const a = new Date(today + 'T12:00:00').getTime();
  const b = new Date(date + 'T12:00:00').getTime();
  return Math.round((b - a) / 86400000);
}

export const uid = (prefix: string) =>
  `${prefix}_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 7)}`;
