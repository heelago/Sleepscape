import { DrawMode, LineStyle, hexToRgba, type RGBA } from './types';
import { PALETTES, CANVAS_BACKGROUNDS, type Palette, type CanvasBackground } from './Palette';
import { AUDIO_PRESETS, type AudioPreset } from './AudioPreset';
import { BREATHING_PRESETS, type BreathingPreset } from './BreathingPreset';
import { loadFloat, loadBool, saveFloat, saveBool } from '../utils/persistence';

export type StateChangeCallback = () => void;

export class AppState {
  // Drawing
  drawMode: DrawMode = DrawMode.Mandala;
  symmetry = 8;
  brushSize = 4.0;
  currentPalette: Palette = PALETTES[0];
  currentInkIndex = 0;
  lineStyle: LineStyle = LineStyle.Neon;

  // Effects
  sparklesEnabled = false;
  ripplesEnabled = true;
  rippleReach = 0.5;
  bloomsEnabled = false;
  bloomSpawnRate = 0.5;
  bloomIntensity = 0.6;

  // Glow & brightness (persisted)
  private _glowIntensity = loadFloat('glowIntensity', 0.65);
  private _brightnessCap = loadFloat('brightnessCap', 0.70);

  get glowIntensity(): number { return this._glowIntensity; }
  set glowIntensity(v: number) { this._glowIntensity = v; saveFloat('glowIntensity', v); this.notify(); }

  get brightnessCap(): number { return this._brightnessCap; }
  set brightnessCap(v: number) { this._brightnessCap = v; saveFloat('brightnessCap', v); this.notify(); }

  // Breathing
  breathPulseEnabled = true;
  breathingPresetId = 'resonance';
  customInhale = 4;
  customHold = 2;
  customExhale = 6;
  customHold2 = 0;

  // Stroke behavior (persisted)
  private _pathSmoothing = loadBool('pathSmoothing', false);
  private _slowInk = loadBool('slowInk', false);
  private _paceThrottle = loadFloat('paceThrottle', 0);

  get pathSmoothingEnabled(): boolean { return this._pathSmoothing; }
  set pathSmoothingEnabled(v: boolean) { this._pathSmoothing = v; saveBool('pathSmoothing', v); }

  get slowInkEnabled(): boolean { return this._slowInk; }
  set slowInkEnabled(v: boolean) { this._slowInk = v; saveBool('slowInk', v); }

  get paceThrottle(): number { return this._paceThrottle; }
  set paceThrottle(v: number) { this._paceThrottle = v; saveFloat('paceThrottle', v); }

  // Auto color cycling
  autoColorEnabled = true;
  autoColorSpeed = 0.077;

  // Audio
  isPlaying = false;
  volume = 0.7;
  currentPreset: AudioPreset = AUDIO_PRESETS[0];

  // Canvas background
  canvasBackground: CanvasBackground = CANVAS_BACKGROUNDS[0];

  // Sleep timer
  sleepTimerMinutes: number | null = null;
  sleepTimerStarted: Date | null = null;

  // UI state
  showBreathGuide = false;
  showSleepOverlay = false;
  showSettings = false;
  clearRequested = false;
  undoRequested = false;
  redoRequested = false;
  canUndo = false;
  canRedo = false;

  // Rerender flag
  needsFullRerender = false;

  // Change listeners
  private listeners: StateChangeCallback[] = [];

  onChange(cb: StateChangeCallback): void {
    this.listeners.push(cb);
  }

  notify(): void {
    for (const cb of this.listeners) cb();
  }

  // ── Computed ──

  get breathingPreset(): BreathingPreset | null {
    return BREATHING_PRESETS.find(p => p.id === this.breathingPresetId) ?? null;
  }

  get breathPhases(): { inhale: number; hold: number; exhale: number; hold2: number } {
    if (this.breathingPresetId === 'custom') {
      return { inhale: this.customInhale, hold: this.customHold, exhale: this.customExhale, hold2: this.customHold2 };
    }
    const preset = this.breathingPreset;
    if (!preset) return { inhale: 6, hold: 0, exhale: 6, hold2: 0 };
    return { inhale: preset.inhale, hold: preset.hold, exhale: preset.exhale, hold2: preset.hold2 };
  }

  get breathCycleDuration(): number {
    const p = this.breathPhases;
    return p.inhale + p.hold + p.exhale + p.hold2;
  }

  get currentInkHex(): string {
    return this.currentPalette.inks[this.currentInkIndex];
  }

  get currentInkRGBA(): RGBA {
    return hexToRgba(this.currentInkHex);
  }

  get backgroundRGBA(): RGBA {
    return hexToRgba(this.canvasBackground.hex);
  }
}
