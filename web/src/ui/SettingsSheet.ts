import type { AppState } from '../state/AppState';
import { DrawMode, LineStyle, LINE_STYLE_NAMES } from '../state/types';
import { BREATHING_PRESETS } from '../state/BreathingPreset';
import { AUDIO_PRESETS } from '../state/AudioPreset';

/**
 * Half-screen settings sheet with 5 card sections:
 * Canvas, Stroke, Effects, Breathing, Audio.
 */
export class SettingsSheet {
  private el: HTMLElement;
  private scrim: HTMLElement;
  private state: AppState;
  private onChanged: () => void;
  private idleTimer: ReturnType<typeof setTimeout> | null = null;

  constructor(state: AppState, onChanged: () => void) {
    this.state = state;
    this.onChanged = onChanged;

    // Scrim
    this.scrim = document.createElement('div');
    this.scrim.className = 'settings-scrim';
    this.scrim.addEventListener('click', () => this.close());

    // Sheet
    this.el = document.createElement('div');
    this.el.className = 'settings-sheet';
    this.el.addEventListener('click', () => this.resetIdleTimer());
    this.el.addEventListener('touchstart', () => this.resetIdleTimer(), { passive: true });

    this.buildContent();
    document.body.appendChild(this.scrim);
    document.body.appendChild(this.el);
  }

  private buildContent(): void {
    // Drag handle
    const handle = document.createElement('div');
    handle.className = 'settings-handle';
    const handleBar = document.createElement('div');
    handleBar.className = 'settings-handle-bar';
    handle.appendChild(handleBar);
    this.el.appendChild(handle);

    // Cards container
    const cards = document.createElement('div');
    cards.className = 'settings-cards';

    cards.appendChild(this.buildCanvasCard());
    cards.appendChild(this.buildStrokeCard());
    cards.appendChild(this.buildEffectsCard());
    cards.appendChild(this.buildBreathingCard());
    cards.appendChild(this.buildAudioCard());

    this.el.appendChild(cards);
  }

  // ── Canvas Card ──
  private buildCanvasCard(): HTMLElement {
    const card = this.card('CANVAS');

    // Mode pills
    card.appendChild(this.label('mode'));
    card.appendChild(this.hint('mandala mirrors your strokes with rotational symmetry'));
    const modeRow = this.pillRow();
    for (const mode of [DrawMode.Free, DrawMode.Mandala]) {
      modeRow.appendChild(this.pill(mode, this.state.drawMode === mode, () => {
        this.state.drawMode = mode;
        this.changed();
      }));
    }
    card.appendChild(modeRow);

    // Fold count (only for mandala)
    card.appendChild(this.label('folds'));
    card.appendChild(this.hint('higher fold counts create more intricate patterns'));
    const foldRow = this.pillRow();
    for (const n of [4, 6, 8, 12, 16]) {
      foldRow.appendChild(this.pill(String(n), this.state.symmetry === n, () => {
        this.state.symmetry = n;
        this.changed();
      }));
    }
    card.appendChild(foldRow);

    return card;
  }

  // ── Stroke Card ──
  private buildStrokeCard(): HTMLElement {
    const card = this.card('STROKE');

    // Line style pills
    card.appendChild(this.label('style'));
    card.appendChild(this.hint('changes how each stroke looks and glows'));
    const styleRow = this.pillRow();
    for (const ls of [LineStyle.Neon, LineStyle.SoftGlow, LineStyle.Dashed, LineStyle.Dotted, LineStyle.Sketch]) {
      styleRow.appendChild(this.pill(LINE_STYLE_NAMES[ls], this.state.lineStyle === ls, () => {
        this.state.lineStyle = ls;
        this.changed();
      }));
    }
    card.appendChild(styleRow);

    // Auto color
    card.appendChild(this.hint('cycles through the palette as you draw'));
    card.appendChild(this.toggle('auto color', this.state.autoColorEnabled, (v) => {
      this.state.autoColorEnabled = v;
      this.changed();
    }));

    // Auto color speed slider
    card.appendChild(this.slider('speed', 0.02, 0.25, this.state.autoColorSpeed, '4s', '30s', (v) => {
      this.state.autoColorSpeed = v;
      this.changed();
    }));

    // Path smoothing
    card.appendChild(this.hint('rounds out sharp corners in your strokes'));
    card.appendChild(this.toggle('path smoothing', this.state.pathSmoothingEnabled, (v) => {
      this.state.pathSmoothingEnabled = v;
      this.changed();
    }));

    // Slow ink
    card.appendChild(this.hint('adds resistance for a more deliberate feel'));
    card.appendChild(this.toggle('slow ink', this.state.slowInkEnabled, (v) => {
      this.state.slowInkEnabled = v;
      this.changed();
    }));

    // Pace throttle
    card.appendChild(this.hint('controls how quickly new points are accepted'));
    card.appendChild(this.slider('pace', 0, 120, this.state.paceThrottle, 'free', 'slow', (v) => {
      this.state.paceThrottle = v;
      this.changed();
    }));

    return card;
  }

  // ── Effects Card ──
  private buildEffectsCard(): HTMLElement {
    const card = this.card('EFFECTS');

    card.appendChild(this.hint('bright particles trail along pencil strokes'));
    card.appendChild(this.toggle('sparkles', this.state.sparklesEnabled, (v) => {
      this.state.sparklesEnabled = v;
      this.changed();
    }));

    card.appendChild(this.hint('expanding rings bloom from each touch — turn off here if distracting'));
    card.appendChild(this.toggle('ripples', this.state.ripplesEnabled, (v) => {
      this.state.ripplesEnabled = v;
      this.changed();
    }));

    card.appendChild(this.hint('how far the ripple rings expand outward'));
    card.appendChild(this.slider('ripple reach', 0.0, 1.0, this.state.rippleReach, 'tight', 'wide', (v) => {
      this.state.rippleReach = v;
      this.changed();
    }));

    card.appendChild(this.hint('controls the soft halo around each stroke'));
    card.appendChild(this.slider('glow intensity', 0.0, 1.0, this.state.glowIntensity, 'crisp', 'dreamy', (v) => {
      this.state.glowIntensity = v;
      this.state.needsFullRerender = true;
      this.changed();
    }));

    card.appendChild(this.hint('limits maximum brightness to keep things calm'));
    card.appendChild(this.slider('brightness cap', 0.3, 1.0, this.state.brightnessCap, 'soft', 'full', (v) => {
      this.state.brightnessCap = v;
      this.changed();
    }));

    return card;
  }

  // ── Breathing Card ──
  private buildBreathingCard(): HTMLElement {
    const card = this.card('BREATHING');

    card.appendChild(this.hint('an animated ring that guides your breathing'));
    card.appendChild(this.toggle('breath pulse', this.state.breathPulseEnabled, (v) => {
      this.state.breathPulseEnabled = v;
      this.changed();
    }));

    // Preset pills
    card.appendChild(this.label('pattern'));
    card.appendChild(this.hint('each pattern has different timing for inhale, hold, and exhale'));
    const presetRow = this.pillRow();
    presetRow.style.flexWrap = 'wrap';
    for (const preset of BREATHING_PRESETS) {
      presetRow.appendChild(this.pill(preset.name, this.state.breathingPresetId === preset.id, () => {
        this.state.breathingPresetId = preset.id;
        this.changed();
      }));
    }
    presetRow.appendChild(this.pill('custom', this.state.breathingPresetId === 'custom', () => {
      this.state.breathingPresetId = 'custom';
      this.changed();
    }));
    card.appendChild(presetRow);

    // Show description of current preset
    const desc = document.createElement('div');
    desc.className = 'settings-breath-desc';
    const currentPreset = BREATHING_PRESETS.find(p => p.id === this.state.breathingPresetId);
    if (currentPreset) {
      const phases = this.state.breathPhases;
      desc.textContent = `${currentPreset.subtitle} \u00b7 ${phases.inhale}s in \u00b7 ${phases.hold}s hold \u00b7 ${phases.exhale}s out`;
    }
    card.appendChild(desc);

    // Visibility slider
    card.appendChild(this.hint('how prominent the breathing ring appears'));
    card.appendChild(this.slider('visibility', 0.1, 1.0, this.state.breathPulseOpacity, 'dim', 'bright', (v) => {
      this.state.breathPulseOpacity = v;
      this.changed();
    }));

    // Phase text toggle
    card.appendChild(this.hint('displays inhale/hold/exhale inside the ring'));
    card.appendChild(this.toggle('show phase text', this.state.breathPhaseText, (v) => {
      this.state.breathPhaseText = v;
      this.changed();
    }));

    // Custom sliders (show only when custom)
    if (this.state.breathingPresetId === 'custom') {
      card.appendChild(this.slider('inhale', 1, 10, this.state.customInhale, '1s', '10s', (v) => {
        this.state.customInhale = Math.round(v);
        this.changed();
      }));
      card.appendChild(this.slider('hold', 0, 10, this.state.customHold, '0s', '10s', (v) => {
        this.state.customHold = Math.round(v);
        this.changed();
      }));
      card.appendChild(this.slider('exhale', 1, 10, this.state.customExhale, '1s', '10s', (v) => {
        this.state.customExhale = Math.round(v);
        this.changed();
      }));
      card.appendChild(this.slider('hold 2', 0, 10, this.state.customHold2, '0s', '10s', (v) => {
        this.state.customHold2 = Math.round(v);
        this.changed();
      }));
    }

    return card;
  }

  // ── Audio Card ──
  private buildAudioCard(): HTMLElement {
    const card = this.card('AUDIO');

    card.appendChild(this.label('frequency'));
    for (const preset of AUDIO_PRESETS) {
      const btn = document.createElement('button');
      btn.className = 'settings-audio-btn';
      if (this.state.currentPreset.id === preset.id) btn.classList.add('active');
      const name = document.createElement('span');
      name.className = 'settings-audio-name';
      name.textContent = preset.name;
      btn.appendChild(name);
      const desc = document.createElement('span');
      desc.className = 'settings-audio-desc';
      desc.textContent = preset.description;
      btn.appendChild(desc);
      btn.addEventListener('click', () => {
        this.state.currentPreset = preset;
        this.changed();
      });
      card.appendChild(btn);
    }

    return card;
  }

  // ── Building blocks ──

  private card(title: string): HTMLElement {
    const card = document.createElement('div');
    card.className = 'settings-card';
    const h = document.createElement('div');
    h.className = 'settings-card-title';
    h.textContent = title;
    card.appendChild(h);
    return card;
  }

  private label(text: string): HTMLElement {
    const l = document.createElement('div');
    l.className = 'settings-label';
    l.textContent = text;
    return l;
  }

  private hint(text: string): HTMLElement {
    const p = document.createElement('p');
    p.className = 'settings-hint';
    p.textContent = text;
    return p;
  }

  private pillRow(): HTMLElement {
    const row = document.createElement('div');
    row.className = 'settings-pill-row';
    return row;
  }

  private pill(text: string, active: boolean, onClick: () => void): HTMLElement {
    const btn = document.createElement('button');
    btn.className = 'settings-pill';
    if (active) btn.classList.add('active');
    btn.textContent = text;
    btn.addEventListener('click', onClick);
    return btn;
  }

  private toggle(text: string, value: boolean, onChange: (v: boolean) => void): HTMLElement {
    const row = document.createElement('div');
    row.className = 'settings-toggle-row';

    const label = document.createElement('span');
    label.className = 'settings-toggle-label';
    label.textContent = text;
    row.appendChild(label);

    const toggle = document.createElement('button');
    toggle.className = 'settings-toggle';
    if (value) toggle.classList.add('on');

    const knob = document.createElement('span');
    knob.className = 'settings-toggle-knob';
    toggle.appendChild(knob);

    toggle.addEventListener('click', () => {
      const newVal = !toggle.classList.contains('on');
      toggle.classList.toggle('on', newVal);
      onChange(newVal);
    });
    row.appendChild(toggle);

    return row;
  }

  private slider(label: string, min: number, max: number, value: number, leftLabel: string, rightLabel: string, onChange: (v: number) => void): HTMLElement {
    const row = document.createElement('div');
    row.className = 'settings-slider-row';

    const lbl = document.createElement('span');
    lbl.className = 'settings-slider-label';
    lbl.textContent = label;
    row.appendChild(lbl);

    const sliderWrap = document.createElement('div');
    sliderWrap.className = 'settings-slider-wrap';

    const left = document.createElement('span');
    left.className = 'settings-slider-range';
    left.textContent = leftLabel;
    sliderWrap.appendChild(left);

    const input = document.createElement('input');
    input.type = 'range';
    input.min = String(min);
    input.max = String(max);
    input.step = String((max - min) / 100);
    input.value = String(value);
    input.className = 'settings-slider';
    input.addEventListener('input', () => {
      onChange(parseFloat(input.value));
    });
    sliderWrap.appendChild(input);

    const right = document.createElement('span');
    right.className = 'settings-slider-range';
    right.textContent = rightLabel;
    sliderWrap.appendChild(right);

    row.appendChild(sliderWrap);
    return row;
  }

  // ── Open/Close ──

  open(): void {
    this.scrim.classList.add('open');
    this.el.classList.add('open');
    this.resetIdleTimer();
    // Rebuild content to reflect current state
    this.el.innerHTML = '';
    this.buildContent();
  }

  close(): void {
    this.scrim.classList.remove('open');
    this.el.classList.remove('open');
    this.state.showSettings = false;
    if (this.idleTimer) clearTimeout(this.idleTimer);
  }

  get isOpen(): boolean {
    return this.el.classList.contains('open');
  }

  private resetIdleTimer(): void {
    if (this.idleTimer) clearTimeout(this.idleTimer);
    this.idleTimer = setTimeout(() => this.close(), 10000);
  }

  private changed(): void {
    this.state.notify();
    this.onChanged();
    this.resetIdleTimer();
    // Rebuild to reflect new state
    this.el.innerHTML = '';
    this.buildContent();
  }
}
