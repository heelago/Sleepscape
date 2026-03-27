# Sleepscape

A free, open source meditative drawing and ambient sound app for iPad.

No subscriptions. No hidden costs. No data collection. Just something to help you sleep.

---

## Why this exists

I built this for myself. I live in Israel and I've been having trouble sleeping because of the war. I wanted something I could actually draw on before bed -- not a productivity tool, not a journaling app, just something calm and visual that would quiet my head. Every sleep app I found was either paywalled after three days or suspiciously interested in my data. So I built my own.

It started as a single HTML file. It grew from there.

---

## What it does

You draw on a dark canvas while generative ambient audio plays. That's the whole thing.

**Drawing** -- three modes:
- **Mandala** -- your strokes are mirrored with 4, 6, 8, 12, or 16-fold rotational symmetry. Whatever you draw becomes a pattern. You can't make anything ugly.
- **Ellipse** -- drag to place concentric ovals, mirrored across all symmetry axes.
- **Free** -- no symmetry, just smooth glowing strokes.

Five line styles: neon (glowing), soft glow, dashed, dotted, sketch. Apple Pencil supported with pressure sensitivity, but finger drawing works fully.

Touch anywhere and ripple rings bloom outward from your finger, slow and meditative. Ambient bloom particles appear across the canvas like slow-motion fireworks -- tiny glowing seeds that expand, break apart into embers, and dissolve into nothing.

**Audio** -- a generative ambient engine, no loops, never repeats:
- Binaural tones in the A pentatonic scale, each one breathing in and out independently on its own slow cycle
- A melody voice that wanders between notes with long portamento glides
- Soft piano-key tones that surface every few seconds and decay slowly
- A barely-there air layer underneath it all
- Three frequency presets: Delta (~2Hz, deep sleep), Theta (~6Hz, meditation), 528Hz (solfeggio, warm)

**Breathing guide** -- a razor-thin dotted ring that expands on inhale, flashes softly on hold, contracts on exhale. Six presets: 4-7-8 (sleep), Box (grounding), Cardiac coherence (anxiety), Resonance (natural rhythm), Gentle (beginner), and fully Custom.

**Palettes** -- six moods: moonlit, dusk, slate, amber, sakura, forest. Eight ink colors per palette. Auto color cycling option. Six canvas backgrounds from deep midnight to warm parchment.

**Glow & brightness controls** -- glow intensity scales the soft halo around strokes from crisp to dreamy. Brightness cap clamps luminance across the whole canvas to prevent additive blending blowout at the mandala centre.

**Sleep timer** -- tap the moon button and set 15, 30, or 60 minutes. Audio fades gradually to silence, then stops.

**Stroke controls** -- path smoothing (Chaikin curves), slow ink (drawing through water), and pace throttle (calm output from frantic input). All persist across sessions.

---

## The science (briefly)

Two things are reasonably well-supported by research and are built into Sleepscape:

**Binaural beats** -- when each ear hears a slightly different frequency, the brain perceives a third tone at the difference. A 2-6Hz difference puts that perceived tone in the delta/theta wave range associated with deep sleep and meditation. Sleepscape uses carrier tones with configurable left/right splits. Requires headphones to work -- the effect disappears through speakers.

**Mandala drawing** -- structured repetitive drawing with rotational symmetry reduces anxiety. Curry & Kasser (2005) found mandala colouring lowered anxiety more than drawing on blank paper. Khademi et al. (2021) found 30 minutes/day over six days significantly reduced anxiety in hospitalised patients. The mechanism seems to be present-moment focus combined with the inherent visual reward of symmetry.

Sleepscape combines both. Use headphones.

---

## Running it on your own device

You need a Mac, an iPad (any model running iOS 18+), a USB-C cable, and a free Apple ID. No paid developer account required.

### Step 1 -- Install Xcode

Download Xcode from the Mac App Store. It's free. This will take a while -- it's a large download. Once installed, open it once and let it finish its setup.

### Step 2 -- Get the code

Open Terminal and run:

```bash
git clone https://github.com/heelago/Sleepscape.git
cd Sleepscape
open Sleepscape.xcodeproj
```

Xcode will open. You'll see a message about resolving Swift packages -- wait for it to finish. This downloads the audio dependencies automatically.

### Step 3 -- Connect your iPad

Plug your iPad into your Mac with a USB-C cable. Your iPad will show a "Trust This Computer?" prompt -- tap Trust.

Enable Developer Mode on your iPad: **Settings -> Privacy & Security -> Developer Mode** -> turn it on -> restart when prompted.

### Step 4 -- Sign the app with your Apple ID

In Xcode, click **Sleepscape** in the left sidebar (the blue icon at the top). Then click the **Sleepscape** target -> **Signing & Capabilities** tab.

- Check **Automatically manage signing**
- Under **Team**, select **Add an Account** if your Apple ID isn't listed
- Sign in with your Apple ID
- The team will show as "Your Name (Personal Team)" -- that's correct

### Step 5 -- Select your iPad and run

At the top of the Xcode window, click the device selector. Your connected iPad should appear. Select it and hit Cmd+R. First build takes 1-3 minutes.

### Step 6 -- Trust the app on your iPad

The first time you run an app from a personal Apple ID, iOS flags it as untrusted. On your iPad:

**Settings -> General -> VPN & Device Management** -> tap your Apple ID -> tap **Trust**

### The 7-day expiry

With a free Apple ID, the app needs to be re-signed every 7 days. When it stops launching, just plug your iPad back in and hit Cmd+R again. Takes 30 seconds.

---

## Things that can go wrong

**"No route to host" when Xcode tries to download packages** -- DNS issue. Run `sudo networksetup -setdnsservers Wi-Fi 8.8.8.8 8.8.4.4` in Terminal, then try again.

**"Untrusted developer" on iPad** -- See Step 6 above.

**iPad not showing up in the device list** -- Unplug and replug the cable. Check that Developer Mode is enabled.

**Metal Toolchain error during build** -- Go to Xcode -> Settings -> Platforms, look for a download arrow, click it.

**No sound** -- Check your iPad's silent switch is off. Check the play button in the app is actually playing (icon should show pause).

---

## Tech stack

- **Language:** Swift 5.9+ with @Observable macro
- **UI:** SwiftUI
- **Rendering:** Metal (MTKView at 120fps, custom vertex + fragment shaders, MetalPerformanceShaders for Gaussian blur)
- **Audio:** AudioKit 5.6.1, SoundpipeAudioKit 5.6.1
- **Architecture:** MVVM with @Observable classes

---

## Privacy

Sleepscape collects no user data. There are no analytics, no network requests, no tracking, and no third-party SDKs beyond AudioKit. A PrivacyInfo.xcprivacy manifest is included declaring no data collection.

---

## Current status

The native iOS app is fully functional. Sound design improvements are in progress with a collaborator (see `SOUND_DESIGN_BRIEF.md`). The ambient bloom visual effect (firework-style particle dissipation) is being refined.

The original HTML prototype is in `sleepscape.html` -- open it in any browser to try the experience without building anything.

---

## Making changes with Claude Code

This repo includes a `CLAUDE.md` file that Claude Code reads automatically when you open the project. It contains the full architecture reference, rendering pipeline details, and conventions — no setup needed. Just clone, open with Claude Code, and describe what you want to change.

If you're using regular Claude chat instead, point it at `CLAUDE.md` and the relevant source files for context.

---

## Project structure

```
sleepscape/
  Sleepscape/
    App/                        -- entry point, ContentView
    Drawing/                    -- Metal rendering, shaders, symmetry, touch handling
    Audio/                      -- AudioKit generative engine
    Models/                     -- AppState, Palette, DrawMode, LineStyle, AudioPreset
    Session/                    -- breath guide, session manager
    UI/                         -- TopBar, GripStrip, SettingsSheet, overlays
    Resources/Fonts/            -- Cormorant Garamond, Crimson Pro
  CLAUDE.md                     -- architecture reference for Claude Code
  sleepscape.html               -- original HTML prototype
  SLEEPSCAPE_SPEC.md            -- full technical spec
  HANDOFF.md                    -- developer handoff document
  SOUND_DESIGN_BRIEF.md         -- audio collaboration brief
  PrivacyInfo.xcprivacy         -- App Store privacy manifest
```

---

## Contributing

Issues and PRs welcome. This is a personal project so I'm not on a fixed roadmap -- if you fix something or add something thoughtful, I'll look at it.

If you fork it and make your own version, I'd love to see it.

---

## License

MIT. Do what you want with it, don't sue me, don't pretend you made it from scratch.

---

## Credits

Built by **Heela** with Claude Code (Anthropic)

Fonts: Cormorant Garamond and Crimson Pro (SIL OFL, Google Fonts)
Audio synthesis: [AudioKit](https://audiokit.io) (MIT)

Science references: Curry & Kasser (2005), Khademi et al. (2021), Jirakittayakorn & Wongsawat (2017, 2018).
