// Playing without the mouse: the computer keyboard, and MIDI (keyboards, knob boxes, DJ controllers).
//
// Computer keyboard (works whenever the unsound window is in front and no text box has focus):
//   A W S E D F T G Y H U J K O L P ;   notes on the selected track, like Ableton's computer keyboard
//   Z / X        keyboard octave down / up
//   space        play / stop
//   1–9          select instrument track 1–9;  0 selects master
//   ← / →        previous / next track
//   ↑ / ↓        selected track volume up / down   (with shift: tempo of that track up / down)
//   tab          box: next page (shift-tab: previous) · studio: Clip / Devices / Mods
//   `            switch between the box and the studio window
//   '  hold: takeover (the selected track goes to infinity, everything else ducks)
//   return  keep everything on the tape (shift: the last minute)
//   N  new sound on the selected track     M  mute selected     R  resync selected
//   /  dice the selected track (instrument + devices)     I  infect: scatter mods     \  cure: remove all mods
//   B  hold: stutter every stutter device on the master while held
//   V  hold: freeze every freeze device on the master while held
//   Q  glide somewhere new    =  cut there instantly    -  back (undo)
//   C  capture a scene      [ / ]  launch previous / next scene
//   , / .        master tempo down / up
//
// MIDI: notes play the selected track. MIDI learn: switch on "learn" in the transport, touch a knob
// or toggle on screen, then move a knob / press a button on the controller. That control is now
// mapped. Works with DJ controllers too (faders, crossfader, EQ knobs, pads); jog wheels that send
// relative values are detected and nudge instead of jump.

~kbOctave = 5;   // A = C at this octave (C4 = 60 when 5)
~kbMap = "awsedftgyhujkolp;";
~keysDown = Set[];

~selectedTrack = { ~tracks[~selected] };

~trackList = { ~wallList.() ++ ~voiceOrder.asArray ++ ~returnOrder.asArray ++ [\master] };

~selectOffset = { |dir|
	var list = ~trackList.(), i = list.indexOf(~selected) ? 0;
	~select.(list.wrapAt(i + dir));
};

// Play a note on a track from a key or a MIDI note.
~playKey = { |t, midi|
	var f = t !? { ~voiceTypes[t[\type]] !? { |it| it[\key] } };
	if (f.notNil) { f.value(t, midi) };
};

~holdMaster = { |type, on|
	~masterTrack[\devices].do { |d| if (d[\type] == type) { ~devHold.(d, on) } };
};

~keyDown = { |view, char, mod, unicode, keycode, key|
	var typing = view.isKindOf(NumberBox) or: { view.isKindOf(TextField) and: { view.isKindOf(DragView).not } };
	if (typing.not and: { ~keysDown.includes(key).not }) {   // auto-repeat sends the key again
		~keysDown.add(key);
		~keyCommand.(char, mod, key);
	};
	nil
};

~keyCommand = { |char, mod, key|
	var t = ~selectedTrack.(), i = char !? { ~kbMap.indexOf(char.toLower) };
	case
	{ i.notNil and: { mod.isCmd.not } } { ~playKey.(t, (~kbOctave * 12) + i) }
	{ char == $z } { ~kbOctave = (~kbOctave - 1).max(1) }
	{ char == $x } { ~kbOctave = (~kbOctave + 1).min(9) }
	{ char == Char.space } { if (~running == true) { ~stop.() } { ~start.() } }
	{ char.notNil and: { char.isDecDigit } } {
		i = char.digit;
		if (i == 0) { ~select.(\master) } { ~voiceOrder[i - 1] !? { |n| ~select.(n) } };
	}
	{ key == 16r1000012 } { ~selectOffset.(-1) }
	{ key == 16r1000014 } { ~selectOffset.(1) }
	{ key == 16r1000013 } {
		if (mod.isShift) { ~nudgeTempo.(t, 1.03) } { ~tset.(~selected, \level, (t[\level] * 1.12).min(1.4)) }
	}
	{ key == 16r1000015 } {
		if (mod.isShift) { ~nudgeTempo.(t, 1 / 1.03) } { ~tset.(~selected, \level, t[\level] / 1.12) }
	}
	{ key == 16r1000001 and: { ~viewMode == \box } } { ~boxPageStep.(1) }
	{ key == 16r1000002 and: { ~viewMode == \box } } { ~boxPageStep.(-1) }
	{ key == 16r1000001 } { ~detailMode = switch (~detailMode) { \clip } { \devices } { \devices } { \mods } { \clip }; ~refreshDetail.() }
	{ char == $' } { ~holdTakeover.(true) }
	{ key == 16r1000004 or: { key == 16r1000005 } } { if (mod.isShift) { ~keep.(60) } { ~keep.() } }
	{ char == $` } { ~viewMode = if (~viewMode == \box) { \studio } { \box }; ~refreshGui.() }
	{ char == $? } { { ~showHelp.() }.defer }
	{ char == $n } { ~repatch.(~selected) }
	{ char == $/ } { ~pushHistory.(); ~diceTrack.(~selected) }
	{ char == $i } { ~infect.(3) }
	{ char == $\\ } { ~cure.() }
	{ char == $m } { ~tset.(~selected, \on, t[\on].not) }
	{ char == $r } { ~resync.(~selected) }
	{ char == $b } { ~holdMaster.(\stutter, true) }
	{ char == $v } { ~holdMaster.(\freeze, true) }
	{ char == $q } { ~glide.() }
	{ char == $= } { ~cut.() }
	{ char == $- } { ~back.() }
	{ char == $c } { ~capture.() }
	{ char == $[ } { ~launch.(((~currentScene ? 0) - 1).max(0)) }
	{ char == $] } { ~launch.(((~currentScene ? -1) + 1).min(~scenes.size - 1)) }
	{ char == $, } { ~bpm.(~tempo / 1.03) }
	{ char == $. } { ~bpm.(~tempo * 1.03) };
};

~keyUp = { |view, char, mod, unicode, keycode, key|
	~keysDown.remove(key);
	case
	{ char == $b } { ~holdMaster.(\stutter, false) }
	{ char == $v } { ~holdMaster.(\freeze, false) }
	{ char == $' } { ~holdTakeover.(false) };
	nil
};

// Shift-↑/↓ on a synced track unsyncs it so it can go its own way.
~nudgeTempo = { |t, factor|
	if (t.notNil and: { t[\kind] == \inst }) {
		if (t[\sync] != false) { t[\bpm] = ~tempo; ~tset.(t[\name], \sync, false) };
		~tset.(t[\name], \bpm, (t[\bpm] * factor).max(0.1));
	};
};

~installKeys = {
	View.globalKeyDownAction = { |...args| ~keyDown.(*args) };
	View.globalKeyUpAction = { |...args| ~keyUp.(*args) };
};

// ---------------------------------------------------------------- MIDI

~midiLearn = false;
~midiMap = ();   // "cc:chan:num" or "note:chan:num" → (set: { |0..1| }, kind: \abs or \toggle)

// Called by knobs and toggles when they're touched while learn is on.
~learn = { |target| if (~midiLearn) { ~learnTarget = target } };

~midiKey = { |kind, chan, num| "%:%:%".format(kind, chan, num).asSymbol };

~initMidi = {
	try {
		MIDIClient.init(verbose: false);
		MIDIIn.connectAll(false);
	} { "unsound: MIDI not available".postln };

	MIDIdef.cc(\uCC, { |val, num, chan|
		var k = ~midiKey.(\cc, chan, num), m;
		if (~learnTarget.notNil) {
			~midiMap[k] = (target: ~learnTarget, last: val);
			"unsound: CC % (ch %) → %".format(num, chan + 1, ~learnTarget[\name]).postln;
			~learnTarget = nil;
		} {
			m = ~midiMap[k];
			if (m.notNil) { { ~midiApply.(m, val) }.defer };
		};
	});

	MIDIdef.noteOn(\uNoteOn, { |vel, num, chan|
		var k = ~midiKey.(\note, chan, num), m;
		case
		{ ~learnTarget.notNil } {
			~midiMap[k] = (target: ~learnTarget, button: true);
			"unsound: note % (ch %) → %".format(num, chan + 1, ~learnTarget[\name]).postln;
			~learnTarget = nil;
		}
		{ (m = ~midiMap[k]).notNil } { { ~midiPress.(m, true) }.defer }
		{ { ~playKey.(~selectedTrack.(), num) }.defer };
	});

	MIDIdef.noteOff(\uNoteOff, { |vel, num, chan|
		var m = ~midiMap[~midiKey.(\note, chan, num)];
		if (m.notNil) { { ~midiPress.(m, false) }.defer };
	});
};

// A CC moves a knob. Absolute controls jump; relative ones (jog wheels: values just above 0 or
// just below 128, or around 64) nudge.
~midiApply = { |m, val|
	var tg = m[\target], cur, delta;
	if (tg[\toggle].notNil) { if (val >= 64) { tg[\toggle].value } } {
		if (m[\relative].isNil and: { m[\last].notNil }) {
			m[\hits] = (m[\hits] ? 0) + 1;
			if ([1, 2, 3, 63, 65, 125, 126, 127].includes(val) and: { m[\hits] > 3 } and: { (val - m[\last]).abs < 3 }) {
				m[\relative] = true;
			};
		};
		m[\last] = val;
		if (m[\relative] == true) {
			delta = case { val < 64 and: { val > 0 } } { val } { val > 64 } { val - 128 } { 0 };
			if (val == 64) { delta = 0 };
			cur = tg[\spec].unmap(tg[\get].value);
			tg[\set].value(tg[\spec].map((cur + (delta / 200)).clip(0, 1)));
		} {
			tg[\set].value(tg[\spec].map(val / 127));
		};
	};
};

// A button toggles a toggle, holds a hold, or (on a knob) jumps it to 0 / 1.
~midiPress = { |m, down|
	var tg = m[\target];
	case
	{ tg[\hold].notNil } { tg[\hold].value(down) }
	{ tg[\toggle].notNil } { if (down) { tg[\toggle].value } }
	{ tg[\set].notNil } { if (down) { tg[\set].value(tg[\spec].map(1 - tg[\spec].unmap(tg[\get].value).round)) } };
};

// ---------------------------------------------------------------- saving MIDI maps

// Mappings are saved by the target's id: knobs, the box's encoders and buttons. Plain toggles aren't (yet).
~midiState = {
	var out = List[];
	~midiMap.keysValuesDo { |k, m|
		var tg = m[\target];
		if (tg[\tid].notNil) {
			out.add((key: k, tid: tg[\tid], spec: tg[\spec] !? { |x| x.asCompileString }, relative: m[\relative], button: m[\button]));
		};
	};
	out.asArray
};

~applyMidi = { |list|
	list.do { |e|
		var tg = ~resolveTarget.(e[\tid], e[\spec] !? { |x| x.interpret });
		if (tg.notNil) { ~midiMap[e[\key]] = (target: tg, relative: e[\relative], button: e[\button]) };
	};
};
