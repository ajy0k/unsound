# unsound

A noise machine laid out like an Ableton set. Point it at a folder of samples. Instruments
play from it (grains, kick, sample-keys, FM) through insert devices, with real sends into return
tracks and a master chain. Things move by themselves, and every part is open for you to grab.

Written in plain SuperCollider (3.14), with no quarks.

## Run it

1. Open `play.scd` in SuperCollider.app.
2. Set `~folder` in the first block and evaluate it (Cmd-Return).
3. Press **play**.

## Playing it without the mouse

The computer keyboard works like Ableton's: **A W S E D F T G Y H U J K O L P ;** play the selected
track, **Z/X** change octave, **space** plays/stops, **1–9** and **←→** select tracks, **↑↓** volume
(⇧ = that track's tempo), **tab** Clip/Devices, **N** new sound, **M** mute, **R** resync,
**B** / **V** hold master stutter / freeze, **Q** lurch, **C** capture scene, **[ ]** scenes,
**, .** tempo. The full list is under the transport.

MIDI: notes play the selected track. Turn on **MIDI learn**, touch any knob or toggle on screen,
then move a control on your keyboard / knob box / DJ controller. Jog wheels (relative encoders)
are detected and nudge instead of jump.

## The window

- **Browser** (left): instruments, ~50 effect presets in categories, and whole chains. Drag onto a
  mixer strip, the device area, or onto a device to insert before it. Or press **+** to add to
  the selected track.
- **Transport:** play, bpm, chaos, scale and key, lurch, rec, MIDI learn, save/load set.
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

## Layout

| file | what |
|---|---|
| `play.scd` | boot block and code cheat sheet |
| `unsound.scd` | loader: config, module list, server graph, boot |
| `lib/corpus.scd` | folder → buffers → grains (skips silence) |
| `lib/tracks.scd` | tracks, strips, sends, returns, solo/mute, meters |
| `lib/devices.scd` | insert devices and their movers |
| `lib/melody.scd` | piano roll, wander mode, repeats, mutation |
| `lib/scenes.scd` | scenes, morphing, song, save/load sets |
| `lib/control.scd` | computer keyboard and MIDI (notes, learn, DJ controllers) |
| `lib/voices/*.scd` | instruments: `grains`, `kick`, `keys`, `fm` (each with its Clip and Devices views) |
| `lib/motion.scd` | transport, tempo, lurch, recording |
| `lib/gui/*.scd` | widgets (drawn knobs), browser, clip views, mixer + scenes, main window |

To add an instrument, add a file to `lib/voices/` that registers `~voiceTypes[\name]` (copy one of
the existing ones), then add it to the list in `unsound.scd`. To add a device, add a `~deviceDef`
and an entry in `~deviceTypes` (in `lib/devices.scd`).

See [PLAN.md](PLAN.md) for where this is going.
