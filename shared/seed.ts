import type { Allocation, AppState, Expense, Org, User } from './types.ts';

const ACCOUNTS = 'u_jordan';

const orgs: Org[] = [
  {
    id: 'uptous',
    name: 'Up to Us',
    initials: 'UU',
    email: 'uptous@luther.edu',
    cboard: '48210',
    advisorId: 'u_olsen',
    term: 'Fall 2026',
    mission: 'Student-led campaign promoting financial wellness and civic engagement.',
    active: true,
    funding: { status: 'not_started' },
  },
  {
    id: 'bizclub',
    name: 'Luther Business Club',
    initials: 'BC',
    email: 'businessclub@luther.edu',
    cboard: '48117',
    advisorId: 'u_haugen',
    term: 'Fall 2026',
    mission: 'Networking, case competitions and career events for future business leaders.',
    active: true,
    funding: { status: 'submitted', submittedAt: '2026-11-12T15:20:00Z', requested: 2400 },
  },
  {
    id: 'csclub',
    name: 'Computer Science Club',
    initials: 'CS',
    email: 'csclub@luther.edu',
    cboard: '48344',
    advisorId: 'u_haugen',
    term: 'Fall 2026',
    mission: 'Hack nights, tech talks and the annual campus hackathon.',
    active: true,
    funding: { status: 'submitted', submittedAt: '2026-11-08T19:02:00Z', requested: 1800 },
  },
  {
    id: 'isa',
    name: 'International Student Association',
    initials: 'IS',
    email: 'isa@luther.edu',
    cboard: '48056',
    advisorId: 'u_berg',
    term: 'Fall 2026',
    mission: 'Celebrating the cultures of Luther’s international community.',
    active: true,
    funding: { status: 'approved', submittedAt: '2026-10-30T10:00:00Z', requested: 3000 },
  },
  {
    id: 'eco',
    name: 'Environmental Concerns Org',
    initials: 'EC',
    email: 'eco@luther.edu',
    cboard: '48402',
    advisorId: 'u_olsen',
    term: 'Fall 2026',
    mission: 'Campus sustainability projects, garden days and film screenings.',
    active: true,
    funding: { status: 'not_started' },
  },
  {
    id: 'outdoor',
    name: 'Ski & Outdoor Club',
    initials: 'SO',
    email: 'outdoorclub@luther.edu',
    cboard: '48271',
    advisorId: 'u_berg',
    term: 'Fall 2026',
    mission: 'Trips, gear library and weekend adventures around Decorah.',
    active: true,
    funding: { status: 'submitted', submittedAt: '2026-11-17T21:40:00Z', requested: 1500 },
  },
  {
    id: 'dance',
    name: 'Dance Marathon',
    initials: 'DM',
    email: 'dancemarathon@luther.edu',
    cboard: '48190',
    advisorId: 'u_berg',
    term: 'Fall 2026',
    mission: 'Year-long fundraising that ends in one big night of dancing.',
    active: true,
    funding: { status: 'not_started' },
  },
  {
    id: 'chess',
    name: 'Chess Club',
    initials: 'CC',
    email: 'chess@luther.edu',
    cboard: '48333',
    advisorId: 'u_haugen',
    term: 'Fall 2026',
    mission: 'Weekly casual play and two tournaments a semester.',
    active: true,
    funding: { status: 'not_started' },
  },
];

const users: User[] = [
  { id: 'u_alex', name: 'Beka Abesadze', email: 'abesbe01@luther.edu', role: 'officer', title: 'Treasurer · Up to Us', orgIds: ['uptous'], active: true },
  { id: 'u_sofia', name: 'Sofia Martinez', email: 'sofia.martinez@luther.edu', role: 'officer', title: 'President · Up to Us', orgIds: ['uptous'], active: true },
  { id: 'u_priya', name: 'Priya Shah', email: 'priya.shah@luther.edu', role: 'officer', title: 'Treasurer · Computer Science Club', orgIds: ['csclub'], active: true },
  { id: 'u_marcus', name: 'Marcus Bell', email: 'marcus.bell@luther.edu', role: 'officer', title: 'Treasurer · Luther Business Club', orgIds: ['bizclub'], active: true },
  { id: 'u_lena', name: 'Lena Okafor', email: 'lena.okafor@luther.edu', role: 'officer', title: 'President · Intl. Student Association', orgIds: ['isa'], active: true },
  { id: 'u_nora', name: 'Nora Lindqvist', email: 'nora.lindqvist@luther.edu', role: 'officer', title: 'Treasurer · Environmental Concerns Org', orgIds: ['eco'], active: true },
  { id: 'u_kai', name: 'Kai Thompson', email: 'kai.thompson@luther.edu', role: 'officer', title: 'Treasurer · Ski & Outdoor Club', orgIds: ['outdoor'], active: true },
  { id: 'u_maya', name: 'Maya Johnson', email: 'maya.johnson@luther.edu', role: 'officer', title: 'Treasurer · Dance Marathon', orgIds: ['dance'], active: true },
  { id: 'u_theo', name: 'Theo Nguyen', email: 'theo.nguyen@luther.edu', role: 'officer', title: 'President · Chess Club', orgIds: ['chess'], active: true },
  { id: ACCOUNTS, name: 'Sab Abesadze', email: 'abessa01@luther.edu', role: 'accounts', title: 'Student Accounts', orgIds: [], active: true },
  { id: 'u_olsen', name: 'Prof. Maren Olsen', email: 'maren.olsen@luther.edu', role: 'advisor', title: 'Faculty advisor', orgIds: ['uptous', 'eco'], active: true },
  { id: 'u_haugen', name: 'Dr. Erik Haugen', email: 'erik.haugen@luther.edu', role: 'advisor', title: 'Faculty advisor', orgIds: ['bizclub', 'csclub', 'chess'], active: true },
  { id: 'u_berg', name: 'Prof. Ingrid Berg', email: 'ingrid.berg@luther.edu', role: 'advisor', title: 'Faculty advisor', orgIds: ['isa', 'outdoor', 'dance'], active: true },
  { id: 'u_sam', name: 'Sam Taylor', email: 'sam.taylor@luther.edu', role: 'platform', title: 'Platform administrator', orgIds: [], active: true },
];

const alloc = (orgId: string, amount: number, at = '2026-09-12T15:00:00Z', note = 'Fall 2026 allocation'): Allocation => ({
  id: `al_${orgId}_${at.slice(0, 10)}`,
  orgId,
  amount,
  note,
  at,
  by: ACCOUNTS,
});

const allocations: Allocation[] = [
  alloc('uptous', 600),
  alloc('bizclub', 1200),
  alloc('csclub', 900),
  alloc('isa', 1500),
  alloc('isa', 250, '2026-10-21T14:00:00Z', 'Supplemental — International Night'),
  alloc('eco', 450),
  alloc('outdoor', 750),
  alloc('dance', 400),
  alloc('chess', 200),
];

let n = 0;
type Partial2 = Omit<Expense, 'id' | 'history' | 'submittedAt' | 'docType'> & {
  docType?: Expense['docType'];
  submittedAt?: string;
};

function exp(e: Partial2): Expense {
  n += 1;
  const submittedAt = e.submittedAt ?? `${e.date}T18:${String(10 + (n % 40)).padStart(2, '0')}:00Z`;
  const history: Expense['history'] = [{ at: submittedAt, by: e.submittedBy, action: 'submitted' }];
  if (e.status !== 'pending' && e.reviewedAt) {
    history.push({
      at: e.reviewedAt,
      by: e.reviewedBy ?? ACCOUNTS,
      action: e.status === 'approved' ? 'approved' : e.status === 'rejected' ? 'rejected' : 'needs_info',
      note: e.reviewNote,
    });
  }
  return { docType: 'receipt', ...e, id: `ex_${String(n).padStart(3, '0')}`, submittedAt, history };
}

const reviewed = (date: string, hour = '16:05') => ({ reviewedAt: `${date}T${hour}:00Z`, reviewedBy: ACCOUNTS });

const expenses: Expense[] = [
  exp({
    orgId: 'uptous',
    vendor: 'Document Center',
    category: 'printing',
    description: 'Posters for the Up to Us Day of Action',
    amount: 35,
    date: '2026-11-10',
    status: 'needs_info',
    reviewNote: 'Please attach the itemized Document Center invoice — the card slip only shows the total.',
    ...reviewed('2026-11-12', '14:30'),
    submittedBy: 'u_sofia',
    image: '/samples/docucenter.png',
    scanned: ['vendor', 'date', 'amount'],
  }),
  exp({
    orgId: 'uptous',
    vendor: "Domino's Pizza",
    category: 'food',
    description: 'Pizza for the Day of Action volunteer meeting',
    amount: 85,
    tax: 5.79,
    date: '2026-11-15',
    status: 'pending',
    submittedBy: 'u_alex',
    image: '/samples/pizza.png',
    items: [
      { name: 'Large pepperoni x3', amount: 47.97 },
      { name: 'Large cheese x2', amount: 31.24 },
    ],
    scanned: ['vendor', 'date', 'amount', 'tax', 'items'],
  }),

  exp({ orgId: 'bizclub', vendor: 'Luther Dining Services', category: 'food', description: 'Catering — Alumni networking night', amount: 310, date: '2026-10-02', status: 'approved', ...reviewed('2026-10-04'), submittedBy: 'u_marcus' }),
  exp({ orgId: 'bizclub', vendor: 'Jefferson Lines', category: 'transport', description: 'Bus tickets — Des Moines case competition', amount: 180, date: '2026-10-19', status: 'approved', ...reviewed('2026-10-21'), submittedBy: 'u_marcus' }),
  exp({ orgId: 'bizclub', vendor: 'Document Center', category: 'printing', description: 'Name badges and agendas', amount: 45.5, date: '2026-10-01', status: 'approved', ...reviewed('2026-10-03'), submittedBy: 'u_marcus' }),
  exp({ orgId: 'bizclub', vendor: 'Luther Book Shop', category: 'prizes', description: 'Case competition winner gift cards', amount: 120, date: '2026-11-17', status: 'pending', submittedBy: 'u_marcus', image: '/samples/bookshop-gift.png', scanned: ['vendor', 'date', 'amount'] }),

  exp({ orgId: 'csclub', vendor: 'Walmart', category: 'food', description: 'Hack night snacks and drinks', amount: 142.37, tax: 9.41, date: '2026-09-25', status: 'approved', ...reviewed('2026-09-28'), submittedBy: 'u_priya' }),
  exp({ orgId: 'csclub', vendor: 'Micro Center', category: 'equipment', description: 'Raspberry Pi kits for workshop', amount: 219.8, date: '2026-10-08', status: 'approved', ...reviewed('2026-10-10'), submittedBy: 'u_priya' }),
  exp({ orgId: 'csclub', vendor: 'Custom Ink', category: 'prizes', description: 'Hackathon T-shirts', amount: 260, date: '2026-10-28', status: 'approved', ...reviewed('2026-10-30'), submittedBy: 'u_priya' }),
  exp({ orgId: 'csclub', vendor: 'Amazon', category: 'other', description: 'Gaming chair for club room', amount: 189, date: '2026-11-03', status: 'rejected', reviewNote: 'Furniture for a club room is not an eligible expense under the allocation guidelines.', ...reviewed('2026-11-05'), submittedBy: 'u_priya' }),
  exp({ orgId: 'csclub', docType: 'check', vendor: 'Decorah Makerspace', category: 'equipment', description: 'Soldering workshop materials (check #1042)', amount: 150, date: '2026-11-18', checkNumber: '1042', memo: 'Soldering workshop', status: 'pending', submittedBy: 'u_priya', image: '/samples/check.png', scanned: ['vendor', 'date', 'amount', 'checkNumber', 'memo'] }),

  exp({ orgId: 'isa', vendor: 'Oneota Community Food Co-op', category: 'food', description: 'International Night ingredients', amount: 640, date: '2026-10-24', status: 'approved', ...reviewed('2026-10-27'), submittedBy: 'u_lena' }),
  exp({ orgId: 'isa', vendor: 'Party City', category: 'supplies', description: 'Flags and decorations', amount: 95.5, date: '2026-10-20', status: 'approved', ...reviewed('2026-10-22'), submittedBy: 'u_lena' }),
  exp({ orgId: 'isa', vendor: 'Luther Transportation', category: 'transport', description: 'Van rental — Minneapolis cultural trip', amount: 300, date: '2026-09-20', status: 'approved', ...reviewed('2026-09-23'), submittedBy: 'u_lena' }),
  exp({ orgId: 'isa', vendor: 'Document Center', category: 'printing', description: 'International Night posters', amount: 62, date: '2026-10-12', status: 'approved', ...reviewed('2026-10-14'), submittedBy: 'u_lena' }),

  exp({ orgId: 'eco', vendor: 'Fareway', category: 'supplies', description: 'Seeds and soil for garden day', amount: 64.25, date: '2026-09-18', status: 'approved', ...reviewed('2026-09-21'), submittedBy: 'u_nora' }),
  exp({ orgId: 'eco', vendor: 'Bullfrog Films', category: 'other', description: 'Screening license — documentary night', amount: 150, date: '2026-10-15', status: 'approved', ...reviewed('2026-10-16'), submittedBy: 'u_nora' }),
  exp({ orgId: 'eco', vendor: 'Home Depot', category: 'equipment', description: 'Compost bins for residence halls', amount: 89.99, date: '2026-11-16', status: 'pending', submittedBy: 'u_nora' }),

  exp({ orgId: 'outdoor', vendor: 'Luther Transportation', category: 'transport', description: 'Van rental — Lake Pepin trip', amount: 268, date: '2026-10-09', status: 'approved', ...reviewed('2026-10-12'), submittedBy: 'u_kai' }),
  exp({ orgId: 'outdoor', vendor: 'Decorah Bicycles', category: 'equipment', description: 'Gear library repairs', amount: 74, date: '2026-10-30', status: 'approved', ...reviewed('2026-11-02'), submittedBy: 'u_kai' }),

  exp({ orgId: 'dance', vendor: 'Document Center', category: 'printing', description: 'Kickoff flyers', amount: 58, date: '2026-09-30', status: 'approved', ...reviewed('2026-10-02'), submittedBy: 'u_maya' }),
  exp({ orgId: 'dance', vendor: 'Walmart', category: 'supplies', description: 'Glow sticks for the big night', amount: 46, date: '2026-11-19', status: 'pending', submittedBy: 'u_maya' }),

  exp({ orgId: 'chess', vendor: 'Kwik Star', category: 'food', description: 'Snacks — fall tournament', amount: 18.5, date: '2026-10-17', status: 'approved', ...reviewed('2026-10-19'), submittedBy: 'u_theo' }),
];

export function makeSeed(): AppState {
  return {
    version: 1,
    updatedAt: '2026-11-20T08:00:00Z',
    institution: { name: 'Luther College', domain: 'luther.edu', term: 'Fall 2026', aiEnabled: true },
    orgs: structuredClone(orgs),
    users: structuredClone(users),
    expenses: structuredClone(expenses),
    allocations: structuredClone(allocations),
    announcements: [
      {
        id: 'an_funding',
        title: 'Submit your 2027–28 annual funding request',
        body:
          'Every registered organization must submit the annual funding request to receive a budget for the upcoming academic year. Have your officers agree on the amount first, then fill out the form once for the whole organization.',
        kind: 'funding',
        audience: 'all',
        dueDate: '2026-12-11',
        link: 'https://docs.google.com/forms',
        linkLabel: 'Open funding request form',
        requiresAction: true,
        createdAt: '2026-11-01T14:00:00Z',
        by: ACCOUNTS,
      },
      {
        id: 'an_receipts',
        title: 'Submit receipts within two weeks of purchase',
        body:
          'Upload the itemized receipt (not just the card slip) for every purchase within 14 days so we can close the books for the semester on time.',
        kind: 'deadline',
        audience: 'all',
        requiresAction: false,
        createdAt: '2026-10-05T14:00:00Z',
        by: ACCOUNTS,
      },
    ],
    documents: [
      { id: 'doc_form', title: '2027–28 Annual Funding Request', kind: 'form', summary: 'Google Form · one submission per organization', url: 'https://docs.google.com/forms', updatedAt: '2026-11-01', audience: 'all' },
      { id: 'doc_guide', title: 'Student Organization Purchasing Guide', kind: 'guide', summary: 'How to buy with your C-board number and what to keep', updatedAt: '2026-08-20', audience: 'all' },
      { id: 'doc_print', title: 'Document Center print request', kind: 'template', summary: 'Email documentcenter@luther.edu with size, quantity and due date', updatedAt: '2026-08-20', audience: 'all' },
      { id: 'doc_policy', title: 'Eligible & ineligible expenses', kind: 'policy', summary: 'What allocations can and cannot pay for', updatedAt: '2026-08-20', audience: 'all' },
    ],
    notices: [
      {
        id: 'nt_needsinfo',
        to: { orgId: 'uptous' },
        title: 'Posters need one more document',
        body: 'Student Accounts asked for the itemized Document Center invoice for $35.00.',
        at: '2026-11-12T14:30:00Z',
        kind: 'needs_info',
        ref: 'ex_001',
        readBy: [],
      },
      {
        id: 'nt_funding',
        to: { role: 'officer' },
        title: 'Annual funding request is open',
        body: 'Submit your 2027–28 request by December 11.',
        at: '2026-11-01T14:00:00Z',
        kind: 'announcement',
        ref: 'an_funding',
        readBy: [],
      },
      {
        id: 'nt_q1',
        to: { role: 'accounts' },
        title: 'New expense from Computer Science Club',
        body: 'Check #1042 · Decorah Makerspace · $150.00',
        at: '2026-11-18T19:12:00Z',
        kind: 'submitted',
        ref: 'ex_011',
        readBy: [],
      },
    ],
  };
}

export const DEMO_ACCOUNTS = [
  { userId: 'u_alex', role: 'officer' as const, label: 'Organization officer', who: 'Beka Abesadze · Up to Us' },
  { userId: 'u_jordan', role: 'accounts' as const, label: 'Student Accounts', who: 'Sab Abesadze · Student Accounts' },
  { userId: 'u_olsen', role: 'advisor' as const, label: 'Faculty advisor', who: 'Prof. Maren Olsen · 2 orgs' },
];
