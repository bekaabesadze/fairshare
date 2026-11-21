import { useEffect, useRef, useState } from 'react';
import {
  Receipt as ReceiptIcon,
  Bank,
  Camera,
  UploadSimple,
  ArrowLeft,
  Check,
  CheckCircle,
  Sparkle,
  PencilSimple,
  Warning,
  ArrowRight,
  Plus,
  Trash,
} from '@phosphor-icons/react';
import type { CategoryId, DocType, Expense, LineItem } from '../../../shared/types.ts';
import { CATEGORIES, orgSummary, usd, uid, longDate } from '../../../shared/money.ts';
import { navigate, todayISO, useIsMobile, useStore } from '../store.tsx';
import { CATEGORY_ICON } from '../ui/kit.tsx';
import { DocumentPreview } from './common.tsx';
import { downscale, fileToDataUrl } from '../lib/image.ts';
import { scanDocument, warmOcr } from '../lib/ocr.ts';
import { detectDocType } from '../../../shared/ocr-parse.ts';
import { useOfficerOrg } from './officer.tsx';

type Step = 'type' | 'capture' | 'scan' | 'review' | 'done';

interface Form {
  vendor: string;
  amount: string;
  date: string;
  category: CategoryId | null;
  description: string;
  tax: string;
  items: LineItem[];
  checkNumber: string;
  memo: string;
}

const EMPTY: Form = { vendor: '', amount: '', date: todayISO(), category: null, description: '', tax: '', items: [], checkNumber: '', memo: '' };

const SAMPLES: Record<DocType, { src: string; label: string }> = {
  receipt: { src: '/samples/bookshop.png', label: 'Luther Book Shop receipt' },
  check: { src: '/samples/check-uptous.png', label: 'Check to Decorah Public Library' },
};

export function AddExpensePage() {
  const { state, user, dispatch } = useStore();
  const org = useOfficerOrg();
  const mobile = useIsMobile();
  const [step, setStep] = useState<Step>('type');
  const [docType, setDocType] = useState<DocType>('receipt');
  const [image, setImage] = useState<string | undefined>();
  const [form, setForm] = useState<Form>(EMPTY);
  const [scanned, setScanned] = useState<string[]>([]);
  const [progress, setProgress] = useState(0);
  const [found, setFound] = useState<string[]>([]);
  const [mismatch, setMismatch] = useState<DocType | null>(null);
  const [scanError, setScanError] = useState<string | null>(null);
  const [tried, setTried] = useState(false);
  const [drag, setDrag] = useState(false);
  const [submitted, setSubmitted] = useState<Expense | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const camRef = useRef<HTMLInputElement>(null);
  const s = orgSummary(state, org.id);

  useEffect(() => {
    warmOcr();
  }, []);

  const set = <K extends keyof Form>(k: K, v: Form[K]) => setForm((f) => ({ ...f, [k]: v }));

  const runScan = async (src: string, type: DocType) => {
    setImage(src);
    setStep('scan');
    setProgress(0);
    setFound([]);
    setScanError(null);
    setMismatch(null);
    const started = Date.now();
    try {
      const res = await scanDocument(src, type, (p, status) => status.includes('recogniz') && setProgress(p));
      const p = res.parsed;
      const detected = detectDocType(res.text);
      if (detected !== type) setMismatch(detected);
      const order = ['vendor', 'date', 'amount', 'tax', 'items', 'checkNumber', 'memo'].filter((k) => p.found.includes(k));
      const minShow = Math.max(0, 900 - (Date.now() - started));
      await new Promise((r) => setTimeout(r, minShow));
      for (const k of order) {
        setFound((f) => [...f, k]);
        await new Promise((r) => setTimeout(r, 170));
      }
      setForm({
        ...EMPTY,
        vendor: p.vendor ?? '',
        amount: p.amount !== undefined ? p.amount.toFixed(2) : '',
        date: p.date ?? todayISO(),
        category: p.category ?? null,
        tax: p.tax !== undefined ? p.tax.toFixed(2) : '',
        items: p.items,
        checkNumber: p.checkNumber ?? '',
        memo: p.memo ?? '',
        description: p.memo ?? '',
      });
      setScanned(p.found.concat(p.category ? ['category'] : []));
      if (!p.found.length) setScanError('We couldn’t read this one clearly. Please fill in the details below.');
      await new Promise((r) => setTimeout(r, 450));
      setStep('review');
    } catch {
      setScanError('Scanning isn’t available right now. Please fill in the details below.');
      setForm({ ...EMPTY });
      setScanned([]);
      setStep('review');
    }
  };

  const onFile = async (file: File | undefined) => {
    if (!file) return;
    if (file.type === 'application/pdf') {
      setImage(await fileToDataUrl(file));
      setScanError('PDFs are attached as-is. Please check the details below.');
      setForm({ ...EMPTY });
      setScanned([]);
      setStep('review');
      return;
    }
    runScan(await downscale(file), docType);
  };

  const amount = parseFloat(form.amount) || 0;
  const errors = {
    vendor: !form.vendor.trim() ? (docType === 'check' ? 'Who was the check paid to?' : 'Where did you buy it?') : null,
    amount: !(amount > 0) ? 'Enter the total amount.' : null,
    date: !form.date ? 'Add the date of the purchase.' : null,
    category: !form.category ? 'Pick a category.' : null,
    description: form.description.trim().length < 3 ? 'Add a few words about what it was for.' : null,
  };
  const valid = Object.values(errors).every((e) => !e);

  const submit = () => {
    setTried(true);
    if (!valid) return;
    const now = new Date().toISOString();
    const e: Expense = {
      id: uid('ex'),
      orgId: org.id,
      docType,
      vendor: form.vendor.trim(),
      category: form.category!,
      description: form.description.trim(),
      amount: Math.round(amount * 100) / 100,
      tax: form.tax ? parseFloat(form.tax) : undefined,
      date: form.date,
      items: form.items.length ? form.items : undefined,
      checkNumber: docType === 'check' ? form.checkNumber || undefined : undefined,
      memo: docType === 'check' ? form.memo || undefined : undefined,
      image,
      scanned,
      status: 'pending',
      submittedBy: user!.id,
      submittedAt: now,
      history: [{ at: now, by: user!.id, action: 'submitted' }],
    };
    dispatch({ type: 'expense/submit', expense: e });
    setSubmitted(e);
    setStep('done');
    window.scrollTo({ top: 0 });
  };

  const reset = () => {
    setStep('type');
    setImage(undefined);
    setForm(EMPTY);
    setScanned([]);
    setTried(false);
    setSubmitted(null);
  };

  const stepIndex = { type: 0, capture: 1, scan: 2, review: 2, done: 3 }[step];
  const back = () => (step === 'capture' ? setStep('type') : step === 'review' ? setStep('capture') : navigate('/home'));

  const header = step !== 'done' && (
    <div className="row" style={{ gap: 12, marginBottom: 24 }}>
      <button className="icon-btn" onClick={back} aria-label="Back">
        <ArrowLeft size={22} />
      </button>
      <div className="progress-steps grow" aria-label={`Step ${stepIndex + 1} of 3`}>
        {[0, 1, 2].map((i) => (
          <span key={i} className={i <= stepIndex ? 'on' : ''} />
        ))}
      </div>
      <span className="t-cap faint num" style={{ width: 36, textAlign: 'right' }}>
        {Math.min(stepIndex + 1, 3)}/3
      </span>
    </div>
  );

  if (step === 'type') {
    return (
      <Frame mobile={mobile}>
        {header}
        <h1 className="t-large">What are you adding?</h1>
        <p className="muted" style={{ marginTop: 6, marginBottom: 24 }}>
          Receipts and checks are handled differently by Student Accounts, so start by telling us which one you have.
        </p>
        <div className="col" style={{ gap: 12 }}>
          {(
            [
              ['receipt', ReceiptIcon, 'A receipt', 'Proof of something you bought — store receipt, invoice, card slip.'],
              ['check', Bank, 'A check or payment document', 'A check your organization wrote, or a payment form.'],
            ] as const
          ).map(([t, I, title, hint]) => (
            <button
              key={t}
              className="choice"
              aria-pressed={docType === t}
              onClick={() => {
                setDocType(t);
                setStep('capture');
              }}
            >
              <span className="choice-icon">
                <I size={24} weight={docType === t ? 'fill' : 'regular'} />
              </span>
              <span className="col grow">
                <span className="t-head">{title}</span>
                <span className="t-cap muted" style={{ marginTop: 2 }}>
                  {hint}
                </span>
              </span>
              <ArrowRight size={18} className="faint" />
            </button>
          ))}
        </div>
      </Frame>
    );
  }

  if (step === 'capture') {
    const sample = SAMPLES[docType];
    return (
      <Frame mobile={mobile}>
        {header}
        <h1 className="t-large">{docType === 'check' ? 'Add a photo of the check' : 'Snap the receipt'}</h1>
        <p className="muted" style={{ marginTop: 6, marginBottom: 24 }}>
          We’ll read the {docType === 'check' ? 'payee, date and amount' : 'store, date, items and total'} for you. You can fix anything before sending.
        </p>
        <input ref={fileRef} type="file" accept="image/*,application/pdf" hidden onChange={(e) => onFile(e.target.files?.[0])} />
        <input ref={camRef} type="file" accept="image/*" capture="environment" hidden onChange={(e) => onFile(e.target.files?.[0])} />
        <div
          className={`dropzone ${drag ? 'drag' : ''}`}
          onDragOver={(e) => {
            e.preventDefault();
            setDrag(true);
          }}
          onDragLeave={() => setDrag(false)}
          onDrop={(e) => {
            e.preventDefault();
            setDrag(false);
            onFile(e.dataTransfer.files?.[0]);
          }}
        >
          <span className="choice-icon" style={{ margin: '0 auto 14px', width: 56, height: 56, borderRadius: 18 }}>
            {docType === 'check' ? <Bank size={28} /> : <ReceiptIcon size={28} />}
          </span>
          <div className="t-head">{mobile ? 'Take a photo or choose a file' : 'Drop a photo or PDF here'}</div>
          <p className="t-cap muted" style={{ marginTop: 4 }}>
            JPG, PNG, HEIC or PDF · Lay it flat in good light
          </p>
          <div className="row wrap" style={{ gap: 10, justifyContent: 'center', marginTop: 18 }}>
            {mobile && (
              <button className="btn btn-primary btn-lg" onClick={() => camRef.current?.click()}>
                <Camera size={20} weight="fill" /> Take photo
              </button>
            )}
            <button className={`btn ${mobile ? 'btn-secondary' : 'btn-primary'} btn-lg`} onClick={() => fileRef.current?.click()}>
              <UploadSimple size={20} /> {mobile ? 'Choose file' : 'Upload file'}
            </button>
          </div>
        </div>
        <div className="row wrap" style={{ gap: 10, marginTop: 20, justifyContent: 'space-between' }}>
          <button className="chip" onClick={() => runScan(sample.src, docType)}>
            <Sparkle size={15} weight="fill" color="var(--accent)" /> Try with a sample: {sample.label}
          </button>
          <button
            className="btn btn-ghost btn-sm"
            onClick={() => {
              setImage(undefined);
              setForm(EMPTY);
              setScanned([]);
              setScanError(null);
              setStep('review');
            }}
          >
            <PencilSimple size={16} /> Enter details manually
          </button>
        </div>
      </Frame>
    );
  }

  if (step === 'scan') {
    const LABELS: Record<string, string> = { vendor: docType === 'check' ? 'Payee' : 'Store', date: 'Date', amount: 'Total', tax: 'Tax', items: 'Items', checkNumber: 'Check number', memo: 'Memo' };
    return (
      <Frame mobile={mobile}>
        {header}
        <div style={{ display: 'grid', gridTemplateColumns: mobile ? '1fr' : '1fr 1fr', gap: 28, alignItems: 'center' }}>
          <DocumentPreview src={image} height={mobile ? 320 : 480} scanning />
          <div>
            <div className="t-micro" style={{ color: 'var(--accent-text)' }}>
              Scanning
            </div>
            <h1 className="t-large" style={{ marginTop: 6 }}>
              Reading your {docType}…
            </h1>
            <div className="bar-track" style={{ marginTop: 18, height: 6 }}>
              <div className="bar-fill" style={{ width: `${Math.round((found.length ? 1 : progress) * 100)}%`, background: 'var(--accent)' }} />
            </div>
            <div className="col" style={{ gap: 10, marginTop: 22 }}>
              {found.map((k) => (
                <div key={k} className="row" style={{ gap: 10, animation: 'rise 300ms var(--ease) both' }}>
                  <span style={{ width: 22, height: 22, borderRadius: 11, background: 'var(--green)', color: '#fff', display: 'grid', placeItems: 'center', animation: 'pop 300ms var(--ease) both' }}>
                    <Check size={14} weight="bold" />
                  </span>
                  <span className="w-500">Found the {LABELS[k]?.toLowerCase()}</span>
                </div>
              ))}
              {!found.length && <p className="muted t-cap">Recognizing text on the device — nothing is sent anywhere yet.</p>}
            </div>
          </div>
        </div>
      </Frame>
    );
  }

  if (step === 'done' && submitted) {
    return (
      <Frame mobile={mobile} narrow>
        <div style={{ textAlign: 'center', paddingTop: mobile ? 24 : 40 }}>
          <span style={{ width: 84, height: 84, borderRadius: 42, background: 'var(--green)', color: '#fff', display: 'inline-grid', placeItems: 'center', animation: 'pop 420ms var(--ease) both' }}>
            <Check size={44} weight="bold" />
          </span>
          <h1 className="t-large" style={{ marginTop: 20 }}>
            Sent for review
          </h1>
          <p className="muted" style={{ marginTop: 6 }}>
            Student Accounts has your {submitted.docType}. We’ll let you know as soon as it’s approved.
          </p>
        </div>
        <div className="card card-pad" style={{ marginTop: 28 }}>
          <div className="row between">
            <div>
              <div className="w-600">{submitted.vendor}</div>
              <div className="t-cap muted">{longDate(submitted.date)}</div>
            </div>
            <div className="t-title num">{usd(submitted.amount)}</div>
          </div>
          <hr className="divider" style={{ margin: '16px 0' }} />
          {[
            ['Pending review now', 'It shows as pending so nobody spends it twice.'],
            ['Student Accounts checks it', 'Usually within 2 business days.'],
            ['Your balance updates', `When approved, ${org.name}’s remaining balance goes down by ${usd(submitted.amount)}.`],
          ].map(([t, h], i) => (
            <div key={i} className="row" style={{ alignItems: 'flex-start', gap: 12, marginTop: i ? 14 : 0 }}>
              <span style={{ width: 24, height: 24, borderRadius: 12, background: i === 0 ? 'var(--amber-soft)' : 'var(--surface-2)', color: i === 0 ? 'var(--amber-text)' : 'var(--text-2)', display: 'grid', placeItems: 'center', fontSize: 12, fontWeight: 700, flexShrink: 0 }}>
                {i + 1}
              </span>
              <span className="col">
                <span className="w-600" style={{ fontSize: 14 }}>
                  {t}
                </span>
                <span className="t-cap muted">{h}</span>
              </span>
            </div>
          ))}
        </div>
        <div className="col" style={{ gap: 10, marginTop: 20 }}>
          <button className="btn btn-primary btn-lg btn-block" onClick={() => navigate('/home')}>
            Back to Home
          </button>
          <button className="btn btn-secondary btn-lg btn-block" onClick={reset}>
            <Plus size={18} /> Add another
          </button>
        </div>
      </Frame>
    );
  }

  const tag = (k: string) =>
    scanned.includes(k) ? (
      <span className="scanned-tag">
        <Sparkle size={11} weight="fill" /> Scanned
      </span>
    ) : null;
  const err = (k: keyof typeof errors) => tried && errors[k] && <span className="t-cap" style={{ color: 'var(--red-text)' }}>{errors[k]}</span>;
  const after = Math.round((s.available - amount) * 100) / 100;

  const formEl = (
    <div className="col" style={{ gap: 18 }}>
      {scanError ? (
        <div className="notice-banner" style={{ background: 'var(--amber-soft)' }}>
          <Warning size={22} weight="fill" color="var(--amber-text)" />
          <span className="t-cap">{scanError}</span>
        </div>
      ) : scanned.length > 0 ? (
        <div className="notice-banner">
          <Sparkle size={22} weight="fill" color="var(--accent)" />
          <span className="t-cap">
            <span className="w-600">We filled in {scanned.length} details.</span> Give them a quick check — you’re the one submitting.
          </span>
        </div>
      ) : null}
      {mismatch && (
        <div className="notice-banner" style={{ background: 'var(--amber-soft)', flexWrap: 'wrap' }}>
          <Warning size={22} weight="fill" color="var(--amber-text)" />
          <span className="t-cap grow">This looks like a {mismatch === 'check' ? 'check' : 'receipt'}, not a {docType}.</span>
          <button
            className="btn btn-secondary btn-sm"
            onClick={() => {
              setDocType(mismatch);
              if (image) runScan(image, mismatch);
            }}
          >
            Treat as {mismatch}
          </button>
        </div>
      )}

      <div className="field">
        <label className="field-label" htmlFor="amt">
          Total amount {tag('amount')}
        </label>
        <input id="amt" className="input input-money" inputMode="decimal" placeholder="$0.00" value={form.amount ? `$${form.amount}` : ''} onChange={(e) => set('amount', e.target.value.replace(/[^0-9.]/g, ''))} />
        {err('amount')}
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: mobile ? '1fr' : '1.4fr 1fr', gap: 14 }}>
        <div className="field">
          <label className="field-label" htmlFor="vendor">
            {docType === 'check' ? 'Paid to' : 'Store or vendor'} {tag('vendor')}
          </label>
          <input id="vendor" className="input" value={form.vendor} placeholder={docType === 'check' ? 'Who received the check' : 'e.g. Luther Book Shop'} onChange={(e) => set('vendor', e.target.value)} />
          {err('vendor')}
        </div>
        <div className="field">
          <label className="field-label" htmlFor="date">
            Date {tag('date')}
          </label>
          <input id="date" type="date" className="input" value={form.date} onChange={(e) => set('date', e.target.value)} />
          {err('date')}
        </div>
      </div>
      {docType === 'check' && (
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 2fr', gap: 14 }}>
          <div className="field">
            <label className="field-label" htmlFor="chk">
              Check no. {tag('checkNumber')}
            </label>
            <input id="chk" className="input num" value={form.checkNumber} onChange={(e) => set('checkNumber', e.target.value)} />
          </div>
          <div className="field">
            <label className="field-label" htmlFor="memo">
              Memo {tag('memo')}
            </label>
            <input id="memo" className="input" value={form.memo} onChange={(e) => set('memo', e.target.value)} />
          </div>
        </div>
      )}
      <div className="field">
        <span className="field-label">Category {tag('category')}</span>
        <div className="row wrap" style={{ gap: 8 }}>
          {CATEGORIES.map((c) => {
            const I = CATEGORY_ICON[c.id];
            return (
              <button key={c.id} className="chip" aria-pressed={form.category === c.id} onClick={() => set('category', c.id)} title={c.hint}>
                <I size={16} weight={form.category === c.id ? 'fill' : 'regular'} /> {c.short}
              </button>
            );
          })}
        </div>
        {err('category')}
      </div>
      <div className="field">
        <label className="field-label" htmlFor="desc">
          What was it for?
        </label>
        <input id="desc" className="input" value={form.description} placeholder="e.g. Prizes for the Up to Us Day of Action" onChange={(e) => set('description', e.target.value)} />
        {err('description')}
      </div>
      {docType === 'receipt' && (form.items.length > 0 || form.tax) && (
        <details className="inset" style={{ padding: '12px 16px' }} open={!mobile}>
          <summary className="row between" style={{ cursor: 'pointer', listStyle: 'none' }}>
            <span className="field-label">
              Items & tax {tag('items')}
            </span>
            <span className="t-cap faint">{form.items.length} items</span>
          </summary>
          <div className="col" style={{ gap: 8, marginTop: 10 }}>
            {form.items.map((it, i) => (
              <div key={i} className="row" style={{ gap: 8 }}>
                <input className="input grow" style={{ height: 38, fontSize: 14 }} value={it.name} onChange={(e) => set('items', form.items.map((x, j) => (j === i ? { ...x, name: e.target.value } : x)))} aria-label="Item name" />
                <input
                  className="input num"
                  style={{ height: 38, width: 96, fontSize: 14, textAlign: 'right' }}
                  value={it.amount.toFixed(2)}
                  onChange={(e) => set('items', form.items.map((x, j) => (j === i ? { ...x, amount: parseFloat(e.target.value) || 0 } : x)))}
                  aria-label="Item amount"
                />
                <button className="icon-btn" aria-label="Remove item" onClick={() => set('items', form.items.filter((_, j) => j !== i))}>
                  <Trash size={16} />
                </button>
              </div>
            ))}
            <div className="row between" style={{ marginTop: 4 }}>
              <span className="t-cap muted">Tax {tag('tax')}</span>
              <input className="input num" style={{ height: 38, width: 96, fontSize: 14, textAlign: 'right' }} value={form.tax} onChange={(e) => set('tax', e.target.value.replace(/[^0-9.]/g, ''))} aria-label="Tax" />
            </div>
          </div>
        </details>
      )}

      <div className="card card-pad" style={{ boxShadow: 'none' }}>
        <div className="row between">
          <span className="t-cap muted">Safe to spend now</span>
          <span className="w-600 num">{usd(s.available)}</span>
        </div>
        <div className="row between" style={{ marginTop: 6 }}>
          <span className="t-cap muted">After this expense</span>
          <span className="w-600 num" style={{ color: after < 0 ? 'var(--red-text)' : 'var(--text)' }}>
            {usd(after)}
          </span>
        </div>
        <div className="bar-track" style={{ marginTop: 12 }}>
          <div className="bar-fill" style={{ width: `${Math.max(0, Math.min(100, (after / Math.max(1, s.allocated)) * 100))}%`, background: after < 0 ? 'var(--red)' : 'var(--accent)' }} />
          <div
            className="bar-fill"
            style={{ width: `${Math.max(0, Math.min(100, (Math.min(amount, Math.max(0, s.available)) / Math.max(1, s.allocated)) * 100))}%`, background: 'repeating-linear-gradient(45deg, var(--amber) 0 3px, color-mix(in srgb, var(--amber) 55%, transparent) 3px 6px)' }}
          />
        </div>
        {after < 0 && (
          <p className="t-cap" style={{ color: 'var(--red-text)', marginTop: 8 }}>
            This is more than you can safely spend. You can still submit it — Student Accounts will decide.
          </p>
        )}
      </div>
      <button className="btn btn-primary btn-lg btn-block" onClick={submit}>
        Submit for review
      </button>
      {tried && !valid && (
        <p className="t-cap" style={{ color: 'var(--red-text)', textAlign: 'center' }}>
          A few details are missing — see the highlighted fields.
        </p>
      )}
    </div>
  );

  return (
    <Frame mobile={mobile} wide>
      {header}
      <h1 className="t-large" style={{ marginBottom: 6 }}>
        Check the details
      </h1>
      <p className="muted" style={{ marginBottom: 24 }}>
        {docType === 'check' ? 'Check or payment document' : 'Receipt'} for {org.name}
      </p>
      {mobile ? (
        <div className="stack-16">
          {image && <DocumentPreview src={image} height={220} />}
          {formEl}
        </div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0, 0.9fr) minmax(0, 1.1fr)', gap: 32, alignItems: 'start' }}>
          <div style={{ position: 'sticky', top: 88 }}>
            <DocumentPreview src={image} height={600} />
          </div>
          {formEl}
        </div>
      )}
    </Frame>
  );
}

function Frame({ children, mobile, wide, narrow }: { children: React.ReactNode; mobile: boolean; wide?: boolean; narrow?: boolean }) {
  if (mobile) return <div className="m-page rise">{children}</div>;
  return (
    <div className="page rise" style={{ maxWidth: wide ? 1100 : narrow ? 520 : 680 }}>
      {children}
    </div>
  );
}
