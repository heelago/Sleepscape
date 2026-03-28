/**
 * SVG breath guide overlay. Shows a pulsing circle with "breathe" text.
 * Always visible while enabled. Hides after 20 minutes of total inactivity.
 */
export class BreathGuide {
  private el: HTMLElement;
  private idleTimer: ReturnType<typeof setTimeout> | null = null;
  private enabled = true;
  private static IDLE_TIMEOUT = 20 * 60 * 1000; // 20 minutes

  constructor() {
    this.el = document.createElement('div');
    this.el.className = 'breath-guide';
    this.el.innerHTML = `
      <svg viewBox="0 0 120 120" class="breath-guide-svg">
        <circle cx="60" cy="60" r="40" class="breath-guide-circle" />
      </svg>
      <span class="breath-guide-text">breathe</span>
    `;
    document.body.appendChild(this.el);
  }

  /** Reset idle timer. Call on any user interaction. */
  resetIdle(): void {
    // Show if not already visible
    if (this.enabled) this.show();
    // Reset the long idle timeout
    if (this.idleTimer) clearTimeout(this.idleTimer);
    if (this.enabled) {
      this.idleTimer = setTimeout(() => this.hide(), BreathGuide.IDLE_TIMEOUT);
    }
  }

  show(): void {
    this.el.classList.add('visible');
  }

  setOpacity(v: number): void {
    // Scale the SVG circle stroke and text opacity with prominence
    const circle = this.el.querySelector('.breath-guide-circle') as SVGElement | null;
    const text = this.el.querySelector('.breath-guide-text') as HTMLElement | null;
    if (circle) circle.style.strokeOpacity = `${0.08 + v * 0.35}`;
    if (text) text.style.opacity = `${0.18 + v * 0.5}`;
  }

  hide(): void {
    this.el.classList.remove('visible');
  }

  setEnabled(v: boolean): void {
    this.enabled = v;
    if (!v) {
      this.hide();
      if (this.idleTimer) clearTimeout(this.idleTimer);
    } else {
      this.show();
      // Start the idle timeout
      if (this.idleTimer) clearTimeout(this.idleTimer);
      this.idleTimer = setTimeout(() => this.hide(), BreathGuide.IDLE_TIMEOUT);
    }
  }
}
