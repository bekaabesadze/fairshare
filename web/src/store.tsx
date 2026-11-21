import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import type { Action, AppState, AssistantMessage, AssistantReply, Notice, User } from '../../shared/types.ts';
import { makeSeed } from '../../shared/seed.ts';
import { reduce, noticesFor } from '../../shared/reducer.ts';
import { localAnswer } from '../../shared/assistant.ts';

export type SyncMode = 'connecting' | 'live' | 'offline';
export type Theme = 'system' | 'light' | 'dark';

export interface Toast {
  id: string;
  title: string;
  body?: string;
  tone: Notice['kind'] | 'info';
  ref?: string;
}

const LS_STATE = 'fairshare.state.v1';
const SS_SESSION = 'fairshare.session';
const LS_THEME = 'fairshare.theme';

const safe = {
  get(store: Storage, k: string) {
    try {
      return store.getItem(k);
    } catch {
      return null;
    }
  },
  set(store: Storage, k: string, v: string) {
    try {
      store.setItem(k, v);
    } catch {}
  },
  del(store: Storage, k: string) {
    try {
      store.removeItem(k);
    } catch {}
  },
};

function loadLocal(): AppState | null {
  const raw = safe.get(localStorage, LS_STATE);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as AppState;
  } catch {
    return null;
  }
}

export const todayISO = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};

interface Store {
  state: AppState;
  sync: SyncMode;
  user: User | null;
  signIn: (userId: string) => void;
  signOut: () => void;
  dispatch: (action: Action) => void;
  ask: (orgId: string, messages: AssistantMessage[]) => Promise<AssistantReply>;
  toasts: Toast[];
  toast: (t: Omit<Toast, 'id'>) => void;
  dismissToast: (id: string) => void;
  theme: Theme;
  setTheme: (t: Theme) => void;
  reconnect: () => void;
  aiEngine: 'claude' | 'local';
}

const Ctx = createContext<Store | null>(null);

export function StoreProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AppState>(() => loadLocal() ?? makeSeed());
  const [sync, setSync] = useState<SyncMode>('connecting');
  const [sessionId, setSessionId] = useState<string | null>(() => safe.get(sessionStorage, SS_SESSION));
  const [toasts, setToasts] = useState<Toast[]>([]);
  const [theme, setThemeState] = useState<Theme>(() => (safe.get(localStorage, LS_THEME) as Theme) || 'system');
  const [aiEngine, setAiEngine] = useState<'claude' | 'local'>('local');
  const stateRef = useRef(state);
  stateRef.current = state;
  const syncRef = useRef(sync);
  syncRef.current = sync;
  const channel = useRef<BroadcastChannel | null>(null);
  const esRef = useRef<EventSource | null>(null);
  const remoteVersion = useRef(-1);
  const streamAlive = useRef(false);
  const pollTimer = useRef<ReturnType<typeof setInterval> | null>(null);

  const setTheme = useCallback((t: Theme) => {
    setThemeState(t);
    if (t === 'system') {
      safe.del(localStorage, LS_THEME);
      delete document.documentElement.dataset.theme;
    } else {
      safe.set(localStorage, LS_THEME, t);
      document.documentElement.dataset.theme = t;
    }
  }, []);

  const dismissToast = useCallback((id: string) => setToasts((ts) => ts.filter((t) => t.id !== id)), []);
  const toast = useCallback(
    (t: Omit<Toast, 'id'>) => {
      const id = Math.random().toString(36).slice(2);
      setToasts((ts) => [...ts.slice(-2), { ...t, id }]);
      setTimeout(() => dismissToast(id), 5200);
    },
    [dismissToast],
  );

  const connect = useCallback(async () => {
    setSync('connecting');
    try {
      const ctrl = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), 1800);
      const res = await fetch('/api/health', { signal: ctrl.signal });
      clearTimeout(timer);
      if (!res.ok) throw new Error('no server');
      const health = (await res.json()) as { ai?: { engine: 'claude' | 'local' } };
      setAiEngine(health.ai?.engine ?? 'local');
      esRef.current?.close();
      const es = new EventSource('/api/events');
      esRef.current = es;
      es.addEventListener('state', (ev) => {
        const next = JSON.parse((ev as MessageEvent).data) as AppState;
        remoteVersion.current = next.version;
        streamAlive.current = true;
        setState(next);
        setSync('live');
      });
      if (pollTimer.current) clearInterval(pollTimer.current);
      pollTimer.current = setInterval(async () => {
        if (streamAlive.current) return;
        try {
          const r = await fetch(`/api/state?since=${remoteVersion.current}`, { cache: 'no-store' });
          if (r.status === 200) {
            const next = (await r.json()) as AppState;
            remoteVersion.current = next.version;
            setState(next);
          }
          if (r.ok) setSync('live');
        } catch {}
      }, 1000);
      es.onerror = () => {
        if (es.readyState === EventSource.CLOSED) setSync('offline');
      };
    } catch {
      setSync('offline');
    }
  }, []);

  useEffect(() => {
    connect();
    try {
      channel.current = new BroadcastChannel('fairshare');
      channel.current.onmessage = (e) => {
        if (syncRef.current !== 'live' && e.data?.type === 'state') setState(e.data.state as AppState);
      };
    } catch {}
    return () => {
      esRef.current?.close();
      if (pollTimer.current) clearInterval(pollTimer.current);
      channel.current?.close();
    };
  }, [connect]);

  useEffect(() => {
    if (sync === 'offline') safe.set(localStorage, LS_STATE, JSON.stringify(state));
  }, [state, sync]);

  const dispatch = useCallback((action: Action) => {
    const next = reduce(stateRef.current, action);
    setState(next);
    if (syncRef.current === 'live') {
      fetch('/api/action', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action }) })
        .then((r) => r.json())
        .then((reply: { state?: AppState }) => {
          if (reply.state && reply.state.version >= remoteVersion.current) {
            remoteVersion.current = reply.state.version;
            setState(reply.state);
          }
        })
        .catch(() => setSync('offline'));
    } else {
      safe.set(localStorage, LS_STATE, JSON.stringify(next));
      channel.current?.postMessage({ type: 'state', state: next });
    }
  }, []);

  const ask = useCallback(async (orgId: string, messages: AssistantMessage[]): Promise<AssistantReply> => {
    const question = messages[messages.length - 1]?.text ?? '';
    const started = Date.now();
    let reply: AssistantReply;
    if (syncRef.current === 'live') {
      try {
        const res = await fetch('/api/assistant', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ orgId, messages }) });
        reply = (await res.json()) as AssistantReply;
      } catch {
        reply = localAnswer(stateRef.current, orgId, question, todayISO(), messages);
      }
    } else {
      reply = localAnswer(stateRef.current, orgId, question, todayISO(), messages);
    }
    const wait = 650 - (Date.now() - started);
    if (wait > 0) await new Promise((r) => setTimeout(r, wait));
    return reply;
  }, []);

  const user = useMemo(() => state.users.find((u) => u.id === sessionId) ?? null, [state.users, sessionId]);
  const signIn = useCallback((userId: string) => {
    safe.set(sessionStorage, SS_SESSION, userId);
    setSessionId(userId);
  }, []);
  const signOut = useCallback(() => {
    safe.del(sessionStorage, SS_SESSION);
    setSessionId(null);
    location.hash = '#/';
  }, []);

  const seen = useRef<Set<string> | null>(null);
  useEffect(() => {
    if (!user) {
      seen.current = null;
      return;
    }
    const mine = noticesFor(state, user);
    if (!seen.current) {
      seen.current = new Set(mine.map((n) => n.id));
      return;
    }
    for (const n of mine) {
      if (seen.current.has(n.id)) continue;
      seen.current.add(n.id);
      if (Date.now() - new Date(n.at).getTime() > 90_000) continue;
      toast({ title: n.title, body: n.body, tone: n.kind, ref: n.ref });
    }
  }, [state, user, toast]);

  const value = useMemo<Store>(
    () => ({ state, sync, user, signIn, signOut, dispatch, ask, toasts, toast, dismissToast, theme, setTheme, reconnect: connect, aiEngine }),
    [state, sync, user, signIn, signOut, dispatch, ask, toasts, toast, dismissToast, theme, setTheme, connect, aiEngine],
  );
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useStore() {
  const s = useContext(Ctx);
  if (!s) throw new Error('useStore outside provider');
  return s;
}

export function useRoute() {
  const [hash, setHash] = useState(() => location.hash || '#/');
  useEffect(() => {
    const on = () => setHash(location.hash || '#/');
    window.addEventListener('hashchange', on);
    return () => window.removeEventListener('hashchange', on);
  }, []);
  const parts = hash.replace(/^#\/?/, '').split('?')[0].split('/').filter(Boolean);
  return { path: parts, raw: hash };
}

export const navigate = (to: string) => {
  const next = to.startsWith('#') ? to : `#${to.startsWith('/') ? to : '/' + to}`;
  if (location.hash !== next) location.hash = next;
};

export function useIsMobile(breakpoint = 860) {
  const [m, setM] = useState(() => window.matchMedia(`(max-width: ${breakpoint}px)`).matches);
  useEffect(() => {
    const mq = window.matchMedia(`(max-width: ${breakpoint}px)`);
    const on = () => setM(mq.matches);
    mq.addEventListener('change', on);
    return () => mq.removeEventListener('change', on);
  }, [breakpoint]);
  return m;
}
