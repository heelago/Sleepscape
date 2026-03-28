export interface Palette {
  id: string;
  name: string;
  background: string; // hex
  inks: string[];     // hex array, 8 colors
}

export const PALETTES: Palette[] = [
  {
    id: 'moonlit', name: 'moonlit',
    background: '#04030a',
    inks: ['#c4b8e8', '#5fcfcf', '#a8c8f0', '#d9768a', '#6ecba8', '#d4a96a', '#e8d5b0', '#ffffff'],
  },
  {
    id: 'dusk', name: 'dusk',
    background: '#06040e',
    inks: ['#b8d4c8', '#8fb8a8', '#a8c8b8', '#c8b8d8', '#b8a8c8', '#d8c8e0', '#c0d0c8', '#ffffff'],
  },
  {
    id: 'slate', name: 'slate',
    background: '#050810',
    inks: ['#b8c8d8', '#98a8c0', '#a8b8c8', '#d8c8b8', '#c8b8a8', '#c0c8d0', '#d8d0c8', '#ffffff'],
  },
  {
    id: 'amber', name: 'amber',
    background: '#080400',
    inks: ['#d4b896', '#c8a888', '#e8d4b8', '#d8c0a0', '#e0c898', '#c8b890', '#f0dcc0', '#ffffff'],
  },
  {
    id: 'sakura', name: 'sakura',
    background: '#08040a',
    inks: ['#ffb7c5', '#ff8fab', '#ffc8dd', '#ffafcc', '#bde0fe', '#a2d2ff', '#e2b4bd', '#ffffff'],
  },
  {
    id: 'forest', name: 'forest',
    background: '#010803',
    inks: ['#74c69d', '#52b788', '#95d5b2', '#a9def9', '#d8f3dc', '#e4c1f9', '#b7e4c7', '#ffffff'],
  },
];

export interface CanvasBackground {
  id: string;
  name: string;
  hex: string;
  isDark: boolean;
}

export const CANVAS_BACKGROUNDS: CanvasBackground[] = [
  { id: 'midnight',  name: 'Midnight',    hex: '#04030a', isDark: true },
  { id: 'deepNavy',  name: 'Deep Navy',   hex: '#0a0e1a', isDark: true },
  { id: 'charcoal',  name: 'Charcoal',    hex: '#1a1a1e', isDark: true },
  { id: 'warmBlack', name: 'Warm Black',  hex: '#0f0c08', isDark: true },
  { id: 'softCream', name: 'Soft Cream',  hex: '#c8b99a', isDark: false },
  { id: 'parchment', name: 'Parchment',   hex: '#a89880', isDark: false },
];
