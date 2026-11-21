export class SpringValue {
  value: number;
  velocity = 0;
  target: number;
  private k = 170;
  private c = 26;

  constructor(v: number) {
    this.value = v;
    this.target = v;
  }

  to(target: number, response: number, dampingFraction: number) {
    this.target = target;
    const w = (2 * Math.PI) / Math.max(0.01, response);
    this.k = w * w;
    this.c = 2 * dampingFraction * w;
  }

  set(v: number) {
    this.value = v;
    this.target = v;
    this.velocity = 0;
  }

  step(dt: number): boolean {
    const steps = Math.max(1, Math.ceil(dt / (1 / 240)));
    const h = dt / steps;
    for (let i = 0; i < steps; i++) {
      const a = -this.k * (this.value - this.target) - this.c * this.velocity;
      this.velocity += a * h;
      this.value += this.velocity * h;
    }
    if (Math.abs(this.value - this.target) < 0.0005 && Math.abs(this.velocity) < 0.005) {
      this.value = this.target;
      this.velocity = 0;
      return false;
    }
    return true;
  }
}

export class Animator {
  private raf = 0;
  private last = 0;
  constructor(
    private springs: SpringValue[],
    private render: () => void,
  ) {}

  kick() {
    if (this.raf) return;
    this.last = performance.now();
    const tick = (t: number) => {
      const dt = Math.min(0.05, (t - this.last) / 1000);
      this.last = t;
      let moving = false;
      for (const s of this.springs) moving = s.step(dt) || moving;
      this.render();
      this.raf = moving ? requestAnimationFrame(tick) : 0;
    };
    this.raf = requestAnimationFrame(tick);
  }

  stop() {
    cancelAnimationFrame(this.raf);
    this.raf = 0;
  }
}

export const prefersReducedMotion = () => window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;
