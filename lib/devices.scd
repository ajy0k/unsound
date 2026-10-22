// Devices: effects that process a track's bus in place. Any device goes on any track, return
// or the master, in any order, as many as you like. Each has a dry/wet `mix` (100% wet on returns).
//
// A device type is an Event with:
//   def     SynthDef name (built with ~deviceDef)
//   cat     browser category
//   params  list of ~p.(key, default, spec, label, conv); conv \beats means the knob is in
//           beats and the synth gets seconds
//   mover   optional { |track, device| loop { … } }, runs while the transport runs
//   gui     optional { |track, device| [views] } extra controls for its panel
//
// The master's limiter is pinned: always last, can't be removed. LIMITER ALWAYS.

~deviceDef = { |name, func|
	SynthDef(name, {
		var bus = \bus.kr(0), dry = In.ar(bus, 2), mix = \mix.kr(1, 0.05);
		var wet = SynthDef.wrap(func, nil, [dry]);
		ReplaceOut.ar(bus, (dry * (1 - mix)) + (wet * mix));
	}).add;
};

~p = { |key, default, spec, label, conv| (key: key, default: default, spec: spec.asSpec, label: label ? key.asString, conv: conv) };

~driveModes = [\soft, \tube, \hard, \fold, \fuzz, \rectify, \sine, \crunch];

~defs.add({
	// ------------------------------------------------ distortion
	~deviceDef.(\dDrive, { |sig, gain = 4, mode = 0, bias = 0, tone = 8000, level = 0.5|
		var x = (sig * gain) + bias;
		var shaped = Select.ar(mode.round.clip(0, 7), [
			x.tanh,                                            // soft
			x.max(0).tanh + (x.min(0) * 0.5).tanh,             // tube: asymmetric
			x.clip2(1),                                        // hard
			x.fold2(1),                                        // fold
			(x * 8).softclip,                                  // fuzz
			x.abs.tanh * 2 - 1,                                // rectify: octave-up grit
			(x * 0.5pi).sin,                                   // sine shaper
			Latch.ar(x, Impulse.ar(6000)).round(0.125).tanh    // crunch
		]);
		LeakDC.ar(LPF.ar(shaped, tone.clip(100, 18000))) * level
	});

	~deviceDef.(\dCrush, { |sig, bits = 8, rate = 8000|
		Latch.ar(sig, Impulse.ar(rate)).round(2 ** bits.neg)
	});

	// Crackle and hiss that follow the input's loudness (`follow` 0 = constant).
	~deviceDef.(\dDirt, { |sig, crackle = 0.3, hiss = 0.1, follow = 1|
		var env = Amplitude.kr(Mix(sig), 0.01, 0.2).min(1);
		var noise = (Dust2.ar(crackle * 300 ! 2) * 0.6) + (PinkNoise.ar(hiss ! 2) * 0.5);
		sig + (noise * ((env * 4 * follow) + (1 - follow)))
	});

	// ------------------------------------------------ filter and tone
	~deviceDef.(\dFilter, { |sig, cutoff = 18000, res = 0.2, mode = 0|
		var f = cutoff.lag(0.08).clip(30, 18000), rq = res.linlin(0, 1, 1, 0.05);
		Select.ar(mode.round.clip(0, 2), [RLPF.ar(sig, f, rq), RHPF.ar(sig, f, rq), BPF.ar(sig, f, rq) * (1 + (res * 3))])
	});

	~deviceDef.(\dEQ, { |sig, low = 0, mid = 0, midFreq = 1000, high = 0|
		BHiShelf.ar(BPeakEQ.ar(BLowShelf.ar(sig, 200, 1, low), midFreq.clip(60, 16000), 1, mid), 5000, 1, high)
	});

	// Tuned comb: anything going through it rings at `note`.
	~deviceDef.(\dComb, { |sig, note = 48, decay = 1|
		(CombC.ar(sig, 0.05, note.midicps.reciprocal, decay) * 0.5).softclip
	});

	// Four-partial resonator bank; `spread` pulls the partials from harmonic to bell-like.
	~deviceDef.(\dResonator, { |sig, note = 48, decay = 1, spread = 1|
		var f = note.midicps * [1, 1 + spread, 1 + (spread * 2.3), 1 + (spread * 4.1)];
		DynKlank.ar(`[f, [1, 0.5, 0.3, 0.2], decay ! 4], sig * 0.05).softclip
	});

	~deviceDef.(\dRing, { |sig, freq = 200, wobble = 0|
		sig * SinOsc.ar(freq * (1 + LFNoise2.kr(0.3, wobble)))
	});

	// Frequency shifter with feedback: a barber-pole spiral, opposite directions per side.
	~deviceDef.(\dShift, { |sig, shift = 120, fb = 0.4|
		var loop = LocalIn.ar(2);
		var out = LeakDC.ar(FreqShift.ar(sig + (loop * fb), shift.lag(0.5) * [1, -1])).softclip;
		LocalOut.ar(DelayC.ar(out, 0.5, 0.12));
		out
	});

	// ------------------------------------------------ time and space
	~deviceDef.(\dSpace, { |sig, size = 0.85, damp = 0.4|
		var x = HPF.ar(sig, 150);
		FreeVerb2.ar(x[0], x[1], 1, size, damp)
	});

	// Ping-pong tape echo. Changing `time` warps the pitch like a tape machine.
	~deviceDef.(\dEcho, { |sig, time = 0.34, fb = 0.55, tone = 3500, wobble = 0.002|
		var loop = LocalIn.ar(2);
		var t = (time.lag(0.3) + LFNoise2.kr([0.2, 0.23], wobble)).clip(0.01, 3.9) - ControlDur.ir;
		var out = LPF.ar(DelayC.ar(sig + (loop * fb), 4, t), tone).softclip;
		LocalOut.ar(out.reverse);
		out
	});

	// Chorus at long delays, flanger at short ones with feedback.
	~deviceDef.(\dChorus, { |sig, rate = 0.3, depth = 0.004, delay = 0.012, fb = 0|
		var loop = LocalIn.ar(2);
		var t = (delay + (SinOsc.kr(rate * [1, 1.13], [0, 0.5pi]) * depth)).clip(0.0002, 0.09);
		var out = DelayC.ar(sig + (loop * fb), 0.1, t).softclip;
		LocalOut.ar(out);
		out
	});

	~deviceDef.(\dTape, { |sig, wow = 0.3, flutter = 0.2, sat = 0.3, age = 0.3, hiss = 0.03|
		var t = 0.01 + (LFNoise2.kr(0.5) * wow * 0.004) + (SinOsc.kr(6.3) * flutter * 0.0006);
		var x = DelayC.ar(sig, 0.05, t);
		x = (x * (1 + (sat * 4))).tanh / (1 + sat);
		LPF.ar(x, age.linexp(0, 1, 18000, 2500)) + (PinkNoise.ar(hiss ! 2) * 0.3)
	});

	~deviceDef.(\dPitch, { |sig, ratio = 0.5, jitter = 0, grit = 0|
		PitchShift.ar(sig, 0.2, ratio, jitter, grit * 0.2)
	});

	// Plays the last `len` backwards, chunk after chunk.
	~deviceDef.(\dReverse, { |sig, len = 0.5|
		var buf = LocalBuf(SampleRate.ir * 4, 2).clear;
		var frames = BufFrames.ir(buf), n = (len * SampleRate.ir).clip(256, frames / 2 - 1);
		var w = Phasor.ar(0, 1, 0, frames), ph = Phasor.ar(0, 1, 0, n);
		BufWr.ar(sig, buf, w);
		BufRd.ar(2, buf, w - (2 * ph), loop: 1) * (ph / n * pi).sin
	});

	// Granular smear: keeps the last 3 s and sprays grains from random points in it.
	~deviceDef.(\dSmear, { |sig, density = 25, grain = 0.12, spread = 1.5, pitch = 1|
		var buf = LocalBuf(SampleRate.ir * 3).clear;
		var frames = BufFrames.ir(buf);
		var w = Phasor.ar(0, 1, 0, frames);
		var trig = Dust.ar(density);
		var back = TRand.ar(0.05, spread.clip(0.06, 2.9), trig) * SampleRate.ir;
		BufWr.ar(Mix(sig) * 0.5, buf, w);
		GrainBuf.ar(2, trig, grain, buf, pitch * (2 ** TIRand.ar(-1, 1, trig)),
			((w - back) / frames).wrap(0, 1), 2, TRand.ar(-1, 1, trig))
	});

	// ------------------------------------------------ glitch
	// Stutter: a 4 s ring buffer that stops writing while `stut` is on and loops the last `len`.
	~deviceDef.(\dStutter, { |sig, stut = 0, len = 0.125|
		var buf = LocalBuf(SampleRate.ir * 4, 2).clear;
		var frames = BufFrames.ir(buf);
		var on = stut > 0.5, mix = Lag.kr(on, 0.004);
		var n = (len * SampleRate.ir).clip(32, frames - 1);
		var wpos = Phasor.ar(0, 1 - on, 0, frames);
		var looped;
		BufWr.ar(sig, buf, wpos);
		looped = BufRd.ar(2, buf, wpos - n + Phasor.ar(on, 1, 0, n), loop: 1, interpolation: 1);
		(sig * (1 - mix)) + (looped * mix)
	});

	// Rhythmic gate. `rate` is the gate period.
	~deviceDef.(\dChop, { |sig, rate = 0.25, depth = 1, width = 0.5|
		sig * (1 - (depth * (1 - LFPulse.ar(rate.max(0.005).reciprocal, 0, width).lag(0.003))))
	});

	~deviceDef.(\dFreeze, { |sig, freeze = 0|
		IFFT(PV_MagFreeze(FFT({ LocalBuf(2048) } ! 2, sig), freeze > 0.5))
	});

	~deviceDef.(\dScramble, { |sig, amount = 0.3, width = 0.2, rate = 4|
		IFFT(PV_BinScramble(FFT({ LocalBuf(2048) } ! 2, sig), amount, width, Dust.kr(rate)))
	});

	~deviceDef.(\dBlur, { |sig, bins = 10|
		IFFT(PV_MagSmear(FFT({ LocalBuf(2048) } ! 2, sig), bins))
	});

	// A feedback loop through a delay, a band-pass and a drive. `gain` above 1 lets it scream by itself.
	~deviceDef.(\dFeedback, { |sig, gain = 1.1, freq = 800, res = 0.5, delay = 0.01, drive = 2|
		var loop = LocalIn.ar(2);
		var x = DelayC.ar(sig + (loop * gain), 0.2, delay.lag(0.1).clip(0.0005, 0.2));
		x = BPF.ar(x, freq.lag(0.1).clip(30, 16000), res.linlin(0, 1, 1, 0.05)) * (1 + (res * 3));
		x = LeakDC.ar((x * drive).tanh);
		LocalOut.ar(x.reverse);
		x * 0.7
	});

	// ------------------------------------------------ dynamics and utility
	~deviceDef.(\dCompressor, { |sig, thresh = 0.3, ratio = 4, makeup = 1.5|
		Compander.ar(sig, sig, thresh, 1, ratio.reciprocal, 0.005, 0.1) * makeup
	});

	~deviceDef.(\dGate, { |sig, thresh = 0.05| Compander.ar(sig, sig, thresh, 10, 1, 0.002, 0.05) });

	~deviceDef.(\dWidth, { |sig, width = 1, autopan = 0, rate = 0.5|
		var m = (sig[0] + sig[1]) * 0.5, sd = (sig[0] - sig[1]) * 0.5 * width;
		Balance2.ar(m + sd, m - sd, SinOsc.kr(rate) * autopan)
	});

	// EQ Eight: eight bands, each a low cut, low shelf, bell, notch, high shelf or high cut.
	~deviceDef.(\dEQ8, { |sig|
		8.do { |i|
			var n = i + 1;
			var f = ("f" ++ n).asSymbol.kr(1000, 0.05).clip(20, 20000);
			var g = ("g" ++ n).asSymbol.kr(0, 0.05);
			var q = ("q" ++ n).asSymbol.kr(0.71, 0.05).clip(0.1, 18);
			var type = ("t" ++ n).asSymbol.kr(2).round.clip(0, 5);
			var on = ("on" ++ n).asSymbol.kr(1) > 0.5;
			var x0 = (2 * q).reciprocal, bw = (2 / 2.log) * (x0 + (x0.squared + 1).sqrt).log;   // octaves, from Q
			var x = Select.ar(type, [
				BHiPass.ar(sig, f, q.reciprocal), BLowShelf.ar(sig, f, 1, g), BPeakEQ.ar(sig, f, q.reciprocal, g),
				BBandStop.ar(sig, f, bw), BHiShelf.ar(sig, f, 1, g), BLowPass.ar(sig, f, q.reciprocal)
			]);
			sig = Select.ar(on, [sig, x]);
		};
		sig * \out.kr(1, 0.05)
	});

	// Only if the VSTPlugin extension is installed (https://git.iem.at/pd/vstplugin). Referenced by
	// name, so this file still compiles without it.
	if (\VSTPlugin.asClass.notNil) { ~deviceDef.(\dVST, { |sig| \VSTPlugin.asClass.ar(sig, 2) }) };

	~deviceDef.(\dLimiter, { |sig, gain = 1, ceiling = 0.95|
		Limiter.ar(LeakDC.ar(sig) * gain, ceiling)
	});
});

// ---------------------------------------------------------------- device movers

// Random walk on the cutoff, around the cutoff you set (mostly below it).
~filterMover = { |t, d|
	var x = 0, p, live;
	loop {
		p = d[\params];
		if (p[\drift] > 0) {
			x = (x + 0.gauss(p[\drift] * 0.2 + (~m[\chaos] * 0.08))).fold(-5 * p[\drift] - 0.01, p[\drift]);
			live = (p[\cutoff] * (2 ** x)).clip(30, 18000);
			s.bind { d[\synth].set(\cutoff, live) };
		};
		0.25.wait;
	}
};

// Turns `key` on for a while on the beat grid, `auto` sets how often. Leaves it alone while you hold.
// With `shrink`, it also halves `len` while holding (the pitch-up stutter).
~holdMover = { |key|
	{ |t, d|
		var p, c, hold, len;
		loop {
			p = d[\params];
			c = ~m[\chaos];
			if ((p[\auto] * 0.5).coin and: { d[\held] != true }) {
				hold = [0.5, 1, 2, 0.25].wchoose([3, 2, 1, c + 0.1].normalizeSum);
				len = (p[\len] ? 0.125) * [1, 0.5, 2, 0.25, 1.5].wchoose([4, 2, 1, c + 0.2, c].normalizeSum);
				s.bind { d[\synth].set(\len, len / ~clock.tempo, key, 1) };
				if ((p[\shrink] ? 0).coin) {
					4.do { |i| s.bind { d[\synth].set(\len, len / (2 ** i) / ~clock.tempo) }; (hold / 4).wait };
				} { hold.wait };
				if (d[\held] != true) { s.bind { d[\synth].set(key, 0) } };
			} { [0.5, 1, 1, 2].choose.wait };
		}
	}
};

// Momentary hold from a pad, a key, or a MIDI button.
~devHold = { |d, on|
	var key = ~deviceTypes[d[\type]][\hold];
	d[\held] = on;
	s.bind {
		if (d[\params][\len].notNil) { d[\synth].set(\len, d[\params][\len] / ~clock.tempo) };
		d[\synth].set(key, if (on) { 1 } { 0 });
	};
};

~holdPad = { |t, d|
	[UserView().fixedSize_(Size(84, 44)).canFocus_(false).background_(Color(0.55, 0.12, 0.12))
		.drawFunc_({ |uv| Pen.stringCenteredIn("HOLD", uv.bounds.moveTo(0, 0), Font(Font.defaultSansFace, 13, true), Color.white) })
		.mouseDownAction_({ ~devHold.(d, true); nil }).mouseUpAction_({ ~devHold.(d, false); nil })]
};

// ---------------------------------------------------------------- the device list

// EQ Eight: band n has fn (freq), gn (gain dB), qn (Q), tn (type), onn (on).
~eq8Types = [\lowcut, \lowshelf, \bell, \notch, \highshelf, \highcut];
~eq8Defaults = (
	f: [30, 100, 250, 600, 1500, 3500, 8000, 18000], t: [0, 1, 2, 2, 2, 2, 4, 5],
	q: [0.71, 0.71, 1, 1, 1, 1, 0.71, 0.71], on: [0, 1, 1, 1, 1, 1, 1, 0]);
~eq8Params = (1..8).collect { |n|
	var i = n - 1;
	[~p.(("f" ++ n).asSymbol, ~eq8Defaults[\f][i], [20, 20000, \exp], "freq " ++ n),
		~p.(("g" ++ n).asSymbol, 0, [-18, 18], "gain " ++ n),
		~p.(("q" ++ n).asSymbol, ~eq8Defaults[\q][i], [0.1, 18, \exp], "q " ++ n),
		~p.(("t" ++ n).asSymbol, ~eq8Defaults[\t][i], [0, 5, \lin, 1], "type " ++ n).put(\dice, false),
		~p.(("on" ++ n).asSymbol, ~eq8Defaults[\on][i], [0, 1, \lin, 1], "on " ++ n).put(\dice, false)]
}.flatten ++ [~p.(\out, 1, [0, 2, \amp], "output"), ~p.(\mix, 1, [0, 1])];

~deviceTypes = (
	drive: (def: \dDrive, cat: \distortion, params: [
		~p.(\gain, 4, [1, 60, \exp]), ~p.(\mode, 0, [0, 7, \lin, 1], "mode"), ~p.(\bias, 0, [-1, 1]),
		~p.(\tone, 8000, [200, 18000, \exp]), ~p.(\level, 0.5, [0, 1]), ~p.(\mix, 1, [0, 1])]),
	crush: (def: \dCrush, cat: \distortion, params: [
		~p.(\bits, 8, [1, 16]), ~p.(\rate, 8000, [100, 48000, \exp]), ~p.(\mix, 1, [0, 1])]),
	dirt: (def: \dDirt, cat: \distortion, params: [
		~p.(\crackle, 0.3, [0, 1]), ~p.(\hiss, 0.1, [0, 1]), ~p.(\follow, 1, [0, 1]), ~p.(\mix, 1, [0, 1])]),

	filter: (def: \dFilter, cat: \filter, mover: ~filterMover, params: [
		~p.(\cutoff, 18000, [30, 18000, \exp]), ~p.(\res, 0.2, [0, 1]),
		~p.(\mode, 0, [0, 2, \lin, 1], "lp/hp/bp"), ~p.(\drift, 0, [0, 1]), ~p.(\mix, 1, [0, 1])]),
	eq: (def: \dEQ, cat: \filter, params: [
		~p.(\low, 0, [-24, 12]), ~p.(\mid, 0, [-24, 12]), ~p.(\midFreq, 1000, [60, 16000, \exp], "mid freq"),
		~p.(\high, 0, [-24, 12]), ~p.(\mix, 1, [0, 1])]),
	comb: (def: \dComb, cat: \filter, params: [
		~p.(\note, 48, [24, 96, \lin, 1]), ~p.(\decay, 1, [0.05, 8, \exp]), ~p.(\mix, 0.5, [0, 1])]),
	resonator: (def: \dResonator, cat: \filter, params: [
		~p.(\note, 48, [24, 96, \lin, 1]), ~p.(\decay, 1, [0.05, 8, \exp]), ~p.(\spread, 1, [0, 3]), ~p.(\mix, 0.5, [0, 1])]),
	ring: (def: \dRing, cat: \filter, params: [
		~p.(\freq, 200, [1, 4000, \exp]), ~p.(\wobble, 0, [0, 1]), ~p.(\mix, 0.5, [0, 1])]),
	shift: (def: \dShift, cat: \filter, params: [
		~p.(\shift, 120, [-1000, 1000]), ~p.(\fb, 0.4, [0, 0.95], "feedback"), ~p.(\mix, 0.35, [0, 1])]),

	space: (def: \dSpace, cat: \time, params: [
		~p.(\size, 0.85, [0, 1]), ~p.(\damp, 0.4, [0, 1]), ~p.(\mix, 0.35, [0, 1])]),
	echo: (def: \dEcho, cat: \time, params: [
		~p.(\time, 0.75, [1/16, 4, \exp], "time", \beats), ~p.(\fb, 0.55, [0, 1.1], "feedback"),
		~p.(\tone, 3500, [200, 12000, \exp]), ~p.(\wobble, 0.002, [0, 0.02]), ~p.(\mix, 0.35, [0, 1])]),
	chorus: (def: \dChorus, cat: \time, params: [
		~p.(\rate, 0.3, [0.01, 10, \exp]), ~p.(\depth, 0.004, [0, 0.02]), ~p.(\delay, 0.012, [0.0005, 0.05, \exp]),
		~p.(\fb, 0, [0, 0.95], "feedback"), ~p.(\mix, 0.5, [0, 1])]),
	tape: (def: \dTape, cat: \time, params: [
		~p.(\wow, 0.3, [0, 1]), ~p.(\flutter, 0.2, [0, 1]), ~p.(\sat, 0.3, [0, 1], "saturate"),
		~p.(\age, 0.3, [0, 1]), ~p.(\hiss, 0.03, [0, 0.3]), ~p.(\mix, 1, [0, 1])]),
	pitch: (def: \dPitch, cat: \time, params: [
		~p.(\ratio, 0.5, [0.25, 4, \exp]), ~p.(\jitter, 0, [0, 1]), ~p.(\grit, 0, [0, 1]), ~p.(\mix, 0.5, [0, 1])]),
	reverse: (def: \dReverse, cat: \time, params: [
		~p.(\len, 0.5, [1/16, 2, \exp], "length", \beats), ~p.(\mix, 0.5, [0, 1])]),
	smear: (def: \dSmear, cat: \time, params: [
		~p.(\density, 25, [1, 120, \exp]), ~p.(\grain, 0.12, [0.01, 0.5, \exp]),
		~p.(\spread, 1.5, [0.06, 2.9]), ~p.(\pitch, 1, [0.25, 4, \exp]), ~p.(\mix, 0.35, [0, 1])]),

	stutter: (def: \dStutter, cat: \glitch, hold: \stut, mover: ~holdMover.(\stut), gui: ~holdPad, params: [
		~p.(\len, 0.125, [1/64, 1, \exp], "length", \beats), ~p.(\auto, 0.3, [0, 1]), ~p.(\shrink, 0.3, [0, 1]),
		~p.(\mix, 1, [0, 1])]),
	chop: (def: \dChop, cat: \glitch, params: [
		~p.(\rate, 0.25, [1/16, 2, \exp], "rate", \beats), ~p.(\depth, 1, [0, 1]),
		~p.(\width, 0.5, [0.05, 0.95]), ~p.(\mix, 1, [0, 1])]),
	freeze: (def: \dFreeze, cat: \glitch, hold: \freeze, mover: ~holdMover.(\freeze), gui: ~holdPad, params: [
		~p.(\auto, 0.2, [0, 1]), ~p.(\mix, 1, [0, 1])]),
	scramble: (def: \dScramble, cat: \glitch, params: [
		~p.(\amount, 0.3, [0, 1]), ~p.(\width, 0.2, [0, 1]), ~p.(\rate, 4, [0.1, 40, \exp]), ~p.(\mix, 1, [0, 1])]),
	blur: (def: \dBlur, cat: \glitch, params: [~p.(\bins, 10, [0, 100, \lin, 1]), ~p.(\mix, 1, [0, 1])]),
	feedback: (def: \dFeedback, cat: \glitch, params: [
		~p.(\gain, 1.1, [0, 2]), ~p.(\freq, 800, [30, 12000, \exp]), ~p.(\res, 0.5, [0, 1]),
		~p.(\delay, 0.01, [0.0005, 0.2, \exp]), ~p.(\drive, 2, [1, 20, \exp]), ~p.(\mix, 0.5, [0, 1])]),

	compressor: (def: \dCompressor, cat: \dynamics, params: [
		~p.(\thresh, 0.3, [0.01, 1, \exp]), ~p.(\ratio, 4, [1, 20, \exp]), ~p.(\makeup, 1.5, [0.5, 8, \exp]), ~p.(\mix, 1, [0, 1])]),
	gate: (def: \dGate, cat: \dynamics, params: [~p.(\thresh, 0.05, [0.001, 0.5, \exp]), ~p.(\mix, 1, [0, 1])]),
	width: (def: \dWidth, cat: \dynamics, params: [
		~p.(\width, 1, [0, 3]), ~p.(\autopan, 0, [0, 1]), ~p.(\rate, 0.5, [0.01, 20, \exp]), ~p.(\mix, 1, [0, 1])]),
	eq8: (def: \dEQ8, cat: \filter, panel: { |t, d| ~eq8Panel.(t, d) }, width: 470, params: ~eq8Params,
		pages: [["eq gain", (1..8).collect { |n| ("g" ++ n).asSymbol }], ["eq freq", (1..8).collect { |n| ("f" ++ n).asSymbol }],
			["eq q", (1..8).collect { |n| ("q" ++ n).asSymbol }]]),
	limiter: (def: \dLimiter, cat: \dynamics, params: [~p.(\gain, 1, [0.25, 8, \exp], "drive in"), ~p.(\ceiling, 0.95, [0.1, 1])])
);

// ---------------------------------------------------------------- VST (experimental)
// The plugin's name is kept as the device's label, so sets and scenes reopen it.
if (\VSTPlugin.asClass.notNil) {
	~deviceTypes[\vst] = (def: \dVST, cat: \dynamics, params: [~p.(\mix, 1, [0, 1])],
		built: { |t, d|
			d[\vst] = \VSTPluginController.asClass.new(d[\synth]);
			if (d[\label].notNil and: { d[\label] != "vst" }) { { d[\vst].open(d[\label], editor: true) }.defer(0.5) };
		},
		gui: { |t, d| [
			~button.("plugin…", {
				\VSTPlugin.asClass.search(s, action: {
					{
						var keys = \VSTPlugin.asClass.pluginKeys(s);
						Menu(*keys.collect { |k| MenuAction(k.asString, { d[\label] = k.asString; d[\vst].open(k, editor: true); ~refreshDetail.() }) }).front;
					}.defer;
				});
			}),
			~button.("editor", { d[\vst] !? { |v| v.editor } })
		] });
	~vstItems = [["vst plugin", \vst, ()]];
} { ~vstItems = [] };

// Browser entries: a device with preset params, or a whole chain. Drag them onto a track.
~browserItems = [
	[\distortion, [
		["overdrive", \drive, (mode: 0, gain: 4)], ["tube", \drive, (mode: 1, gain: 6)],
		["hard clip", \drive, (mode: 2, gain: 8)], ["wavefold", \drive, (mode: 3, gain: 5)],
		["fuzz", \drive, (mode: 4, gain: 10)], ["rectify", \drive, (mode: 5, gain: 3)],
		["sine shaper", \drive, (mode: 6, gain: 4)], ["crunch", \drive, (mode: 7, gain: 5)],
		["bitcrush", \crush, (bits: 6, rate: 8000)], ["bitrot", \crush, (bits: 3, rate: 1500)],
		["dirt", \dirt, ()]
	]],
	[\filter, [
		["low pass", \filter, (mode: 0, cutoff: 1200, res: 0.4)], ["high pass", \filter, (mode: 1, cutoff: 400)],
		["band pass", \filter, (mode: 2, cutoff: 1500, res: 0.6)], ["drifting filter", \filter, (cutoff: 6000, drift: 0.6)],
		["eq", \eq, ()], ["comb", \comb, ()], ["resonator", \resonator, ()], ["bells", \resonator, (spread: 2.4, decay: 3)],
		["ring mod", \ring, ()], ["freq shift", \shift, ()]
	]],
	[\time, [
		["space", \space, ()], ["huge space", \space, (size: 1, damp: 0.1, mix: 0.6)],
		["echo", \echo, ()], ["slapback", \echo, (time: 0.25, fb: 0.15)], ["dub echo", \echo, (time: 0.75, fb: 0.9, tone: 1500)],
		["chorus", \chorus, ()], ["flanger", \chorus, (delay: 0.002, depth: 0.0015, fb: 0.8, rate: 0.15)],
		["tape", \tape, ()], ["octave down", \pitch, (ratio: 0.5)], ["octave up", \pitch, (ratio: 2)],
		["reverse", \reverse, ()], ["smear", \smear, ()]
	]],
	[\glitch, [
		["stutter", \stutter, ()], ["chop", \chop, ()], ["freeze", \freeze, ()], ["scramble", \scramble, ()],
		["blur", \blur, ()], ["feedback", \feedback, ()], ["screamer", \feedback, (gain: 1.5, drive: 8, res: 0.8)]
	]],
	[\dynamics, [
		["compressor", \compressor, ()], ["gate", \gate, ()], ["width", \width, ()], ["autopan", \width, (autopan: 0.8)],
		["limiter", \limiter, ()]
	] ++ ~vstItems],
	[\chains, [
		["noise wall", [[\drive, (mode: 4, gain: 12)], [\feedback, ()], [\smear, (mix: 0.6)], [\space, (mix: 0.5)]]],
		["broken radio", [[\filter, (mode: 2, cutoff: 1800, res: 0.7)], [\crush, (bits: 5, rate: 4000)], [\dirt, ()], [\chop, (rate: 0.125, depth: 0.7)]]],
		["tape ghost", [[\tape, (wow: 0.7, age: 0.7)], [\reverse, ()], [\echo, (fb: 0.7)], [\space, (mix: 0.5)]]],
		["metal", [[\drive, (mode: 3, gain: 6)], [\resonator, (spread: 2.4, decay: 2)], [\shift, (shift: 300)]]],
		["dissolve", [[\scramble, ()], [\blur, (bins: 30)], [\smear, (mix: 0.7)], [\space, (size: 1, mix: 0.7)]]]
	]]
];

// ---------------------------------------------------------------- managing devices

~convert = { |p, val| if (p[\conv] == \beats) { val / ~clock.tempo } { val } };

~deviceArgs = { |d|
	~deviceTypes[d[\type]][\params].collect { |p| [p[\key], ~convert.(p, d[\params][p[\key]])] }.flatten
};

~buildDevice = { |t, d|
	d[\synth] = Synth.tail(t[\fxg], ~deviceTypes[d[\type]][\def], [bus: t[\bus]] ++ ~deviceArgs.(d));
	if (d[\on].not) { d[\synth].run(false) };
	~deviceTypes[d[\type]][\built].value(t, d);
};

~orderDevices = { |t| t[\devices].do { |d| d[\synth].moveToTail(t[\fxg]) } };

~startDevice = { |t, d|
	var m = ~deviceTypes[d[\type]][\mover];
	d[\routine].stop;
	if (m.notNil) { d[\routine] = Routine({ m.value(t, d) }).play(~clock, quant: 1) };
};

// ~dev.(\master, \crush)  or  ~dev.(\keys, \echo, 0, (fb: 0.9)) to put it first with settings.
// New devices go before pinned ones (the master limiter). Returns the device.
~dev = { |name, type, index, preset, label|
	var t = ~tracks[name], dt = ~deviceTypes[type], d, last;
	if (t.isNil or: { dt.isNil }) { "unsound: no track % or device %".format(name, type).warn; nil } {
		~nextUid = (~nextUid ? 0) + 1;
		d = (type: type, on: true, params: (), label: label, uid: ~nextUid);
		dt[\params].do { |p| d[\params][p[\key]] = p[\default] };
		~rollMystery.(d);
		if (t[\kind] == \return and: { d[\params][\mix].notNil }) { d[\params][\mix] = 1 };
		(preset ? ()).keysValuesDo { |k, v| d[\params][k] = v };
		last = t[\devices].count { |x| x[\pinned] != true };
		index = (index ? last).clip(0, last);
		t[\devices].insert(index, d);
		~buildDevice.(t, d);
		~orderDevices.(t);
		~soDevice.(t, d);
		if (~running == true) { ~startDevice.(t, d) };
		if (~alive == true and: { ~booted == true } and: { t[\kind] != \master } and: { d[\pinned] != true }) { ~infectDevice.(t, d) };
		~refreshDetail.();
		d
	}
};

// Add a browser item (a device preset or a chain) to a track.
~addItem = { |name, item, index|
	if (item[1].isKindOf(Symbol)) { ~dev.(name, item[1], index, item[2], item[0]) } {
		item[1].do { |c, i| ~dev.(name, c[0], index !? { index + i }, c[1]) };
	};
};

// Set a device parameter. `d` is the device Event (or use ~dset with a track and index).
~dparam = { |d, key, val|
	var p = ~deviceTypes[d[\type]][\params].detect { |x| x[\key] == key };
	d[\params][key] = val;
	if (p.notNil) { d[\synth].set(key, ~convert.(p, val)) };
};

~dset = { |name, index, key, val| ~dparam.(~tracks[name][\devices][index], key, val) };

~dbypass = { |d| d[\on] = d[\on].not; d[\synth].run(d[\on]) };

~drem = { |name, d|
	if (d[\pinned] != true) {
		~unmodPrefix.("d:%:".format(d[\uid]));
		~soRemovePrefix.("d:%:".format(d[\uid]));
		d[\routine].stop;
		d[\synth].free;
		~tracks[name][\devices].remove(d);
		~refreshDetail.();
	};
};

~dmove = { |name, d, dir|
	var list = ~tracks[name][\devices], i = list.indexOf(d), j = i + dir;
	if (j >= 0 and: { j < list.size } and: { d[\pinned] != true } and: { list[j][\pinned] != true }) {
		list.swap(i, j);
		~orderDevices.(~tracks[name]);
		~refreshDetail.();
	};
};

// Free and rebuild a track's whole chain from a list of device descriptions (used by scenes).
~setChain = { |name, descs|
	var t = ~tracks[name];
	t[\devices].do { |d| d[\routine].stop; d[\synth].free; ~unmodPrefix.("d:%:".format(d[\uid])); ~soRemovePrefix.("d:%:".format(d[\uid])) };
	t[\devices] = List.newFrom(descs.collect { |x|
		var d = (type: x[\type], on: x[\on], params: x[\params].copy, label: x[\label], pinned: x[\pinned],
			uid: x[\uid] ?? { ~nextUid = (~nextUid ? 0) + 1 });
		~nextUid = (~nextUid ? 0).max(d[\uid]);
		~rollMystery.(d);
		~buildDevice.(t, d);
		~soDevice.(t, d);
		if (~running == true) { ~startDevice.(t, d) };
		d
	});
	~refreshDetail.();
};

// Re-send beat-based params after a tempo change.
~retimeDevices = {
	~tracks.do { |t| t[\devices].do { |d| d[\synth].set(*~deviceArgs.(d)) } };
};
