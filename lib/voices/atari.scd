// atari: the Atari 2600's TIA sound chip. Two channels, each with the three real registers:
//   AUDC  0–15  waveform: which of the chip's counters (poly4, poly5, poly9, ÷2, ÷3, ÷31) clock the output
//   AUDF  0–31  frequency: divides the ~31.4 kHz audio clock by AUDF+1
//   AUDV  0–15  volume, 4 bits
// The 16 waveforms are worked out here, tick by tick, from the same counters the chip uses
// (after Ron Fries' TIASound), and played back at the chip's clock with no interpolation.
// Notes snap to the nearest AUDF, so melodies come out out-of-tune, like the real thing.
// Channel A plays the roll / wander / keys; channel B makes sound effects every so often.
// `clock` is the chip's audio clock: 31399.5 Hz on an NTSC machine. Overclock it if you like.

~tiaClock = 31399.5;
~tiaNames = ["0 set to 1", "1 buzz poly4", "2 rumble ÷31 poly4", "3 rumble poly5→4", "4 pure ÷2", "5 pure ÷2",
	"6 bass ÷31", "7 buzz poly5→÷2", "8 white noise poly9", "9 noise poly5", "10 pure ÷31", "11 set to 1",
	"12 lead ÷6", "13 lead ÷6", "14 bass ÷93", "15 buzz ÷3 poly5"];

// Maximal-length shift register for x^n + x^k + 1: one period of its output bits.
~lfsr = { |n, k|
	var reg = (1 << n) - 1, out = Array.newClear((1 << n) - 1);
	out.size.do { |i|
		var fb = (reg bitXor: (reg >> (n - k))) & 1;
		out[i] = reg & 1;
		reg = (reg >> 1) | (fb << (n - 1));
	};
	out
};

// One period of AUDC `c`'s output (0/1 per tick of the divided clock).
~tiaSequence = { |c|
	var bit4 = ~lfsr.(4, 3), bit5 = ~lfsr.(5, 3), bit9 = ~lfsr.(9, 5);
	var div31 = Array.fill(31, { |i| [0, 18].includes(i).binaryValue });
	var p4 = 0, p5 = 0, p9 = 0, out = 0, len = if (c == 8) { 511 } { 930 };
	if (c == 10) { c = 6 };   // on the chip, 10 sounds like 6: a ÷31 pure tone
	if ([0, 11].includes(c)) { 1 ! len } {
		Array.fill(len, {
			var clock;
			p5 = (p5 + 1) % 31;
			clock = ((c & 2) == 0) or: { ((c & 1) == 0) and: { div31[p5] == 1 } } or: { ((c & 1) == 1) and: { bit5[p5] == 1 } };
			if (clock) {
				case
				{ (c & 4) != 0 } { out = 1 - out }
				{ (c & 8) != 0 } { if (c == 8) { p9 = (p9 + 1) % 511; out = bit9[p9] } { out = bit5[p5] } }
				{ p4 = (p4 + 1) % 15; out = bit4[p4] };
			};
			out
		})
	}
};

// Shortest repeat of a sequence (in ticks): what decides a waveform's pitch.
~seqPeriod = { |seq|
	(1 .. seq.size).detect { |p| seq.size % p == 0 and: { seq.every { |x, i| x == seq.wrapAt(i + p) } } } ? seq.size
};

~tiaSeqs = (0..15).collect { |c| ~tiaSequence.(c) };
~tiaPeriods = ~tiaSeqs.collect { |q| ~seqPeriod.(q) };

~tiaFreq = { |c, f, clock| clock / ((f + 1) * (if (c >= 12) { 3 } { 1 })) / ~tiaPeriods[c] };

// The AUDF that gets closest to `midi` on waveform `c` (trying octaves if it's out of range).
~tiaNearest = { |c, midi, clock|
	var best, err = inf;
	[0, -12, 12, -24, 24, -36].do { |oct|
		if (err > 1) {
			(0..31).do { |f|
				var e = (~tiaFreq.(c, f, clock).cpsmidi - (midi + oct)).abs;
				if (e < err) { err = e; best = f };
			};
		};
	};
	best
};

~defs.add({
	~tiaBufs = Buffer.allocConsecutive(16, s, 1024, 1, { |b, i| b.setnMsg(0, ~tiaSeqs[i].keep(1024)) });

	SynthDef(\uAtari, { |out, gate = 0, c0 = 4, f0 = 12, v0 = 10, dec0 = 0.4, c1 = 8, f1 = 20, v1 = 0, dec1 = 0,
		clock = 31399.5, width = 0.3|
		var base = \tables.kr(0), env = EnvGen.kr(Env.asr(0.005, 1, 0.1), gate);
		var chan = { |c, f, v, dec, trig|
			var cc = c.round.clip(0, 15), ff = f.round.clip(0, 31);
			var rate = clock / ((ff + 1) * Select.kr(cc > 11.5, [1, 3]));
			var len = Select.kr((cc - 8).abs < 0.5, [930, 511]);
			var bit = BufRd.ar(1, base + cc, Phasor.ar(0, rate / SampleRate.ir, 0, len), 1, 1);
			var venv = Select.kr(dec > 0.001, [1, EnvGen.kr(Env([0, 1, 0], [0, dec.max(0.001)]), trig)]);
			bit * ((v.clip(0, 15) * venv).round / 15)
		};
		var a = chan.(c0, f0, v0, dec0, \trig0.tr(0)), b = chan.(c1, f1, v1, dec1, \trig1.tr(0));
		var sig = Latch.ar([a + (b * 0.6), b + (a * 0.6)] * 0.5, Impulse.ar(clock.clip(100, SampleRate.ir)));
		Out.ar(out, LeakDC.ar(sig) * width.linlin(0, 1, 1, 0.6) * env);
	}).add;
});

~atariNote = { |t, midi, beats|
	var c = t[\c0].round.asInteger.clip(0, 15), f = ~tiaNearest.(c, midi, t[\clock]);
	t[\f0] = f;
	s.bind { t[\voice] !? { |v| v.set(\f0, f, \trig0, 1) } };
};

~atariKeys = [\c0, \f0, \v0, \dec0, \c1, \f1, \v1, \dec1, \clock, \width];
~atariSpec = (c0: [0, 15, \lin, 1], f0: [0, 31, \lin, 1], v0: [0, 15, \lin, 1], dec0: [0, 3, 4],
	c1: [0, 15, \lin, 1], f1: [0, 31, \lin, 1], v1: [0, 15, \lin, 1], dec1: [0, 3, 4],
	clock: [1000, 200000, \exp], width: [0, 1]);
~atariLabel = (c0: "A wave", f0: "A freq", v0: "A vol", dec0: "A decay", c1: "B wave", f1: "B freq", v1: "B vol",
	dec1: "B decay", clock: "clock", width: "mono");

// A sound effect on channel B: a sweep of AUDF on a noisy waveform, volume stepping down.
~atariSfx = { |t|
	Routine({
		var c = [8, 3, 15, 2, 1, 7, 9, 6].choose, n = rrand(6, 24), a = 32.rand, b = 32.rand, v = rrand(8, 15);
		n.do { |i|
			s.bind { t[\voice] !? { |x| x.set(\c1, c, \f1, a + ((b - a) * i / n), \v1, (v * (1 - (i / n))).round, \dec1, 0) } };
			[0.016, 0.033, 0.05].choose.wait;
		};
		s.bind { t[\voice] !? { |x| x.set(*[\c1, \f1, \v1, \dec1].collect { |k| [k, t[k]] }.flatten) } };
	}).play(SystemClock);
};

~voiceTypes[\atari] = (
	color: Color(0.95, 0.45, 0.2),
	chain: [[\filter, (cutoff: 11000, res: 0.1)]],
	key: { |t, midi| ~atariNote.(t, midi, 0.5) },
	defaults: (level: 0.5, busy: 0.6, wander: 0, root: 60, sends: [0.1, 0.2, 0, 0],
		play: \wander, gate: 1, spread: 0, repeats: 3, repChance: 0.1, mutate: 0.1, octave: 0,
		c0: 12, f0: 12, v0: 10, dec0: 0.4, c1: 8, f1: 20, v1: 0, dec1: 0, clock: ~tiaClock, width: 0.3),
	init: { |t| ~melodicInit.(t); ~suggestRoll.(t) },
	build: { |t|
		t[\voice] = Synth(\uAtari, [out: t[\bus], tables: ~tiaBufs[0].bufnum, gate: (~running == true).binaryValue]
			++ ~atariKeys.collect { |k| [k, t[k]] }.flatten, t[\src]);
	},
	repatch: { |t|
		t[\c0] = [1, 4, 6, 7, 12, 14, 15].choose; t[\dec0] = exprand(0.05, 1);
		t[\c1] = [8, 3, 2, 15, 9].choose;
		s.bind { t[\voice].set(\c0, t[\c0], \dec0, t[\dec0], \c1, t[\c1]) };
	},
	sometimes: [
		[\soSfx, "sfx", { |t| ~atariSfx.(t) }, 0.15],
		[\soGlitch, "glitch", { |t|
			Routine({
				s.bind { t[\voice].set(\c0, 16.rand, \clock, t[\clock] * [0.5, 2, 0.25, 1.5].choose) };
				~vwait.(t, [0.5, 1, 2].choose);
				s.bind { t[\voice].set(\c0, t[\c0], \clock, t[\clock]) };
			}).play(~clock);
		}, 0.03]
	],
	note: ~atariNote,
	mover: { |t| ~melodicMover.(t, ~atariNote) },
	pages: { |t| [
		~pg.(t, "tia", [\c0, \f0, \v0, \dec0, \c1, \f1, \v1, \dec1].collect { |k| [k, ~atariSpec[k], ~atariLabel[k]] }),
		~pg.(t, "chip", [[\clock, ~atariSpec[\clock], "clock"], [\width, [0, 1], "mono"], [\busy, [0, 1]], [\mutate, [0, 1]]])
	] },
	clip: { |t| ~rollPanel.(t) },
	device: { |t|
		var k = { |key| ~tknob.(t, key, ~atariSpec[key], ~atariLabel[key], 40) };
		var chan = { |n, name|
			var ck = ("c" ++ n).asSymbol;
			~panel.("channel " ++ name, t[\color], VLayout(
				~menu.((0..15), { t[ck].round.asInteger }, { |x| ~tset.(t[\name], ck, x) }, ~tiaNames),
				~row.(k.(ck), k.(("f" ++ n).asSymbol), k.(("v" ++ n).asSymbol), k.(("dec" ++ n).asSymbol))
			), 230)
		};
		[
			chan.(0, "A (notes)"), chan.(1, "B (effects)"),
			~panel.("chip", t[\color], VLayout(~row.(k.(\clock), k.(\width), ~button.("NTSC", { ~tset.(t[\name], \clock, ~tiaClock) })), ~soRow.(t)))
		]
	}
);
