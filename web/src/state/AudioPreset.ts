export interface AudioPreset {
  id: string;
  name: string;
  description: string;
  noteFrequencies: number[];
  detuneCents: number;
  lowpassCutoff: number;
  reverbFeedback: number;
  volumeScale: number;
}

export const BELL_FREQUENCIES = [110, 164.81, 220, 246.94, 329.63, 440, 493.88];

export const AUDIO_PRESETS: AudioPreset[] = [
  {
    id: 'delta',
    name: 'delta',
    description: 'deep sleep \u00b7 2 Hz',
    noteFrequencies: [55, 110, 164.81, 220, 246.94, 329.63, 440],
    detuneCents: 4.0,
    lowpassCutoff: 1400,
    reverbFeedback: 0.95,
    volumeScale: 1.0,
  },
  {
    id: 'theta',
    name: 'theta',
    description: 'meditation \u00b7 6 Hz',
    noteFrequencies: [55, 110, 164.81, 220, 246.94, 329.63, 440],
    detuneCents: 16.0,
    lowpassCutoff: 1800,
    reverbFeedback: 0.93,
    volumeScale: 0.9,
  },
  {
    id: '528hz',
    name: '528 hz',
    description: 'solfeggio \u00b7 warm',
    noteFrequencies: [132, 264, 396, 528, 594, 792],
    detuneCents: 2.0,
    lowpassCutoff: 2200,
    reverbFeedback: 0.92,
    volumeScale: 0.8,
  },
];
