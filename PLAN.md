# unsound: a broken machine you overdrive

*Direction set in a brainstorm at the end of session 3 (2026-10-22). Everything below the line is
the earlier, Ableton-shaped plan: kept as history, and the engine it describes is still underneath.*

## What it's for

The ritual it should bring back: three sources, seven weird effects on each, four on the master,
everything in the red, clicking through knobs you half understand for 30 minutes, then cutting the
recording up later. Mostly garbage, the occasional keeper, always fun. **Low intention, lots of
material, live.** It should feel like a **broken machine**, not a DAW and not a toy.

What the user reached for when playing it: the bitmeister first (all its knobs), the granular thing
second, Atari for a moment. Drums went off almost immediately. Gain went up on almost everything.
The moments they remember: overdriving one sound "to infinity" until it overpowers everything, and a
background noise wall swapped in and out.

**Not modular.** No cables, no plugboards. Depth comes from mods-into-mods and from code, not from patching.

## Digital, on purpose

Noise music leans on analog. This doesn't: **use the whole power of the computer**, the things an
analog box can't do. Things to explore:

- **integer and bit arithmetic** as sound: bytebeat, bit masks, XOR/AND between signals, overflow and wraparound
- **aliasing, quantization, sample-rate abuse**: crushing on purpose, impossible pitch shifts, sample-and-hold at odd rates
- **spectral surgery**: FFT bins frozen, sorted, swapped between sources, shifted, thinned, randomized
- **exact memory**: perfect loops, instant recall, time travel through the tape (play the last 10 minutes backwards at 40×)
- **rhythm ↔ pitch**: unlimited tempo; a pattern sped up until it becomes a tone (the **line**)
- **codec and data damage**: lossy-compression artefacts, packet loss, buffer underrun stutter, wrong-format reads
- **scale**: hundreds of voices, thousands of grains, sorting or searching audio by descriptors (the old Samplebrain idea)
- **exact chaos**: feedback with no noise floor, chaotic maps, cellular automata, Markov chains at audio rate
- **instant states**: lurch / cut / back between whole machine states with no settling time

When adding something, ask: *could a pedal do this?* If yes, it's fine, but it isn't the point.

## The six nouns

| noun | what it is | what you do with it |
|---|---|---|
| **sources** | a few broken generators: bitmeister(s), grains, lines (others optional) | pick, push, mutate |
| **stacks** | each source's chain of drawer effects; every one breakable, mostly digital | stack, click through, turn knobs |
| **the wall** | a first-class background noise layer (not a track): several walls to swap or crossfade, shaped by a simple lows/highs band shaper | swap in/out, shape |
| **sends** | echo / space returns, themselves overdriven | throw things into them |
| **mods** | functions of time bound to any parameter, including other mods' rates and depths | infect, chain, steer |
| **tape** | always recording the last 15 minutes; **keep** saves it | forget about recording |

Plus one verb: **takeover**. Push one source to infinity and it eats the mix: on a fader or a held
pad, built in rather than accidental.

### Lines
A gesture that appears out of nowhere, holds, speeds up, slows down, speeds up until the rhythm
becomes a tone (the Merzbow move), then goes away. Two modes, one at a time:
- **hit**: one sound (a blip, a grain, a bit-burst) repeated faster and faster
- **phrase**: a short pattern accelerating until it smears into a tone

Either can be fired by hand or come by itself every so often. Rate is unlimited (sub-audio to audio rate).

### Mods into mods (both, no cables)
- **visible chains** (the legwork): each modulated knob shows a small trail of what moves it
  ("sine ← drunk ← chaos"); right-click keeps going deeper. A view of the whole tree.
- **a console**: one line of text, e.g. `wall.lows ~ drunk(0.1) ~ chaos(3)` or
  `bit.rate ~ follow(grains) * 4`. Text instead of cables. It's also where the user's DSP-book
  experiments plug in later (writing new effects as small files).

### Everything into the red
Every device gets input gain and breaks *musically* (mostly digitally) when pushed. Gain is a
gesture, not a level. The sends overdrive too. The master limiter stays as a safety net (to be
confirmed), but nothing before it is polite.

## Controllers: a fixed layout, no MIDI learn

The user has two cheap, general controllers. The layout is fixed so it becomes muscle memory:

- **generic box** (8 sliders, 2 rows of 10 knobs, ~20 buttons):
  - sliders: source levels, wall level, send levels; the last slider is **takeover**
  - top knob row: the focused source's stack (the main knob of each effect)
  - bottom knob row: mod depths, plus the wall's lows / highs
  - buttons: focus a source, bypass effects, keep, glide / cut / back
- **4×4 pads**: one row fires lines, one swaps walls, one is momentary takeover (hold = infinity),
  one is chaos (dice, infect, cure, keep)

Needed first: the actual CC / note numbers. A "move everything once" script that prints what each
control sends will map them.

## Build order

**First slice: try the direction before committing to all of it**
1. ✅ **tape**: always-on 15-minute ring buffer in memory (`~tapeMinutes`); **keep** (return) saves it all,
   shift-return the last minute, to `~/Music/unsound/keep-<date>.wav`
2. ✅ **the wall**: a layer of its own (kind `\wall`: strip, sends, chain; ignores solo, dice and glide).
   Seven recipes in `~wallTypes` (static, bitwall, crackle, bit rain, spectral, scream, mains), crossfade
   on pick, fade in/out, `band` (lows/highs, drawn) + hard clip on its chain
3. ✅ **takeover**: a slider (no numbers) and ∞ (hold, or hold `'`) for the focused track: it's driven
   into digital clipping and up in level while the other tracks and the wall duck. Follows focus
4. ✅ default set: **bitmeister ×2 + grains + wall**, no drums; sends A (echo) and B (space) are overdriven
5. ✅ **digital drawer** (new browser category): bitmask, aliaser, bins, codec, overflow, skip, with
   presets (xor storm, dial-up, wraparound, scratched…) and two chains (digital rot, broken stream)

After the first play ("this thing fucking ROCKS now!!!"): the user couldn't find the sends,
the mods-into-mods, or the takeover slider. Added:
- ✅ a **mix** column at the start of every chain (volume, pan, wander, a send per return, named by its effect)
- ✅ **mods as a tree** under it: every mod on the track; a mod's rate/depth are knobs, and a mod on
  them shows up indented underneath (the "visible chains" item, first version)
- ✅ **hover tooltips** on the browser (what each thing is), knobs, sliders and the top bar
- ✅ visible slider tracks (the takeover slider was there but drawn invisibly dark)
- ✅ **mouth**: a talking machine (formant synthesis): babbles, says typed text in a loop, or holds a
  vowel; s/sh/f hiss, p/t/k pops, m/n nose; pitch, throat size, sing, robot, lofi (Speak & Spell)

Then:
- ✅ **LFOs, Serum / Vital style** (the user's "banger idea"): a row of LFOs under the pads, any number.
  Draw the shape (points + bendable curves, presets), sync or free rate, drag the handle onto any knob,
  drag the knob's outer ring for amount. An LFO's rate is a knob, so LFOs move LFOs. Saved with sets.
- ✅ the wall respects solo (and has an S)
- ✅ **session recording**: everything, always, to `~/Music/unsound/sessions/` in 30-minute parts
  (2 s overlap, 24-bit); keep also drops a marker into the session's .txt

Also from the same session: **pop-out windows** (⧉ on any device, or the whole track: as many as
you like, like plugin windows; the user never minded 20 windows and tabbing between them) and
**M / S / volume** on every pad.

**Then**
- ⬜ **lines** (hit and phrase)
- 🟡 **visible mod chains** (the tree in the mods panel is a first version; next: show the chain on
  the knob itself), then the **console**
- ⬜ **controller template** for both controllers
- ⬜ input gain + musical breakup on every device; overdriven sends
- ⬜ "stack 7 random" in the drawer
- ⬜ a `fx/` folder where each file is one effect (the DSP-book bridge)

**Offshoots, later or elsewhere**
- **weather**: a place that's always running, with seasons and storms you nudge. Probably its own project.

## Principles (new)

1. **Broken machine, not a DAW.** If it looks like Ableton, ask why. But don't throw the DAW away:
   the user knows it deeply. The track/device/send engine and the studio view stay underneath;
   the machine is a new front on top of them.
2. **Digital on purpose.** Do what a computer can do and a pedal can't.
3. **Low intention, high yield.** Make lots of material fast; keeping it is one button.
4. **Into the red is normal.** Loud and broken is a valid setting for everything.
5. **Depth without cables.** Mods into mods, and code, never patching.
6. **Still open, still yours** (from before): every parameter reachable; the machine varies around
   what you set; the master is hands-only.

---

## History: the Ableton-shaped plan (sessions 1–3, 2026-10-21 / 22)

### What it is

A glitch centre for the laptop, laid out like an Ableton set: instruments on tracks, real sends
into return tracks, device chains everywhere, and a piano roll or step grid when you want to
write something. On top of that, things **move by themselves**. Instruments improvise, patterns
mutate, filters drift, the master stutters. You can let it run, nudge it, or grab any part directly.

**Current direction (after playing it): toy, not workspace.** It should be a noise toy first:
make interesting sound the moment it starts, reward poking at things you don't understand, and
keep surprising you. The Ableton structure stays as the skeleton, but sound, randomness and
play come first. Expect lots of short iterations: play it → say what feels dead → change it.

**Where it's heading (end of session 1, 2026-10-21):** it's a playground today. The interest is
in *the sounds a computer can make on its own*, not in patching (no plugboards/modular UI). Wanted:
- **Everything can modulate everything**: any signal or setting as a source, any setting as a target,
  without a patching interface (sources picked by gesture, chance, or "infect").
- **Lurch toward something, or switch on a dime**: glide the whole set toward a target state
  (a scene, a dice roll, a "mood") at any speed, from slow drift to an instant cut.
- **Better use of the screen**, still to be worked out.

**Session 3 wants (2026-10-22, "just for fun", one shot):** see the section *Session 3* below.
More sound sources (a noise generator built to be extended, a tape deck, a 3xOsc, an Atari 2600 chip),
FM and loaded samples on the drums, a graphical EQ, "every so often" controls everywhere, and an
interface that feels closer to hardware.

Principles:

1. **Open, not locked down.** Every parameter has a control. Nothing is hidden behind a macro.
2. **Your settings are home.** Mutation, drift and chaos vary *around* what you set and drift back.
   They never overwrite your roll, your pattern or your knobs. Turn mutate to 0 and it plays exactly what you wrote.
3. **Ableton muscle memory.** Session-style mixer, sends A/B/C…, returns, master, Clip/Devices
   detail view, device boxes with on/reorder/remove.
4. **Motion is a layer, not the whole thing.** Movers, ramps and events sit on top of normal
   instruments and devices.
5. **Memory.** Later material grows out of earlier material, both its motion and its audio.
6. **Fun at every step.** Each milestone has to make a sound worth playing with.

### Architecture

```
 folder ──▶ corpus (buffers → grains → [descriptors]) ◀── [resampled output]
                  │
   ┌──────────────┴──────────────────────────────────────────────────────────┐
   │ instrument tracks: instrument → insert devices → strip                  │
   │   grains · kick · keys · fm · [hats] [noise] [bass] [resonator] …       │
   │   strip: volume · pan · wander · activator · solo · meter · sends A..H  │
   └───────┬───────────────────────────────────┬─────────────────────────────┘
           │ post-fader                        │ sends (pre or post, per return)
           ▼                                   ▼
      master bus ◀──────── return tracks: devices → strip (can send to other returns)
           │
   master track: stutter → filter → limiter (any devices) → speakers / recorder

   motion: instrument movers · device movers · ramps · [events/score] · [motion memory]
   control: window (mixer + clip + devices) · play.scd · [MIDI] · [scenes]
```

### Status

Legend: ✅ working · 🟡 partly there · ⬜ not started

#### 1. Mixer and routing
- ✅ Instrument tracks, return tracks, master track; add and remove at runtime
- ✅ Per-track tempo: sync or own bpm, tempo drift, speed, resync; live bpm shown on each strip
- ✅ Strips: volume (dB), pan, wander, activator, solo (returns stay audible), stereo peak meters
- ✅ Genuine sends from every track to every return (up to 8 returns), pre/post per return
- ✅ Return → return sends (feedback allowed, one block late)
- ⬜ Send/return to/from a specific track (sidechain-style routing, "audio from" another track)
- ⬜ Track groups (sum a few tracks into a group strip)
- ⬜ Crossfader A/B assignment, à la Ableton
- ⬜ Rename tracks; reorder tracks by dragging

#### 2. Devices
- ✅ Insert chains on any track, return or master: add, bypass, reorder, remove
- ✅ Browser: double-click adds to the end of the chain, drag & drop places; ~50 presets + whole chains
- ✅ Master limiter pinned last, always; every instrument starts with its own overdrive variation
- ✅ 27 devices: drive (8 modes), crush, dirt, filter, eq, comb, resonator, ring, shift, space, echo, chorus,
  tape, pitch, reverse, smear, stutter, chop, freeze, scramble, blur, feedback, compressor, gate, width, limiter
- ⬜ Save your own browser presets and chains from a track's current chain
- ⬜ A noise-machine "chain designer": randomize a whole chain (types and settings) with a seed
- ⬜ Parallel chains (Ableton audio effect rack): split into 2–4 chains and mix them
- ⬜ More devices: freeze (spectral hold), tape stop, ring mod, chorus/ensemble, compressor (with sidechain from another track),
  EQ three, beat repeat (Ableton-style with grid/chance/gate), vocoder (one track modulates another)
- ⬜ Rack-style macros: map 8 knobs to any device params on a track
- ⬜ Modulators as devices: LFO, random, envelope follower, each assignable to any parameter

#### 2½. Modulation, randomness, play
- ✅ Mods on anything: right-click any knob (device, instrument, send, pan, bpm…) to make it move by itself;
  shapes sine/tri/square/saw/random/drunk/chaos/burst; turning a modulated knob moves its home
- ✅ Mods on mods: a mod's rate and depth are knobs too ("rate of rate of creature fever")
- ✅ Mods view (tab) listing every mod; infect (I) scatters mods across the set; cure (\\) removes all
- ✅ Mystery "?" knob on every device: sweeps a hidden random handful of its params
- ✅ Dice (/) per track and per device
- ✅ "alive": new tracks/devices arrive with mods; the master is never automated (hands only)
- ✅ Mod sources: own shape, follow any track's loudness, or driven by another mod; bipolar depth (ducking)
- ✅ Mods saved in scenes and sets (re-linked on load, including mods on mods)
- ✅ **Lurch toward / switch on a dime**: glide (Q) and cut (=) to a random destination, `distance` knob,
  back (-) through a 50-step history
- ✅ **Events at intervals**: every N bars, by chance — glide, cut, back, dice, drop-outs, solos
- ⬜ Mod sources from audio features beyond loudness: onsets, brightness, pitch
- ⬜ Lurch toward a *chosen* destination: a scene, a saved "mood", or "more like this track"
- ⬜ Event kinds editable in the GUI (weights per kind)
- ⬜ Mods that change shape by themselves; mods that spawn/kill other mods ("ecology")
- ⬜ "Temperature": one knob that scales every mod depth at once
- ⬜ Visual feedback that feels alive: knob trails, a big scope/spectrum, track activity glows

#### 3. Instruments
- ✅ **creature**: Gendy + Latoocarfian + feedback FM + crackle, tangled; vague knobs (hunger, tangle, grit,
  breath, fever, rot, body); XY pad; spasms
- ✅ **bytebeat**: 8 integer formulas on a counter, a/b/c shifts, rate (keys transpose it)
- ✅ **hum**: self-oscillating four-delay feedback network (tension, size, tint, unrest, swell)
- ✅ **drums**: 8 lanes, polymeter lane lengths, 5 generator styles, mutation-that-drifts-home, synth or sample per lane
- ⬜ drums: per-lane sends/outputs, accents/velocity, fills every N bars, lanes stealing hits from each other
- ⬜ bytebeat (the bitmeister, a favourite): formula morphing, two counters at different rates, live formula editing
- ⬜ More noise sources: circuit-bent oscillators, Gendy swarms, granular noise from the corpus run at audio rate,
  "radio" (scanning filtered noise + bursts), feedback between tracks (a track's output as another's input)
- ✅ **grains**: corpus walk or stick to one file (with `stray` and `hop` per bar); random or scanning playhead; size, pitch, reverse, click,
  gestures (single/cloud/ratchet/smear) with weights; repeat count
- ✅ **kick**: 16-step grid you draw; mutation shows as a variation and drifts home; tone/decay/sweep/click/drive/swing/ratchet
- ✅ **keys**: a sample region as a synth. In `shot` mode it plays the region pitched; in `loop` mode a
  tiny cycle becomes an oscillator, and `scan` and `drift` move it through the region. Plus ADSR-ish shape and a filter with env
- ✅ **fm**: drawable carrier and modulator waveforms (presets, smooth/fold/nudge), 3 operators, index env
- ⬜ **drums**: a multi-lane step grid (kick/snare/hat/perc) with each lane pulling from the corpus by descriptor
- ⬜ **noise**: filtered noise beds, crackle, Dust/Gendy textures
- ⬜ **bass**: sub that follows the kick or a roll
- ⬜ **sampler**: one whole sample, slices mapped across the roll (Simpler slice mode)
- ⬜ keys: multi-sample zones, loop crossfade, velocity
- ⬜ fm: more algorithms, operator feedback, 4 drawable waves, morph between two drawings

#### 4. Clips
(Not there yet: today each track has one roll/pattern, not Ableton-style clips.)
- ⬜ **Clip slots per track** with launch/stop, each holding notes or steps *and* modulation lanes
- ⬜ **Per-clip modulation over time**: draw or record any knob's movement into the clip (automation lanes
  that loop with the clip), and clip-level mods (an LFO that only exists while that clip plays)
- ✅ Piano roll (24 rows, 8–64 steps, scale highlighting, click/drag/delete, preview on click), own speed knob
- ✅ Wander mode (improvises in scale) with `keep wander` to capture it into the roll; `suggest`
- ✅ Repeats and repeat chance per note; non-destructive mutation (shift/octave/skip/double)
- ⬜ Velocity and per-note probability (Ableton 11-style chance)
- ⬜ Multiple clips per track and a clip launcher (session view slots), with follow actions
- ⬜ Clip length/loop brace in the roll; zoom and scroll; draw mode; copy/paste
- ⬜ Polyrhythm: each clip with its own length, so loops phase against each other
- ⬜ Automation lanes: record knob moves into the clip

#### 5. Motion
- ✅ Instrument movers; device movers (filter drift, auto-stutter); `~ramp` any setting; per-track speed
- ✅ Chaos macro; lurch
- ✅ **Scenes**: capture everything, launch with morph time; **song** = list of [scene, bars]
- ⬜ Song editor in the GUI (arrangement strip of scenes); per-scene tempo and follow actions
- ⬜ **Events at intervals**: chance-weighted gestures every N bars (collapse to kick only, reverse,
  halve speeds, swap corpus folder, mute a random track)
- ⬜ **Score from very high up**: `[0: \calm, 64: \build, 96: \break]`, where each section is a set of
  targets the controls ramp toward
- ⬜ Mover library to assign to any knob: random walk, LFO, sample-and-hold, attractor, Markov, logistic map
- ⬜ Tempo drift; tape stop; "re-align" all speeds to 1

#### 6. Memory
- ⬜ **Motion memory**: record every control's history; replay a window of it (reversed, slower) onto any control
- ⬜ **Audio memory**: resample the master into the corpus so the machine eats its own past
- ⬜ A "memory" amount: how much of the corpus is original vs. its own past

#### 7. Corpus brain (Samplebrain)
- ✅ Silence-skipping grain table with rough loudness per grain
- ⬜ Descriptors per grain: loudness, brightness, noisiness, MFCCs; cached per folder
- ⬜ Nearest-neighbour search; tagging grains as kicky/hatty/tonal/texture
- ⬜ **Target mode**: rebuild a sound from the closest-matching corpus grains
- ⬜ **Song-from-a-folder**: drums, bass and keys all pulled from the folder by role

#### 8. Playing live
- ✅ BPM unlimited (min wait 2 ms); per-track bpm unlimited too
- ✅ Record button with timer → ~/Music/unsound/unsound-<date>.wav (24-bit), "show" reveals it
- ✅ MIDI knob mappings saved with the set
- ✅ Record master to disk; save/load whole sets (tracks, devices, clips, sends, scenes, song)
- ✅ Help window (? key / button) listing every shortcut
- ✅ Computer keyboard: notes on the selected track (A–; like Ableton), transport, track select, holds, scenes
- ✅ MIDI: notes play the selected track; MIDI learn for any knob/toggle/hold; relative jog wheels detected
- ⬜ Controller templates (Launchpad grid → scenes/tracks, DJ deck layout)
- ⬜ Hold-to-play sustain from keys/MIDI (note length = how long you hold)
- ⬜ Keyboard "parameter mode": focus a device and turn its knobs with keys
- ⬜ Stem recording; CPU guard
- ⬜ Knob right-click: reset to default / assign mover / map to MIDI

#### 9. Session 3: wants (2026-10-22)
- ✅ **EQ Eight**: 8-band graphical EQ like Ableton's. Drag the dots (freq/gain), scroll for Q,
  per-band type (low cut, low shelf, bell, notch, high shelf, high cut) and on/off; the curve is the real response
- ✅ **noise**: an extensible noise generator. Two layers, each sweeping *continuously* through a list of
  noise kinds (white, pink, brown, velvet, crackle, chaos maps, radio, rain…). Adding a kind = one line in `~noiseKinds`
- ✅ **deck**: a tape-style player. Open any file (file browser) or grab one from the folder; a playhead you can
  see and grab; varispeed from −8× to 8× with motor inertia (tape stop, spin back), wow/flutter, chew (skips and
  drop-outs), drive; loops a region forever. Not granular: it plays the tape
- ✅ **drums**: FM as a third lane source (synth / fm / sample); load your own sample per lane; random slice
  per lane, from the folder or from **one long sample** loaded for the whole kit (slices start at onsets)
- ✅ **osc3**: 3xOsc-style synth. Three oscillators (sine/tri/saw/square/noise), osc 2 and 3 mix, ring,
  FM or AM into osc 1; a built-in LFO; an `lfo →` menu that puts a modulator on any of its knobs in one click
- ✅ **sometimes**: a button + a slider without numbers, "every so often, at random intervals". On every
  instrument (new sound, spasm, fill, skip, sfx…), on every device (jump its mystery knob), and global (glide, cut).
  The sliders can be modulated like any knob
- ✅ **atari**: Atari 2600 TIA emulation. Two channels with the real AUDC (16 waveforms from the poly4/poly5/poly9
  counters), AUDF (5-bit divider) and AUDV (4-bit volume) registers at the TIA clock. Notes snap to the nearest
  AUDF, so it's out of tune like the real thing. Channel B does sound effects every so often
- 🟡 **VST** (back of the list): a `vst plugin` device that appears only if the VSTPlugin extension is installed.
  Written but untested (VSTPlugin isn't installed here). Install it from https://git.iem.at/pd/vstplugin to try
- ✅ **Interface: the box** (below)

##### Interface: closer to hardware
The studio window has too many buttons and too much hopping between clip / devices / mods. Hardware
gets away with very few controls because of **focus**: you pick one thing, and the same knobs and screen
become that thing. The box view (default now; `studio` switches back to the old window) is built that way.

First try (one big screen, effects behind pages and a `+ effect` menu) was rejected: "too big", it hid the
browser, and paging meant clicks for things that used to sit side by side. **The user works on this one
screen at this resolution and keeps things small to fit more.** Second layout (current):

- **browser** on the left, as in the studio (double-click / drag to add instruments and effects).
- **pads** along the top, one per track: click = focus, double-click = mute, right-click = solo. They glow with the level.
- **screen**, kept small: the focused track's visual part (XY pad, drum grid, roll, tape) plus a narrow
  column with a small scope, its sometimes, and the 8 encoders.
- **chain**, the big part: the instrument's panel and every effect in one row, like the studio's devices.
- a **drag handle** between screen and chain sets the split (the screen scrolls if it's smaller than its contents).
- **8 encoders**, always the same 8, mapped to the focused track's current **page**.
  Pages are made automatically: the instrument's knobs, mix (level, pan, sends), then one page per device.
  tab / shift-tab or ◀ ▶ change page. (The drum pages go across lanes: a level page is 8 lane levels.)
- **every-so-often row**: the focused track's sometimes sliders.
- **MIDI**: learn the 8 encoders once (and ◀ ▶ page, ◀ ▶ track, glide, cut) and any 8-knob controller drives
  everything, following focus. That's the question for tonight: which controller becomes "the box"?

Not in the box yet: the mixer strips (sends, faders) and the mods view: those are still in studio.
The user is still finding out what they want here ("less buttons" vs. "use the screen, more knobs"):
next step is to play it and note what gets in the way.

Next for the box, once a controller is picked: a fixed template for it (no learning), LED feedback,
pads on the controller = track pads, and a second "performance" page set (glide/cut/sometimes on knobs).

### Milestones

| # | milestone | what you can do at the end |
|---|---|---|
| M1 | ✅ grains, kick, glitch | hear it move |
| M2 | ✅ voices, sends, first ladder | pull voices together, push them around |
| M3 | ✅ Ableton-style rebuild | mixer, real sends/returns, device chains, piano roll, steps, waveforms, drawn wavetables |
| M4 | ✅ tempo per track, browser, 27 devices, keys + MIDI, scenes, sets | play it without the mouse, keep what you made |
| M5 | clips and launcher | several clips per track, follow actions, automation |
| M5½ | ✅ noise toys: creature/bytebeat/hum, mods on mods, infect/dice/mystery | it makes noise on its own the moment it starts |
| M5¾ | ✅ session 3 wants: noise, deck, osc3, atari, EQ Eight, FM/sample drums, sometimes, the box | more sources, one focus-driven hardware-ish view |
| M6 | clips with automation lanes + saved MIDI maps | per-clip motion; launch clips like Ableton |
| M7 | events, score, memory | leave it running and it develops and quotes itself |
| M8 | descriptors + corpus brain | drums from the folder; Samplebrain-style reconstruction |

Suggested next (after session 3): pick a controller for the box and make a fixed template for it; play
the new instruments and say what feels dead; a spectrum analyzer behind EQ Eight; VST once VSTPlugin is installed.

Earlier suggestion: keep iterating on *sound* until it's fun to sit with (more noise sources, audio-rate
mod sources, temperature knob, undo-dice). Then clips with automation lanes (M6).

### Open questions

- Which MIDI controller (Push, Launchpad, a knob box)? It decides the M6 layout.
- Should clips be per-track slots (Session view) or one timeline (Arrangement)?
- How big is the sample folder? It decides how soon the descriptor cache is needed.
