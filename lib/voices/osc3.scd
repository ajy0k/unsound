// osc3: a 3xOsc-style synth. Three oscillators (sine, tri, saw, square, noise), each with its own
// semitones, detune and level. Osc 2 and osc 3 each either mix in, ring-modulate osc 1, FM it, or
// AM it. A built-in LFO wobbles the pitch, and the `lfo →` menu puts a modulator on any knob in one
// click (right-click works too, like everywhere). Plays the piano roll or wanders, like keys and fm.

~osc3Waves = [\sine, \tri, \saw, \square, \noise];
~osc3Modes = [\mix, \ring, \fm, \am];

~defs.add({
	var tables = [\sine, \tri, \saw, \square].collect { |k| ~toWavetable.(~shapes[k].()).asArray };
	~osc3Bufs = Buffer.allocConsecutive(4, s, 2048, 1, { |b, i| b.setnMsg(0, tables[i]) });

	SynthDef(\uOsc3, { |out, freq = 220, sustain = 0.3, amp = 0.2, pan = 0,
		w1 = 2, w2 = 3, w3 = 0, s1 = 0, s2 = -12, s3 = 7, d1 = 0, d2 = 7, d3 = 0, l1 = 0.6, l2 = 0.4, l3 = 0.3,
		m2 = 0, m3 = 1, fmAmt = 1, atk = 0.005, dec = 0.2, sus = 0.6, rel = 0.2,
		cutoff = 5000, res = 0.2, fenv = 0.3, lfoRate = 5, lfoAmt = 0|
		var base = \tables.kr(0);
		var gate = EnvGen.kr(Env([1, 1, 0], [sustain, 0]));
		var env = EnvGen.ar(Env.adsr(atk, dec, sus, rel), gate, doneAction: 2);
		var lfo = SinOsc.kr(lfoRate) * lfoAmt;
		var fr = { |semis, cents| (freq * (semis + (cents / 100) + lfo).midiratio).clip(1, 20000) };
		var osc = { |w, f, ph = 0|
			Select.ar(w.round.clip(0, 4) >= 3.5, [Osc.ar(base + w.round.clip(0, 3), f, ph), WhiteNoise.ar])
		};
		var o2 = osc.(w2, fr.(s2, d2)), o3 = osc.(w3, fr.(s3, d3));
		var pm = ((((m2 - 2).abs < 0.5) * o2) + (((m3 - 2).abs < 0.5) * o3)) * fmAmt * 4;
		var o1 = osc.(w1, fr.(s1, d1), pm);
		var into = { |m, o, l| Select.ar(m.round.clip(0, 3), [o * l, o1 * o * l * 2, DC.ar(0), o1 * (o * 0.5 + 0.5) * l]) };
		var sig = (o1 * l1) + into.(m2, o2, l2) + into.(m3, o3, l3);
		var fe = EnvGen.kr(Env.perc(0.002, dec + 0.05));
		sig = RLPF.ar(sig, (cutoff * (1 + (fenv * 8 * fe))).clip(40, 18000), res.linlin(0, 1, 1, 0.08));
		OffsetOut.ar(out, Pan2.ar(sig.softclip * env * amp * 1.6, pan));
	}).add;
});

~osc3Keys = [\w1, \w2, \w3, \s1, \s2, \s3, \d1, \d2, \d3, \l1, \l2, \l3, \m2, \m3, \fmAmt,
	\atk, \dec, \sus, \rel, \cutoff, \res, \fenv, \lfoRate, \lfoAmt];

~osc3Note = { |t, midi, beats|
	var jump = if (Main.elapsedTime < (t[\jumpUntil] ? 0)) { t[\jumpBy] } { 0 };
	s.bind {
		Synth(\uOsc3, [out: t[\bus], tables: ~osc3Bufs[0].bufnum, freq: (midi + jump).midicps,
			sustain: ~beatSecs.(t, beats) * t[\gate], pan: t[\spread] * 1.0.rand2]
			++ ~osc3Keys.collect { |k| [k, t[k]] }.flatten, t[\src])
	};
};

~osc3Spec = (w1: [0, 4, \lin, 1], w2: [0, 4, \lin, 1], w3: [0, 4, \lin, 1],
	s1: [-24, 24, \lin, 1], s2: [-24, 24, \lin, 1], s3: [-24, 24, \lin, 1],
	d1: [-50, 50], d2: [-50, 50], d3: [-50, 50], l1: [0, 1], l2: [0, 1], l3: [0, 1],
	m2: [0, 3, \lin, 1], m3: [0, 3, \lin, 1], fmAmt: [0, 4],
	atk: [0.001, 2, \exp], dec: [0.01, 2, \exp], sus: [0, 1], rel: [0.01, 4, \exp],
	cutoff: [40, 18000, \exp], res: [0, 1], fenv: [0, 1], lfoRate: [0.05, 40, \exp], lfoAmt: [0, 2]);

~osc3Label = (w1: "wave 1", w2: "wave 2", w3: "wave 3", s1: "semi 1", s2: "semi 2", s3: "semi 3",
	d1: "cents 1", d2: "cents 2", d3: "cents 3", l1: "level 1", l2: "level 2", l3: "level 3",
	m2: "2 into 1", m3: "3 into 1", fmAmt: "fm amt", lfoRate: "lfo rate", lfoAmt: "lfo amt");

// A menu that puts a sine LFO on one of the given targets (or takes it off).
~lfoMenu = { |targets|
	PopUpMenu().canFocus_(false).items_(["lfo → …"] ++ targets.collect { |tg|
		(if (~modFor.(tg[\tid]).notNil) { "● " } { "" }) ++ tg[\name] })
		.action_({ |m|
			var tg = targets[m.value - 1];
			if (tg.notNil) {
				if (~modFor.(tg[\tid]).notNil) { ~removeMod.(~modFor.(tg[\tid])) } { ~addMod.(tg, \sine, exprand(0.1, 3), 0.3) };
			};
			m.items = ["lfo → …"] ++ targets.collect { |x| (if (~modFor.(x[\tid]).notNil) { "● " } { "" }) ++ x[\name] };
			m.value = 0;
		})
};

~voiceTypes[\osc3] = (
	color: Color(0.4, 0.85, 1),
	chain: [[\drive, (mode: 0, gain: 2, mix: 0.4)], [\echo, (time: 0.5, fb: 0.4, mix: 0.2)]],
	key: { |t, midi| ~osc3Note.(t, midi, 0.5) },
	defaults: (level: 0.5, busy: 0.5, wander: 0.2, root: 48, sends: [0.2, 0.2, 0, 0],
		play: \wander, gate: 0.8, spread: 0.3, repeats: 3, repChance: 0, mutate: 0.15, octave: 0,
		w1: 2, w2: 3, w3: 0, s1: 0, s2: -12, s3: 7, d1: 0, d2: 7, d3: 0, l1: 0.6, l2: 0.4, l3: 0.3,
		m2: 0, m3: 1, fmAmt: 1, atk: 0.005, dec: 0.2, sus: 0.6, rel: 0.2,
		cutoff: 5000, res: 0.2, fenv: 0.3, lfoRate: 5, lfoAmt: 0),
	init: { |t| ~melodicInit.(t); ~suggestRoll.(t) },
	repatch: { |t|
		[\w1, \w2, \w3].do { |k| t[k] = [0, 1, 2, 3, 2, 3, 4].choose };
		t[\s2] = [-12, -24, 0, 7, 12, -5].choose;
		t[\s3] = [7, 12, 19, -12, 5, 24].choose;
		t[\m2] = 4.rand; t[\m3] = 4.rand;
		t[\fmAmt] = exprand(0.2, 3);
		t[\d2] = 15.rand2;
	},
	sometimes: [[\soJump, "jump", { |t|
		t[\jumpBy] = [12, -12, 7, 5, 24, -24, 1].choose;
		t[\jumpUntil] = Main.elapsedTime + ~beatSecs.(t, [1, 2, 4].choose);
	}, 0.05]],
	note: ~osc3Note,
	mover: { |t| ~melodicMover.(t, ~osc3Note) },
	pages: { |t| [
		~pg.(t, "osc 1·2", [\w1, \s1, \d1, \l1, \w2, \s2, \d2, \l2].collect { |k| [k, ~osc3Spec[k], ~osc3Label[k] ? k.asString] }),
		~pg.(t, "osc 3·mod", [\w3, \s3, \d3, \l3, \m2, \m3, \fmAmt, \lfoAmt].collect { |k| [k, ~osc3Spec[k], ~osc3Label[k] ? k.asString] }),
		~pg.(t, "env·filter", [\atk, \dec, \sus, \rel, \cutoff, \res, \fenv, \lfoRate].collect { |k| [k, ~osc3Spec[k], ~osc3Label[k] ? k.asString] })
	] },
	clip: { |t| ~rollPanel.(t) },
	device: { |t|
		var k = { |key| ~tknob.(t, key, ~osc3Spec[key], ~osc3Label[key] ? key.asString, 36) };
		var oscPanel = { |n|
			~panel.("osc " ++ n, t[\color], VLayout(
				~menu.((0..4), { t[("w" ++ n).asSymbol].round }, { |x| ~tset.(t[\name], ("w" ++ n).asSymbol, x) }, ~osc3Waves),
				if (n > 1) { ~menu.((0..3), { t[("m" ++ n).asSymbol].round }, { |x| ~tset.(t[\name], ("m" ++ n).asSymbol, x) },
					~osc3Modes.collect { |m| m.asString ++ " → osc 1" }) } { ~lbl.("the carrier") },
				~row.(k.(("s" ++ n).asSymbol), k.(("d" ++ n).asSymbol), k.(("l" ++ n).asSymbol))
			), 170)
		};
		var targets = ~osc3Keys.collect { |key| ~trackTarget.(t, key, ~osc3Spec[key], ~osc3Label[key]) };
		[
			oscPanel.(1), oscPanel.(2), oscPanel.(3),
			~panel.("mod · env · filter", t[\color], VLayout(
				~row.(k.(\fmAmt), k.(\lfoRate), k.(\lfoAmt), ~lfoMenu.(targets)),
				~row.(k.(\atk), k.(\dec), k.(\sus), k.(\rel)),
				~row.(k.(\cutoff), k.(\res), k.(\fenv), ~tknob.(t, \gate, [0.05, 2, \exp], "length", 36)),
				~soRow.(t)
			))
		]
	}
);
