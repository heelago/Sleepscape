import { AppState } from './state/AppState';
import { WebGLRenderer } from './rendering/WebGLRenderer';
import { DrawingEngine } from './drawing/DrawingEngine';
import { InputHandler } from './drawing/InputHandler';
import { AudioEngine } from './audio/AudioEngine';
import { TopBar } from './ui/TopBar';
import { GripStrip } from './ui/GripStrip';
import { SettingsSheet } from './ui/SettingsSheet';
import { SleepOverlay } from './ui/SleepOverlay';
import { BreathGuide } from './ui/BreathGuide';
import { Starfield } from './ui/Starfield';

// ── Bootstrap ──

const canvas = document.getElementById('canvas') as HTMLCanvasElement;
if (!canvas) throw new Error('Canvas element not found');

// State
const state = new AppState();

// Renderer
const renderer = new WebGLRenderer(canvas, state);

// Drawing engine
const engine = new DrawingEngine(
  state,
  renderer.strokeRenderer,
  () => ({ width: renderer.pixelWidth, height: renderer.pixelHeight }),
);

// Wire engine into renderer for particle updates
renderer.drawingEngine = engine;

// Input
const inputHandler = new InputHandler(canvas, state, engine, () => renderer.dpr);

// Audio
const audioEngine = new AudioEngine();

// ── UI ──

new Starfield();
const breathGuide = new BreathGuide();
const sleepOverlay = new SleepOverlay();

const topBar = new TopBar(state, {
  onUndo: () => engine.undo(),
  onRedo: () => engine.redo(),
});

const settingsSheet = new SettingsSheet(state, () => {
  // State changed from settings -- handle side effects
  if (state.needsFullRerender) {
    state.needsFullRerender = false;
    renderer.clearStrokeTexture();
    engine.reRenderAll();
  }
  topBar.update();
  gripStrip.update();
});

const gripStrip = new GripStrip(state, {
  onPlayPause: () => {
    state.isPlaying = !state.isPlaying;
    if (state.isPlaying) {
      audioEngine.start(state.currentPreset, state.volume);
    } else {
      audioEngine.stop();
    }
    state.notify();
    gripStrip.update();
  },
  onClear: () => {
    engine.clear();
    renderer.clearStrokeTexture();
  },
  onSettingsToggle: () => {
    if (settingsSheet.isOpen) {
      settingsSheet.close();
    } else {
      state.showSettings = true;
      settingsSheet.open();
    }
    gripStrip.update();
  },
});

// Start render loop
renderer.start();

// ── Breath guide idle timer ──

const resetBreathGuide = () => breathGuide.resetIdle();
canvas.addEventListener('pointerdown', resetBreathGuide);
canvas.addEventListener('pointermove', resetBreathGuide);
breathGuide.resetIdle();

// ── State change listeners ──

state.onChange(() => {
  // Audio volume
  audioEngine.setVolume(state.volume);

  // Audio preset switch
  if (state.isPlaying && audioEngine.playing) {
    // Preset change handled via settings callback
  }

  // Breath guide
  breathGuide.setEnabled(state.breathPulseEnabled);
  breathGuide.setOpacity(state.breathPulseOpacity);
  breathGuide.setPhases(state.breathPhases);
  breathGuide.setShowPhaseText(state.breathPhaseText);

  // Undo/redo state
  topBar.update();
});

// ── Sleep timer logic ──

let sleepTimerInterval: ReturnType<typeof setInterval> | null = null;

state.onChange(() => {
  if (state.sleepTimerMinutes && state.sleepTimerStarted && !sleepTimerInterval) {
    const baseVolume = state.volume;
    sleepTimerInterval = setInterval(() => {
      if (!state.sleepTimerStarted || !state.sleepTimerMinutes) {
        if (sleepTimerInterval) clearInterval(sleepTimerInterval);
        sleepTimerInterval = null;
        return;
      }
      const elapsed = (Date.now() - state.sleepTimerStarted.getTime()) / 1000;
      const total = state.sleepTimerMinutes * 60;
      const progress = Math.min(elapsed / total, 1.0);
      const fadeVol = baseVolume * Math.pow(1.0 - progress, 2);
      audioEngine.setVolume(fadeVol);

      if (progress >= 1.0) {
        if (sleepTimerInterval) clearInterval(sleepTimerInterval);
        sleepTimerInterval = null;
        state.isPlaying = false;
        audioEngine.stop();
        state.sleepTimerMinutes = null;
        state.sleepTimerStarted = null;
        sleepOverlay.show();
        gripStrip.update();
      }
    }, 5000);
  }
});

// ── Keyboard shortcuts ──

document.addEventListener('keydown', (e) => {
  if (e.key === 'z' && (e.ctrlKey || e.metaKey) && !e.shiftKey) {
    e.preventDefault();
    engine.undo();
  }
  if (e.key === 'z' && (e.ctrlKey || e.metaKey) && e.shiftKey) {
    e.preventDefault();
    engine.redo();
  }
  if (e.key === 'c' && (e.ctrlKey || e.metaKey) && e.shiftKey) {
    e.preventDefault();
    engine.clear();
    renderer.clearStrokeTexture();
  }
});

// ── Auto-color cycling ──

let autoColorTimer: ReturnType<typeof setInterval> | null = null;

function startAutoColor(): void {
  if (autoColorTimer) return;
  const intervalMs = () => Math.max(2000, (1.0 / state.autoColorSpeed) * 1000);
  const tick = () => {
    if (!state.autoColorEnabled) { stopAutoColor(); return; }
    state.currentInkIndex = (state.currentInkIndex + 1) % state.currentPalette.inks.length;
    state.notify();
    topBar.update();
    autoColorTimer = setTimeout(tick, intervalMs());
  };
  autoColorTimer = setTimeout(tick, intervalMs());
}

function stopAutoColor(): void {
  if (autoColorTimer) { clearTimeout(autoColorTimer); autoColorTimer = null; }
}

if (state.autoColorEnabled) startAutoColor();
state.onChange(() => {
  if (state.autoColorEnabled && !autoColorTimer) startAutoColor();
  else if (!state.autoColorEnabled && autoColorTimer) stopAutoColor();
});

// ── Save canvas to PNG ──

function saveCanvasPNG(): void {
  canvas.toBlob((blob) => {
    if (!blob) return;
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `sleepscape-${Date.now()}.png`;
    a.click();
    URL.revokeObjectURL(url);
  }, 'image/png');
}

document.addEventListener('keydown', (e) => {
  if (e.key === 's' && (e.ctrlKey || e.metaKey)) {
    e.preventDefault();
    saveCanvasPNG();
  }
});

// Log confirmation
console.log('Sleepscape web initialized', {
  pixelWidth: renderer.pixelWidth,
  pixelHeight: renderer.pixelHeight,
  dpr: renderer.dpr,
});
