import { useEffect, useRef, useState } from 'react';
import { ArrowUp, Sparkle, Copy, EnvelopeSimple, Check, BookOpen } from '@phosphor-icons/react';
import type { AssistantMessage, AssistantReply } from '../../../shared/types.ts';
import { SUGGESTED_QUESTIONS } from '../../../shared/assistant.ts';
import { orgSummary, usd } from '../../../shared/money.ts';
import { useIsMobile, useRoute, useStore } from '../store.tsx';
import { RichText } from '../ui/kit.tsx';
import { useOfficerOrg } from './officer.tsx';

interface Turn {
  role: 'user' | 'assistant';
  text: string;
  reply?: AssistantReply;
}

export function AssistantPage() {
  const { ask, state, aiEngine } = useStore();
  const org = useOfficerOrg();
  const mobile = useIsMobile();
  const { raw } = useRoute();
  const [turns, setTurns] = useState<Turn[]>([]);
  const [input, setInput] = useState('');
  const [busy, setBusy] = useState(false);
  const endRef = useRef<HTMLDivElement>(null);
  const taRef = useRef<HTMLTextAreaElement>(null);
  const s = orgSummary(state, org.id);
  const asked = useRef(false);

  const send = async (text: string) => {
    const q = text.trim();
    if (!q || busy) return;
    const history: AssistantMessage[] = [...turns.map((t) => ({ role: t.role, text: t.text })), { role: 'user', text: q }];
    setTurns((t) => [...t, { role: 'user', text: q }]);
    setInput('');
    setBusy(true);
    const reply = await ask(org.id, history);
    setTurns((t) => [...t, { role: 'assistant', text: reply.text, reply }]);
    setBusy(false);
  };

  useEffect(() => {
    const m = raw.match(/[?&]q=([^&]+)/);
    if (m && !asked.current) {
      asked.current = true;
      send(decodeURIComponent(m[1]));
      history.replaceState(null, '', '#/ask');
    }
  }, [raw]);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: 'smooth', block: 'end' });
  }, [turns, busy]);

  const lastSuggestions = [...turns].reverse().find((t) => t.reply)?.reply?.suggestions;

  return (
    <div className={mobile ? 'm-page' : 'page'} style={{ maxWidth: 780, display: 'flex', flexDirection: 'column', minHeight: mobile ? 'calc(100dvh - 190px)' : 'calc(100dvh - 76px)', paddingBottom: mobile ? 8 : 24 }}>
      {turns.length === 0 ? (
        <div className="rise" style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', paddingTop: mobile ? 12 : 32 }}>
          <span style={{ width: 56, height: 56, borderRadius: 18, background: 'var(--accent-soft)', color: 'var(--accent)', display: 'grid', placeItems: 'center' }}>
            <Sparkle size={30} weight="fill" />
          </span>
          <h1 className="t-large" style={{ marginTop: 18 }}>
            Ask about {org.name}’s money
          </h1>
          <p className="muted" style={{ marginTop: 6, maxWidth: 520 }}>
            I know your budget ({usd(s.remaining)} remaining, {usd(s.pending)} pending) and Luther’s purchasing procedures. If I don’t know something, I’ll say so — I never guess prices or rules.
          </p>
          <div style={{ display: 'grid', gridTemplateColumns: mobile ? '1fr' : '1fr 1fr', gap: 10, marginTop: 24 }}>
            {SUGGESTED_QUESTIONS.map((q) => (
              <button key={q} className="choice" style={{ padding: '14px 16px' }} onClick={() => send(q)}>
                <span className="t-body w-500">{q}</span>
              </button>
            ))}
          </div>
        </div>
      ) : (
        <div className="chat" style={{ flex: 1, paddingTop: mobile ? 8 : 16 }}>
          {turns.map((t, i) =>
            t.role === 'user' ? (
              <div key={i} className="bubble bubble-user">
                {t.text}
              </div>
            ) : (
              <div key={i} className="col" style={{ gap: 8, alignItems: 'flex-start', maxWidth: '88%' }}>
                <div className="bubble bubble-ai" style={{ maxWidth: '100%' }}>
                  <RichText text={t.text} />
                </div>
                {t.reply?.draft && <DraftCard draft={t.reply.draft} />}
                {t.reply && t.reply.sources.length > 0 && (
                  <div className="row wrap" style={{ gap: 6, paddingLeft: 4 }}>
                    {t.reply.sources.map((s) => (
                      <span key={s} className="source-chip">
                        <BookOpen size={12} /> {s}
                      </span>
                    ))}
                  </div>
                )}
              </div>
            ),
          )}
          {busy && (
            <div className="bubble bubble-ai typing" aria-label="FairShare is typing">
              <span />
              <span />
              <span />
            </div>
          )}
          {!busy && lastSuggestions && (
            <div className="row wrap" style={{ gap: 8 }}>
              {lastSuggestions.map((q) => (
                <button key={q} className="chip" onClick={() => send(q)}>
                  {q}
                </button>
              ))}
            </div>
          )}
          <div ref={endRef} />
        </div>
      )}
      <div style={{ position: 'sticky', bottom: mobile ? 'calc(96px + env(safe-area-inset-bottom))' : 16, marginTop: 16 }}>
        <form
          className="composer"
          onSubmit={(e) => {
            e.preventDefault();
            send(input);
          }}
        >
          <textarea
            ref={taRef}
            rows={1}
            value={input}
            placeholder="Ask anything about your budget…"
            aria-label="Message"
            onChange={(e) => {
              setInput(e.target.value);
              e.target.style.height = 'auto';
              e.target.style.height = `${e.target.scrollHeight}px`;
            }}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                send(input);
              }
            }}
          />
          <button className="send-btn" type="submit" disabled={!input.trim() || busy} aria-label="Send">
            <ArrowUp size={18} weight="bold" />
          </button>
        </form>
        <p className="t-cap faint" style={{ textAlign: 'center', marginTop: 8 }}>
          {aiEngine === 'claude' ? 'Answers by Claude, grounded in your organization’s books.' : 'Answers come from your organization’s books and Luther procedures.'}
        </p>
      </div>
    </div>
  );
}

function DraftCard({ draft }: { draft: NonNullable<AssistantReply['draft']> }) {
  const [copied, setCopied] = useState(false);
  const mailto = `mailto:${draft.to}?subject=${encodeURIComponent(draft.subject)}&body=${encodeURIComponent(draft.body)}`;
  return (
    <div className="card" style={{ width: '100%', padding: 16, animation: 'rise 320ms var(--ease) both' }}>
      <div className="row" style={{ gap: 8 }}>
        <EnvelopeSimple size={18} className="muted" />
        <span className="t-micro">Draft email</span>
      </div>
      <div className="t-cap" style={{ marginTop: 10 }}>
        <span className="muted">To </span>
        {draft.to}
      </div>
      <div className="t-cap w-600" style={{ marginTop: 2 }}>
        {draft.subject}
      </div>
      <pre className="t-cap" style={{ whiteSpace: 'pre-wrap', fontFamily: 'var(--font)', margin: '10px 0 0', padding: 12, background: 'var(--surface-2)', borderRadius: 10, maxHeight: 220, overflow: 'auto' }}>
        {draft.body}
      </pre>
      <div className="row" style={{ gap: 8, marginTop: 12 }}>
        <a className="btn btn-primary btn-sm" href={mailto}>
          <EnvelopeSimple size={16} /> Open in Mail
        </a>
        <button
          className="btn btn-secondary btn-sm"
          onClick={() => {
            navigator.clipboard?.writeText(`To: ${draft.to}\nSubject: ${draft.subject}\n\n${draft.body}`);
            setCopied(true);
            setTimeout(() => setCopied(false), 1600);
          }}
        >
          {copied ? <Check size={16} /> : <Copy size={16} />} {copied ? 'Copied' : 'Copy'}
        </button>
      </div>
    </div>
  );
}
