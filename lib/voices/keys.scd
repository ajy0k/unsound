// Keys: a region of a sample played like a synth, from the piano roll or improvising.
//   \shot  the region, pitched by playback rate (a classic sampler; the sample is treated as C4)
//   \loop  a tiny `cycle` of the region looped at audio rate, so it becomes an oscillator;
//          `scan` picks where in the region that cycle sits, and `drift` slowly moves it

~defs.add({
	SynthDef(\uKeys, { |out, buf, start = 0, len = 4410, loopLen = 0, rate = 1, sustain = 0.3,
		atk = 0.005, rel = 0.1, amp = 0.3, cutoff = 6000, res = 0.2, fenv = 0, pan = 0|
		var env = EnvGen.ar(Env.linen(atk, sustain, rel, curve: -3), doneAction: 2);
		var end = Select.kr(loopLen > 0, [start + len, start + loopLen]);
		var sig = BufRd.ar(1, buf, Phasor.ar(0, rate * BufRateScale.kr(buf), start, end, start), 1, 4);
		var cf = cutoff * (1 + (fenv * 6 * EnvGen.ar(Env.perc(0.002, 0.25))));
		sig = RLPF.ar(LeakDC.ar(sig), cf.clip(40, 18000), res.linlin(0, 1, 1, 0.08));
		OffsetOut.ar(out, Pan2.ar(sig * env * amp, pan));
	}).add;
});

~keyNote = { |t, midi, beats|
	var buf = ~bufs.wrapAt(t[\file]), sr = buf.sampleRate, loopLen = 0, start = t[\start], rate;
	var sustain = ~beatSecs.(t, beats) * t[\gate];
	t[\scan] = (t[\scan] + 0.gauss(t[\drift] * 0.03)).fold(0, 1);
	midi = midi + t[\tune];
	if (t[\mode] == \loop) {
		loopLen = (t[\cycle] / 1000 * sr).round.max(4);
		start = start + (t[\scan] * (t[\len] - loopLen).max(0));
		rate = midi.midicps * loopLen / sr;
	} {
		rate = (midi - 60).midiratio;
	};
	t[\lastBuf] = buf;
	t[\lastPos] = start;
	s.bind {
		Synth(\uKeys, [out: t[\bus], buf: buf, start: start, len: t[\len], loopLen: loopLen, rate: rate,
			sustain: sustain, atk: t[\atk], rel: t[\rel], amp: 0.3, cutoff: t[\cutoff], res: t[\res],
			fenv: t[\fenv], pan: (t[\spread] * 1.0.rand2)], t[\src])
	};
};

~voiceTypes[\keys] = (
	color: Color(0.95, 0.62, 0.25),
	chain: [[\drive, (mode: 0, gain: 2, mix: 0.5)]],
	key: { |t, midi| ~keyNote.(t, midi, 0.5) },
	defaults: (level: 0.5, busy: 0.4, wander: 0.2, root: 60, sends: [0.3, 0.25, 0, 0],
		play: \wander, mode: \shot, cycle: 4, scan: 0.5, gate: 0.6, atk: 0.005, rel: 0.2,
		cutoff: 6000, res: 0.2, fenv: 0.3, tune: 0, octave: 0, spread: 0.3,
		repeats: 3, repChance: 0, mutate: 0.1),
	init: { |t|
		~melodicInit.(t);
		~voiceTypes[\keys][\repatch].value(t);
	},
	repatch: { |t|
		var g = ~keyGrains.choose;
		t[\file] = ~bufs.indexOf(g[0]);
		t[\start] = g[1];
		t[\len] = g[2];
		t[\mode] = [\shot, \loop].choose;
	},
	note: ~keyNote,
	mover: { |t| ~melodicMover.(t, ~keyNote) },
	pages: { |t| [
		~pg.(t, "sample", [[\cycle, [0.3, 30, \exp], "cycle ms"], [\scan, [0, 1]], [\drift, [0, 1]], [\tune, [-12, 12, \lin, 1]],
			[\atk, [0.001, 2, \exp], "attack"], [\rel, [0.01, 4, \exp], "release"], [\gate, [0.05, 2, \exp], "length"], [\spread, [0, 1]]]),
		~pg.(t, "filter·play", [[\cutoff, [60, 18000, \exp]], [\res, [0, 1]], [\fenv, [0, 1], "f env"], [\busy, [0, 1]],
			[\repeats, [1, 8, \lin, 1]], [\repChance, [0, 1], "repeat %"], [\mutate, [0, 1]], [\octave, [-3, 3, \lin, 1]]])
	] },
	clip: { |t| ~rollPanel.(t) },
	device: { |t|
		[
			~panel.("sample", t[\color], VLayout(
				~waveView.(t,
					{ |buf| [t[\start], t[\len]] },
					{ |sel| t[\start] = sel[0].asInteger; t[\len] = sel[1].asInteger; ~keyNote.(t, t[\root], 1) },
					{ |buf| t[\start] = 0; t[\len] = buf.numFrames.min(buf.sampleRate * 0.5).asInteger }
				),
				~row.(~lbl.("mode"), ~tmenu.(t, \mode, [\shot, \loop]),
					~tknob.(t, \cycle, [0.3, 30, \exp], "cycle ms"),
					~tknob.(t, \scan, [0, 1]),
					~tknob.(t, \drift, [0, 1]),
					~tknob.(t, \tune, [-12, 12, \lin, 1]))
			), 520),
			~panel.("amp + filter", t[\color], VLayout(
				~row.(~tknob.(t, \atk, [0.001, 2, \exp], "attack"), ~tknob.(t, \rel, [0.01, 4, \exp], "release"),
					~tknob.(t, \gate, [0.05, 2, \exp], "length")),
				~row.(~tknob.(t, \cutoff, [60, 18000, \exp]), ~tknob.(t, \res, [0, 1]), ~tknob.(t, \fenv, [0, 1], "f env")),
				~row.(~tknob.(t, \spread, [0, 1], "spread"))
			))
		]
	}
);
