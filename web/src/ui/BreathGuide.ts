/**
 * SVG breath guide overlay. Shows a pulsing circle with phase text
 * (inhale/hold/exhale) or static "breathe". Always visible while enabled.
 * Hides after 20 minutes of total inactivity.
 */
export class BreathGuide {
  private el: HTMLElement;
  private textEl: HTMLElement;
  private idleTimer: ReturnType<typeof setTimeout> | null = null;
  private enabled = true;
  private showPhaseText = true;
  private phaseInterval: ReturnType<typeof setInterval> | null = null;
  private phases = { inhale: 6, hold: 0, exhale: 6, hold2: 0 };
  private cycleStart = 0;
  private static IDLE_TIMEOUT = 20 * 60 * 1000; // 20 minutes

  constructor() {
    this.el = document.createElement('div');
    this.el.className = 'breath-guide';
    this.el.innerHTML = `
      <span class="breath-guide-text">breathe</span>
    `;
    this.textEl = this.el.querySelector('.breath-guide-text')!;
    document.body.appendChild(this.el);
    this.cycleStart = performance.now() / 1000;
    this.startPhaseUpdater();
  }

  /** Reset idle timer. Call on any user interaction. */
  resetIdle(): void {
    if (this.enabled) this.show();
    if (this.idleTimer) clearTimeout(this.idleTimer);
    if (this.enabled) {
      this.idleTimer = setTimeout(() => this.hide(), BreathGuide.IDLE_TIMEOUT);
    }
  }

  show(): void {
    this.el.classList.add('visible');
  }

  hide(): void {
    this.el.classList.remove('visible');
  }

  setOpacity(v: number): void {
    if (this.textEl) this.textEl.style.opacity = `${0.5 + v * 0.5}`;
  }

  setPhases(phases: { inhale: number; hold: number; exhale: number; hold2: number }): void {
    this.phases = phases;
  }

  setShowPhaseText(v: boolean): void {
    this.showPhaseText = v;
    if (!v) {
      this.textEl.textContent = 'breathe';
    }
  }

  setEnabled(v: boolean): void {
    this.enabled = v;
    if (!v) {
      this.hide();
      if (this.idleTimer) clearTimeout(this.idleTimer);
    } else {
      this.show();
      if (this.idleTimer) clearTimeout(this.idleTimer);
      this.idleTimer = setTimeout(() => this.hide(), BreathGuide.IDLE_TIMEOUT);
    }
  }

  private startPhaseUpdater(): void {
    this.phaseInterval = setInterval(() => {
      if (!this.showPhaseText || !this.enabled) return;
      const p = this.phases;
      const cycle = p.inhale + p.hold + p.exhale + p.hold2;
      if (cycle <= 0) return;

      const now = performance.now() / 1000;
      const t = (now - this.cycleStart) % cycle;

      let label: string;
      if (t < p.inhale) {
        label = 'inhale';
      } else if (t < p.inhale + p.hold) {
        label = 'hold';
      } else if (t < p.inhale + p.hold + p.exhale) {
        label = 'exhale';
      } else {
        label = 'hold';
      }

      if (this.textEl.textContent !== label) {
        this.textEl.textContent = label;
      }
    }, 200);
  }
}
