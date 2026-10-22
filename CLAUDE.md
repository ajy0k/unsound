# CLAUDE.md: notes to future self

## What this is

**unsound** is a noise / glitch instrument written in plain SuperCollider 3.14 (no quarks, no
plugins). Its owner makes noise music, comes from Ableton, is a programmer, and is learning DSP from
a book. It started as "Ableton, but things move by themselves" and has become **a broken machine you
overdrive**: a few broken sources (the bitmeister above all), stacks of nasty mostly-digital effects,
a background noise wall, everything modulating everything, recording all the time. The owner is
having a great time with it ("better noise than I ever have").

- `PLAN.md`: the direction at the top (the six nouns, the build order), then the old plan as history.
  **Read its top before changing anything big.**
- `MANUAL.md`: the user's manual, with screenshots in `docs/img`. `docs/unsound-manual.docx` is
  built from it by pandoc (command below). Keep it up to date when features change.
- `README.md`: short overview and file layout. `wants.md`: the owner's original wishlist for session 3.

## Running it

The owner opens `play.scd` in SuperCollider.app and runs its first block (Cmd-Return). That sets
`~folder` (samples) and loads `unsound.scd`, which boots the server and opens the window.

**Testing without a person (do this after every change):**

```
tools/run.sh                 # boot silently, play 6 s, print each track's peak, quit
tools/run.sh my-test.scd     # my-test.scd sets ~testScript = { … } (a Routine body)
```

Output goes to a private bus (nothing plays aloud); logs to `/tmp/unsound-smoke/log.txt`. Grep the
log for `ERROR` / `FAILURE`. The meters line is the main sign that each track actually makes sound.
In tests, wrap anything touching the GUI in `{ … }.defer`.

**Screenshots:** grab SuperCollider's own window, not the screen (the owner is usually using the
machine, and a full-screen `screencapture` once caught their terminal). Stop the GUI tick first or
`Image.fromWindow` can deadlock (it holds the language lock while a UserView wants it to repaint):

```
{ ~tick.stop }.defer; 0.4.wait; { Image.fromWindow(~win).write(path); ~startTick.() }.defer;
```

If a run hangs, `run.sh` saves the stack to `/tmp/unsound-smoke/sample.txt` before killing it.

Rebuild the Word manual: `pandoc MANUAL.md -o docs/unsound-manual.docx --resource-path=. --toc --toc-depth=2`

## How it's built

Everything is environment variables (`~name`) and Events: no classes. `unsound.scd` loads the files
in order (that order matters: later files use earlier ones at load time), builds the server graph,
and sets up the default set. Each module adds a SynthDef builder to `~defs`.

Signal flow: instrument → its device chain → strip (volume, pan, sends, takeover) → master bus →
master devices (limiter always last) → output. Returns get the sends. `~buildGraph` rebuilds all
nodes after Cmd-. (via ServerTree).

| file | what |
|---|---|
| `lib/tracks.scd` | tracks (`\inst`, `\return`, `\master`, `\wall`), strips, sends, solo, `~tset`, takeover, per-track tempo |
| `lib/devices.scd` | every effect (`~deviceDef` + an entry in `~deviceTypes`), browser presets (`~browserItems`), add / remove / move |
| `lib/mods.scd` | modulation: a mod moves one *target* around a home value; mods on mods; infect / cure / dice; `~resolveTarget` |
| `lib/lfos.scd` | Serum-style drawn LFOs; a mod whose source is `"lfo:<id>"` follows one |
| `lib/sometimes.scd` | "every so often": random-interval triggers on tracks, devices, the transport |
| `lib/tape.scd` | the 15-minute RAM tape + `~keep`, and the always-on session recording to disk |
| `lib/wall.scd` | the wall: background noise layer, recipes in `~wallTypes` |
| `lib/presets.scd` | saving / loading your own instruments and chains |
| `lib/scenes.scd` | snapshots (`~snapshot`, `~applyState`, `~applyTrackState`), scenes, song, sets on disk |
| `lib/motion.scd` | transport, tempo, glide / cut / back, events, the old record button |
| `lib/control.scd` | computer keyboard and MIDI (learn, relative encoders) |
| `lib/descriptions.scd` | one-line descriptions: the browser's tooltips |
| `lib/voices/*.scd` | instruments (see below) |
| `lib/gui/*.scd` | widgets, browser, the box (default view), the studio view (main + mixer), clip views, EQ Eight, band, mix/mods column, LFO row |

**Targets and ids.** Anything with a knob is a *target* `(tid, name, spec, get, set)`. Ids are
strings: `t:<track>:<key>`, `d:<deviceUid>:<param>` (`?` = mystery knob), `l:<track>:<lane>:<key>`,
`s:<track>:<return>`, `m:<modId>:rate|depth`, `lfo:<id>:hz`, `g:<name>` (global), `box:<i>`,
`btn:<name>`. `~resolveTarget` turns an id back into a target (used to restore mods and MIDI maps).
Mods, sometimes and MIDI all key off these ids.

**An instrument** is `~voiceTypes[\name] = (…)` with some of: `color`, `params` (list of `~p.(…)`:
diceable, infectable, shown on encoder pages), `defaults`, `chain` (starting effects), `init`,
`build` (continuous synth into `t[\src]`), `mover` (a Routine body; wait with `~vwait.(t, beats)`),
`key` (keyboard / MIDI note), `repatch` ("new sound"), `dice`, `onSet` (react to `~tset`),
`restored` (after a set or preset loads), `sometimes` (`[key, label, action, default]`), `pages`,
`screen` (the box's small view), `clip` (the full clip view), `device` (panels in the chain).
`~droneType` builds continuous ones. Copy a similar instrument, add the file to `unsound.scd`, and
add a line to `lib/descriptions.scd`.

**An effect**: a `~deviceDef.(\dName, { |sig, …| … })` in the `~defs` block, an entry in
`~deviceTypes` (`def`, `cat`, `params`, optionally `mover`, `gui`, `panel`, `pages`), a browser
entry in `~browserItems`, a description. `dice: false` on a param keeps dice / infect / mystery off it.

**The GUI** rebuilds whole sections rather than diffing. Every live control registers a function
in `~bindings` (or `~animated`), run 20 times a second by `~tick`; each returns false once its view
is closed. `~refreshDetail` rebuilds the focused track's views (and pop-out track windows),
`~refreshGui` rebuilds the window, `~refreshMods` / `~refreshLfos` / `~refreshBrowser` their parts.
Two views: **the box** (`~viewMode = \box`, default: browser, pads, LFO row, small screen + focus
column, drag handle, chain) and **the studio** (the original Ableton-like window). Backtick toggles.

## SuperCollider gotchas we've hit

- `~list = ~list.select/reject { … }` hands back an Array; a later `.add` may not mutate it and
  things silently vanish. Mutate in place with `removeAllSuchThat`.
- `includes` compares by identity: fine for Symbols, numbers and Chars, wrong for Strings. Use `includesEqual`.
- Never use `^` inside a Function (non-local return error). `inf` is a reserved word (not a variable name).
- Event literal keys must be plain identifiers: `(sawUp: …)`, not `("saw up": …)`.
- `x.round` returns a Float: `"uWall" ++ 1.0` is `"uWall1.0"`. Use `.asInteger`.
- UGens don't have `asinh`, `eq:` etc.; write the maths out (`(a - b).abs < 0.5` for equality).
- `Buffer.copyData` copies *from* the receiver *into* the argument.
- Qt calls from a non-AppClock thread fail: defer them.
- Core only: `Scale.performDegreeToKey` (not `degreeToKey`), no `midiname`, no PV_MaxMagN (sc3-plugins).
- The owner's Mac has mismatched input / output sample rates: keep `s.options.numInputBusChannels = 0`.
  A script that boots the server itself needs `s.options.memSize` raised first.
- Plain Qt views only start a drag with Cmd held; drag sources call `uv.beginDrag` on mouse move.

## Working with the owner

- Dense UI: they use one screen at its native resolution and keep things small. Keep the browser and
  the device chains in a row; never hide controls behind pages or menus. Many windows are fine
  (pop-outs), view tabs aren't.
- Every parameter reachable ("open, not locked down"); the machine varies *around* what you set and
  drifts back. The master is hands-only (never infected).
- Digital on purpose ("could a pedal do this?"). No modular / patching UIs.
- They like to play, react, and ask for the next thing. Ship working pieces, test them, commit,
  explain where to find them. Hover tooltips and the manual matter: they've struggled to find things.

## Dev log

- **Sessions 1–2 (2026-10-21)**: grains / kick / glitch → Ableton-style rebuild: mixer, real sends and
  returns, device chains, piano roll, drawn wavetables, per-track tempo, browser, 27 devices,
  keyboard + MIDI, scenes, sets. Then noise toys (creature, bytebeat, hum), mods on anything, mods
  on mods, infect / cure / dice, mystery knobs, lurch (glide / cut / back), events, drums.
- **Session 3 (2026-10-22)**: from `wants.md`: noise (extensible), deck (tape player), osc3, atari
  (TIA from its counters), FM / loaded / sliced samples on drums, EQ Eight, "every so often", VST
  (guarded, untested), the box. The box's first version was rejected (too big, browser gone, pages)
  and rebuilt dense. Brainstorm → new direction ("broken machine you overdrive"). Then: tape + keep,
  the wall, takeover, digital effects (bitmask, alias, bins, codec, overflow, skip), new default set
  (bitmeister ×2 + grains + wall), pop-out windows, M / S / volume on pads, mix + mods column (mods
  as a tree), tooltips, mouth (speech synthesis), the manual, Serum-style LFOs (draw, drag onto
  knobs, ring-drag for amount), the wall respects solo, session recording to disk, saved
  instruments / chains, foldable browser categories, this file, `tools/`.
- **Next** (PLAN.md): lines (Merzbow accelerations, hit / phrase), mod chains on the knob itself, a
  text console for mods (`wall.lows ~ drunk(0.1)`), a fixed template for the owner's two controllers
  (generic 8 sliders / 2×10 knobs / buttons, and a 4×4 pad; CC numbers still needed), input gain +
  musical breakup on every device, "stack 7 random", an `fx/` folder for their DSP-book experiments.
