/**
 * Full-screen dark overlay that fades in when the sleep timer completes.
 * Tap to dismiss.
 */
export class SleepOverlay {
  private el: HTMLElement;

  constructor() {
    this.el = document.createElement('div');
    this.el.className = 'sleep-overlay';
    this.el.addEventListener('click', () => this.hide());
    this.el.addEventListener('touchstart', () => this.hide(), { passive: true });
    document.body.appendChild(this.el);
  }

  show(): void {
    this.el.classList.add('visible');
  }

  hide(): void {
    this.el.classList.remove('visible');
  }

  get isVisible(): boolean {
    return this.el.classList.contains('visible');
  }
}
