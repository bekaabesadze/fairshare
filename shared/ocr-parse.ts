import type { CategoryId, DocType, LineItem } from './types.ts';

export interface ParsedDocument {
  docType: DocType;
  vendor?: string;
  date?: string;
  amount?: number;
  subtotal?: number;
  tax?: number;
  items: LineItem[];
  checkNumber?: string;
  memo?: string;
  category?: CategoryId;
  found: string[];
}

const MONEY = /\$?\s?(\d{1,4}(?:,\d{3})*\.\d{2})\b/g;
const lastMoney = (line: string): number | undefined => {
  const all = [...line.matchAll(MONEY)];
  if (!all.length) return undefined;
  return parseFloat(all[all.length - 1][1].replace(/,/g, ''));
};

const MONTHS = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

export function findDate(text: string): string | undefined {
  const m = text.match(/\b(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})\b/);
  if (m) {
    let [, mo, d, y] = m;
    if (y.length === 2) y = `20${y}`;
    const month = Number(mo), day = Number(d);
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) return `${y}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
  }
  const w = text.match(/\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(\d{1,2}),?\s+(\d{4})/i);
  if (w) {
    const month = MONTHS.indexOf(w[1].toLowerCase()) + 1;
    return `${w[3]}-${String(month).padStart(2, '0')}-${w[2].padStart(2, '0')}`;
  }
  return undefined;
}

const titleCase = (s: string) =>
  s
    .toLowerCase()
    .replace(/(^|[\s-])([a-z])/g, (_, p, c) => p + c.toUpperCase())
    .replace(/\b(Of|And|The|At)\b/g, (w, _1, i) => (i === 0 ? w : w.toLowerCase()))
    .replace(/'S\b/g, "'s");

export function detectDocType(text: string): DocType {
  const t = text.toLowerCase();
  const hits = [/pay\s*to\s*the/, /order\s*of/, /\bmemo\b/, /\bdollars\b/, /authorized\s*signature/, /\bno\.\s*\d{3,6}/].filter((r) => r.test(t)).length;
  return hits >= 2 ? 'check' : 'receipt';
}

export function guessCategory(text: string): CategoryId | undefined {
  const t = text.toLowerCase();
  const rules: [CategoryId, RegExp][] = [
    ['printing', /print|poster|flyer|copies|document center|banner/],
    ['food', /pizza|food|snack|drink|soda|coffee|catering|grocery|cookie|bagel|subway|dining|co-?op/],
    ['transport', /\bbus\b|\bvan\b|fuel|\bgas\b|transport|jefferson lines|mileage|rental car/],
    ['prizes', /gift card|prize|giveaway|sticker|lanyard|water bottle|t-?shirt|book shop|bookshop|mug/],
    ['supplies', /tape|plates|cups|napkin|\bdecorations?\b|balloon|glow|party/],
    ['equipment', /kit|tool|cable|equipment|makerspace|solder|raspberry|gear/],
  ];
  return rules.find(([, r]) => r.test(t))?.[0];
}

export function parseReceipt(raw: string): ParsedDocument {
  const lines = raw
    .split(/\r?\n/)
    .map((l) => l.replace(/\s+/g, ' ').trim())
    .filter((l) => l.length > 0);
  const found: string[] = [];
  const out: ParsedDocument = { docType: 'receipt', items: [], found };

  const nameLike = (l: string) => /[a-z]{3,}/i.test(l) && !/\d{2,}/.test(l) && !/^(date|time|tel|phone|www|http)/i.test(l) && l.length <= 34;
  const idx = lines.findIndex(nameLike);
  if (idx >= 0) {
    let v = lines[idx];
    const next = lines[idx + 1];
    if (v.split(' ').length === 1 && next && nameLike(next) && next === next.toUpperCase()) v = `${v} ${next}`;
    out.vendor = titleCase(v.replace(/[^a-z0-9'&.\s-]/gi, '').trim());
    found.push('vendor');
  }

  out.date = findDate(raw);
  if (out.date) found.push('date');

  const totalLine = lines.find((l) => /\btotal\b/i.test(l) && !/sub\s*-?\s*total/i.test(l) && lastMoney(l) !== undefined);
  const subLine = lines.find((l) => /sub\s*-?\s*total/i.test(l));
  const taxLine = lines.find((l) => /\btax\b/i.test(l) && lastMoney(l) !== undefined);
  if (totalLine) out.amount = lastMoney(totalLine);
  if (subLine) out.subtotal = lastMoney(subLine);
  if (taxLine) out.tax = lastMoney(taxLine);
  if (out.amount === undefined) {
    const all = [...raw.matchAll(MONEY)].map((m) => parseFloat(m[1].replace(/,/g, '')));
    if (all.length) out.amount = Math.max(...all);
  }
  if (out.amount !== undefined) found.push('amount');
  if (out.tax !== undefined) found.push('tax');

  const stopAt = lines.findIndex((l) => /sub\s*-?\s*total|\btotal\b/i.test(l));
  const skip = /total|tax|change|cash|visa|master|amex|debit|credit|paid|balance|auth|approved|tip/i;
  for (const l of lines.slice(0, stopAt >= 0 ? stopAt : lines.length)) {
    const price = lastMoney(l);
    if (price === undefined || skip.test(l) || /date|trans|order|store|reg/i.test(l)) continue;
    let name = l.replace(MONEY, '').replace(/\s{2,}/g, ' ').trim();
    const qty = name.match(/^(.*?)\s+(\d+)\s*[@x]\s*[\d.]*$/i) ?? name.match(/^(.*?)\s+x\s?(\d+)$/i);
    if (qty) name = `${qty[1].trim()} ×${qty[2]}`;
    name = name.replace(/[^a-z0-9×'&\s.-]/gi, '').trim();
    if (name.length >= 3) out.items.push({ name, amount: price });
  }
  if (out.items.length) found.push('items');

  out.category = guessCategory(`${out.vendor ?? ''}\n${raw}`);
  return out;
}

export function parseCheck(raw: string): ParsedDocument {
  const found: string[] = [];
  const out: ParsedDocument = { docType: 'check', items: [], found };
  const flat = raw.replace(/\r?\n/g, '\n');

  const amountLine = flat.split('\n').find((l) => /\$\s?[\d,]+\.\d{2}/.test(l) && /[a-z]{3,}/i.test(l.split('$')[0]));
  let payee = amountLine?.split('$')[0] ?? flat.match(/order\s*of[:\s]*([^\n$]{3,40})/i)?.[1];
  if (payee) {
    const tokens = payee.replace(/pay\s*to\s*the|order\s*of/gi, ' ').trim().split(/\s+/);
    while (tokens.length > 1 && !/^[A-Z][a-zA-Z'&.-]+$/.test(tokens[0])) tokens.shift();
    payee = tokens.join(' ').replace(/[^a-z0-9 '&.-]/gi, '').trim();
    if (payee.length >= 3) {
      out.vendor = payee;
      found.push('vendor');
    }
  }
  const amount = flat.match(/\$\s?([\d,]+\.\d{2})/);
  if (amount) {
    out.amount = parseFloat(amount[1].replace(/,/g, ''));
    found.push('amount');
  }
  const num = flat.match(/\bno\.?\s*(\d{3,6})\b/i);
  if (num) {
    out.checkNumber = num[1];
    found.push('checkNumber');
  }
  out.date = findDate(flat);
  if (out.date) found.push('date');
  const memo = flat.match(/memo[:\s]+([^\n]{3,60})/i);
  if (memo) {
    out.memo = memo[1].replace(/authorized.*$/i, '').replace(/\s{2,}.*/, '').trim();
    if (out.memo) found.push('memo');
  }
  out.category = guessCategory(`${out.vendor ?? ''} ${out.memo ?? ''}`);
  return out;
}

export function parseDocument(raw: string, forced?: DocType): ParsedDocument {
  const type = forced ?? detectDocType(raw);
  return type === 'check' ? parseCheck(raw) : parseReceipt(raw);
}
