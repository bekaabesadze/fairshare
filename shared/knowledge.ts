export interface KnowledgeEntry {
  id: string;
  title: string;
  source: string;
  body: string;
  keywords: string[];
}

export const KNOWLEDGE: KnowledgeEntry[] = [
  {
    id: 'kb_print',
    title: 'Printing posters and flyers',
    source: 'Document Center',
    body:
      'Posters, flyers and banners are printed by the Luther Document Center. Email your print-ready file to documentcenter@luther.edu with the size, paper, quantity, the date you need it, and your organization’s C-board number so the job is charged to your budget. Upload the Document Center invoice to FairShare as the receipt.',
    keywords: ['print', 'poster', 'posters', 'flyer', 'flyers', 'banner', 'document center', 'copies'],
  },
  {
    id: 'kb_cboard',
    title: 'Buying on campus with your C-board number',
    source: 'Purchasing Guide',
    body:
      'At campus purchasing locations such as Luther Book Shop, give the cashier your organization’s C-board number so the purchase is charged to your organization. Keep the itemized receipt and upload it to FairShare the same week.',
    keywords: ['c-board', 'cboard', 'book shop', 'bookshop', 'campus', 'charge', 'buy on campus'],
  },
  {
    id: 'kb_docs',
    title: 'What documentation to submit',
    source: 'Purchasing Guide',
    body:
      'For every purchase, upload an itemized receipt that shows the vendor, date, items and total — a card slip with only the total is not enough. For payments made by check, upload the check or payment document instead and add the check number and memo. Always add a short description of what the purchase was for and which event it supported.',
    keywords: ['document', 'documentation', 'receipt', 'receipts', 'submit', 'check', 'proof', 'invoice', 'need'],
  },
  {
    id: 'kb_deadline',
    title: 'Receipt deadline',
    source: 'Student Accounts announcement',
    body: 'Student Accounts asks organizations to upload receipts within two weeks (14 days) of the purchase.',
    keywords: ['deadline', 'late', 'how long', 'when', 'due'],
  },
  {
    id: 'kb_funding',
    title: 'Annual funding request',
    source: 'Student Accounts announcement',
    body:
      'Each registered organization submits one annual funding request through the Google Form shared in FairShare. The request for 2027–28 is due December 11, 2026. Agree on the amount with your officers first; FairShare tracks whether it has been submitted.',
    keywords: ['funding', 'request', 'budget next year', 'annual', 'allocation', 'form', 'google form'],
  },
  {
    id: 'kb_shopping',
    title: 'Where to buy food and drinks',
    source: 'FairShare guidance',
    body:
      'FairShare does not have live store prices. For drinks and snacks, organizations usually compare Walmart in Decorah, local grocery stores such as Fareway or the Oneota Community Food Co-op, and campus options such as Luther Dining Services. Buying in bulk and comparing unit prices (price per can or per ounce) is the most reliable way to save.',
    keywords: ['drinks', 'soda', 'snacks', 'buy', 'cheap', 'cheaper', 'walmart', 'grocery', 'where', 'store', 'food', 'pizza', 'water'],
  },
  {
    id: 'kb_eligible',
    title: 'Eligible expenses',
    source: 'Eligible & ineligible expenses',
    body:
      'Allocations pay for costs of organization events and activities: food and refreshments, prizes and giveaways, printing and promotion, event supplies, transportation, and equipment and materials. Student Accounts decides eligibility for each expense; anything unusual should be asked about before buying.',
    keywords: ['eligible', 'allowed', 'can we buy', 'can we use', 'policy', 'rules'],
  },
];

export function searchKnowledge(q: string, limit = 2): KnowledgeEntry[] {
  const text = q.toLowerCase();
  return KNOWLEDGE.map((k) => ({ k, score: k.keywords.reduce((s, w) => s + (text.includes(w) ? w.length : 0), 0) }))
    .filter((x) => x.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map((x) => x.k);
}
