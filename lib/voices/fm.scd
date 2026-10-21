// FM: carrier and modulator use waveforms you draw (single cycles, stored as wavetables),
// plus a sine op2 modulating the modulator. Played from the piano roll or improvising.
// `drift` varies the index and ratio per note around your settings; chaos adds metallic hits.

~defs.add({
	SynthDef(\uFM, { |out, car, mod, freq = 220, ratio = 2, index = 3, idxDecay = 0.3, ratio2 = 1, index2 = 0,
		sustain = 0.3, atk = 0.005, rel = 0.2, amp = 0.15, cutoff = 12000, pan = 0|
		var env = EnvGen.ar(Env.linen(atk, sustain, rel, curve: -3), doneAction: 2);
		var idx = index * (EnvGen.ar(Env.perc(0.001, idxDecay, 1, -4)) * 0.8 + 0.2);
		var op2 = SinOsc.ar(freq * ratio2) * index2;
		var op1 = Osc.ar(mod, freq * ratio, op2) * idx;
		var sig = LPF.ar(Osc.ar(car, freq, op1), cutoff.clip(40, 18000));
		OffsetOut.ar(out, Pan2.ar(sig * env * amp, pan));
	}).add;
});

~shapes = (
	sine: { Array.fill(64, { |i| sin(2pi * i / 64) }) },
	tri: { Array.fill(64, { |i| var p = i / 64; case { p < 0.25 } { p * 4 } { p < 0.75 } { 2 - (p * 4) } { (p * 4) - 4 } }) },
	saw: { Array.fill(64, { |i| 1 - (i / 32) }) },
	square: { Array.fill(64, { |i| if (i < 32) { 1 } { -1 } }) },
	harmonics: {
		var amps = Array.fill(8, { |h| 1.0.rand / (h + 1) }), w;
		w = Array.fill(64, { |i| amps.sum { |a, h| a * sin(2pi * (h + 1) * i / 64) } });
		w / w.abs.maxItem.max(0.001)
	},
	noise: { Array.fill(64, { 1.0.rand2 }) }
);

~toWavetable = { |points| Signal.newFrom(points.resamp1(1024)).asWavetable };

~allocWave = { |points|
	var wt = ~toWavetable.(points).asArray;
	Buffer.alloc(s, 2048, 1, { |b| b.setnMsg(0, wt) })
};

~setWave = { |t, key, points|
	t[key] = points;
	t[if (key == \carWave) { \carBuf } { \modBuf }].setn(0, ~toWavetable.(points).asArray);
};

~ratios = [0.5, 1, 2, 3, 4, 1.5, 3.5, 7];

// `over` is an Event of synth args that replace the track's settings for this one note.
~fmNote = { |t, midi, beats, over|
	var d = t[\drift];
	var args = [out: t[\bus], car: t[\carBuf], mod: t[\modBuf], freq: (midi + t[\tune]).midicps,
		ratio: if ((d * 0.15).coin) { ~ratios.choose } { t[\ratio] },
		index: (t[\index] * (1 + 0.gauss(d * 0.4))).clip(0, 20),
		ratio2: t[\ratio2], index2: t[\index2], idxDecay: t[\idxDecay],
		sustain: ~beatSecs.(t, beats) * t[\gate], atk: t[\atk], rel: t[\rel],
		cutoff: t[\cutoff], pan: t[\spread] * 1.0.rand2];
	if (over.notNil) { over.keysValuesDo { |k, x| args = args ++ [k, x] } };
	s.bind { Synth(\uFM, args, t[\src]) };
	if ((~m[\chaos] * 0.15).coin and: { over.isNil }) {
		~fmNote.(t, midi + 24, 0.125, (ratio: rrand(1.1, 3.9), index: rrand(3, 8), idxDecay: 0.03));
	};
};

~voiceTypes[\fm] = (
	color: Color(0.62, 0.48, 0.95),
	chain: [[\drive, (mode: 2, gain: 3, mix: 0.4)]],
	key: { |t, midi| ~fmNote.(t, midi, 0.5) },
	defaults: (level: 0.45, busy: 0.5, wander: 0.2, root: 48, sends: [0.2, 0.3, 0.1, 0],
		play: \roll, ratio: 2, index: 2, idxDecay: 0.3, ratio2: 1, index2: 0,
		atk: 0.005, rel: 0.3, gate: 0.5, cutoff: 12000, tune: 0, octave: 0, spread: 0.4,
		repeats: 3, repChance: 0, mutate: 0.1),
	init: { |t|
		~melodicInit.(t);
		t[\carWave] = ~shapes[\sine].();
		t[\modWave] = ~shapes[\sine].();
		t[\carBuf] = ~allocWave.(t[\carWave]);
		t[\modBuf] = ~allocWave.(t[\modWave]);
		~voiceTypes[\fm][\repatch].value(t);
		~suggestRoll.(t);
	},
	free: { |t| t[\carBuf].free; t[\modBuf].free },
	repatch: { |t|
		t[\ratio] = ~ratios.choose;
		t[\ratio2] = ~ratios.choose;
		t[\index] = rrand(0.5, 4);
		t[\index2] = if (0.5.coin) { rrand(0.2, 2) } { 0 };
		t[\idxDecay] = exprand(0.05, 0.8);
	},
	note: ~fmNote,
	mover: { |t| ~melodicMover.(t, ~fmNote) },
	clip: { |t| ~rollPanel.(t) },
	device: { |t|
		[
			~panel.("waves", t[\color], HLayout(~waveEditor.(t, \carWave, "carrier"), ~waveEditor.(t, \modWave, "modulator")), 520),
			~panel.("operators", t[\color], VLayout(
				~row.(~tknob.(t, \ratio, [0.125, 16, \exp]), ~tknob.(t, \index, [0, 12]), ~tknob.(t, \idxDecay, [0.01, 2, \exp], "idx decay")),
				~row.(~tknob.(t, \ratio2, [0.125, 16, \exp], "op2 ratio"), ~tknob.(t, \index2, [0, 8], "op2 index"), ~tknob.(t, \drift, [0, 1]))
			)),
			~panel.("amp", t[\color], VLayout(
				~row.(~tknob.(t, \atk, [0.001, 2, \exp], "attack"), ~tknob.(t, \rel, [0.01, 4, \exp], "release")),
				~row.(~tknob.(t, \gate, [0.05, 2, \exp], "length"), ~tknob.(t, \cutoff, [60, 18000, \exp])),
				~row.(~tknob.(t, \tune, [-12, 12, \lin, 1]), ~tknob.(t, \spread, [0, 1]))
			))
		]
	}
);
