import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';
import type { Icon } from '@phosphor-icons/react';
import { Animator, SpringValue, prefersReducedMotion } from './spring.ts';

export interface TabItem {
  key: string;
  label: string;
  icon: Icon;
  badge?: number;
}

const BAR_H = 58;
const PAD = 10;
const LENS_INSET = 5;
const MAX_STRETCH = 26;
const DRAG_THRESHOLD = 6;
export const MINIMIZED_SCALE = 0.837;
const PRESSED_SCALE = 1.037;
const SHRINK_LEAD = 0.2;
const GROW_LEAD = 0.25;

const SPRING = {
  tracking: [0.2, 0.8],
  press: [0.26, 0.7],
  glide: [0.39, 0.72],
  release: [0.32, 0.72],
  minimize: [0.37, 0.73],
} as const;

const rubberBand = (d: number) => (d <= 0 ? 0 : MAX_STRETCH * (1 - 1 / ((d / MAX_STRETCH) * 0.6 + 1)));

function layout(baseW: number, count: number, sL = 0, sR = 0) {
  const width = baseW + sL + sR;
  const slot = Math.max((width - PAD * 2) / Math.max(count, 1), 1);
  return {
    width,
    slot,
    center: (i: number) => PAD + slot * (i + 0.5),
    index: (x: number) => Math.min(Math.max(Math.floor((x - PAD) / slot), 0), count - 1),
  };
}

export function scrollScale(minimized: boolean, lead: number) {
  const l = Math.min(Math.max(lead, 0), 1);
  const range = 1 - MINIMIZED_SCALE;
  return minimized ? MINIMIZED_SCALE + range * GROW_LEAD * l : 1 - range * SHRINK_LEAD * l;
}

export function GlassTabBar({
  items,
  selectedIndex,
  onSelect,
  minimized,
  leadIn,
  onInteraction,
  hidden,
}: {
  items: TabItem[];
  selectedIndex: number;
  onSelect: (i: number) => void;
  minimized: boolean;
  leadIn: number;
  onInteraction: () => void;
  hidden?: boolean;
}) {
  const wrapRef = useRef<HTMLDivElement>(null);
  const barRef = useRef<HTMLDivElement>(null);
  const lensRef = useRef<HTMLDivElement>(null);
  const liftRef = useRef<HTMLDivElement>(null);
  const [baseW, setBaseW] = useState(0);
  const baseWRef = useRef(0);
  const count = items.length;

  const s = useRef({
    scale: new SpringValue(1),
    lensX: new SpringValue(0),
    lensW: new SpringValue(0),
    lensH: new SpringValue(BAR_H - LENS_INSET * 2),
    sL: new SpringValue(0),
    sR: new SpringValue(0),
    lift: new SpringValue(0),
  }).current;

  const g = useRef({ pressed: false, dragging: false, fingerX: 0, downX: 0, pointerId: -1 }).current;
  const reduce = useRef(prefersReducedMotion()).current;
  const spring = (v: SpringValue, target: number, kind: keyof typeof SPRING) => {
    if (reduce) v.to(target, 0.15, 1);
    else v.to(target, SPRING[kind][0], SPRING[kind][1]);
  };

  const render = useCallback(() => {
    const bar = barRef.current;
    const lens = lensRef.current;
    if (!bar || !lens) return;
    const W = baseWRef.current;
    const sL = s.sL.value;
    const sR = s.sR.value;
    bar.style.width = `${W + sL + sR}px`;
    bar.style.transform = `translateX(${-sL}px) scale(${s.scale.value})`;
    const lw = s.lensW.value;
    const lh = s.lensH.value;
    lens.style.width = `${lw}px`;
    lens.style.height = `${lh}px`;
    lens.style.transform = `translate(${s.lensX.value - lw / 2}px, ${(BAR_H - lh) / 2}px)`;
    if (liftRef.current) liftRef.current.style.opacity = String(Math.max(0, Math.min(1, s.lift.value)));
  }, [s]);

  const anim = useRef<Animator | null>(null);
  if (!anim.current) anim.current = new Animator(Object.values(s), render);
  useEffect(() => () => anim.current?.stop(), []);

  useLayoutEffect(() => {
    const el = wrapRef.current;
    if (!el) return;
    const ro = new ResizeObserver(() => {
      const w = el.clientWidth;
      baseWRef.current = w;
      setBaseW(w);
      const L = layout(w, count);
      s.lensX.set(L.center(Math.min(Math.max(selectedIndex, 0), count - 1)));
      s.lensW.set(L.slot + LENS_INSET * 2);
      s.lensH.set(BAR_H - LENS_INSET * 2);
      render();
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, [count]);

  useEffect(() => {
    if (!baseWRef.current || g.pressed) return;
    const L = layout(baseWRef.current, count);
    spring(s.lensX, L.center(Math.min(Math.max(selectedIndex, 0), count - 1)), 'glide');
    anim.current?.kick();
  }, [selectedIndex, count]);

  const prevMin = useRef(minimized);
  useEffect(() => {
    if (g.pressed) return;
    const target = reduce ? (minimized ? MINIMIZED_SCALE : 1) : scrollScale(minimized, leadIn);
    if (prevMin.current !== minimized) {
      prevMin.current = minimized;
      spring(s.scale, target, 'minimize');
    } else {
      s.scale.set(target);
    }
    anim.current?.kick();
    render();
  }, [minimized, leadIn]);

  const localX = (clientX: number) => {
    const rect = wrapRef.current!.getBoundingClientRect();
    return clientX - rect.left;
  };

  const updateDrag = () => {
    const W = baseWRef.current;
    const rest = layout(W, count);
    const overL = Math.max(0, rest.center(0) - g.fingerX);
    const overR = Math.max(0, g.fingerX - rest.center(count - 1));
    const sL = reduce ? 0 : rubberBand(overL);
    const sR = reduce ? 0 : rubberBand(overR);
    spring(s.sL, sL, 'tracking');
    spring(s.sR, sR, 'tracking');
    const L = layout(W, count, sL, sR);
    const local = g.fingerX + sL;
    const cx = Math.min(Math.max(local, L.center(0)), L.center(count - 1));
    spring(s.lensX, cx, g.dragging ? 'tracking' : 'glide');
    spring(s.lensW, (L.slot + LENS_INSET * 2) * 1.14, 'press');
    anim.current?.kick();
  };

  const release = (select: boolean) => {
    const W = baseWRef.current;
    const rest = layout(W, count);
    const index = rest.index(g.fingerX);
    g.pressed = false;
    g.dragging = false;
    spring(s.scale, 1, 'release');
    spring(s.sL, 0, 'release');
    spring(s.sR, 0, 'release');
    spring(s.lift, 0, 'glide');
    spring(s.lensW, rest.slot + LENS_INSET * 2, 'glide');
    spring(s.lensH, BAR_H - LENS_INSET * 2, 'glide');
    spring(s.lensX, rest.center(select ? index : selectedIndex), 'glide');
    anim.current?.kick();
    onInteraction();
    if (select) {
      if ('vibrate' in navigator) navigator.vibrate?.(6);
      onSelect(index);
    }
  };

  const onPointerDown = (e: React.PointerEvent) => {
    if (e.button !== 0) return;
    let x = localX(e.clientX);
    const W = baseWRef.current;
    if (minimized) x = W / 2 + (x - W / 2) / MINIMIZED_SCALE;
    onInteraction();
    g.pressed = true;
    g.dragging = false;
    g.downX = x;
    g.fingerX = x;
    g.pointerId = e.pointerId;
    barRef.current?.setPointerCapture(e.pointerId);
    spring(s.scale, reduce ? 1 : PRESSED_SCALE, 'press');
    spring(s.lift, 1, 'press');
    spring(s.lensH, BAR_H - 4, 'press');
    updateDrag();
  };

  const onPointerMove = (e: React.PointerEvent) => {
    if (!g.pressed || e.pointerId !== g.pointerId) return;
    const x = localX(e.clientX);
    if (!g.dragging && Math.abs(x - g.downX) > DRAG_THRESHOLD) g.dragging = true;
    g.fingerX = x;
    updateDrag();
  };

  const onPointerUp = (e: React.PointerEvent) => {
    if (!g.pressed || e.pointerId !== g.pointerId) return;
    g.fingerX = localX(e.clientX);
    release(true);
  };

  const onPointerCancel = () => {
    if (g.pressed) release(false);
  };

  return (
    <div ref={wrapRef} className={`tabbar-wrap ${hidden ? 'hidden' : ''}`} role="tablist" aria-label="Main">
      <div
        ref={barRef}
        className="tabbar"
        style={{ width: baseW || '100%' }}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerCancel}
        onLostPointerCapture={onPointerCancel}
      >
        <div className="tabbar-glass" />
        <div className="tabbar-lens-clip">
          <div ref={lensRef} className="tabbar-lens" style={{ background: 'var(--lens-rest)' }}>
            <div
              ref={liftRef}
              style={{
                position: 'absolute',
                inset: 0,
                borderRadius: 'inherit',
                opacity: 0,
                background: 'var(--lens-lift)',
                boxShadow: 'inset 0 0 0 0.7px var(--lens-rim), 0 2px 8px rgba(0,0,0,0.14)',
              }}
            />
          </div>
        </div>
        <div className="tabbar-icons">
          {items.map((it, i) => {
            const I = it.icon;
            const on = i === selectedIndex;
            return (
              <div
                key={it.key}
                className="tabbar-slot"
                role="tab"
                aria-selected={on}
                aria-label={it.label}
                tabIndex={0}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    onInteraction();
                    onSelect(i);
                  }
                }}
              >
                <I className="glyph" size={25} weight="regular" style={{ opacity: on ? 0 : 1 }} />
                <I className="glyph" size={25} weight="fill" style={{ opacity: on ? 1 : 0 }} />
                {!!it.badge && <span className="tab-badge num">{it.badge}</span>}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

export function useMinimizeOnScroll(resetKey: unknown) {
  const [minimized, setMinimized] = useState(false);
  const [leadIn, setLeadIn] = useState(0);
  const t = useRef({ lastY: 0, travel: 0, against: false, minimized: false });

  useEffect(() => {
    t.current = { lastY: window.scrollY, travel: 0, against: false, minimized: false };
    setMinimized(false);
    setLeadIn(0);
  }, [resetKey]);

  useEffect(() => {
    const SHRINK = 26;
    const DEAD = 175;
    const GROW = 240;
    const onScroll = () => {
      const tr = t.current;
      const y = window.scrollY;
      const delta = y - tr.lastY;
      tr.lastY = y;
      if (y <= 0) {
        tr.travel = 0;
        tr.against = false;
        if (tr.minimized) {
          tr.minimized = false;
          setMinimized(false);
        }
        setLeadIn(0);
        return;
      }
      if (tr.against !== tr.minimized) {
        tr.travel = 0;
        tr.against = tr.minimized;
      }
      if (!tr.minimized) {
        tr.travel = Math.max(0, tr.travel + delta);
        if (tr.travel >= SHRINK) {
          tr.travel = 0;
          tr.minimized = true;
          tr.against = true;
          setLeadIn(0);
          setMinimized(true);
        } else setLeadIn(tr.travel / SHRINK);
      } else {
        tr.travel = Math.max(0, tr.travel - delta);
        if (tr.travel >= GROW) {
          tr.travel = 0;
          tr.minimized = false;
          tr.against = false;
          setLeadIn(0);
          setMinimized(false);
        } else setLeadIn(Math.max(0, (tr.travel - DEAD) / (GROW - DEAD)));
      }
    };
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  const restore = useCallback(() => {
    t.current.minimized = false;
    t.current.travel = 0;
    t.current.against = false;
    setMinimized(false);
    setLeadIn(0);
  }, []);

  return { minimized, leadIn, restore };
}
