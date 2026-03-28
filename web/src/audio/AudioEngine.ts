import { AUDIO_PRESETS, BELL_FREQUENCIES, type AudioPreset } from '../state/AudioPreset';

/**
 * Generative audio engine using Web Audio API.
 * Binaural drones + wandering melody + piano bells + air noise + reverb.
 * Mirrors the native AudioKit graph.
 */
export class AudioEngine {
  private ctx: AudioContext | null = null;
  private masterGain: GainNode | null = null;
  private isPlaying = false;
  private currentPreset: AudioPreset = AUDIO_PRESETS[0];

  // Scheduled timers
  private bellTimer: ReturnType<typeof setTimeout> | null = null;
  private breatheTimers: ReturnType<typeof setTimeout>[] = [];
  private wanderTimer: ReturnType<typeof setTimeout> | null = null;

  // Active bell oscillators (for cleanup)
  private activeBellOscs: OscillatorNode[] = [];

  // Sleep timer
  private sleepFadeTimer: ReturnType<typeof setInterval> | null = null;

  private built = false;

  /** Volume control (0-1, applied externally). */
  setVolume(v: number): void {
    if (this.masterGain && this.ctx) {
      this.masterGain.gain.cancelScheduledValues(this.ctx.currentTime);
      this.masterGain.gain.setValueAtTime(v * 0.75 * this.currentPreset.volumeScale, this.ctx.currentTime);
    }
  }

  /** Start audio playback. Must be called from a user gesture. */
  start(preset?: AudioPreset, volume = 0.7): void {
    if (preset) this.currentPreset = preset;

    if (!this.built) {
      this.buildGraph(volume);
      this.built = true;
    }

    this.ctx!.resume();
    const target = volume * 0.75 * this.currentPreset.volumeScale;
    this.masterGain!.gain.cancelScheduledValues(this.ctx!.currentTime);
    this.masterGain!.gain.linearRampToValueAtTime(target, this.ctx!.currentTime + 0.8);
    this.isPlaying = true;
    this.scheduleBell();
  }

  /** Stop audio with fade-out. */
  stop(): void {
    if (!this.ctx || !this.masterGain) return;
    this.isPlaying = false;

    this.masterGain.gain.cancelScheduledValues(this.ctx.currentTime);
    this.masterGain.gain.setValueAtTime(this.masterGain.gain.value, this.ctx.currentTime);
    this.masterGain.gain.linearRampToValueAtTime(0.001, this.ctx.currentTime + 1.8);

    setTimeout(() => {
      if (!this.isPlaying) this.ctx?.suspend();
    }, 2000);

    this.clearTimers();
  }

  /** Switch to a different preset with crossfade. */
  switchPreset(preset: AudioPreset, volume: number): void {
    this.currentPreset = preset;
    if (this.isPlaying) {
      // Fade out, rebuild, fade in
      this.stop();
      setTimeout(() => {
        this.built = false;
        this.start(preset, volume);
      }, 900);
    }
  }

  /** Start sleep timer: fade volume to 0 over durationMinutes. */
  startSleepTimer(durationMinutes: number, onComplete: () => void): void {
    this.stopSleepTimer();
    const totalMs = durationMinutes * 60 * 1000;
    const startTime = Date.now();
    const startVol = this.masterGain?.gain.value ?? 0.5;

    this.sleepFadeTimer = setInterval(() => {
      const elapsed = Date.now() - startTime;
      const progress = Math.min(elapsed / totalMs, 1.0);
      // Exponential fade: pow(1 - progress, 2)
      const scale = Math.pow(1.0 - progress, 2.0);
      if (this.masterGain && this.ctx) {
        this.masterGain.gain.setValueAtTime(startVol * scale, this.ctx.currentTime);
      }
      if (progress >= 1.0) {
        this.stopSleepTimer();
        this.stop();
        onComplete();
      }
    }, 10000); // tick every 10s
  }

  stopSleepTimer(): void {
    if (this.sleepFadeTimer) {
      clearInterval(this.sleepFadeTimer);
      this.sleepFadeTimer = null;
    }
  }

  get playing(): boolean {
    return this.isPlaying;
  }

  // ── Private: build audio graph ──

  private buildGraph(volume: number): void {
    this.ctx = new (window.AudioContext || (window as any).webkitAudioContext)();

    // Unlock iOS audio
    const buf = this.ctx.createBuffer(1, 1, this.ctx.sampleRate);
    const src = this.ctx.createBufferSource();
    src.buffer = buf;
    src.connect(this.ctx.destination);
    src.start(0);
    src.stop(0);

    // Limiter
    const limiter = this.ctx.createDynamicsCompressor();
    limiter.threshold.value = -6;
    limiter.knee.value = 8;
    limiter.ratio.value = 3;
    limiter.attack.value = 0.005;
    limiter.release.value = 0.4;
    limiter.connect(this.ctx.destination);

    // Master gain
    this.masterGain = this.ctx.createGain();
    this.masterGain.gain.value = 0.001;
    this.masterGain.connect(limiter);

    // Reverb (generated impulse response)
    const reverbLen = this.ctx.sampleRate * 7;
    const irBuffer = this.ctx.createBuffer(2, reverbLen, this.ctx.sampleRate);
    for (let c = 0; c < 2; c++) {
      const ch = irBuffer.getChannelData(c);
      for (let i = 0; i < reverbLen; i++) {
        ch[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / reverbLen, 1.6);
      }
    }
    const reverb = this.ctx.createConvolver();
    reverb.buffer = irBuffer;

    // Dry/wet split
    const wetGain = this.ctx.createGain();
    wetGain.gain.value = 0.88;
    wetGain.connect(reverb);
    reverb.connect(this.masterGain);

    const dryGain = this.ctx.createGain();
    dryGain.gain.value = 0.12;
    dryGain.connect(this.masterGain);

    // Lowpass filter
    const lowpass = this.ctx.createBiquadFilter();
    lowpass.type = 'lowpass';
    lowpass.frequency.value = this.currentPreset.lowpassCutoff;
    lowpass.Q.value = 0.2;
    lowpass.connect(wetGain);
    lowpass.connect(dryGain);

    // Stereo merger for binaural
    const merger = this.ctx.createChannelMerger(2);
    merger.connect(lowpass);

    const leftBus = this.ctx.createGain();
    leftBus.gain.value = 1;
    leftBus.connect(merger, 0, 0);

    const rightBus = this.ctx.createGain();
    rightBus.gain.value = 1;
    rightBus.connect(merger, 0, 1);

    // Binaural breathing drones
    const detune = this.currentPreset.detuneCents;
    for (const freq of this.currentPreset.noteFrequencies) {
      this.breatheNote(freq, leftBus, -detune);
      this.breatheNote(freq, rightBus, +detune);
    }

    // Wandering melody
    this.buildWanderer(lowpass);

    // Air noise layer
    this.buildNoise(lowpass);
  }

  private breatheNote(freq: number, bus: GainNode, detuneCents: number): void {
    const ctx = this.ctx!;
    const osc = ctx.createOscillator();
    osc.type = 'sine';
    osc.frequency.value = freq;
    osc.detune.value = detuneCents;

    const gain = ctx.createGain();
    gain.gain.value = 0;
    osc.connect(gain);
    gain.connect(bus);
    osc.start();

    const breathe = () => {
      if (!this.isPlaying) return;
      const now = ctx.currentTime;
      const v = (0.02 + Math.random() * 0.06) * (freq < 120 ? 1.2 : 1.0);
      const fadeIn = 5 + Math.random() * 6;
      const hold = 8 + Math.random() * 14;
      const fadeOut = 6 + Math.random() * 8;
      const rest = 8 + Math.random() * 14;

      gain.gain.cancelScheduledValues(now);
      gain.gain.setValueAtTime(gain.gain.value, now);
      gain.gain.linearRampToValueAtTime(v, now + fadeIn);
      gain.gain.linearRampToValueAtTime(v, now + fadeIn + hold);
      gain.gain.linearRampToValueAtTime(0.001, now + fadeIn + hold + fadeOut);

      const timer = setTimeout(breathe, (fadeIn + hold + fadeOut + rest) * 1000);
      this.breatheTimers.push(timer);
    };

    const timer = setTimeout(breathe, Math.random() * 12000);
    this.breatheTimers.push(timer);
  }

  private buildWanderer(target: AudioNode): void {
    const ctx = this.ctx!;
    const osc = ctx.createOscillator();
    osc.type = 'sine';
    osc.frequency.value = this.currentPreset.noteFrequencies[3] ?? 220;

    const gain = ctx.createGain();
    gain.gain.value = 0;
    osc.connect(gain);
    gain.connect(target);
    osc.start();

    const wander = () => {
      if (!this.isPlaying) return;
      const now = ctx.currentTime;
      const freqs = this.currentPreset.noteFrequencies;
      const note = freqs[Math.floor(Math.random() * freqs.length)];
      const glide = 4 + Math.random() * 5;
      const v = 0.02 + Math.random() * 0.04;
      const dur = 12 + Math.random() * 20;

      osc.frequency.setTargetAtTime(note, now, glide * 0.5);
      gain.gain.cancelScheduledValues(now);
      gain.gain.setValueAtTime(gain.gain.value, now);
      gain.gain.linearRampToValueAtTime(v, now + glide);
      gain.gain.linearRampToValueAtTime(v, now + dur);
      gain.gain.linearRampToValueAtTime(0.001, now + dur + glide);

      this.wanderTimer = setTimeout(wander, (dur + glide * 2 + Math.random() * 8) * 1000);
    };

    this.wanderTimer = setTimeout(wander, 2000);
  }

  private buildNoise(target: AudioNode): void {
    const ctx = this.ctx!;
    const bufferLen = ctx.sampleRate * 4;
    const noiseBuffer = ctx.createBuffer(2, bufferLen, ctx.sampleRate);
    for (let c = 0; c < 2; c++) {
      const data = noiseBuffer.getChannelData(c);
      for (let i = 0; i < data.length; i++) {
        data[i] = Math.random() * 2 - 1;
      }
    }

    const source = ctx.createBufferSource();
    source.buffer = noiseBuffer;
    source.loop = true;

    const bandpass = ctx.createBiquadFilter();
    bandpass.type = 'bandpass';
    bandpass.frequency.value = 800;
    bandpass.Q.value = 0.5;

    const gain = ctx.createGain();
    gain.gain.value = 0.004;

    source.connect(bandpass);
    bandpass.connect(gain);
    gain.connect(target);
    source.start();
  }

  private scheduleBell(): void {
    if (!this.isPlaying || !this.ctx) return;

    this.bellTimer = setTimeout(() => {
      if (!this.isPlaying || !this.ctx) return;

      const freq = BELL_FREQUENCIES[Math.floor(Math.random() * BELL_FREQUENCIES.length)];
      const harmonics: [number, number][] = [
        [freq, 0.07],
        [freq * 2, 0.035],
        [freq * 4, 0.012],
      ];

      for (const [f, v] of harmonics) {
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = 'sine';
        osc.frequency.value = f;

        const now = this.ctx.currentTime;
        gain.gain.setValueAtTime(0.001, now);
        gain.gain.linearRampToValueAtTime(v, now + 0.06);
        gain.gain.exponentialRampToValueAtTime(0.0001, now + 8);

        osc.connect(gain);
        gain.connect(this.masterGain!); // bells bypass reverb
        osc.start();
        osc.stop(now + 8.5);

        this.activeBellOscs.push(osc);
        osc.onended = () => {
          const idx = this.activeBellOscs.indexOf(osc);
          if (idx >= 0) this.activeBellOscs.splice(idx, 1);
        };
      }

      this.scheduleBell();
    }, 4000 + Math.random() * 7000);
  }

  private clearTimers(): void {
    if (this.bellTimer) clearTimeout(this.bellTimer);
    if (this.wanderTimer) clearTimeout(this.wanderTimer);
    for (const t of this.breatheTimers) clearTimeout(t);
    this.breatheTimers = [];
    this.bellTimer = null;
    this.wanderTimer = null;
  }
}
