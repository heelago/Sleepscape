const STORAGE_KEY = 'sleepscape_welcomed';

const TIPS: { label: string; desc: string }[] = [
  { label: 'Draw', desc: 'Touch anywhere to create. Strokes mirror automatically.' },
  { label: 'Breathe', desc: 'The ring at the centre guides your breathing. Follow it.' },
  { label: 'Listen', desc: 'Press play for generative ambient audio with binaural beats.' },
  { label: 'Settings', desc: 'Tap the gear to change modes, colors, effects, and patterns.' },
];

/**
 * Full-screen welcome overlay shown on first visit.
 * Can be re-shown via the info button.
 */
export class WelcomeOverlay {
  private el: HTMLElement;
  private isFirstVisit: boolean;
  private onDismissCallback: ((isFirstVisit: boolean) => void) | null = null;

  constructor() {
    this.isFirstVisit = !localStorage.getItem(STORAGE_KEY);
    this.el = this.build();
    document.body.appendChild(this.el);

    // Show on first visit
    if (this.isFirstVisit) {
      requestAnimationFrame(() => this.show());
    }
  }

  /** Register a callback fired when the overlay is dismissed. */
  onDismiss(cb: (isFirstVisit: boolean) => void): void {
    this.onDismissCallback = cb;
  }

  show(): void {
    this.el.classList.add('visible');
  }

  private dismiss(): void {
    const wasFirst = this.isFirstVisit;
    this.isFirstVisit = false;
    localStorage.setItem(STORAGE_KEY, 'true');
    this.el.classList.remove('visible');
    if (this.onDismissCallback) {
      // Small delay so the fade-out starts before tour begins
      setTimeout(() => this.onDismissCallback!(wasFirst), 400);
    }
  }

  private build(): HTMLElement {
    const overlay = document.createElement('div');
    overlay.className = 'welcome-overlay';

    const content = document.createElement('div');
    content.className = 'welcome-content';

    const title = document.createElement('div');
    title.className = 'welcome-title';
    title.textContent = 'sleepscape';
    content.appendChild(title);

    for (const tip of TIPS) {
      const tipEl = document.createElement('div');
      tipEl.className = 'welcome-tip';

      const label = document.createElement('div');
      label.className = 'welcome-tip-label';
      label.textContent = tip.label;
      tipEl.appendChild(label);

      const desc = document.createElement('div');
      desc.className = 'welcome-tip-desc';
      desc.textContent = tip.desc;
      tipEl.appendChild(desc);

      content.appendChild(tipEl);
    }

    const btn = document.createElement('button');
    btn.className = 'welcome-start';
    btn.textContent = 'start drawing';
    btn.addEventListener('click', () => this.dismiss());
    content.appendChild(btn);

    overlay.appendChild(content);

    // Also dismiss on overlay background click
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) this.dismiss();
    });

    return overlay;
  }
}
