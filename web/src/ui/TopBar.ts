import type { AppState } from '../state/AppState';
import { PALETTES, CANVAS_BACKGROUNDS } from '../state/Palette';
import { LINE_STYLE_NAMES, LineStyle } from '../state/types';

const BRUSH_SIZES = [
  { label: 'hairline', value: 0.5 },
  { label: 'fine', value: 1.0 },
  { label: 'light', value: 1.5 },
  { label: 'medium', value: 2.5 },
  { label: 'broad', value: 4.0 },
  { label: 'heavy', value: 6.0 },
  { label: 'marker', value: 8.0 },
];

export interface TopBarCallbacks {
  onUndo: () => void;
  onRedo: () => void;
}

/**
 * Top bar UI: wordmark, palette chips, ink dots, brush picker, undo/redo.
 */
export class TopBar {
  private el: HTMLElement;
  private state: AppState;
  private callbacks: TopBarCallbacks;

  // Sub-elements for updates
  private paletteChips: HTMLElement[] = [];
  private inkDots: HTMLElement[] = [];
  private inkRow!: HTMLElement;
  private brushPreview!: HTMLElement;
  private brushLabel!: HTMLElement;
  private brushDropdown!: HTMLElement;
  private bgDropdown!: HTMLElement;
  private undoBtn!: HTMLElement;
  private redoBtn!: HTMLElement;

  constructor(state: AppState, callbacks: TopBarCallbacks) {
    this.state = state;
    this.callbacks = callbacks;
    this.el = this.build();
    document.body.appendChild(this.el);
  }

  private build(): HTMLElement {
    const bar = document.createElement('div');
    bar.className = 'topbar';

    // Row 1: wordmark + palettes
    const row1 = document.createElement('div');
    row1.className = 'topbar-row';

    // Wordmark
    const wordmark = document.createElement('a');
    wordmark.className = 'topbar-wordmark';
    wordmark.textContent = 'sleepscape';
    wordmark.href = './';
    wordmark.style.textDecoration = 'none';
    wordmark.style.color = 'inherit';
    wordmark.style.cursor = 'pointer';
    row1.appendChild(wordmark);

    // Divider
    row1.appendChild(this.divider());

    // Palette chips (scrollable)
    const paletteScroll = document.createElement('div');
    paletteScroll.className = 'topbar-palette-scroll';
    for (const palette of PALETTES) {
      const chip = document.createElement('button');
      chip.className = 'topbar-palette-chip';
      chip.dataset.id = palette.id;

      const dot = document.createElement('span');
      dot.className = 'topbar-palette-dot';
      dot.style.background = palette.inks[0];
      chip.appendChild(dot);

      const label = document.createElement('span');
      label.textContent = palette.name;
      chip.appendChild(label);

      chip.addEventListener('click', () => {
        this.state.currentPalette = palette;
        this.state.currentInkIndex = 0;
        this.state.notify();
        this.update();
      });

      this.paletteChips.push(chip);
      paletteScroll.appendChild(chip);
    }
    row1.appendChild(paletteScroll);

    // Background picker button
    const bgBtn = document.createElement('button');
    bgBtn.className = 'topbar-icon-btn';
    bgBtn.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 2a10 10 0 0 1 0 20"/></svg>';
    bgBtn.title = 'Background';
    bgBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      this.bgDropdown.classList.toggle('open');
      this.brushDropdown.classList.remove('open');
    });
    row1.appendChild(bgBtn);

    // Background dropdown
    this.bgDropdown = document.createElement('div');
    this.bgDropdown.className = 'topbar-dropdown topbar-bg-dropdown';
    for (const bg of CANVAS_BACKGROUNDS) {
      const item = document.createElement('button');
      item.className = 'topbar-bg-item';
      const swatch = document.createElement('span');
      swatch.className = 'topbar-bg-swatch';
      swatch.style.background = bg.hex;
      if (!bg.isDark) swatch.style.border = '1px solid rgba(255,255,255,0.2)';
      item.appendChild(swatch);
      const label = document.createElement('span');
      label.textContent = bg.name;
      item.appendChild(label);
      item.addEventListener('click', () => {
        this.state.canvasBackground = bg;
        this.state.needsFullRerender = true;
        this.state.notify();
        this.bgDropdown.classList.remove('open');
      });
      this.bgDropdown.appendChild(item);
    }
    row1.appendChild(this.bgDropdown);

    bar.appendChild(row1);

    // Row 2: inks + brush + undo/redo
    const row2 = document.createElement('div');
    row2.className = 'topbar-row';

    // Ink dots
    this.inkRow = document.createElement('div');
    this.inkRow.className = 'topbar-ink-row';
    this.buildInkDots();
    row2.appendChild(this.inkRow);

    // Divider
    row2.appendChild(this.divider());

    // Brush size button
    const brushBtn = document.createElement('button');
    brushBtn.className = 'topbar-brush-btn';
    this.brushPreview = document.createElement('span');
    this.brushPreview.className = 'topbar-brush-preview';
    brushBtn.appendChild(this.brushPreview);
    this.brushLabel = document.createElement('span');
    this.brushLabel.className = 'topbar-brush-label';
    brushBtn.appendChild(this.brushLabel);
    const chevron = document.createElement('span');
    chevron.className = 'topbar-chevron';
    chevron.innerHTML = '&#x25BE;';
    brushBtn.appendChild(chevron);
    brushBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      this.brushDropdown.classList.toggle('open');
      this.bgDropdown.classList.remove('open');
    });
    row2.appendChild(brushBtn);

    // Brush dropdown
    this.brushDropdown = document.createElement('div');
    this.brushDropdown.className = 'topbar-dropdown topbar-brush-dropdown';
    for (const bs of BRUSH_SIZES) {
      const item = document.createElement('button');
      item.className = 'topbar-brush-item';
      const dot = document.createElement('span');
      dot.className = 'topbar-brush-dot';
      dot.style.width = dot.style.height = `${Math.max(3, bs.value * 3)}px`;
      item.appendChild(dot);
      const label = document.createElement('span');
      label.textContent = bs.label;
      item.appendChild(label);
      item.addEventListener('click', () => {
        this.state.brushSize = bs.value;
        this.state.notify();
        this.brushDropdown.classList.remove('open');
        this.update();
      });
      this.brushDropdown.appendChild(item);
    }
    row2.appendChild(this.brushDropdown);

    // Spacer
    const spacer = document.createElement('div');
    spacer.style.flex = '1';
    row2.appendChild(spacer);

    // Undo
    this.undoBtn = document.createElement('button');
    this.undoBtn.className = 'topbar-icon-btn';
    this.undoBtn.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10"/></svg>';
    this.undoBtn.addEventListener('click', () => this.callbacks.onUndo());
    row2.appendChild(this.undoBtn);

    // Redo
    this.redoBtn = document.createElement('button');
    this.redoBtn.className = 'topbar-icon-btn';
    this.redoBtn.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.13-9.36L23 10"/></svg>';
    this.redoBtn.addEventListener('click', () => this.callbacks.onRedo());
    row2.appendChild(this.redoBtn);

    bar.appendChild(row2);

    // Close dropdowns on outside click
    document.addEventListener('click', () => {
      this.brushDropdown.classList.remove('open');
      this.bgDropdown.classList.remove('open');
    });

    this.update();
    return bar;
  }

  private buildInkDots(): void {
    this.inkRow.innerHTML = '';
    this.inkDots = [];
    for (let i = 0; i < this.state.currentPalette.inks.length; i++) {
      const dot = document.createElement('button');
      dot.className = 'topbar-ink-dot';
      dot.style.backgroundColor = this.state.currentPalette.inks[i];
      dot.addEventListener('click', () => {
        this.state.currentInkIndex = i;
        this.state.notify();
        this.update();
      });
      this.inkDots.push(dot);
      this.inkRow.appendChild(dot);
    }
  }

  private divider(): HTMLElement {
    const d = document.createElement('div');
    d.className = 'topbar-divider';
    return d;
  }

  update(): void {
    // Palette chips
    for (const chip of this.paletteChips) {
      chip.classList.toggle('active', chip.dataset.id === this.state.currentPalette.id);
    }

    // Ink dots
    if (this.inkDots.length > 0) {
      const palette = this.state.currentPalette;
      for (let i = 0; i < this.inkDots.length; i++) {
        this.inkDots[i].style.backgroundColor = palette.inks[i] ?? '#fff';
        this.inkDots[i].classList.toggle('active', i === this.state.currentInkIndex);
      }
    }

    // Brush
    const bs = BRUSH_SIZES.find(b => b.value === this.state.brushSize) ?? BRUSH_SIZES[0];
    this.brushLabel.textContent = bs.label;
    this.brushPreview.style.width = this.brushPreview.style.height = `${Math.max(3, this.state.brushSize * 3)}px`;

    // Undo/redo
    this.undoBtn.classList.toggle('disabled', !this.state.canUndo);
    this.redoBtn.classList.toggle('disabled', !this.state.canRedo);
  }

  /** Rebuild ink dots (e.g. after palette change). */
  refreshInks(): void {
    this.buildInkDots();
    this.update();
  }
}
