export interface BreathingPreset {
  id: string;
  name: string;
  subtitle: string;
  inhale: number;
  hold: number;
  exhale: number;
  hold2: number;
}

export const BREATHING_PRESETS: BreathingPreset[] = [
  { id: '4-7-8',     name: '4-7-8',     subtitle: 'for sleep onset', inhale: 4, hold: 7, exhale: 8, hold2: 0 },
  { id: 'box',       name: 'Box',       subtitle: 'grounding',       inhale: 4, hold: 4, exhale: 4, hold2: 4 },
  { id: 'cardiac',   name: 'Cardiac',   subtitle: 'for anxiety',     inhale: 4, hold: 0, exhale: 6, hold2: 0 },
  { id: 'resonance', name: 'Resonance', subtitle: 'natural rhythm',  inhale: 6, hold: 0, exhale: 6, hold2: 0 },
  { id: 'gentle',    name: 'Gentle',    subtitle: 'beginner',        inhale: 2, hold: 1, exhale: 4, hold2: 1 },
];
