// Grains: flings short bits of sound around.
//   source \corpus  walks a cursor through every grain in the folder (nearby grains, chaos widens the steps)
//   source \file    takes grains from a region of one file — at random, or scanned like a tape head

~defs.add({
	SynthDef(\uGrain, { |out, buf, start = 0, dur = 0.1, rate = 1, amp = 0.3, pan = 0, atk = 0.005, rel = 0.02|
		var env = EnvGen.ar(Env.linen(atk, (dur - atk - rel).max(0), rel), doneAction: 2);
		var sig = PlayBuf.ar(1, buf, rate * BufRateScale.kr(buf), 1, start, loop: 1);
		OffsetOut.ar(out, Pan2.ar(sig * env * amp, pan));
	}).add;
});

~fling = { |t, buf, start, dur, rate = 1, amp = 1, pan|
	var c = ~m[\chaos], sharp = t[\sharp].coin;
	t[\lastBuf] = buf;
	t[\lastPos] = start;
	s.bind {
		Synth(\uGrain, [out: t[\bus], buf: buf, start: start, dur: dur.clip(0.003, 6), rate: rate, amp: amp * 0.35,
			pan: pan ?? { 1.0.rand2 * (0.2 + (c * 0.8)) },
			atk: if (sharp) { 0.0005 } { rrand(0.003, 0.02).min(dur * 0.3) },
			rel: if (sharp) { 0.001 } { rrand(0.005, 0.05).min(dur * 0.5) }], t[\src])
	};
};

~grainRate = { |t|
	var r = t[\pitch].midiratio;
	if (t[\pitchVar].coin) { r = r * [0.5, 2, 1.5, 0.75, 0.25, 4/3].wchoose([3, 2, 1, 1, 0.5, 1].normalizeSum) };
	r = r * (1 + (t[\pitchVar] * 0.03).rand2);
	if (t[\reverse].coin) { r.neg } { r }
};

~grainDur = { |t| t[\size] / 1000 * (2 ** (t[\sizeVar] * 2.0.rand2)) };

// Where the next grain comes from: [buffer, startFrame]
// In file mode, `stray` is the chance a grain comes from anywhere in the corpus instead.
~grainSource = { |t|
	var n = ~grains.size, c = ~m[\chaos], buf, a, b, g;
	if (t[\source] == \file and: { t[\stray].coin.not }) {
		buf = ~bufs.wrapAt(t[\file]);
		a = t[\regionStart] * buf.numFrames;
		b = t[\regionEnd].max(t[\regionStart] + 0.001) * buf.numFrames;
		[buf, if (t[\posMode] == \scan) { a + (t[\head] * (b - a)) } { rrand(a, b) }]
	} {
		t[\cursor] = (t[\cursor] + 0.gauss(1 + (c.squared * n * 0.05) + (t[\drift] * 4))).round.asInteger % n;
		if ((0.01 + (c * 0.04)).coin) { t[\cursor] = n.rand };
		g = ~grains[t[\cursor]];
		[g[0], g[1]]
	}
};

// Once a bar, `hop` is the chance the track jumps to a new file (and keeps sticking to it).
~grainHop = { |t, beats|
	t[\barAcc] = (t[\barAcc] ? 0) + beats;
	if (t[\barAcc] >= 4) {
		t[\barAcc] = t[\barAcc] - 4;
		if (t[\hop].coin) { t[\file] = ~bufs.size.rand; t[\head] = 0 };
	};
};

// Gestures are called with .value(track, source), not as Event methods.
~gestures = (
	single: { |t, src| ~fling.(t, src[0], src[1], ~grainDur.(t), ~grainRate.(t)) },
	cloud: { |t, src|
		var n = (t[\cloud] * rrand(0.5, 1.5)).asInteger.max(2), spread = exprand(0.05, 0.5);
		var rate = ~grainRate.(t), sr = src[0].sampleRate;
		fork {
			n.do {
				~fling.(t, src[0], src[1] + (~grainDur.(t) * sr).rand, ~grainDur.(t) * exprand(0.05, 0.4),
					rate * (1 + 0.02.rand2), 0.6, 1.0.rand2);
				(spread / n).wait;
			};
		};
	},
	ratchet: { |t, src|
		var n = rrand(2, t[\repeats].asInteger.max(2)), rate = ~grainRate.(t), dur = ~grainDur.(t);
		var gap = ~beatSecs.(t, t[\grid]) / n * rrand(1, 2), accel = rrand(0.75, 1.1);
		fork {
			n.do { |i|
				~fling.(t, src[0], src[1], dur.min(gap), rate, 1 - (i / n * 0.8));
				gap.wait;
				gap = gap * accel;
			};
		};
	},
	smear: { |t, src| ~fling.(t, src[0], src[1], ~grainDur.(t) * 4, [0.25, 0.5, -0.5, 0.125].choose * t[\pitch].midiratio, 0.8) }
);

~voiceTypes[\grains] = (
	color: Color(0.25, 0.75, 0.72),
	chain: [[\drive, (mode: 3, gain: 2, mix: 0.35)]],
	key: { |t, midi|
		var src = ~grainSource.(t);
		~fling.(t, src[0], src[1], ~grainDur.(t), (midi - 60).midiratio * t[\pitch].midiratio);
	},
	defaults: (level: 0.7, wander: 0.4, sends: [0.15, 0, 0, 0.1],
		source: \corpus, file: 0, regionStart: 0, regionEnd: 1, posMode: \random, scan: 0.3, head: 0,
		size: 120, sizeVar: 0.5, pitch: 0, pitchVar: 0.3, reverse: 0.15, repeats: 6, cloud: 15, sharp: 0.3,
		grid: 0.25, wSingle: 0.8, wCloud: 0.3, wRatchet: 0.2, wSmear: 0.2),
	init: { |t| t[\cursor] = ~grains.size.rand; t[\file] = ~bufs.size.rand },
	repatch: { |t| t[\cursor] = ~grains.size.rand; t[\file] = ~bufs.size.rand },
	mover: { |t|
		var c, d, wait, w, buf;
		loop {
			c = ~m[\chaos];
			d = t[\busy];
			if (~grains.notEmpty and: { (d * 0.7 + 0.3).coin }) {
				w = [t[\wSingle], t[\wCloud] + (c * 0.3), t[\wRatchet] + (c * 0.3), t[\wSmear]];
				if (w.sum > 0) {
					~gestures[[\single, \cloud, \ratchet, \smear].wchoose(w.normalizeSum)].value(t, ~grainSource.(t));
				};
			};
			wait = t[\grid] * [1, 2, 4].wchoose([d + 0.1, 1, 1.1 - d].normalizeSum);
			if ((c * 0.5).coin) { wait = wait * [2/3, 3/4, 1.5, 5/4].choose };   // slip off the grid
			// move the tape head along the region at `scan` × real time
			if (~bufs.notEmpty) {
				buf = ~bufs.wrapAt(t[\file]);
				t[\head] = (t[\head] + (~beatSecs.(t, wait) * t[\scan] * buf.sampleRate
					/ ((t[\regionEnd] - t[\regionStart]).abs.max(0.001) * buf.numFrames))).wrap(0, 1);
			};
			~grainHop.(t, wait);
			~vwait.(t, wait);
		}
	},
	pages: { |t| [
		~pg.(t, "grains", [[\busy, [0, 1]], [\grid, [0.0625, 1, \exp]], [\size, [5, 2000, \exp], "size ms"], [\sizeVar, [0, 1], "size var"],
			[\pitch, [-24, 24, \lin, 1]], [\pitchVar, [0, 1], "pitch var"], [\reverse, [0, 1]], [\sharp, [0, 1], "click"]]),
		~pg.(t, "gestures", [[\wSingle, [0, 1], "single"], [\wCloud, [0, 1], "cloud"], [\cloud, [2, 60, \lin, 1], "cloud n"],
			[\wRatchet, [0, 1], "ratchet"], [\repeats, [2, 16, \lin, 1]], [\wSmear, [0, 1], "smear"], [\scan, [-2, 2]], [\hop, [0, 1], "hop"]])
	] },
	clip: { |t|
		VLayout(
			~row.(~lbl.("source"), ~tmenu.(t, \source, [\corpus, \file], ["whole folder", "stick to one file"]),
				~lbl.("position"), ~tmenu.(t, \posMode, [\random, \scan]),
				~tknob.(t, \stray, [0, 1], "stray"),
				~tknob.(t, \hop, [0, 1], "hop / bar"),
				~tknob.(t, \scan, [-2, 2], "scan"),
				~lbl.("drag on the waveform to pick a region")),
			~waveView.(t,
				{ |buf| [t[\regionStart] * buf.numFrames, (t[\regionEnd] - t[\regionStart]) * buf.numFrames] },
				{ |sel, buf|
					t[\regionStart] = sel[0] / buf.numFrames;
					t[\regionEnd] = (sel[0] + sel[1]) / buf.numFrames;
					t[\source] = \file;
				},
				nil,
				{ t[\source] == \corpus }
			)
		)
	},
	device: { |t|
		[
			~panel.("grains", t[\color], ~row.(
				~tknob.(t, \busy, [0, 1]),
				~tknob.(t, \grid, [0.0625, 1, \exp]),
				~tknob.(t, \size, [5, 2000, \exp], "size ms"),
				~tknob.(t, \sizeVar, [0, 1], "size var"),
				~tknob.(t, \pitch, [-24, 24, \lin, 1]),
				~tknob.(t, \pitchVar, [0, 1], "pitch var"),
				~tknob.(t, \reverse, [0, 1]),
				~tknob.(t, \sharp, [0, 1], "click"),
				~tknob.(t, \scan, [-2, 2], "scan"),
				~tknob.(t, \drift, [0, 1])
			)),
			~panel.("gestures", t[\color], ~row.(
				~tknob.(t, \wSingle, [0, 1], "single"),
				~tknob.(t, \wCloud, [0, 1], "cloud"),
				~tknob.(t, \cloud, [2, 60, \lin, 1], "cloud n"),
				~tknob.(t, \wRatchet, [0, 1], "ratchet"),
				~tknob.(t, \repeats, [2, 16, \lin, 1]),
				~tknob.(t, \wSmear, [0, 1], "smear")
			))
		]
	}
);
