import type { AppState, AssistantMessage, AssistantReply, CategoryId } from './types.ts';
import { CATEGORIES, categoryById, orgSummary, usd, longDate, daysUntil } from './money.ts';
import { KNOWLEDGE, searchKnowledge } from './knowledge.ts';

const CATEGORY_WORDS: Record<CategoryId, string[]> = {
  food: ['food', 'pizza', 'snack', 'snacks', 'drink', 'drinks', 'refreshment', 'refreshments', 'catering', 'cookies', 'meal'],
  prizes: ['prize', 'prizes', 'giveaway', 'giveaways', 'gift', 'raffle', 'swag', 'shirts'],
  printing: ['print', 'printing', 'poster', 'posters', 'flyer', 'flyers', 'promo', 'promotion', 'banner'],
  supplies: ['supplies', 'supply', 'decoration', 'decorations', 'plates', 'cups'],
  transport: ['transport', 'transportation', 'travel', 'van', 'bus', 'gas', 'trip'],
  equipment: ['equipment', 'materials', 'gear', 'kits', 'tools'],
  other: ['other', 'misc'],
};

const has = (q: string, words: string[]) => words.some((w) => new RegExp(`\\b${w}\\b`, 'i').test(q));

function parseAmount(q: string): number | null {
  const m = q.replace(/,/g, '').match(/\$\s?(\d+(?:\.\d{1,2})?)|(\d+(?:\.\d{1,2})?)\s?(?:dollars|usd|bucks)/i);
  if (!m) return null;
  return parseFloat(m[1] ?? m[2]);
}

function detectCategory(q: string): CategoryId | null {
  for (const c of CATEGORIES) if (has(q, CATEGORY_WORDS[c.id])) return c.id;
  return null;
}

export function buildContext(state: AppState, orgId: string, today: string) {
  const org = state.orgs.find((o) => o.id === orgId)!;
  const s = orgSummary(state, orgId);
  const exps = state.expenses.filter((e) => e.orgId === orgId);
  const funding = state.announcements.find((a) => a.kind === 'funding');
  const lines = [
    `Organization: ${org.name} (${org.term})`,
    `Allocated budget: ${usd(s.allocated)}`,
    `Approved spending: ${usd(s.approved)}`,
    `Pending review (not yet approved): ${usd(s.pending)} across ${s.pendingCount + s.needsInfoCount} expense(s)`,
    `Remaining balance (allocated − approved): ${usd(s.remaining)}`,
    `Safe to spend (remaining − pending): ${usd(s.available)}`,
    `Approved spending by category: ${s.byCategory.filter((c) => c.approved > 0).map((c) => `${categoryById(c.id).short} ${usd(c.approved)}`).join(', ') || 'none yet'}`,
    `Annual funding request: ${org.funding.status === 'not_started' ? 'not submitted yet' : org.funding.status}${funding?.dueDate ? `, due ${longDate(funding.dueDate)} (${daysUntil(funding.dueDate, today)} days from today)` : ''}`,
    `Today: ${longDate(today)}`,
    'Transactions:',
    ...exps.map((e) => `- ${e.date} · ${e.vendor} · ${categoryById(e.category).short} · ${usd(e.amount)} · ${e.status}${e.reviewNote ? ` (note: ${e.reviewNote})` : ''} · ${e.description}`),
  ];
  return lines.join('\n');
}

export const SYSTEM_PROMPT = `You are the FairShare assistant, built into the financial platform that student organizations at Luther College use to track their budgets.

You help organization officers — students, usually with no accounting background — understand their money and follow campus procedures. Write in plain, friendly language. Keep answers short: two to five sentences, or a short list. Use **bold** for the key number.

Rules you must follow:
- Use only the organization data and the Luther knowledge base provided below. Do not invent prices, store hours, contacts, policies or numbers. If the answer is not in the data, say you don't know and suggest asking Student Accounts.
- "Remaining balance" is allocated minus approved spending. "Safe to spend" also subtracts pending expenses. When money matters, always use safe to spend so officers never think they have more than they do, and say how much is pending.
- Never reveal the organization's C-board number; tell the officer it is on the Club tab behind Face ID / reveal.
- When the officer asks you to write an email, write it in full, ready to send, signed with the organization name.`;

export function knowledgeText() {
  return KNOWLEDGE.map((k) => `## ${k.title} (source: ${k.source})\n${k.body}`).join('\n\n');
}

export const SUGGESTED_QUESTIONS = [
  'How much money do we have left?',
  'Can we afford a $150 event next week?',
  'How much did we spend on food this semester?',
  'How do I print posters at Luther?',
  'Where should I buy drinks for our next event?',
  'What documentation do I need to submit?',
];

export function localAnswer(state: AppState, orgId: string, question: string, today: string, _history: AssistantMessage[] = []): AssistantReply {
  const q = question.toLowerCase().trim();
  const org = state.orgs.find((o) => o.id === orgId)!;
  const s = orgSummary(state, orgId);
  const exps = state.expenses.filter((e) => e.orgId === orgId);
  const pendingLine = s.pending > 0 ? ` ${usd(s.pending)} is still pending review, so you can safely spend **${usd(s.available)}**.` : '';
  const reply = (text: string, sources: string[], extra: Partial<AssistantReply> = {}): AssistantReply => ({ text, sources, engine: 'local', ...extra });

  if (has(q, ['c-board', 'cboard', 'c board'])) {
    return reply(
      `For security I don’t show your C-board number in chat. Open the **Club** tab and tap the C-board card — it unlocks with Face ID (or your password on the web). Give that number to the cashier at campus locations like Luther Book Shop so the purchase is charged to ${org.name}.`,
      ['Purchasing Guide'],
    );
  }

  if (has(q, ['print', 'printing', 'poster', 'posters', 'flyer', 'flyers', 'banner']) || (has(q, ['email', 'draft']) && has(q, ['document center']))) {
    const kb = KNOWLEDGE.find((k) => k.id === 'kb_print')!;
    return reply(
      `Posters are printed by the **Luther Document Center**. Email your print-ready file to **documentcenter@luther.edu** with the size, paper, quantity and the date you need it, and include your C-board number so it’s charged to ${org.name}. When the invoice arrives, upload it here as the receipt.\n\nI drafted the email for you below — add your details and send it.`,
      [kb.source, 'Purchasing Guide'],
      {
        draft: {
          to: 'documentcenter@luther.edu',
          subject: `Print request — ${org.name}`,
          body: `Hello Document Center team,\n\n${org.name} would like to request printing for an upcoming event.\n\n• File: attached (print-ready PDF)\n• Size: 11 × 17 in poster\n• Paper: glossy, color\n• Quantity: 25\n• Needed by: [date]\n• C-board number: [your C-board number]\n\nPlease let us know if you need anything else from us. Thank you!\n\nBest,\n[Your name]\n${org.name}`,
        },
        suggestions: ['What documentation do I need to submit?', 'How much did we spend on printing?'],
      },
    );
  }

  const amount = parseAmount(q);
  if (amount !== null && has(q, ['afford', 'enough', 'spend', 'budget', 'cover', 'pay'])) {
    const after = Math.round((s.available - amount) * 100) / 100;
    if (after >= 0) {
      const share = s.allocated > 0 ? Math.round((amount / s.allocated) * 100) : 0;
      return reply(
        `Yes. You can safely spend **${usd(s.available)}** right now${s.pending > 0 ? ` (that already sets aside ${usd(s.pending)} pending review)` : ''}. A ${usd(amount)} event would leave **${usd(after)}** — it uses about ${share}% of your ${usd(s.allocated)} budget.\n\nTip: keep the itemized receipts and upload them within two weeks.`,
        ['Your budget', 'Receipt deadline'],
        { suggestions: ['How can we organize an event while staying within budget?', 'Where should I buy drinks for our next event?'] },
      );
    }
    return reply(
      `Not right now. A ${usd(amount)} event is **${usd(Math.abs(after))} more** than you can safely spend (${usd(s.available)}${s.pending > 0 ? `, after setting aside ${usd(s.pending)} pending review` : ''}). You could trim the plan, split costs with another organization, or ask Student Accounts about supplemental funding.`,
      ['Your budget'],
      { suggestions: ['How can we organize an event while staying within budget?'] },
    );
  }

  if (has(q, ['left', 'remaining', 'balance', 'how much money', 'available', 'have']) && !detectCategory(q)) {
    return reply(
      `${org.name} has **${usd(s.remaining)}** remaining of its ${usd(s.allocated)} ${org.term} budget.${pendingLine}${s.approved > 0 ? ` So far ${usd(s.approved)} has been approved.` : ' Nothing has been approved yet this term.'}`,
      ['Your budget'],
      { suggestions: ['Can we afford a $150 event next week?', 'What is our biggest expense category?'] },
    );
  }

  const cat = detectCategory(q);
  if (cat && has(q, ['spend', 'spent', 'spending', 'cost', 'much', 'total'])) {
    const c = s.byCategory.find((x) => x.id === cat)!;
    const label = categoryById(cat).label.toLowerCase();
    const items = exps.filter((e) => e.category === cat && e.status !== 'rejected');
    const list = items.slice(0, 4).map((e) => `• ${e.vendor} — ${usd(e.amount)} (${e.status === 'approved' ? 'approved' : 'pending'})`).join('\n');
    return reply(
      `This semester ${org.name} has **${usd(c.approved)}** in approved ${label}${c.pending > 0 ? `, plus ${usd(c.pending)} waiting for review` : ''}.${list ? `\n\n${list}` : ''}`,
      ['Your transactions'],
    );
  }

  if (has(q, ['biggest', 'largest', 'most', 'top']) && has(q, ['category', 'expense', 'expenses', 'spend', 'spending', 'money'])) {
    const sorted = [...s.byCategory].sort((a, b) => b.approved + b.pending - (a.approved + a.pending));
    const top = sorted[0];
    if (!top || top.approved + top.pending === 0) return reply(`${org.name} hasn’t recorded any spending yet this term.`, ['Your transactions']);
    return reply(
      `Your biggest category is **${categoryById(top.id).label}** — ${usd(top.approved)} approved${top.pending ? ` and ${usd(top.pending)} pending` : ''}. Next is ${categoryById(sorted[1].id).short.toLowerCase()} at ${usd(sorted[1].approved + sorted[1].pending)}.`,
      ['Your transactions'],
    );
  }

  if (has(q, ['pending', 'waiting', 'review', 'approved yet', 'status'])) {
    const waiting = exps.filter((e) => e.status === 'pending' || e.status === 'needs_info');
    if (!waiting.length) return reply('Nothing is waiting for review — every submitted expense has been processed.', ['Your transactions']);
    return reply(
      `${waiting.length} expense${waiting.length > 1 ? 's are' : ' is'} waiting (**${usd(s.pending)}** total):\n\n${waiting.map((e) => `• ${e.vendor} — ${usd(e.amount)} · ${e.status === 'needs_info' ? 'needs documentation from you' : 'pending review'}`).join('\n')}${waiting.some((e) => e.status === 'needs_info') ? '\n\nOpen Activity to add the missing document.' : ''}`,
      ['Your transactions'],
    );
  }

  if (has(q, ['buy', 'where', 'cheap', 'cheaper', 'cheapest', 'store', 'price', 'prices', 'compare'])) {
    return reply(
      `I don’t have live store prices, so I won’t guess them. For drinks and snacks, compare **Walmart** in Decorah, local grocery stores like **Fareway** or the **Oneota Community Food Co-op**, and **Luther Dining Services** if you want it delivered on campus. Compare the price per can or per ounce and buy in bulk.\n\nYou can safely spend **${usd(s.available)}** right now.`,
      ['FairShare guidance', 'Your budget'],
      { suggestions: ['Can we afford a $150 event next week?'] },
    );
  }

  if (has(q, ['document', 'documentation', 'receipt', 'receipts', 'proof', 'invoice', 'submit'])) {
    const kb = KNOWLEDGE.find((k) => k.id === 'kb_docs')!;
    return reply(
      `Upload an **itemized receipt** that shows the vendor, date, items and total — a card slip with only the total isn’t enough. If you paid by **check**, upload the check or payment document instead and add the check number. Add a one-line description of the event it was for, and submit within two weeks of the purchase.`,
      [kb.source, 'Receipt deadline'],
    );
  }

  if (has(q, ['funding', 'next year', 'annual', 'request', 'form'])) {
    const a = state.announcements.find((x) => x.kind === 'funding');
    const status = org.funding.status === 'not_started' ? 'hasn’t been submitted yet' : org.funding.status === 'submitted' ? 'was submitted — Student Accounts is reviewing it' : 'has been approved';
    return reply(
      `${org.name}’s 2027–28 funding request **${status}**.${a?.dueDate ? ` It’s due **${longDate(a.dueDate)}** (${daysUntil(a.dueDate, today)} days left).` : ''} Agree on the amount with your officers, then open the form from the funding card on Home.`,
      ['Student Accounts announcement'],
    );
  }

  if (has(q, ['plan', 'organize', 'event', 'stay', 'within'])) {
    const b = s.available;
    const part = (p: number) => usd(Math.floor(b * p));
    return reply(
      `With **${usd(b)}** safe to spend, a simple split keeps you on budget:\n\n• Food & drinks — about ${part(0.5)}\n• Prizes or giveaways — about ${part(0.2)}\n• Printing & promotion — about ${part(0.1)}\n• Buffer for surprises — about ${part(0.2)}\n\nPrint through the Document Center, compare grocery prices before buying, and upload each receipt the same week so your balance stays accurate.`,
      ['Your budget', 'Document Center'],
    );
  }

  if (has(q, ['summary', 'recent', 'overview', 'transactions', 'history', 'spent'])) {
    const recent = [...exps].sort((a, b) => b.date.localeCompare(a.date)).slice(0, 4);
    return reply(
      `Here’s ${org.name} at a glance: **${usd(s.remaining)}** remaining of ${usd(s.allocated)}, ${usd(s.approved)} approved, ${usd(s.pending)} pending.\n\n${recent.map((e) => `• ${e.date.slice(5).replace('-', '/')} — ${e.vendor} — ${usd(e.amount)} (${e.status.replace('_', ' ')})`).join('\n')}`,
      ['Your transactions'],
    );
  }

  const kb = searchKnowledge(q, 1)[0];
  if (kb) return reply(kb.body, [kb.source]);

  return reply(
    'I don’t know that one, and I’d rather not guess. I can answer questions about your budget, expenses, receipts, printing and funding requests. For anything else, Student Accounts is the best place to ask.',
    [],
    { suggestions: ['How much money do we have left?', 'What documentation do I need to submit?'] },
  );
}
