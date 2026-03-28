import type { SettingsSheet } from './SettingsSheet';

const STORAGE_KEY = 'sleepscape_tour_done';
const SPOTLIGHT_PAD = 8;

interface TourStep {
  selector: string;
  title: string;
  description: string;
  cardPosition: 'above' | 'below';
  beforeShow?: () => Promise<void>;
  onLeave?: () => void;
  pauseSettingsIdle?: boolean;
  scrollIntoView?: boolean;
}

export interface TourDeps {
  settingsSheet: SettingsSheet;
  onSettingsOpen: () => void;
  onSettingsClose: () => void;
}

export class GuidedTour {
  private deps: TourDeps;
  private steps: TourStep[];
  private currentIndex = -1;
  private overlay!: HTMLElement;
  private spotlight!: HTMLElement;
  private card!: HTMLElement;
  private counter!: HTMLElement;
  private titleEl!: HTMLElement;
  private descEl!: HTMLElement;
  private nextBtn!: HTMLElement;
  private active = false;

  constructor(deps: TourDeps) {
    this.deps = deps;
    this.steps = this.buildSteps();
    this.buildDOM();
  }

  get hasCompleted(): boolean {
    return localStorage.getItem(STORAGE_KEY) === 'true';
  }

  start(): void {
    if (this.active) return;
    this.active = true;
    document.body.appendChild(this.overlay);
    document.body.appendChild(this.spotlight);
    document.body.appendChild(this.card);
    window.addEventListener('resize', this.onResize);
    this.showStep(0);
  }

  next(): void {
    this.clearStep();
    const nextIdx = this.currentIndex + 1;
    if (nextIdx >= this.steps.length) {
      this.finish();
    } else {
      this.showStep(nextIdx);
    }
  }

  skip(): void {
    this.clearStep();
    this.finish();
  }

  private finish(): void {
    this.active = false;
    localStorage.setItem(STORAGE_KEY, 'true');
    window.removeEventListener('resize', this.onResize);
    this.overlay.remove();
    this.spotlight.remove();
    this.card.remove();
    this.currentIndex = -1;
  }

  private async showStep(index: number): Promise<void> {
    this.currentIndex = index;
    const step = this.steps[index];

    // Pause settings idle if needed
    if (step.pauseSettingsIdle) {
      this.deps.settingsSheet.pauseIdleTimer();
    }

    // Run beforeShow (e.g. open settings)
    if (step.beforeShow) {
      await step.beforeShow();
    }

    // Find target
    const target = document.querySelector<HTMLElement>(step.selector);
    if (!target) {
      // Skip missing targets
      this.next();
      return;
    }

    // Scroll into view if needed
    if (step.scrollIntoView) {
      target.scrollIntoView({ behavior: 'smooth', block: 'center' });
      await this.wait(350);
    }

    // Position spotlight
    this.positionSpotlight(target);

    // Set card content
    this.counter.textContent = `${index + 1} / ${this.steps.length}`;
    this.titleEl.textContent = step.title;
    this.descEl.textContent = step.description;
    this.nextBtn.textContent = index === this.steps.length - 1 ? 'done' : 'next';

    // Position card
    this.positionCard(target, step.cardPosition);

    // Fade in card
    requestAnimationFrame(() => this.card.classList.add('visible'));
  }

  private clearStep(): void {
    if (this.currentIndex < 0) return;
    const step = this.steps[this.currentIndex];

    if (step.pauseSettingsIdle) {
      this.deps.settingsSheet.resumeIdleTimer();
    }
    if (step.onLeave) {
      step.onLeave();
    }

    this.card.classList.remove('visible');
  }

  private positionSpotlight(target: HTMLElement): void {
    const rect = target.getBoundingClientRect();
    this.spotlight.style.top = `${rect.top - SPOTLIGHT_PAD}px`;
    this.spotlight.style.left = `${rect.left - SPOTLIGHT_PAD}px`;
    this.spotlight.style.width = `${rect.width + SPOTLIGHT_PAD * 2}px`;
    this.spotlight.style.height = `${rect.height + SPOTLIGHT_PAD * 2}px`;
  }

  private positionCard(target: HTMLElement, position: 'above' | 'below'): void {
    const rect = target.getBoundingClientRect();
    const cardWidth = 280;

    // Horizontal: center on target, clamp to viewport
    let left = rect.left + rect.width / 2 - cardWidth / 2;
    left = Math.max(12, Math.min(left, window.innerWidth - cardWidth - 12));
    this.card.style.left = `${left}px`;

    if (position === 'above') {
      this.card.style.bottom = 'auto';
      this.card.style.top = `${rect.top - SPOTLIGHT_PAD - 12}px`;
      this.card.style.transform = 'translateY(-100%)';
    } else {
      this.card.style.top = `${rect.bottom + SPOTLIGHT_PAD + 12}px`;
      this.card.style.bottom = 'auto';
      this.card.style.transform = 'translateY(0)';
    }
  }

  private onResize = (): void => {
    if (!this.active || this.currentIndex < 0) return;
    const step = this.steps[this.currentIndex];
    const target = document.querySelector<HTMLElement>(step.selector);
    if (target) {
      this.positionSpotlight(target);
      this.positionCard(target, step.cardPosition);
    }
  };

  private wait(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  private buildSteps(): TourStep[] {
    return [
      {
        selector: '.topbar-palette-scroll',
        title: 'colour palettes',
        description: 'Swipe to browse palettes. Each sets ink colours and mood.',
        cardPosition: 'below',
      },
      {
        selector: '.topbar-ink-row',
        title: 'ink colours',
        description: 'Tap a dot to pick your drawing colour.',
        cardPosition: 'below',
      },
      {
        selector: '.topbar-brush-btn',
        title: 'brush width',
        description: 'Choose from hairline to marker. Thicker strokes carry more glow.',
        cardPosition: 'below',
      },
      {
        selector: '.gripstrip-play',
        title: 'ambient audio',
        description: "Press play for generative soundscapes with binaural beats. If you can\u2019t hear anything, check your phone isn\u2019t on silent.",
        cardPosition: 'above',
      },
      {
        selector: '.gripstrip-vol-group',
        title: 'volume',
        description: 'Drag to adjust. The sleep timer fades this to zero.',
        cardPosition: 'above',
      },
      {
        selector: '.gripstrip-sleep',
        title: 'sleep timer',
        description: 'Set 15, 30, or 60 minutes. Audio fades out, then the screen goes dark.',
        cardPosition: 'above',
      },
      {
        selector: '.gripstrip-settings',
        title: 'settings',
        description: 'Open for drawing modes, effects, breathing, and audio presets.',
        cardPosition: 'above',
      },
      {
        selector: '.settings-card:nth-child(1)',
        title: 'canvas & stroke',
        description: 'Free draw or mandala mode. Mandala mirrors your strokes with rotational symmetry.',
        cardPosition: 'above',
        pauseSettingsIdle: true,
        beforeShow: async () => {
          if (!this.deps.settingsSheet.isOpen) {
            this.deps.onSettingsOpen();
          }
          await this.wait(450);
        },
      },
      {
        selector: '.settings-card:nth-child(3)',
        title: 'effects',
        description: 'Sparkles, ripples, and glow. Adjust intensity to keep things calm or dreamy.',
        cardPosition: 'above',
        pauseSettingsIdle: true,
        scrollIntoView: true,
      },
      {
        selector: '.settings-card:nth-child(4)',
        title: 'breathing',
        description: 'An animated ring guides your breathing. Pick a pattern or create your own.',
        cardPosition: 'above',
        pauseSettingsIdle: true,
        scrollIntoView: true,
        onLeave: () => {
          this.deps.onSettingsClose();
        },
      },
    ];
  }

  private buildDOM(): void {
    // Click-blocking overlay
    this.overlay = document.createElement('div');
    this.overlay.className = 'tour-overlay';
    this.overlay.addEventListener('click', (e) => {
      e.stopPropagation();
      e.preventDefault();
    });

    // Spotlight cutout
    this.spotlight = document.createElement('div');
    this.spotlight.className = 'tour-spotlight';

    // Description card
    this.card = document.createElement('div');
    this.card.className = 'tour-card';

    this.counter = document.createElement('div');
    this.counter.className = 'tour-card-counter';
    this.card.appendChild(this.counter);

    this.titleEl = document.createElement('div');
    this.titleEl.className = 'tour-card-title';
    this.card.appendChild(this.titleEl);

    this.descEl = document.createElement('div');
    this.descEl.className = 'tour-card-desc';
    this.card.appendChild(this.descEl);

    const actions = document.createElement('div');
    actions.className = 'tour-card-actions';

    const skipBtn = document.createElement('button');
    skipBtn.className = 'tour-card-skip';
    skipBtn.textContent = 'skip';
    skipBtn.addEventListener('click', () => this.skip());
    actions.appendChild(skipBtn);

    this.nextBtn = document.createElement('button');
    this.nextBtn.className = 'tour-card-next';
    this.nextBtn.textContent = 'next';
    this.nextBtn.addEventListener('click', () => this.next());
    actions.appendChild(this.nextBtn);

    this.card.appendChild(actions);
  }
}
