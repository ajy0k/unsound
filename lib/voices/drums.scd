// Drums: eight lanes, each its own little sequencer.
//   - every lane has its own length (polymeter: right-click a cell to end the lane there)
//   - patterns come from generators (styles), or you click them in
//   - mutation plays a variation (outline = added, dot = removed) and drifts back to yours
//   - each lane is a synthesized drum, an FM drum, or a sample: from the folder, a file you load
//     for that lane, or a random slice of one long sample loaded for the whole kit (slices start at
//     onsets). `hop` is the chance a sampled lane picks a new slice each time round
//   - every so often: a fill (one lane rolls), a variation (one lane scrambles, then drifts home)
// Keys / MIDI: white keys play lanes in order; GM drum notes (36 kick, 38 snare, 42 hat…) work too.

~drumNames = [\kick, \snare, \hat, \open, \clap, \rim, \perc, \glitch];

~defs.add({
	var out = { |sig, amp, pan| OffsetOut.ar(\out.kr(0), Pan2.ar(sig * amp, pan)) };
	SynthDef(\dr_kick, { |amp = 0.8, pitch = 0, decay = 1, tone = 0.5, pan = 0|
		var f = 48 * pitch.midiratio;
		var sig = SinOsc.ar(f * (1 + (5 * EnvGen.ar(Env.perc(0.0005, 0.05, curve: -6)))), 0.5pi);
		sig = sig * EnvGen.ar(Env.perc(0.001, 0.45 * decay, curve: -4), doneAction: 2);
		sig = sig + (HPF.ar(WhiteNoise.ar, 3000) * EnvGen.ar(Env.perc(0.0005, 0.006)) * tone);
		out.((sig * (1 + (tone * 4))).tanh, amp, pan);
	}).add;
	SynthDef(\dr_snare, { |amp = 0.6, pitch = 0, decay = 1, tone = 0.5, pan = 0|
		var body = SinOsc.ar(185 * pitch.midiratio) * EnvGen.ar(Env.perc(0.001, 0.08 * decay));
		var noise = BPF.ar(WhiteNoise.ar, tone.linexp(0, 1, 1500, 9000), 0.9) * EnvGen.ar(Env.perc(0.001, 0.2 * decay), doneAction: 2);
		out.((body * 0.6) + (noise * 1.6), amp, pan);
	}).add;
	SynthDef(\dr_hat, { |amp = 0.4, pitch = 0, decay = 1, tone = 0.5, pan = 0|
		var metal = Mix(Pulse.ar([205.3, 304.4, 369.6, 522.7, 540, 800] * pitch.midiratio)) * 0.2;
		var sig = HPF.ar(metal + WhiteNoise.ar(0.5), tone.linexp(0, 1, 4000, 12000));
		out.(sig * EnvGen.ar(Env.perc(0.001, 0.05 * decay, curve: -6), doneAction: 2), amp, pan);
	}).add;
	SynthDef(\dr_open, { |amp = 0.35, pitch = 0, decay = 1, tone = 0.5, pan = 0|
		var metal = Mix(Pulse.ar([205.3, 304.4, 369.6, 522.7, 540, 800] * pitch.midiratio)) * 0.2;
		var sig = HPF.ar(metal + WhiteNoise.ar(0.5), tone.linexp(0, 1, 3000, 10000));
		out.(sig * EnvGen.ar(Env.perc(0.002, 0.4 * decay, curve: -3), doneAction: 2), amp, pan);
	}).add;
	SynthDef(\dr_clap, { |amp = 0.6, pitch = 0, decay = 1, tone = 0.5, pan = 0|
		var env = EnvGen.ar(Env([0, 1, 0.2, 1, 0.2, 1, 0], [0.001, 0.01, 0.001, 0.01, 0.001, 0.25 * decay], -4), doneAction: 2);
		out.(BPF.ar(WhiteNoise.ar, tone.linexp(0, 1, 700, 3000) * pitch.midiratio, 0.6) * env * 2, amp, pan);
	}).add;
	SynthDef(\dr_rim, { |amp = 0.5, pitch = 0, decay = 1, tone = 0.5, pan = 0|
		var sig = SinOsc.ar(1700 * pitch.midiratio) + (BPF.ar(WhiteNoise.ar, 4000 * pitch.midiratio) * tone * 2);
		out.(sig * EnvGen.ar(Env.perc(0.0005, 0.03 * decay), doneAction: 2), amp, pan);
	}).add;
	SynthDef(\dr_perc, { |amp = 0.5, pitch = 0, decay = 1, tone = 0.5, pan = 0|
		var f = 320 * pitch.midiratio, env = EnvGen.ar(Env.perc(0.001, 0.15 * decay), doneAction: 2);
		out.(SinOsc.ar(f, SinOsc.ar(f * 1.41) * tone * 6 * env) * env, amp, pan);
	}).add;
	// FM drum: a sine carrier with a pitch sweep, a sine modulator at `ratio`, and a bit of noise.
	// `tone` is the FM index.
	SynthDef(\dr_fm, { |amp = 0.6, pitch = 0, decay = 1, tone = 0.5, pan = 0, base = 100, ratio = 1.5, sweep = 2, len = 0.3, noise = 0|
		var env = EnvGen.ar(Env.perc(0.001, len * decay, curve: -5), doneAction: 2);
		var ienv = EnvGen.ar(Env.perc(0.0005, len * decay * 0.5));
		var f = base * pitch.midiratio * (1 + (sweep * EnvGen.ar(Env.perc(0.0005, 0.04))));
		var sig = SinOsc.ar(f, SinOsc.ar(f * ratio) * tone * 10 * ienv) + (HPF.ar(WhiteNoise.ar, 2000) * noise * ienv);
		out.((sig * 1.2).tanh * env, amp, pan);
	}).add;
	SynthDef(\dr_glitch, { |amp = 0.4, pitch = 0, decay = 1, tone = 0.5, pan = 0|
		var sig = Latch.ar(WhiteNoise.ar + SinOsc.ar(Rand(80, 2000) * pitch.midiratio), Impulse.ar(tone.linexp(0, 1, 300, 12000)));
		out.(sig.round(0.25) * EnvGen.ar(Env.perc(0.0005, Rand(0.01, 0.12) * decay), doneAction: 2), amp, pan);
	}).add;
});

// Per lane: FM drum voicing [base Hz, pitch sweep, length s, noise], default FM ratio, slice length (s).
~fmDrum = [[50, 4, 0.4, 0], [180, 1, 0.18, 0.6], [2500, 0, 0.05, 0.3], [2300, 0, 0.35, 0.3],
	[900, 0.5, 0.15, 0.5], [1100, 0.3, 0.03, 0.1], [350, 1, 0.15, 0], [700, 8, 0.08, 0.2]];
~fmRatios = [1, 1.6, 3.73, 3.3, 2.7, 2.4, 1.41, 7.1];
~sliceLens = [0.35, 0.2, 0.06, 0.3, 0.15, 0.05, 0.15, 0.1];
~laneSources = [\synth, \fm, \sample];

~newLane = { |name|
	var i = ~drumNames.indexOf(name) ? 0;
	(name: name, index: i, src: \synth, pat: 0 ! 32, live: 0 ! 32, len: 16, level: 0.8, pitch: 0, decay: 1, tone: 0.5,
		ratio: ~fmRatios[i], pan: 0, mutate: 0.2, busy: 0.4, chance: 1, ratchet: 0.05, mute: false, hop: 0)
};

~euclid = { |k, n, rot = 0| Array.fill(n, { |i| ((((i + rot) * k) % n) < k).binaryValue }) };

~setLane = { |ln, len, hits|
	var pat = 0 ! 32;
	hits.do { |h, i| if (i < 32) { pat[i] = h } };
	ln[\len] = len;
	ln[\pat] = pat;
	ln[\live] = pat.copy;
};

// Pattern generators. Each fills one lane (index i) in a style.
~drumStyles = [\four, \broken, \euclid, \sparse, \chaos];
~genLane = { |ln, i, style|
	var r = { |n, p| Array.fill(n, { p.coin.binaryValue }) };
	switch (style)
	{ \four } {
		~setLane.(ln, 16, [
			~euclid.(4, 16), [0, 0, 0, 0, 1, 0, 0, 0] ! 2, [1, 0] ! 8, [0, 0, 1, 0] ! 4,
			[0, 0, 0, 0, 0.5.coin.binaryValue, 0, 0, 0] ! 2, r.(16, 0.08), r.(16, 0.12), r.(16, 0.06)
		][i].flat);
	}
	{ \broken } {
		~setLane.(ln, 16, [
			[1, 0, 0, 0.4.coin.binaryValue, 0, 0, 0.6.coin.binaryValue, 0, 0, 0.5.coin.binaryValue, 1, 0, 0, 0, 0.3.coin.binaryValue, 0],
			[0, 0, 0, 0, 1, 0, 0, 0.2.coin.binaryValue, 0, 0.15.coin.binaryValue, 0, 0, 1, 0, 0, 0.3.coin.binaryValue],
			r.(16, 0.7), r.(16, 0.15), r.(16, 0.1), r.(16, 0.2), r.(16, 0.2), r.(16, 0.15)
		][i]);
	}
	{ \euclid } {
		var n = [16, 12, 16, 10, 7, 9, 11, 13].choose;
		~setLane.(ln, n, ~euclid.(rrand(1, (n * 0.6).asInteger.max(1)), n, n.rand));
	}
	{ \sparse } {
		var n = [16, 24, 32].choose;
		~setLane.(ln, n, r.(n, [0.12, 0.06, 0.15, 0.04, 0.05, 0.08, 0.1, 0.08][i]));
	}
	{ \chaos } {
		var n = rrand(5, 32);
		~setLane.(ln, n, r.(n, rrand(0.05, 0.6)));
	};
};

~genKit = { |t, style|
	style = style ?? { ~drumStyles.choose };
	t[\style] = style;
	t[\lanes].do { |ln, i| ~genLane.(ln, i, style) };
};

// Mutation: lane plays `live`, a variation of `pat` that drifts home. `busy` sets the hit density
// mutation aims for.
~mutateLane = { |ln, t|
	var c = ~m[\chaos], live = ln[\live], n = ln[\len], target = (ln[\busy] * n * 0.5).round.asInteger.max(1);
	if ((ln[\mutate] * (0.5 + c)).coin) {
		((ln[\mutate] + c * 2).rand.round.asInteger + 1).do {
			var on = (0 .. n - 1).select { |i| live[i] == 1 };
			var off = (0 .. n - 1).select { |i| live[i] == 0 };
			case
			{ on.size < target and: { off.notEmpty } } { live[off.choose] = 1 }
			{ on.size > target and: { on.notEmpty } } { live[on.choose] = 0 }
			{ on.notEmpty and: { off.notEmpty } } { live[on.choose] = 0; live[off.choose] = 1 };
		};
	} {
		if ((1 - ln[\mutate]).coin) { ln[\live] = ln[\pat].copy };
	};
	if (ln[\src] == \sample and: { ln[\hop].coin }) { ln[\grain] = ~pickDrumGrain.(t, ln) };
};

// A sound for a sampled lane: a slice of the lane's own file, or of the kit's long sample, or a
// short grain from the folder.
~pickDrumGrain = { |t, ln|
	var slab = (ln !? { ln[\slab] }) ?? { t !? { t[\slab] } }, short;
	if (slab.notNil) { ~sliceSlab.(slab, ln !? { ln[\index] } ? 0) } {
		short = ~grains.select { |g| g[2] / g[3] < 0.5 };
		(if (short.notEmpty) { short } { ~grains }).choose
	}
};

// A loaded file, with a list of onsets (where the loudness jumps) to start slices from.
~loadSlab = { |path, done|
	var sf = SoundFile.openRead(path), sr, nch, frames, data, block = 1024, rms, peak, starts = List[];
	if (sf.isNil) { "unsound: can't read %".format(path).warn } {
		sr = sf.sampleRate;
		nch = sf.numChannels;
		frames = sf.numFrames.min((sr * 90).asInteger);
		data = FloatArray.newClear(frames * nch);
		sf.readData(data);
		sf.close;
		rms = (frames div: block).collect { |b|
			var sum = 0;
			32.do { |k| sum = sum + data[((b * block) + (k * 32)) * nch].squared };
			(sum / 32).sqrt
		};
		peak = rms.maxItem ? 0;
		rms.doAdjacentPairs { |a, b, i| if (b > (a * 2) and: { b > (peak * 0.08) }) { starts.add((i + 1) * block) } };
		Buffer.readChannel(s, path, 0, frames, [0], { |buf|
			{ done.((path: path, buf: buf, starts: starts.asArray, sr: sr, frames: frames)) }.defer
		});
	};
};

~sliceSlab = { |slab, i|
	var len = (~sliceLens.clipAt(i) * slab[\sr] * rrand(0.7, 1.4)).asInteger, start;
	if (slab[\frames] < (slab[\sr] * 2)) {
		[slab[\buf], 0, slab[\frames], slab[\sr], 1]   // a short file: the whole thing
	} {
		start = if (slab[\starts].notEmpty and: { 0.85.coin }) { slab[\starts].choose } { (slab[\frames] - len).max(0).rand };
		[slab[\buf], start, len.min(slab[\frames] - start).max(64), slab[\sr], 1]
	}
};

// Load a file for one lane (or, with ln = nil, the kit's long sample).
~drumLoad = { |t, ln, path|
	~loadSlab.(path, { |slab|
		var old;
		if (ln.notNil) {
			old = ln[\slab]; ln[\slab] = slab; ln[\file] = path; ln[\src] = \sample; ln[\grain] = ~pickDrumGrain.(t, ln);
		} {
			old = t[\slab]; t[\slab] = slab; t[\slabPath] = path;
			t[\lanes].do { |x| if (x[\slab].isNil) { x[\src] = \sample; x[\grain] = ~pickDrumGrain.(t, x) } };
		};
		old !? { |o| { o[\buf].free }.defer(5) };
	});
};

~drumFill = { |t|
	var ln = t[\lanes].reject { |x| x[\mute] }.choose, n = [3, 4, 6, 8].choose;
	ln !? { Routine({ n.do { |k| ~drumHit.(t, ln, 0.5 + (k / n * 0.5)); ~vwait.(t, 1 / n) } }).play(~clock) };
};

~drumVary = { |t|
	var ln = t[\lanes].choose;
	ln[\len].do { |i| if (0.3.coin) { ln[\live][i] = 1 - ln[\live][i] } };
};

~drumHit = { |t, ln, amp = 1|
	var c = ~m[\chaos], g;
	var fm = ~fmDrum[ln[\index] ? 0];
	s.bind {
		case
		{ ln[\src] == \fm } {
			Synth(\dr_fm, [out: t[\bus], amp: amp * ln[\level], pitch: ln[\pitch] + (c * t[\drift] * 2.0.rand2), decay: ln[\decay],
				tone: ln[\tone], pan: ln[\pan], ratio: ln[\ratio], base: fm[0], sweep: fm[1], len: fm[2], noise: fm[3]], t[\src]);
		}
		{ ln[\src] == \sample and: { (g = ln[\grain]).notNil } } {
			Synth(\uGrain, [out: t[\bus], buf: g[0], start: g[1], dur: (g[2] / g[3] * ln[\decay]).clip(0.01, 1.5),
				rate: ln[\pitch].midiratio, amp: amp * ln[\level] * 2, pan: ln[\pan], atk: 0.0005, rel: 0.02], t[\src]);
		} {
			Synth(("dr_" ++ ln[\name]).asSymbol, [out: t[\bus], amp: amp * ln[\level],
				pitch: ln[\pitch] + (c * t[\drift] * 2.0.rand2), decay: ln[\decay], tone: ln[\tone], pan: ln[\pan]], t[\src]);
		};
	};
	ln[\flash] = 1;
};

~drumGM = Dictionary[35 -> 0, 36 -> 0, 38 -> 1, 40 -> 1, 42 -> 2, 44 -> 2, 46 -> 3, 39 -> 4, 37 -> 5, 45 -> 6, 47 -> 6, 49 -> 7, 51 -> 7];

~voiceTypes[\drums] = (
	color: Color(1, 0.45, 0.45),
	chain: [[\drive, (mode: 1, gain: 2.5, mix: 0.5)]],
	defaults: (level: 0.85, wander: 0, swing: 0, drift: 0.2),
	init: { |t|
		t[\lanes] = ~drumNames.collect { |n| ~newLane.(n) };
		~genKit.(t, \four);
	},
	repatch: { |t| t[\lanes].do { |ln| ln[\grain] = ~pickDrumGrain.(t, ln) } },
	dice: { |t|
		~genKit.(t);
		t[\lanes].do { |ln|
			ln[\pitch] = 6.rand2; ln[\decay] = exprand(0.4, 2); ln[\tone] = 1.0.rand; ln[\ratio] = exprand(0.5, 8);
			ln[\src] = [\synth, \fm, \sample].wchoose([0.4, 0.35, 0.25]);
			if (ln[\src] == \sample) { ln[\grain] = ~pickDrumGrain.(t, ln) };
		};
	},
	// after a set or scene is loaded: reload any files it names
	restored: { |t|
		t[\slabPath] !? { |p| if (t[\slab].isNil or: { t[\slab][\path] != p }) { ~drumLoad.(t, nil, p) } };
		t[\lanes].do { |ln|
			ln[\file] !? { |p| if (ln[\slab].isNil or: { ln[\slab][\path] != p }) { ~drumLoad.(t, ln, p) } };
			if (ln[\src] == \sample and: { ln[\grain].isNil }) { ln[\grain] = ~pickDrumGrain.(t, ln) };
		};
	},
	sometimes: [
		[\soFill, "fill", { |t| ~drumFill.(t) }, 0.08],
		[\soVary, "vary", { |t| ~drumVary.(t) }, 0.05]
	],
	pages: { |t|
		[\level, \pitch, \decay, \tone, \ratio, \mutate, \chance, \hop].collect { |k|
			(name: k.asString, targets: t[\lanes].collect { |ln, i|
				(tid: "l:%:%:%".format(t[\name], i, k), name: "% %".format(ln[\name], k), spec: ~laneSpecs[k],
					get: { ln[k] }, set: { |x| ln[k] = x })
			})
		}
	},
	key: { |t, midi|
		var w = [0, 2, 4, 5, 7, 9, 11].indexOf(midi % 12);
		var i = ~drumGM[midi] ?? { w !? { (w + ((midi div: 12) * 7)) % 8 } } ?? { 7 };
		~drumHit.(t, t[\lanes][i]);
	},
	targets: { |t|
		t[\lanes].collect { |ln, i|
			[\level, \pitch, \decay, \tone, \ratio, \mutate, \busy, \chance, \hop].collect { |k|
				var spec = ~laneSpecs[k];
				(tid: "l:%:%:%".format(t[\name], i, k), name: "% % %".format(t[\name], ln[\name], k), spec: spec,
					get: { ln[k] }, set: { |x| ln[k] = x })
			}
		}.flatten(1)
	},
	mover: { |t|
		var step = 0, dur, n;
		loop {
			dur = 0.25 * (1 + (t[\swing] * (if (step.even) { 1 } { -1 })));
			t[\lanes].do { |ln|
				var s = step % ln[\len];
				if (s == 0) { ~mutateLane.(ln, t) };
				ln[\pos] = s;
				if (ln[\mute].not and: { ln[\live][s] == 1 } and: { ln[\chance].coin }) {
					n = if ((ln[\ratchet] * (0.5 + ~m[\chaos])).coin) { rrand(2, 4) } { 1 };
					if (n == 1) { ~drumHit.(t, ln) } {
						Routine({ n.do { |k| ~drumHit.(t, ln, 1 - (k / n * 0.5)); ~vwait.(t, dur / n) } }).play(~clock);
					};
				};
			};
			~vwait.(t, dur);
			step = step + 1;
		}
	},
	clip: { |t| ~drumClip.(t) },
	device: { |t|
		[~panel.("drums", t[\color], VLayout(
			~row.(~tknob.(t, \swing, [0, 0.4]), ~tknob.(t, \drift, [0, 1], "pitch drift")),
			~lbl.("lane sounds and patterns are in the clip view")
		))]
	}
);

~laneSpecs = (level: ControlSpec(0, 1.5, \amp), pitch: ControlSpec(-24, 24, \lin, 1), decay: ControlSpec(0.1, 4, \exp),
	tone: ControlSpec(0, 1), mutate: ControlSpec(0, 1), busy: ControlSpec(0, 1), chance: ControlSpec(0, 1),
	ratchet: ControlSpec(0, 1), pan: ControlSpec(-1, 1), hop: ControlSpec(0, 1), ratio: ControlSpec(0.25, 16, \exp));
