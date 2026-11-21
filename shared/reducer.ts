import type { Action, AppState, Notice } from './types.ts';
import { makeSeed } from './seed.ts';
import { usd, uid } from './money.ts';

const notice = (n: Omit<Notice, 'id' | 'readBy' | 'at'> & { at?: string }): Notice => ({
  id: uid('nt'),
  readBy: [],
  at: n.at ?? new Date().toISOString(),
  ...n,
});

export function reduce(prev: AppState, action: Action): AppState {
  if (action.type === 'demo/reset') return makeSeed();

  const s: AppState = structuredClone(prev);
  const now = new Date().toISOString();
  s.version = prev.version + 1;
  s.updatedAt = now;

  switch (action.type) {
    case 'expense/submit': {
      const e = action.expense;
      if (s.expenses.some((x) => x.id === e.id)) return prev;
      s.expenses.unshift({ ...e, status: 'pending', history: e.history?.length ? e.history : [{ at: e.submittedAt, by: e.submittedBy, action: 'submitted' }] });
      const org = s.orgs.find((o) => o.id === e.orgId);
      s.notices.unshift(
        notice({
          to: { role: 'accounts' },
          kind: 'submitted',
          title: `New expense from ${org?.name ?? 'an organization'}`,
          body: `${e.docType === 'check' ? `Check${e.checkNumber ? ` #${e.checkNumber}` : ''}` : 'Receipt'} · ${e.vendor} · ${usd(e.amount)}`,
          ref: e.id,
        }),
      );
      return s;
    }

    case 'expense/review': {
      const e = s.expenses.find((x) => x.id === action.id);
      if (!e) return prev;
      const at = action.at ?? now;
      e.status = action.status;
      e.reviewNote = action.note || undefined;
      e.reviewedBy = action.by;
      e.reviewedAt = at;
      e.history.push({ at, by: action.by, action: action.status, note: action.note || undefined });
      const verb = action.status === 'approved' ? 'approved' : action.status === 'rejected' ? 'declined' : 'needs more documentation for';
      s.notices.unshift(
        notice({
          to: { orgId: e.orgId },
          kind: action.status,
          at,
          title:
            action.status === 'approved'
              ? `${usd(e.amount)} approved`
              : action.status === 'rejected'
                ? `${usd(e.amount)} was not approved`
                : 'Student Accounts needs one more document',
          body: `Student Accounts ${verb} ${e.vendor} · ${e.description}${action.note ? ` — “${action.note}”` : ''}`,
          ref: e.id,
        }),
      );
      return s;
    }

    case 'expense/document': {
      const e = s.expenses.find((x) => x.id === action.id);
      if (!e) return prev;
      const at = action.at ?? now;
      if (action.image) e.image = action.image;
      e.status = 'pending';
      e.history.push({ at, by: action.by, action: 'documented', note: action.note });
      const org = s.orgs.find((o) => o.id === e.orgId);
      s.notices.unshift(
        notice({ to: { role: 'accounts' }, kind: 'submitted', at, title: `${org?.name ?? 'An organization'} added documentation`, body: `${e.vendor} · ${usd(e.amount)} is back in your queue.`, ref: e.id }),
      );
      return s;
    }

    case 'budget/adjust': {
      const a = action.allocation;
      s.allocations.push(a);
      s.notices.unshift(
        notice({
          to: { orgId: a.orgId },
          kind: 'budget',
          at: a.at,
          title: a.amount >= 0 ? `${usd(a.amount)} added to your budget` : `${usd(Math.abs(a.amount))} removed from your budget`,
          body: a.note,
        }),
      );
      return s;
    }

    case 'announcement/publish': {
      const a = action.announcement;
      s.announcements.unshift(a);
      const targets = a.audience === 'all' ? [{ role: 'officer' as const }] : a.audience.map((orgId) => ({ orgId }));
      for (const to of targets) {
        s.notices.unshift(notice({ to, kind: 'announcement', at: a.createdAt, title: a.title, body: a.dueDate ? `Due ${new Date(a.dueDate + 'T12:00:00').toLocaleDateString('en-US', { month: 'long', day: 'numeric' })}` : a.body.slice(0, 90), ref: a.id }));
      }
      return s;
    }

    case 'document/add': {
      s.documents.unshift(action.document);
      return s;
    }

    case 'funding/submit': {
      const o = s.orgs.find((x) => x.id === action.orgId);
      if (!o) return prev;
      o.funding = { status: 'submitted', submittedAt: action.at ?? now, requested: action.requested };
      s.notices.unshift(
        notice({ to: { role: 'accounts' }, kind: 'funding', title: `${o.name} submitted its funding request`, body: action.requested ? `Requested ${usd(action.requested)} for 2027–28` : 'Annual funding request received' }),
      );
      return s;
    }

    case 'access/report': {
      const u = s.users.find((x) => x.id === action.userId);
      if (!u) return prev;
      const orgs = s.orgs.filter((o) => u.orgIds.includes(o.id)).map((o) => o.name);
      const to = { role: 'accounts' as const };
      s.notices.unshift(
        notice({ to, kind: 'access', at: action.at ?? now, title: `${u.name} says their account is set up wrong`, body: `${u.email} is linked to ${orgs.length ? orgs.join(', ') : u.title}.` }),
      );
      return s;
    }

    case 'org/create': {
      if (s.orgs.some((o) => o.id === action.org.id)) return prev;
      s.orgs.push(action.org);
      if (action.allocation) s.allocations.push(action.allocation);
      const adv = s.users.find((u) => u.id === action.org.advisorId);
      if (adv && !adv.orgIds.includes(action.org.id)) adv.orgIds.push(action.org.id);
      return s;
    }

    case 'org/update': {
      const o = s.orgs.find((x) => x.id === action.id);
      if (!o) return prev;
      Object.assign(o, action.patch);
      return s;
    }

    case 'user/create': {
      if (s.users.some((u) => u.email.toLowerCase() === action.user.email.toLowerCase())) return prev;
      s.users.push(action.user);
      return s;
    }

    case 'user/update': {
      const u = s.users.find((x) => x.id === action.id);
      if (!u) return prev;
      Object.assign(u, action.patch);
      return s;
    }

    case 'notice/read': {
      for (const n of s.notices) if (action.ids.includes(n.id) && !n.readBy.includes(action.userId)) n.readBy.push(action.userId);
      return s;
    }

    case 'settings/update': {
      s.institution = { ...s.institution, ...action.patch };
      return s;
    }
  }
  return prev;
}

export function noticesFor(state: AppState, user: { id: string; role: string; orgIds: string[] }) {
  return state.notices
    .filter((n) => {
      if (n.to.userId) return n.to.userId === user.id;
      if (n.to.orgId) return (user.role === 'officer' || user.role === 'advisor') && user.orgIds.includes(n.to.orgId);
      if (n.to.role) return n.to.role === user.role;
      return false;
    })
    .sort((a, b) => b.at.localeCompare(a.at));
}
