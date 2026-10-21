# unsound — the big plan

## What it is

A glitch centre for the laptop, laid out like an Ableton set: instruments on tracks, real sends
into return tracks, device chains everywhere, and a piano roll or step grid when you want to
write something. On top of that, things **move by themselves**. Instruments improvise, patterns
mutate, filters drift, the master stutters. You can let it run, nudge it, or grab any part directly.

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

## Architecture

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

## Status

Legend: ✅ working · 🟡 partly there · ⬜ not started

### 1. Mixer and routing
- ✅ Instrument tracks, return tracks, master track; add and remove at runtime
- ✅ Per-track tempo: sync or own bpm, tempo drift, speed, resync; live bpm shown on each strip
- ✅ Strips: volume (dB), pan, wander, activator, solo (returns stay audible), stereo peak meters
- ✅ Genuine sends from every track to every return (up to 8 returns), pre/post per return
- ✅ Return → return sends (feedback allowed, one block late)
- ⬜ Send/return to/from a specific track (sidechain-style routing, "audio from" another track)
- ⬜ Track groups (sum a few tracks into a group strip)
- ⬜ Crossfader A/B assignment, à la Ableton
- ⬜ Rename tracks; reorder tracks by dragging

### 2. Devices
- ✅ Insert chains on any track, return or master: add, bypass, reorder, remove
- ✅ Browser with drag & drop (and + buttons): ~50 presets in categories, plus whole chains
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

### 3. Instruments
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

### 4. Clips
- ✅ Piano roll (24 rows, 8–64 steps, scale highlighting, click/drag/delete, preview on click), own speed knob
- ✅ Wander mode (improvises in scale) with `keep wander` to capture it into the roll; `suggest`
- ✅ Repeats and repeat chance per note; non-destructive mutation (shift/octave/skip/double)
- ⬜ Velocity and per-note probability (Ableton 11-style chance)
- ⬜ Multiple clips per track and a clip launcher (session view slots), with follow actions
- ⬜ Clip length/loop brace in the roll; zoom and scroll; draw mode; copy/paste
- ⬜ Polyrhythm: each clip with its own length, so loops phase against each other
- ⬜ Automation lanes: record knob moves into the clip

### 5. Motion
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

### 6. Memory
- ⬜ **Motion memory**: record every control's history; replay a window of it (reversed, slower) onto any control
- ⬜ **Audio memory**: resample the master into the corpus so the machine eats its own past
- ⬜ A "memory" amount: how much of the corpus is original vs. its own past

### 7. Corpus brain (Samplebrain)
- ✅ Silence-skipping grain table with rough loudness per grain
- ⬜ Descriptors per grain: loudness, brightness, noisiness, MFCCs; cached per folder
- ⬜ Nearest-neighbour search; tagging grains as kicky/hatty/tonal/texture
- ⬜ **Target mode**: rebuild a sound from the closest-matching corpus grains
- ⬜ **Song-from-a-folder**: drums, bass and keys all pulled from the folder by role

### 8. Playing live
- ✅ Record master to disk; save/load whole sets (tracks, devices, clips, sends, scenes, song)
- ✅ Computer keyboard: notes on the selected track (A–; like Ableton), transport, track select, holds, scenes
- ✅ MIDI: notes play the selected track; MIDI learn for any knob/toggle/hold; relative jog wheels detected
- ⬜ Save MIDI mappings with the set; controller templates (Launchpad grid → scenes/tracks, DJ deck layout)
- ⬜ Hold-to-play sustain from keys/MIDI (note length = how long you hold)
- ⬜ Keyboard "parameter mode": focus a device and turn its knobs with keys
- ⬜ Stem recording; CPU guard
- ⬜ Knob right-click: reset to default / assign mover / map to MIDI

## Milestones

| # | milestone | what you can do at the end |
|---|---|---|
| M1 | ✅ grains, kick, glitch | hear it move |
| M2 | ✅ voices, sends, first ladder | pull voices together, push them around |
| M3 | ✅ Ableton-style rebuild | mixer, real sends/returns, device chains, piano roll, steps, waveforms, drawn wavetables |
| M4 | ✅ tempo per track, browser, 27 devices, keys + MIDI, scenes, sets | play it without the mouse, keep what you made |
| M5 | clips and launcher | several clips per track, follow actions, automation |
| M6 | modulators + MIDI | any knob can move by itself or be mapped to hardware |
| M7 | events, score, memory | leave it running and it develops and quotes itself |
| M8 | descriptors + corpus brain | drums from the folder; Samplebrain-style reconstruction |

Suggested next: **M6**, modulators as devices plus saved MIDI maps and controller templates. Then the song
editor in the GUI, then **M7** (events + memory).

## Open questions

- Which MIDI controller (Push, Launchpad, a knob box)? It decides the M6 layout.
- Should clips be per-track slots (Session view) or one timeline (Arrangement)?
- How big is the sample folder? It decides how soon the descriptor cache is needed.
