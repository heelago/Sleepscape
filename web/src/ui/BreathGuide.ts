/**
 * SVG breath guide that appears after idle. Shows a pulsing circle
 * with "breathe" text, fading in/out.
 */
export class BreathGuide {
  private el: HTMLElement;
  private idleTimer: ReturnType<typeof setTimeout> | null = null;
  private enabled = true;

  constructor() {
    this.el = document.createElement('div');
    this.el.className = 'breath-guide';
    this.el.innerHTML = `
      <svg viewBox="0 0 120 120" class="breath-guide-svg">
        <circle cx="60" cy="60" r="40" class="breath-guide-circle" />
      </svg>
      <span class="breath-guide-text">breathe</span>
    `;
    // Tap to dismiss
    this.el.addEventListener('click', () => this.hide());
    document.body.appendChild(this.el);
  }

  /** Reset idle timer. Call on any user interaction. */
  resetIdle(): void {
    this.hide();
    if (this.idleTimer) clearTimeout(this.idleTimer);
    if (this.enabled) {
      this.idleTimer = setTimeout(() => this.show(), 5000);
    }
  }

  show(): void {
    this.el.classList.add('visible');
  }

  hide(): void {
    this.el.classList.remove('visible');
  }

  setEnabled(v: boolean): void {
    this.enabled = v;
    if (!v) {
      this.hide();
      if (this.idleTimer) clearTimeout(this.idleTimer);
    }
  }
}
