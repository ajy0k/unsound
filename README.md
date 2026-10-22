# unsound

A noise machine laid out like an Ableton set. Point it at a folder of samples. Instruments
play from it (grains, kick, sample-keys, FM) through insert devices, with real sends into return
tracks and a master chain. Things move by themselves, and every part is open for you to grab.

Written in plain SuperCollider (3.14), with no quarks.

## Run it

1. Open `play.scd` in SuperCollider.app.
2. Set `~folder` in the first block and evaluate it (Cmd-Return).
3. Press **play**.

## The box

The window opens as **the box**, built around focus. The browser is on the left as usual. Pads along
the top (one per track: click = focus, double-click = mute, right-click = solo). Under them, a small
screen for the focused track (its XY pad, drum grid, roll or tape) with a narrow column beside it:
a scope, its every-so-often sliders, and **8 encoders** mapped to the track's current page (pages are
made automatically: the instrument's knobs, mix, then one page per device; **tab** / shift-tab or
◀ ▶ change page). Below that, the big part: the instrument and its whole effect chain in a row.
Drag the little handle between the screen and the chain to change the split. **`** switches to the
studio window (mixer, mods) and back.

MIDI learn on an encoder maps *the encoder*, so 8 knobs on any controller follow focus everywhere.
◀ ▶ page, ◀ ▶ track, glide, cut, dice and new sound learn the same way (pads or buttons).

**Every so often:** wherever you see a small button next to a slider with no numbers, the button
does it now and the slider says how often it happens by itself, at random intervals (empty = never,
full = a few times a second). Every instrument has some (spasm, skip, tape stop, fill, sfx, new
sound…), every device has "jump" (throws its mystery knob), and the top bar has glide and cut.
Right-click the slider to modulate it.

## Playing it without the mouse

Press **?** (or the ? button, top right) for every shortcut.

The computer keyboard works like Ableton's: **A W S E D F T G Y H U J K O L P ;** play the selected
track, **Z/X** change octave, **space** plays/stops, **1–9** and **←→** select tracks, **↑↓** volume
(⇧ = that track's tempo), **tab** Clip/Devices, **N** new sound, **M** mute, **R** resync,
**B** / **V** hold master stutter / freeze, **Q** lurch, **C** capture scene, **[ ]** scenes,
**, .** tempo. The full list is under the transport.

MIDI: notes play the selected track. Turn on **MIDI learn**, touch any knob or toggle on screen,
then move a control on your keyboard / knob box / DJ controller. Jog wheels (relative encoders)
are detected and nudge instead of jump.

## The studio window (`)

- **Browser** (left): instruments, ~50 effect presets in categories, and whole chains.
  **Double-click** to add to the end of the selected track's chain, or drag onto a mixer strip,
  the device area, or onto a device to insert before it.
- **Transport:** play, bpm (no limits: at absurd tempos rhythm turns into pitch), ● record
  (what you hear, to `~/Music/unsound/`, 24-bit wav; "show" reveals it), chaos, scale and key,
  **glide / cut / back** (lurch toward somewhere new over the morph time, jump there on a dime, undo),
  **distance** (how far), **events** (every N bars, by chance, something big happens), new sounds,
  infect / cure / alive, MIDI learn, save/load set.
- **Scenes** (right of master): capture, launch with a morph time, update, and play a song (a list
  of scenes and bar counts).
- **Mixer:** one strip per track. Each strip has sends to every return, pan, a meter and fader,
  an activator, and solo. Click a track's name to select it. Returns have a pre/post toggle and
  can send to each other. Use `+ instrument` and `+ return` to add tracks.
- **Detail** (selected track):
  - **Clip:** piano roll for keys/fm, step grid for kick, waveform region for grains.
    In the roll, click to add a note (you hear it), drag right to lengthen it, and click a note to delete it.
    The roll has its own **speed** knob, plus repeats, repeat chance, mutate and octave. `suggest` writes
    a phrase, and `keep wander` captures what the improviser just played.
  - **Devices:** the instrument's own controls, then an insert chain. Add, bypass, reorder and
    remove: drive (8 modes: soft/tube/hard/fold/fuzz/rectify/sine/crunch), crush, dirt, filter, eq,
    comb, resonator, ring, shift, space, echo, chorus/flanger, tape, pitch, reverse, smear, stutter,
    chop, freeze, scramble, blur, feedback, compressor, gate, width, limiter.
  - The header has the track's **own tempo**: sync to master or its own bpm, **tempo drift**,
    speed and resync.

The master always ends in a limiter, and every instrument starts with its own flavour of overdrive.

Knobs: drag up/down (⇧ for fine), scroll, double-click to reset.

Mutation and drift vary what's played around your settings. They never overwrite what you set.

**Make it move:** right-click (or alt-click) any knob to give it a modulator; right-click again to
remove it. The **mods** tab lists them all, and a mod's rate and depth are knobs too, so you can
modulate the modulators. A mod can run its own shape, **follow another track's loudness**, or be
**driven by another mod**; negative depth inverts (ducking). Mods and MIDI mappings are saved
with scenes and sets. **infect** (I) scatters random mods over the set, **cure** (\\) removes
them, **dice** (/) randomizes a track, and every device has a mystery **?** knob that sweeps a
hidden handful of its settings.

**alive** (transport): new tracks and devices arrive already moving. The master never gets
automatic movement; it's yours to play by hand.

**drums:** eight lanes (kick, snare, hat, open, clap, rim, perc, glitch), each with its own length
(right-click a cell to end the lane there), generated patterns in five styles (four, broken,
euclid, sparse, chaos), mutation that drifts home, and a synth or sampled sound per lane.

**The chain** starts with **mix** (volume, pan, sends, named by what's on each return) and
**mods**: every mod on the track as a tree. Right-click any knob to give it a mod; right-click a
mod's rate or depth and the mod on the mod appears indented under it, as deep as you like.
Hover over anything in the browser to see what it does.

**mouth:** a talking machine. It babbles, says what you type (in a loop), or holds a vowel you sweep
with the XY pad. Formant filters for the vowels, hiss for s / sh / f, pops for p / t / k, a nose for
m / n; pitch, throat, sing, robot and lofi (down to Speak & Spell).

**noise:** an extensible noise generator: two layers, each sweeping continuously through a list of
noise kinds (white, pink, brown, bits, velvet, dust, crackle, rain, wind, radio, metal, logistic,
henon, gendy…), then filter, drive, pulse gate, width. Add a kind with one line in `~noiseKinds`
(`lib/voices/noisegen.scd`).

**deck:** a tape player. **open…** any audio file or take one from the folder; it loops the region
forever. Speed runs from −8× to 8× through a motor with **inertia** (tape stops, spin backs), plus
wow, flutter, **chew** (skips and drop-outs), drive, age and hiss. Click the waveform to move the
playhead, drag to pick the loop.

**osc3:** a 3xOsc: three oscillators (sine/tri/saw/square/noise); osc 2 and 3 mix, ring, FM or AM
into osc 1; a pitch LFO; and an `lfo →` menu that puts a modulator on any of its knobs.

**atari:** the Atari 2600's TIA chip. Two channels with the real AUDC (16 waveforms from the
chip's poly4/poly5/poly9 counters), AUDF and AUDV registers at the chip's clock. Notes snap to the
nearest AUDF, so it's out of tune like the real thing; channel B makes sound effects every so often.

**drums** lanes cycle between **syn / fm / smp**; **rnd** picks a random slice, **load** loads your
own sample, and **long sample…** loads one long file the whole kit slices from (at its onsets).

**EQ Eight** (filter category): eight bands like Ableton's. Drag a dot for freq/gain, scroll for Q,
double-click for on/off; pick a band's type below. The curve is the real response.

**VST:** if the [VSTPlugin](https://git.iem.at/pd/vstplugin) extension is installed, a `vst plugin`
device appears under dynamics (experimental, untested here).

**Noise instruments:** `creature` (chaotic oscillators tangled together), `bytebeat` (8-bit integer
formulas), and `hum` (a self-oscillating feedback network). They drone continuously, spasm by
themselves, and have an XY pad in their clip view.

## Layout

| file | what |
|---|---|
| `play.scd` | boot block and code cheat sheet |
| `unsound.scd` | loader: config, module list, server graph, boot |
| `lib/corpus.scd` | folder → buffers → grains (skips silence) |
| `lib/tracks.scd` | tracks, strips, sends, returns, solo/mute, meters |
| `lib/devices.scd` | insert devices and their movers |
| `lib/melody.scd` | piano roll, wander mode, repeats, mutation |
| `lib/mods.scd` | modulators (and mods on mods), infect, cure, dice, mystery knobs |
| `lib/sometimes.scd` | "every so often": random-interval triggers on tracks, devices and the transport |
| `lib/drones.scd` | shared shape of the continuous noise instruments |
| `lib/scenes.scd` | scenes, morphing, song, save/load sets |
| `lib/control.scd` | computer keyboard and MIDI (notes, learn, DJ controllers) |
| `lib/voices/*.scd` | instruments: `creature`, `bytebeat`, `hum` (noise.scd), `noise` (noisegen.scd), `deck`, `osc3`, `atari`, `drums`, `grains`, `kick`, `keys`, `fm` |
| `lib/motion.scd` | transport, tempo, lurch, recording |
| `lib/gui/*.scd` | widgets (drawn knobs, sliders, sometimes), browser, clip views, mixer + scenes, EQ Eight panel, the box, main window |

To add an instrument, add a file to `lib/voices/` that registers `~voiceTypes[\name]` (copy one of
the existing ones), then add it to the list in `unsound.scd`. Give it `pages` for the box's
encoders and `sometimes` for its every-so-often controls. To add a device, add a `~deviceDef`
and an entry in `~deviceTypes` (in `lib/devices.scd`).

See [PLAN.md](PLAN.md) for where this is going.
