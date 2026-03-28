# Onboarding & Help System — Web Implementation Plan

## Overview

Three-part help system for first-time users: a welcome overlay on first launch, an info button to reopen it, and inline hints throughout settings.

## 1. First-Launch Welcome Overlay

A subtle, dismissable overlay shown once on first visit. Stored in `localStorage` so it doesn't repeat.

### Design:
- Full-screen dark overlay (`rgba(4,3,10,0.92)`) with centered content
- Matches app aesthetic — Cormorant Garamond headings, Raleway body
- 3-4 key tips with icons/labels:
  - **Draw** — Touch anywhere to create. Strokes mirror automatically.
  - **Breathe** — The ring at the centre guides your breathing. Follow it.
  - **Listen** — Press play for generative ambient audio with binaural beats.
  - **Settings** — Tap the gear to change modes, colors, effects, and patterns.
- "start drawing" button to dismiss
- Fade-in on load, fade-out on dismiss

### Implementation:
- New file: `web/src/ui/WelcomeOverlay.ts`
- Class creates a `div.welcome-overlay` with tip content
- Constructor checks `localStorage.getItem('sleepscape_welcomed')`
- On dismiss: set `localStorage.setItem('sleepscape_welcomed', 'true')`, fade out, remove
- CSS in `web/app.html` — same style section as other overlays

### localStorage key: `sleepscape_welcomed`

## 2. Info/Help Button

A small `(?)` or `(i)` button always accessible that reopens the welcome overlay.

### Design:
- Position: near the settings gear in the grip strip, or as a standalone subtle icon
- Same style as other grip strip buttons
- On click: show the welcome overlay again (regardless of localStorage)

### Implementation:
- Add to `web/src/ui/GripStrip.ts` — new button next to settings gear
- Calls `welcomeOverlay.show()` on click
- The WelcomeOverlay needs a `show()` method that works independent of the first-launch check

## 3. Inline Hints in Settings

Short descriptions under each settings card/section explaining what the controls do.

### Design:
- Small text under each section label, same style as breathing preset descriptions
- Muted color (`var(--text-faint)` or similar), CrimsonPro-ExtraLight 11px
- Only show hints that aren't self-explanatory

### Suggested hints:
| Section | Hint |
|---------|------|
| mode (free/mandala) | "mandala mirrors your strokes with rotational symmetry" |
| folds | "higher fold counts create more intricate patterns" |
| style (neon/soft glow/etc) | "changes how each stroke looks and glows" |
| auto color | "cycles through the palette as you draw" |
| path smoothing | "rounds out sharp corners in your strokes" |
| slow ink | "adds resistance for a more deliberate feel" |
| pace | "controls how quickly new points are accepted" |
| sparkles | "bright particles trail along pencil strokes" |
| ripples | "expanding rings bloom from each touch" |
| ripple reach | "how far the ripple rings expand outward" |
| glow intensity | "controls the soft halo around each stroke" |
| brightness cap | "limits maximum brightness to keep things calm" |
| breath pulse | "an animated ring that guides your breathing" |
| visibility (dim/bright) | "how prominent the breathing ring appears" |
| show phase text | "displays inhale/hold/exhale inside the ring" |
| pattern | "each pattern has different timing for inhale, hold, and exhale" |

### Implementation:
- Add a helper method to `SettingsSheet.ts`: `hint(text: string): HTMLElement`
  - Creates a `<p class="settings-hint">` element
  - Styled in `app.html` CSS
- Insert `card.appendChild(this.hint('...'))` after relevant labels/controls
- Keep hints concise — one line each

## Files to Create/Modify

| File | Action |
|------|--------|
| `web/src/ui/WelcomeOverlay.ts` | Create — overlay class |
| `web/src/ui/GripStrip.ts` | Modify — add info button |
| `web/src/ui/SettingsSheet.ts` | Modify — add inline hints |
| `web/src/main.ts` | Modify — instantiate WelcomeOverlay |
| `web/app.html` | Modify — add CSS for overlay and hints |

## CSS Tokens

```css
.welcome-overlay {
  position: fixed; inset: 0; z-index: 50;
  background: rgba(4,3,10,0.92);
  display: flex; align-items: center; justify-content: center;
  opacity: 0; transition: opacity 0.8s ease;
}
.welcome-overlay.visible { opacity: 1; }

.welcome-tip { margin-bottom: 24px; }
.welcome-tip-label {
  font-family: 'Cormorant Garamond', serif;
  font-size: 1.1rem; color: var(--glow);
}
.welcome-tip-desc {
  font-family: 'Raleway', sans-serif;
  font-size: 0.85rem; color: var(--text-dim);
}

.settings-hint {
  font-size: 11px; color: var(--text-faint);
  font-family: 'Raleway', sans-serif;
  margin-top: -4px; margin-bottom: 4px;
}
```

---

## Next Session Prompt

> I'm implementing the onboarding and help system for the Sleepscape web app. Read `ONBOARDING_PLAN.md` in the repo root for the full plan. Before starting, pull latest from main and verify the web app builds cleanly with `cd web && npx tsc --noEmit`. Then implement all three parts: (1) first-launch welcome overlay, (2) info button in the grip strip, (3) inline hints in settings. Reference the existing UI components in `web/src/ui/` for styling patterns.
