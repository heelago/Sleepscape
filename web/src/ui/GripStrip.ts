import type { AppState } from '../state/AppState';

export interface GripStripCallbacks {
  onPlayPause: () => void;
  onClear: () => void;
  onSettingsToggle: () => void;
}

/**
 * Bottom control strip: play/pause, volume, clear, sleep timer, settings gear.
 */
export class GripStrip {
  private el: HTMLElement;
  private state: AppState;
  private callbacks: GripStripCallbacks;

  private playBtn!: HTMLElement;
  private volumeSlider!: HTMLInputElement;
  private sleepBtn!: HTMLElement;
  private sleepMenu!: HTMLElement;
  private settingsBtn!: HTMLElement;

  constructor(state: AppState, callbacks: GripStripCallbacks) {
    this.state = state;
    this.callbacks = callbacks;
    this.el = this.build();
    document.body.appendChild(this.el);
  }

  private build(): HTMLElement {
    const strip = document.createElement('div');
    strip.className = 'gripstrip';

    // Play/Pause
    this.playBtn = document.createElement('button');
    this.playBtn.className = 'gripstrip-btn gripstrip-play';
    this.playBtn.addEventListener('click', () => this.callbacks.onPlayPause());
    strip.appendChild(this.playBtn);

    // Volume
    const volGroup = document.createElement('div');
    volGroup.className = 'gripstrip-vol-group';
    const volIcon = document.createElement('span');
    volIcon.className = 'gripstrip-vol-icon';
    volIcon.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02z"/></svg>';
    volGroup.appendChild(volIcon);
    this.volumeSlider = document.createElement('input');
    this.volumeSlider.type = 'range';
    this.volumeSlider.min = '0';
    this.volumeSlider.max = '1';
    this.volumeSlider.step = '0.01';
    this.volumeSlider.value = String(this.state.volume);
    this.volumeSlider.className = 'gripstrip-volume';
    this.volumeSlider.addEventListener('input', () => {
      this.state.volume = parseFloat(this.volumeSlider.value);
      this.state.notify();
    });
    volGroup.appendChild(this.volumeSlider);
    strip.appendChild(volGroup);

    // Clear
    const clearBtn = document.createElement('button');
    clearBtn.className = 'gripstrip-btn gripstrip-clear';
    clearBtn.textContent = 'clear';
    clearBtn.addEventListener('click', () => this.callbacks.onClear());
    strip.appendChild(clearBtn);

    // Sleep timer
    const sleepWrap = document.createElement('div');
    sleepWrap.className = 'gripstrip-sleep-wrap';
    this.sleepBtn = document.createElement('button');
    this.sleepBtn.className = 'gripstrip-btn gripstrip-sleep';
    this.sleepBtn.innerHTML = '<svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor"><path d="M12 3c-4.97 0-9 4.03-9 9s4.03 9 9 9 9-4.03 9-9c0-.46-.04-.92-.1-1.36-.98 1.37-2.58 2.26-4.4 2.26-2.98 0-5.4-2.42-5.4-5.4 0-1.81.89-3.42 2.26-4.4-.44-.06-.9-.1-1.36-.1z"/></svg> <span class="sleep-label">sleep</span>';
    this.sleepBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      this.sleepMenu.classList.toggle('open');
    });
    sleepWrap.appendChild(this.sleepBtn);

    // Sleep menu
    this.sleepMenu = document.createElement('div');
    this.sleepMenu.className = 'gripstrip-sleep-menu';
    const menuTitle = document.createElement('div');
    menuTitle.className = 'sleep-menu-title';
    menuTitle.textContent = 'SLEEP TIMER';
    this.sleepMenu.appendChild(menuTitle);
    const menuDesc = document.createElement('div');
    menuDesc.className = 'sleep-menu-desc';
    menuDesc.textContent = 'Sound fades to silence';
    this.sleepMenu.appendChild(menuDesc);

    for (const mins of [15, 30, 60]) {
      const btn = document.createElement('button');
      btn.className = 'sleep-menu-option';
      btn.textContent = `${mins}m`;
      btn.addEventListener('click', () => {
        this.state.sleepTimerMinutes = mins;
        this.state.sleepTimerStarted = new Date();
        this.state.notify();
        this.sleepMenu.classList.remove('open');
        this.update();
      });
      this.sleepMenu.appendChild(btn);
    }

    const cancelBtn = document.createElement('button');
    cancelBtn.className = 'sleep-menu-option sleep-menu-cancel';
    cancelBtn.textContent = 'cancel';
    cancelBtn.addEventListener('click', () => {
      this.state.sleepTimerMinutes = null;
      this.state.sleepTimerStarted = null;
      this.state.notify();
      this.sleepMenu.classList.remove('open');
      this.update();
    });
    this.sleepMenu.appendChild(cancelBtn);
    sleepWrap.appendChild(this.sleepMenu);
    strip.appendChild(sleepWrap);

    // Settings
    this.settingsBtn = document.createElement('button');
    this.settingsBtn.className = 'gripstrip-btn gripstrip-settings';
    this.settingsBtn.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>';
    this.settingsBtn.addEventListener('click', () => this.callbacks.onSettingsToggle());
    strip.appendChild(this.settingsBtn);

    // Close sleep menu on outside click
    document.addEventListener('click', () => {
      this.sleepMenu.classList.remove('open');
    });

    this.update();
    return strip;
  }

  update(): void {
    // Play/pause icon
    if (this.state.isPlaying) {
      this.playBtn.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/></svg>';
      this.playBtn.classList.add('active');
    } else {
      this.playBtn.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"/></svg>';
      this.playBtn.classList.remove('active');
    }

    // Sleep label
    const sleepLabel = this.sleepBtn.querySelector('.sleep-label') as HTMLElement;
    if (this.state.sleepTimerMinutes) {
      sleepLabel.textContent = `${this.state.sleepTimerMinutes}m`;
      this.sleepBtn.classList.add('active');
    } else {
      sleepLabel.textContent = 'sleep';
      this.sleepBtn.classList.remove('active');
    }

    // Settings active
    this.settingsBtn.classList.toggle('active', this.state.showSettings);
  }
}
