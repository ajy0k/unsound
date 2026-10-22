// The wall: a background noise layer, always there to swap in and out. Not an instrument track:
// one per set, and dice / glide leave it alone (it's yours to shape). It does respect solo. Under the
// hood it's a track of kind \wall, so it has a strip, sends, a meter and an effect chain like any
// other (it starts with `band`, the lows/highs shaper, and a hard digital drive).
//
//   pick    which recipe is playing; changing it crossfades to the new one over `swap` seconds
//   in      fade the wall in or out (over `swap` seconds)
//   dens    density / rate / clock, whatever the recipe takes it to mean
//   grit    how broken
//   motion  how much it moves by itself
//
// To add a recipe: add a line to ~wallTypes and reload. { |dens, grit, motion| stereo signal }.

~wallTypes = [
	["static", { |d, g, m|
		Latch.ar(WhiteNoise.ar ! 2, Impulse.ar(d.linexp(0, 1, 300, 44100))).round(g.linexp(0, 1, 0.001, 0.6))
	}],
	["bitwall", { |d, g, m|
		var t = PulseCount.ar(Impulse.ar(d.linexp(0, 1, 1500, 44100))), a = (3 + (g * 9)).round;
		[(t * ((t >> 5) | (t >> a))) & 255, (t * ((t >> 4) | (t >> (a + 1)))) & 255] / 127.5 - 1
	}],
	["crackle", { |d, g, m| (PinkNoise.ar(0.5 ! 2) + (Dust2.ar(d.linexp(0, 1, 30, 8000) ! 2) * (1 + (g * 4)))).clip2(1) }],
	["bit rain", { |d, g, m|
		{ Mix.fill(6, { |i| LFClipNoise.ar(d.linexp(0, 1, 40, 20000) * (2 ** i.neg)) * (2 ** i.neg) }) } ! 2
		* (1 + (g * 3))
	}],
	["spectral", { |d, g, m|
		{ |i|
			var c = FFT(LocalBuf(1024), WhiteNoise.ar);
			c = PV_RandComb(c, g * 0.95, Impulse.kr(d.linexp(0, 1, 0.5, 40)));
			c = PV_MagFreeze(c, LFPulse.kr(0.2 + (m * 4), i * 0.5));
			IFFT(c) * 2
		} ! 2
	}],
	["scream", { |d, g, m|
		var loop = LocalIn.ar(2) + (WhiteNoise.ar(0.001 ! 2));
		var x = DelayC.ar(loop, 0.2, d.linexp(0, 1, 0.15, 0.0005) * [1, 1.13]);
		x = BPF.ar(x, d.linexp(0, 1, 200, 6000), 0.3) * 4;
		x = (x * (2 + (g * 30))).clip2(1);
		LocalOut.ar(LeakDC.ar(x.reverse) * 0.98);
		x
	}],
	["mains", { |d, g, m|
		var f = [50, 60] * d.linexp(0, 1, 0.5, 4);
		var x = Mix(Pulse.ar(f.collect { |b| b * (1..6) }.flop, 0.1, 0.3));
		Latch.ar((x * (1 + (g * 10))).clip2(1), Impulse.ar(g.linexp(0, 1, 44100, 2000)))
	}]
];

~defs.add({
	~wallTypes.do { |w, i|
		SynthDef(("uWall" ++ i).asSymbol, { |out, gate = 0, alive = 1, swap = 2, dens = 0.5, grit = 0.3, motion = 0.3|
			var fade = EnvGen.kr(Env.asr(swap, 1, swap), gate) * EnvGen.kr(Env.asr(0, 1, swap), alive, doneAction: 2);
			var wob = { |x, r| (x + (LFNoise2.kr(r * (0.1 + (motion * 2))) * motion * 0.3)).clip(0, 1) };
			var sig = w[1].value(wob.(dens.lag(0.1), 1), wob.(grit.lag(0.1), 1.3), motion);
			Out.ar(out, LeakDC.ar(sig).clip2(1) * fade * 0.45);
		}).add;
	};
});

~wallKeys = [\swap, \dens, \grit, \motion];

~wallList = { if (~tracks[\wall].notNil) { [\wall] } { [] } };

// Start the current recipe (on build, or crossfading from whatever was playing).
~wallStart = { |t|
	var old = t[\voice], playing = (~running == true and: { t[\in] }).binaryValue;
	t[\playing] = t[\pick].round.asInteger.clip(0, ~wallTypes.size - 1);
	t[\voice] = Synth.head(t[\src], ("uWall" ++ t[\playing]).asSymbol,
		[out: t[\bus], gate: playing] ++ ~wallKeys.collect { |k| [k, t[k]] }.flatten);
	old !? { |o| o.set(\swap, t[\swap], \alive, 0) };
};

~wallPick = { |i|
	var t = ~tracks[\wall];
	if (t.notNil) { t[\pick] = i.clip(0, ~wallTypes.size - 1); ~wallStart.(t) };
};

~wallIn = { |on|
	var t = ~tracks[\wall];
	if (t.notNil) {
		t[\in] = on;
		t[\voice] !? { |v| v.set(\swap, t[\swap], \gate, (on and: { ~running == true }).binaryValue) };
	};
};

~makeWall = {
	var t = ~newTrack.(\wall, \wall);
	t.putAll((level: 0.5, color: Color(0.55, 0.6, 0.7), pick: 1, in: true, swap: 2, dens: 0.5, grit: 0.3, motion: 0.3));
	t[\sends][0] = 0.1;
	t[\bus] = Bus.audio(s, 2);
	~tracks[\wall] = t;
	~buildTrack.(t);
	~dev.(\wall, \band, nil, (lows: 60, highs: 9000));
	~dev.(\wall, \drive, nil, (mode: 2, gain: 3, mix: 0.6), "hard clip");
	t
};

// ---------------------------------------------------------------- the wall's screen

// One button per recipe (click = crossfade to it), in/out, and its knobs. The band shaper and
// the rest of the wall's chain are in the chain below, like any track.
~wallScreen = { |t|
	var picks = ~wallTypes.collect { |w, i|
		var b = Button().canFocus_(false).minHeight_(30);
		var show = { b.states = [[w[0], if (t[\playing] == i) { Color.black } { Color.grey(0.85) },
			if (t[\playing] == i) { t[\color] } { Color.grey(0.2) }]] };
		var last;
		show.();
		b.action = { ~tset.(\wall, \pick, i) };
		~bindings.add({ if (b.isClosed) { false } { if (last != t[\playing]) { last = t[\playing]; show.() }; true } });
		b
	};
	VLayout(
		HLayout(*(picks ++ [nil])).spacing_(2),
		~row.(
			~toggle.("  wall in  ", { t[\in] }, { |x| ~tset.(\wall, \in, x) }, t[\color]),
			~tknob.(t, \swap, [0, 30, 4], "swap secs", 34),
			~tknob.(t, \dens, [0, 1], "dens", 34),
			~tknob.(t, \grit, [0, 1], "grit", 34),
			~tknob.(t, \motion, [0, 1], "motion", 34),
			~tknob.(t, \level, ~levelSpec, "level", 34),
			~lbl.("click a wall to crossfade to it · double-click the wall pad = in / out")
		),
		nil
	).spacing_(4)
};
