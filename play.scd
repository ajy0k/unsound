// unsound — performance sheet.
// Most things are in the window now; this is for doing them from code.
// Put the cursor on a line (or inside a ( ) block) and press Cmd-Return.
// Cmd-. is panic: everything stops, the graph rebuilds itself, press play again.

// ---- 1. boot: point it at a folder of samples (subfolders are included)
(
~folder = "~/Music/samples";   // falls back to macOS system sounds if empty
"unsound.scd".loadRelative;
)

~start.();
~stop.();
~set.(\chaos, 0.8);   // the one global macro
~bpm.(100);
~lurch.();            // most instruments grab a new sound
~scale = Scale.dorian; ~key = 2;

// ---- 2. tracks
~add.(\keys);                        // → keys2
~add.(\fm, (root: 36, busy: 0.8));   // → fm2
~remove.(\fm2);
~tset.(\keys, \busy, 0.9);           // any track/instrument setting
~tset.(\kick, \solo, true);
~tset.(\fm, \pan, -0.5);
~tset.(\keys, \wander, 1);           // moves around the stereo field
~ramp.(\fm, \speed, 3, 16);          // speed up to 3x over 16 beats
~ramp.(\fm, \speed, 0.5, 32);

~tset.(\fm, \sync, false); ~tset.(\fm, \bpm, 90);   // fm runs at its own 90 bpm
~tset.(\keys, \tempoDrift, 0.6);    // keys' tempo wanders
~resync.(\keys);                     // snap back in phase on the next bar
~tset.(\grains, \source, \file); ~tset.(\grains, \stray, 0.2); ~tset.(\grains, \hop, 0.3);

// ---- 3. sends and returns
~send.(\keys, \B, 0.6);              // keys → return B
~send.(\A, \B, 0.5);                 // returns can send to returns
~tset.(\B, \pre, true);              // pre-fader sends into B
~addReturn.(\comb);                  // → E
~remove.(\E);

// ---- 4. devices (any device, any track, any order)
~dev.(\keys, \crush);                // add to the end of the chain
~dev.(\fm, \filter, 0);              // add at the front
~dset.(\keys, 0, \bits, 4);          // track, device index, param, value
~dev.(\master, \chop);              // goes before the master limiter, which is always last
~addItem.(\grains, ~browserItems[5][1][0]);   // a whole browser chain ("noise wall")

// ---- 5. piano roll from code
~suggestRoll.(~tracks[\keys]); ~tset.(\keys, \play, \roll);
~keepHeard.(~tracks[\keys]);         // keep what wander mode just played

// ---- 6. scenes, song, sets
~capture.("intro");                  // snapshot everything
~launch.(0, 8);                      // morph to scene 0 over 8 beats
~song = List[[0, 16], [1, 8], [0, 8]]; ~playSong.();   // [scene, bars] …
~stopSong.();
~saveSet.();                         // → sets/<date>.unsound
~loadSet.("sets/….unsound".resolveRelative);

// ---- 7. MIDI: turn on "MIDI learn", touch a knob or toggle, move a controller knob / press a pad.
// MIDI notes play the selected track. MIDIClient.sources lists what's connected.

~reload.("~/Music/other-folder");    // swap the sample folder while it plays
