// deck: a tape-style player. Not granular: it plays the tape, at whatever speed the motor runs.
//   - open any audio file (file browser), or take a random one from the folder ("new sound")
//   - loops the region between `start` and `end` forever (drag on the waveform to pick it)
//   - varispeed from -8x to 8x (negative = backwards), plus `semis`; `inertia` is how long the
//     motor takes to get there, so speed changes swoop like a real tape machine
//   - wow, flutter, chew (random skips and drop-outs), drive, age (dull), hiss
//   - click the waveform to move the playhead; the reels show the motor
//   - every so often: skip, tape stop, reverse
// Keys / MIDI: notes set `semis` (C4 = original pitch) and cue the region start.

~defs.add({
	[1, 2].do { |nch|
		SynthDef(("uDeck" ++ nch).asSymbol, { |out, buf, gate = 0, rate = 1, semis = 0, inertia = 0.3,
			start = 0, end = 1, wow = 0.1, flutter = 0.1, chew = 0, drive = 0, age = 0, hiss = 0, id = 0|
			var frames = BufFrames.kr(buf), env = EnvGen.kr(Env.asr(0.01, 1, 0.05), gate);
			var jump = \jump.tr(0), jumpTo = \jumpTo.kr(0);
			var motor = Lag.kr(rate * semis.midiratio, inertia.max(0.001));
			var wobble = 1 + (LFNoise2.kr(0.7) * wow * 0.03) + (SinOsc.kr(7.3) * flutter * 0.006);
			var s0 = start.clip(0, 0.999) * frames, e0 = end.clip(start + 0.001, 1) * frames;
			var prev = LocalIn.kr(1), chewT = Dust.kr(chew * 4);
			var resetPos = Select.kr(jump > 0, [prev + (TRand.kr(-0.4, 0.4, chewT) * SampleRate.ir), jumpTo * frames]);
			var phase = Phasor.ar(jump + chewT, motor * wobble * BufRateScale.kr(buf), s0, e0, resetPos);
			var sig = BufRd.ar(nch, buf, phase, 1, 4);
			LocalOut.kr(A2K.kr(phase));
			if (nch == 1) { sig = sig ! 2 };
			sig = sig * (1 - (Trig1.kr(Dust.kr(chew * 3), TRand.kr(0.02, 0.2, Dust.kr(chew * 3))) * chew.min(1)).lag(0.004));
			sig = SelectX.ar((drive > 0.01).lag(0.05), [sig, (sig * (1 + (drive * 8))).tanh / (1 + drive)]);
			sig = LPF.ar(sig, age.linexp(0, 1, 19000, 1200)) + (PinkNoise.ar(hiss ! 2) * 0.15);
			SendReply.kr(Impulse.kr(25), '/uDeck', [A2K.kr(phase) / frames, motor * wobble], id);
			Out.ar(out, LeakDC.ar(sig) * env * 0.8);
		}).add;
	};
});

OSCdef(\uDeck, { |msg|
	var t = ~meterIds[msg[2].asInteger];
	if (t.notNil) { t[\head] = msg[3]; t[\motor] = msg[4] };
}, '/uDeck');

~deckArgs = { |t|
	[out: t[\bus], buf: t[\deckBuf], gate: (~running == true).binaryValue, id: t[\id]]
	++ [\rate, \semis, \inertia, \start, \end, \wow, \flutter, \chew, \drive, \age, \hiss].collect { |k| [k, t[k]] }.flatten
};

~deckSynth = { |t|
	var b = t[\deckBuf];
	if (b.notNil and: { t[\src].notNil }) {
		t[\voice] !? { |v| v.free };
		t[\voice] = Synth.head(t[\src], ("uDeck" ++ b.numChannels.clip(1, 2)).asSymbol, ~deckArgs.(t));
	};
};

// Load a file onto the deck (the old tape is freed a bit later, in case it's still playing).
~deckLoad = { |t, path|
	if (path.notNil and: { File.exists(path) }) {
		t[\loading] = path;
		Buffer.read(s, path, action: { |b|
			{
				var old = t[\deckBuf];
				if (t[\loading] == path) {
					t[\deckBuf] = b;
					t[\path] = path;
					t[\loadedPath] = path;
					~deckSynth.(t);
					old !? { |o| { o.free }.defer(3) };
				} { b.free };
			}.defer;
		});
	} { "unsound: deck: no file %".format(path).warn };
};

~deckJump = { |t, pos| t[\voice] !? { |v| v.set(\jumpTo, pos.clip(0, 1), \jump, 1) } };

// Change the motor for a while without touching your setting, then go back.
~deckFor = { |t, rate, beats|
	Routine({
		t[\voice] !? { |v| v.set(\rate, rate) };
		~vwait.(t, beats);
		t[\voice] !? { |v| v.set(\rate, t[\rate]) };
	}).play(~clock);
};

~voiceTypes[\deck] = (
	color: Color(0.85, 0.7, 0.5),
	chain: [[\drive, (mode: 1, gain: 2, mix: 0.3)]],
	defaults: (level: 0.6, wander: 0.1, sends: [0.15, 0.1, 0, 0],
		rate: 1, semis: 0, inertia: 0.3, start: 0, end: 1, wow: 0.15, flutter: 0.1, chew: 0, drive: 0, age: 0.1, hiss: 0),
	init: { |t| t[\path] = ~bufs.choose !? { |b| b.path } },
	build: { |t|
		if (t[\deckBuf].notNil) { ~deckSynth.(t) } { ~deckLoad.(t, t[\path]) };
	},
	free: { |t| t[\deckBuf] !? { |b| { b.free }.defer(3) } },
	onSet: { |t, key, val|
		if (key == \path and: { val != t[\loadedPath] }) { ~deckLoad.(t, val) };
	},
	repatch: { |t| ~bufs.choose !? { |b| ~deckLoad.(t, b.path) } },
	key: { |t, midi|
		~tset.(t[\name], \semis, midi - 60);
		~deckJump.(t, t[\start]);
	},
	sometimes: [
		[\soSkip, "skip", { |t| ~deckJump.(t, rrand(t[\start], t[\end])) }, 0.1],
		[\soStop, "tape stop", { |t| ~deckFor.(t, 0, [1, 2, 4].choose) }, 0.03],
		[\soRev, "reverse", { |t| ~deckFor.(t, t[\rate].neg, [1, 2, 4].choose) }, 0.04]
	],
	pages: { |t| [
		~pg.(t, "tape", [[\rate, [-8, 8], "speed"], [\semis, [-24, 24, \lin, 1]], [\inertia, [0, 6, 4], "inertia"],
			[\start, [0, 1]], [\end, [0, 1]], [\wow, [0, 1]], [\flutter, [0, 1]], [\chew, [0, 1]]]),
		~pg.(t, "wear", [[\drive, [0, 1]], [\age, [0, 1]], [\hiss, [0, 1]]])
	] },
	mover: { |t| loop { ~vwait.(t, 4) } },
	clip: { |t| ~deckClip.(t) },
	screen: { |t| ~deckScreen.(t) },
	device: { |t|
		[~panel.("deck", t[\color], VLayout(
			~row.(~tknob.(t, \rate, [-8, 8], "speed"), ~tknob.(t, \semis, [-24, 24, \lin, 1]), ~tknob.(t, \inertia, [0, 6, 4])),
			~row.(~tknob.(t, \wow, [0, 1]), ~tknob.(t, \flutter, [0, 1]), ~tknob.(t, \chew, [0, 1])),
			~row.(~tknob.(t, \drive, [0, 1]), ~tknob.(t, \age, [0, 1]), ~tknob.(t, \hiss, [0, 1])),
			~soRow.(t)
		))]
	}
);

// ---------------------------------------------------------------- the deck's screen

~reelView = { |t, size = 150|
	var view = UserView().fixedSize_(Size(size, size)).canFocus_(false), angle = 0;
	view.drawFunc = { |uv|
		var k = size / 150, c = Point(75, 75) * k, full = (66 - ((t[\head] ? 0) * 30)) * k;
		Pen.fillColor = Color.grey(0.16);
		Pen.fillOval(Rect.aboutPoint(c, 70 * k, 70 * k));
		Pen.fillColor = Color.grey(0.07);
		Pen.fillOval(Rect.aboutPoint(c, full, full));
		Pen.strokeColor = t[\color];
		Pen.width = 6 * k;
		3.do { |i|
			var a = angle + (i * 2pi / 3);
			Pen.line(c + (Point(a.cos, a.sin) * 12 * k), c + (Point(a.cos, a.sin) * 30 * k));
		};
		Pen.stroke;
		Pen.fillColor = Color.grey(0.8);
		Pen.fillOval(Rect.aboutPoint(c, 8 * k, 8 * k));
		Pen.stringCenteredIn(((t[\motor] ? 0).round(0.01)).asString ++ "x", Rect(0, size - 18, size, 16), Font.monospace(9), Color.grey(0.7));
	};
	~animated.add({
		if (view.isClosed) { false } { angle = angle + ((t[\motor] ? 0) * 0.35); view.refresh; true }
	});
	view
};

~deckWave = { |t|
	var sfv = SoundFileView().canFocus_(false).gridOn_(false).timeCursorOn_(true).timeCursorColor_(Color.white)
		.waveColors_([t[\color], t[\color]]).background_(Color.grey(0.08)).minHeight_(140)
		.setSelectionColor(0, Color(1, 1, 1, 0.12));
	var shown, frames = 1;
	var load = {
		var sf = t[\path] !? { |p| SoundFile.openRead(p) };
		shown = t[\path];
		if (sf.notNil) {
			frames = sf.numFrames.max(1);
			sfv.readFile(sf, 0, sf.numFrames.min(sf.sampleRate * 600), 64, true);
			sfv.setSelection(0, [t[\start] * frames, (t[\end] - t[\start]) * frames]);
		};
	};
	sfv.mouseUpAction = {
		var sel = sfv.selection(0);
		if (sel[1] > (frames * 0.01)) {
			~tset.(t[\name], \start, sel[0] / frames);
			~tset.(t[\name], \end, (sel[0] + sel[1]) / frames);
		} {
			~deckJump.(t, sel[0] / frames);
			sfv.setSelection(0, [t[\start] * frames, (t[\end] - t[\start]) * frames]);
		};
	};
	~animated.add({
		if (sfv.isClosed) { false } {
			if (shown != t[\path]) { load.() };
			sfv.timeCursorPosition = (t[\head] ? 0) * frames;
			true
		}
	});
	load.();
	sfv
};

~deckScreen = { |t|
	var name = StaticText().stringColor_(Color.grey(0.8)).font_(Font.monospace(9));
	~bindings.add({ if (name.isClosed) { false } { name.string = t[\path] !? { |p| PathName(p).fileName } ? "(no tape)"; true } });
	VLayout(
		~row.(~deckButtons.(t), name),
		HLayout(VLayout(~reelView.(t, 80), nil), [~deckWave.(t).minHeight_(60), stretch: 1])
	).spacing_(2)
};

~deckButtons = { |t|
	HLayout(
		~button.("open…", { Dialog.openPanel({ |p| ~deckLoad.(t, p) }) }),
		~button.("from folder", { ~repatch.(t[\name]) }),
		~toggle.("stop", { t[\rate].abs < 0.001 }, { |x|
			if (x) { t[\lastRate] = t[\rate]; ~tset.(t[\name], \rate, 0) } { ~tset.(t[\name], \rate, t[\lastRate] ? 1) };
		}, Color(1, 0.4, 0.3)),
		~button.("spin back", { ~deckFor.(t, -6, 0.5) }),
		~button.("reverse", { ~tset.(t[\name], \rate, t[\rate].neg) }),
		~button.("1x", { ~tset.(t[\name], \rate, 1); ~tset.(t[\name], \semis, 0) }),
		~button.("whole tape", { ~tset.(t[\name], \start, 0); ~tset.(t[\name], \end, 1) })
	).spacing_(2)
};

~deckClip = { |t|
	var name = StaticText().stringColor_(Color.grey(0.8)).font_(Font.monospace(10));
	~bindings.add({ if (name.isClosed) { false } { name.string = t[\path] !? { |p| PathName(p).fileName } ? "(no tape)"; true } });
	VLayout(
		~row.(~deckButtons.(t), name),
		HLayout(
			VLayout(~reelView.(t), nil),
			[~deckWave.(t), stretch: 1]
		),
		~row.(~tknob.(t, \rate, [-8, 8], "speed", 50), ~tknob.(t, \semis, [-24, 24, \lin, 1], "semis", 50),
			~tknob.(t, \inertia, [0, 6, 4], "inertia", 50), ~tknob.(t, \wow, [0, 1], "wow", 50),
			~tknob.(t, \flutter, [0, 1], "flutter", 50), ~tknob.(t, \chew, [0, 1], "chew", 50),
			~tknob.(t, \drive, [0, 1], "drive", 50), ~tknob.(t, \age, [0, 1], "age", 50), ~tknob.(t, \hiss, [0, 1], "hiss", 50)),
		~soRow.(t),
		~lbl.("click the waveform to move the playhead · drag to pick the loop · it loops forever")
	)
};
