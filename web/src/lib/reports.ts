import type { AppState, Expense, Org } from '../../../shared/types.ts';
import type ExcelJSNS from 'exceljs';
import { CATEGORIES, categoryById, orgSummary, STATUS_LABEL, usd, longDate, shortDate, campusSummary } from '../../../shared/money.ts';

export interface ReportOptions {
  preparedFor?: string;
}

function reportData(state: AppState, org: Org) {
  const s = orgSummary(state, org.id);
  const txns = state.expenses.filter((e) => e.orgId === org.id).sort((a, b) => b.date.localeCompare(a.date));
  const allocations = state.allocations.filter((a) => a.orgId === org.id);
  const breakdown = s.byCategory.filter((c) => c.approved + c.pending > 0);
  return { s, txns, allocations, breakdown };
}

function download(blob: Blob, name: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}

const slug = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');

async function logoDataUrl(): Promise<string | null> {
  try {
    const res = await fetch('/apple-touch-icon.png');
    const blob = await res.blob();
    return await new Promise((resolve) => {
      const r = new FileReader();
      r.onload = () => resolve(String(r.result));
      r.readAsDataURL(blob);
    });
  } catch {
    return null;
  }
}

const INK: [number, number, number] = [21, 21, 23];
const MUTED: [number, number, number] = [110, 110, 116];
const ACCENT: [number, number, number] = [36, 83, 230];
const HAIR: [number, number, number] = [228, 228, 224];

export async function downloadPdf(state: AppState, org: Org, opts: ReportOptions = {}) {
  const [{ jsPDF }, { default: autoTable }] = await Promise.all([import('jspdf'), import('jspdf-autotable')]);
  const { s, txns, breakdown } = reportData(state, org);
  const doc = new jsPDF({ unit: 'pt', format: 'letter' });
  const W = doc.internal.pageSize.getWidth();
  const M = 48;
  const logo = await logoDataUrl();

  if (logo) doc.addImage(logo, 'PNG', M, 40, 26, 26);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(13);
  doc.setTextColor(...INK);
  doc.text('FairShare', M + 34, 58);
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(9);
  doc.setTextColor(...MUTED);
  doc.text('FINANCIAL REPORT', W - M, 50, { align: 'right' });
  doc.text(`${state.institution.name} · Student Accounts`, W - M, 62, { align: 'right' });

  doc.setDrawColor(...HAIR);
  doc.line(M, 84, W - M, 84);

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(24);
  doc.setTextColor(...INK);
  doc.text(`${org.name} — ${org.term}`, M, 122);
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(10);
  doc.setTextColor(...MUTED);
  doc.text(
    `Generated ${longDate(new Date().toISOString())}${opts.preparedFor ? ` · Prepared for ${opts.preparedFor}` : ''} · C-board ••• ${org.cboard.slice(-2)}`,
    M,
    142,
  );

  const tiles: [string, string, [number, number, number]][] = [
    ['Original budget', usd(s.allocated), INK],
    ['Approved expenses', usd(s.approved), INK],
    ['Remaining balance', usd(s.remaining), ACCENT],
    ['Pending review', usd(s.pending), [143, 100, 0]],
  ];
  const tw = (W - M * 2 - 12 * 3) / 4;
  tiles.forEach(([label, value, color], i) => {
    const x = M + i * (tw + 12);
    doc.setFillColor(245, 245, 243);
    doc.roundedRect(x, 166, tw, 70, 8, 8, 'F');
    doc.setFontSize(8);
    doc.setTextColor(...MUTED);
    doc.text(label.toUpperCase(), x + 12, 186);
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(17);
    doc.setTextColor(...color);
    doc.text(value, x + 12, 216);
    doc.setFont('helvetica', 'normal');
  });

  const by = 258;
  const bw = W - M * 2;
  doc.setFillColor(231, 231, 227);
  doc.roundedRect(M, by, bw, 8, 4, 4, 'F');
  const used = s.allocated > 0 ? Math.min(1, s.approved / s.allocated) : 0;
  const pend = s.allocated > 0 ? Math.min(1 - used, s.pending / s.allocated) : 0;
  if (used > 0) {
    doc.setFillColor(...INK);
    doc.roundedRect(M, by, bw * used, 8, 4, 4, 'F');
  }
  if (pend > 0) {
    doc.setFillColor(224, 161, 0);
    doc.roundedRect(M + bw * used + 2, by, Math.max(4, bw * pend - 2), 8, 4, 4, 'F');
  }
  doc.setFontSize(9);
  doc.setTextColor(...MUTED);
  doc.text(`${Math.round(used * 100)}% of the budget spent · ${usd(s.available)} safe to spend after pending items`, M, by + 24);

  doc.setFont('helvetica', 'bold');
  doc.setFontSize(12);
  doc.setTextColor(...INK);
  doc.text('Expense breakdown', M, by + 58);
  autoTable(doc, {
    startY: by + 68,
    margin: { left: M, right: M },
    head: [['Category', 'Approved', 'Pending', 'Share of approved']],
    body: breakdown.length
      ? breakdown.map((c) => [categoryById(c.id).label, usd(c.approved), c.pending ? usd(c.pending) : '—', s.approved > 0 ? `${Math.round((c.approved / s.approved) * 100)}%` : '—'])
      : [['No expenses recorded yet', '', '', '']],
    foot: [['Total', usd(s.approved), usd(s.pending), s.approved > 0 ? '100%' : '—']],
    theme: 'plain',
    styles: { font: 'helvetica', fontSize: 10, cellPadding: { top: 7, bottom: 7, left: 6, right: 6 }, textColor: INK },
    headStyles: { fontSize: 8, textColor: MUTED, fontStyle: 'bold' },
    footStyles: { fontStyle: 'bold', textColor: INK },
    columnStyles: { 1: { halign: 'right' }, 2: { halign: 'right' }, 3: { halign: 'right' } },
    didParseCell: (d) => {
      if ((d.section === 'foot' || d.section === 'head') && d.column.index > 0) d.cell.styles.halign = 'right';
    },
    didDrawCell: (d) => {
      if (d.section === 'body' || d.section === 'head') {
        doc.setDrawColor(...HAIR);
        doc.line(d.cell.x, d.cell.y + d.cell.height, d.cell.x + d.cell.width, d.cell.y + d.cell.height);
      }
    },
  });

  const afterBreakdown = (doc as unknown as { lastAutoTable: { finalY: number } }).lastAutoTable.finalY;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(12);
  doc.text('Transaction history', M, afterBreakdown + 36);
  autoTable(doc, {
    startY: afterBreakdown + 46,
    margin: { left: M, right: M, bottom: 60 },
    head: [['Date', 'Vendor', 'Category', 'Description', 'Status', 'Amount']],
    body: txns.map((e) => [shortDate(e.date), e.vendor, categoryById(e.category).short, e.description, STATUS_LABEL[e.status], usd(e.amount)]),
    theme: 'plain',
    styles: { font: 'helvetica', fontSize: 9, cellPadding: { top: 6, bottom: 6, left: 5, right: 5 }, textColor: INK, overflow: 'linebreak' },
    headStyles: { fontSize: 8, textColor: MUTED, fontStyle: 'bold' },
    columnStyles: { 0: { cellWidth: 46 }, 3: { cellWidth: 160 }, 5: { halign: 'right', cellWidth: 62 } },
    didParseCell: (d) => {
      if (d.section === 'body' && d.column.index === 4) {
        const v = String(d.cell.raw);
        d.cell.styles.textColor = v === 'Approved' ? [21, 122, 69] : v === 'Rejected' ? [184, 41, 31] : v === 'Pending review' ? [143, 100, 0] : ACCENT;
      }
    },
    didDrawCell: (d) => {
      if (d.section === 'body' || d.section === 'head') {
        doc.setDrawColor(...HAIR);
        doc.line(d.cell.x, d.cell.y + d.cell.height, d.cell.x + d.cell.width, d.cell.y + d.cell.height);
      }
    },
  });

  const pages = doc.getNumberOfPages();
  for (let i = 1; i <= pages; i++) {
    doc.setPage(i);
    const H = doc.internal.pageSize.getHeight();
    doc.setFontSize(8);
    doc.setTextColor(...MUTED);
    doc.text('Generated automatically by FairShare from approved Student Accounts records. Pending amounts are not yet approved.', M, H - 32);
    doc.text(`Page ${i} of ${pages}`, W - M, H - 32, { align: 'right' });
  }

  download(doc.output('blob'), `${slug(org.name)}-${slug(org.term)}-report.pdf`);
}

export async function downloadXlsx(state: AppState, org: Org) {
  const { default: ExcelJS } = await import('exceljs');
  const { s, txns, breakdown, allocations } = reportData(state, org);
  const wb = new ExcelJS.Workbook();
  wb.creator = 'FairShare';
  wb.created = new Date();
  const money = '"$"#,##0.00';
  const header = (row: ExcelJSNS.Row) => {
    row.font = { bold: true, color: { argb: 'FF6E6E74' }, size: 10 };
    row.border = { bottom: { style: 'thin', color: { argb: 'FFE4E4E0' } } };
  };

  const sum = wb.addWorksheet('Summary', { views: [{ showGridLines: false }] });
  sum.columns = [{ width: 30 }, { width: 18 }];
  sum.addRow([`${org.name} — ${org.term}`]).font = { bold: true, size: 16 };
  sum.addRow([`Generated ${longDate(new Date().toISOString())} by FairShare`]).font = { color: { argb: 'FF6E6E74' } };
  sum.addRow([]);
  const rows: [string, number][] = [
    ['Original budget', s.allocated],
    ['Approved expenses', s.approved],
    ['Remaining balance', s.remaining],
    ['Pending review', s.pending],
    ['Safe to spend (after pending)', s.available],
  ];
  for (const [k, v] of rows) {
    const r = sum.addRow([k, v]);
    r.getCell(2).numFmt = money;
    if (k === 'Remaining balance') r.font = { bold: true };
  }
  sum.addRow([]);
  header(sum.addRow(['Budget changes', 'Amount']));
  for (const a of allocations) sum.addRow([`${a.note} (${a.at.slice(0, 10)})`, a.amount]).getCell(2).numFmt = money;

  const cat = wb.addWorksheet('By category', { views: [{ state: 'frozen', ySplit: 1, showGridLines: false }] });
  cat.columns = [
    { header: 'Category', width: 26 },
    { header: 'Approved', width: 14, style: { numFmt: money } },
    { header: 'Pending', width: 14, style: { numFmt: money } },
  ];
  header(cat.getRow(1));
  for (const c of breakdown) cat.addRow([categoryById(c.id).label, c.approved, c.pending]);
  const totalRow = cat.addRow(['Total', s.approved, s.pending]);
  totalRow.font = { bold: true };

  const tx = wb.addWorksheet('Transactions', { views: [{ state: 'frozen', ySplit: 1, showGridLines: false }] });
  tx.columns = [
    { header: 'Date', width: 12 },
    { header: 'Vendor', width: 26 },
    { header: 'Category', width: 22 },
    { header: 'Description', width: 44 },
    { header: 'Document', width: 12 },
    { header: 'Status', width: 22 },
    { header: 'Amount', width: 14, style: { numFmt: money } },
    { header: 'Reviewer note', width: 50 },
  ];
  header(tx.getRow(1));
  txns.forEach((e: Expense) =>
    tx.addRow([e.date, e.vendor, categoryById(e.category).label, e.description, e.docType === 'check' ? `Check ${e.checkNumber ?? ''}`.trim() : 'Receipt', STATUS_LABEL[e.status], e.amount, e.reviewNote ?? '']),
  );
  tx.autoFilter = { from: 'A1', to: 'H1' };

  const buf = await wb.xlsx.writeBuffer();
  download(new Blob([buf], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }), `${slug(org.name)}-${slug(org.term)}-report.xlsx`);
}

export async function downloadCampusXlsx(state: AppState) {
  const { default: ExcelJS } = await import('exceljs');
  const c = campusSummary(state);
  const wb = new ExcelJS.Workbook();
  const money = '"$"#,##0.00';
  const ws = wb.addWorksheet('Organizations', { views: [{ state: 'frozen', ySplit: 1, showGridLines: false }] });
  ws.columns = [
    { header: 'Organization', width: 34 },
    { header: 'C-board', width: 10 },
    { header: 'Allocated', width: 14, style: { numFmt: money } },
    { header: 'Approved', width: 14, style: { numFmt: money } },
    { header: 'Pending', width: 14, style: { numFmt: money } },
    { header: 'Remaining', width: 14, style: { numFmt: money } },
    { header: 'Funding request', width: 18 },
  ];
  ws.getRow(1).font = { bold: true };
  for (const { org, s } of c.orgs) ws.addRow([org.name, org.cboard, s.allocated, s.approved, s.pending, s.remaining, org.funding.status.replace('_', ' ')]);
  const t = ws.addRow(['All organizations', '', c.allocated, c.approved, c.pending, c.remaining, `${c.fundingSubmitted}/${c.orgCount} submitted`]);
  t.font = { bold: true };
  const cats = wb.addWorksheet('By category');
  cats.columns = [
    { header: 'Category', width: 26 },
    { header: 'Approved', width: 14, style: { numFmt: money } },
  ];
  cats.getRow(1).font = { bold: true };
  for (const row of c.byCategory) cats.addRow([CATEGORIES.find((x) => x.id === row.id)!.label, row.approved]);
  const buf = await wb.xlsx.writeBuffer();
  download(new Blob([buf], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }), `fairshare-campus-${state.institution.term.toLowerCase().replace(/\s+/g, '-')}.xlsx`);
}
