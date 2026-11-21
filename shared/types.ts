export type Role = 'officer' | 'accounts' | 'advisor' | 'platform';

export type ExpenseStatus = 'pending' | 'needs_info' | 'approved' | 'rejected';

export type DocType = 'receipt' | 'check';

export type CategoryId =
  | 'food'
  | 'prizes'
  | 'printing'
  | 'supplies'
  | 'transport'
  | 'equipment'
  | 'other';

export interface Category {
  id: CategoryId;
  label: string;
  short: string;
  hint: string;
}

export interface LineItem {
  name: string;
  amount: number;
}

export interface ExpenseEvent {
  at: string;
  by: string;
  action: 'submitted' | 'approved' | 'rejected' | 'needs_info' | 'documented' | 'edited';
  note?: string;
}

export interface Expense {
  id: string;
  orgId: string;
  docType: DocType;
  vendor: string;
  category: CategoryId;
  description: string;
  amount: number;
  tax?: number;
  date: string;
  items?: LineItem[];
  checkNumber?: string;
  memo?: string;
  image?: string;
  scanned?: string[];
  status: ExpenseStatus;
  submittedBy: string;
  submittedAt: string;
  reviewNote?: string;
  reviewedBy?: string;
  reviewedAt?: string;
  history: ExpenseEvent[];
}

export interface Allocation {
  id: string;
  orgId: string;
  amount: number;
  note: string;
  at: string;
  by: string;
}

export type FundingStatus = 'not_started' | 'submitted' | 'approved';

export interface Org {
  id: string;
  name: string;
  initials: string;
  email: string;
  cboard: string;
  advisorId: string;
  term: string;
  mission: string;
  active: boolean;
  funding: { status: FundingStatus; submittedAt?: string; requested?: number };
}

export interface User {
  id: string;
  name: string;
  email: string;
  role: Role;
  title: string;
  orgIds: string[];
  active: boolean;
}

export interface Announcement {
  id: string;
  title: string;
  body: string;
  kind: 'funding' | 'deadline' | 'info';
  audience: 'all' | string[];
  dueDate?: string;
  link?: string;
  linkLabel?: string;
  requiresAction: boolean;
  createdAt: string;
  by: string;
}

export interface DocumentItem {
  id: string;
  title: string;
  kind: 'form' | 'policy' | 'guide' | 'template';
  summary: string;
  url?: string;
  updatedAt: string;
  audience: 'all' | string[];
}

export interface Notice {
  id: string;
  to: { orgId?: string; role?: Role; userId?: string };
  title: string;
  body: string;
  at: string;
  kind: 'approved' | 'rejected' | 'needs_info' | 'submitted' | 'announcement' | 'budget' | 'funding' | 'access';
  ref?: string;
  readBy: string[];
}

export interface AppState {
  version: number;
  updatedAt: string;
  institution: { name: string; domain: string; term: string; aiEnabled: boolean };
  orgs: Org[];
  users: User[];
  expenses: Expense[];
  allocations: Allocation[];
  announcements: Announcement[];
  documents: DocumentItem[];
  notices: Notice[];
}

export type Action =
  | { type: 'expense/submit'; expense: Expense }
  | { type: 'expense/review'; id: string; status: 'approved' | 'rejected' | 'needs_info'; note?: string; by: string; at?: string }
  | { type: 'expense/document'; id: string; image?: string; note?: string; by: string; at?: string }
  | { type: 'budget/adjust'; allocation: Allocation }
  | { type: 'announcement/publish'; announcement: Announcement }
  | { type: 'document/add'; document: DocumentItem }
  | { type: 'funding/submit'; orgId: string; by: string; requested?: number; at?: string }
  | { type: 'org/create'; org: Org; allocation?: Allocation }
  | { type: 'org/update'; id: string; patch: Partial<Org> }
  | { type: 'user/create'; user: User }
  | { type: 'user/update'; id: string; patch: Partial<User> }
  | { type: 'access/report'; userId: string; at?: string }
  | { type: 'notice/read'; userId: string; ids: string[] }
  | { type: 'settings/update'; patch: Partial<AppState['institution']> }
  | { type: 'demo/reset' };

export interface AssistantReply {
  text: string;
  sources: string[];
  draft?: { to: string; subject: string; body: string };
  suggestions?: string[];
  engine: 'claude' | 'local';
}

export interface AssistantMessage {
  role: 'user' | 'assistant';
  text: string;
}
