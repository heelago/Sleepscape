import { AppState } from './state/AppState';
import { WebGLRenderer } from './rendering/WebGLRenderer';
import { DrawingEngine } from './drawing/DrawingEngine';
import { InputHandler } from './drawing/InputHandler';

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
new InputHandler(canvas, state, engine, () => renderer.dpr);

// Start render loop
renderer.start();

// ── Keyboard shortcuts (dev) ──
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

// Log confirmation
console.log('Sleepscape web initialized', {
  pixelWidth: renderer.pixelWidth,
  pixelHeight: renderer.pixelHeight,
  dpr: renderer.dpr,
});
