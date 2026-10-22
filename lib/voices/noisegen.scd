// noise: an extensible noise generator. Two layers; each one sweeps *continuously* through the list
// of noise kinds below (so a mod on `kind` morphs white → pink → brown → … instead of switching).
// Then a filter, drive, a pulse gate and stereo width.
//
// To add a kind: add a line to ~noiseKinds and reload. A kind is [name, { |rate, char| mono signal }]
// where `rate` is the layer's rate knob (1 Hz – 20 kHz: density, clock, speed, pitch, whatever the
// kind wants) and `char` is its character knob (0..1). Neighbours in the list crossfade, so put
// kinds that sound related next to each other.

~noiseKinds = [
	["white", { |r, c| WhiteNoise.ar }],
	["pink", { |r, c| PinkNoise.ar * 1.5 }],
	["brown", { |r, c| BrownNoise.ar }],
	["grey", { |r, c| GrayNoise.ar * 0.7 }],
	["bits", { |r, c| Latch.ar(WhiteNoise.ar, Impulse.ar(r)).round(0.05 + (c * 0.95)) }],
	["stepped", { |r, c| LFNoise0.ar(r) }],
	["clipped", { |r, c| LFClipNoise.ar(r) * 0.7 }],
	["smooth", { |r, c| LFNoise2.ar(r) * 1.4 }],
	["velvet", { |r, c| Dust2.ar(r.clip(1, 20000)) * (1 + (c * 3)) }],
	["dust", { |r, c| Decay2.ar(Dust.ar(r.sqrt * 2), 0.0005, 0.002 + (c * 0.05)) * WhiteNoise.ar * 2 }],
	["crackle", { |r, c| Crackle.ar(1.0 + (c * 0.99)) * 0.8 }],
	["rain", { |r, c| var tr = Dust.ar(r.sqrt * 4); Ringz.ar(tr, TExpRand.ar(500, 5000 + (c * 8000), tr), 0.02 + (c * 0.1)) * 0.5 }],
	["wind", { |r, c| BPF.ar(PinkNoise.ar, LFNoise2.kr(0.2 + c).exprange(200, r.clip(300, 8000)), 0.3) * 3 }],
	["radio", { |r, c|
		(BPF.ar(WhiteNoise.ar, LFNoise0.kr(0.3 + (c * 10)).exprange(300, 5000), 0.04) * 5)
		+ (SinOsc.ar(LFNoise0.kr(c * 4 + 0.1).exprange(200, 3000)) * 0.3 * (LFNoise0.kr(3) > 0.3))
	}],
	["metal", { |r, c| (Mix(Pulse.ar([205.3, 304.4, 369.6, 522.7, 540, 800] * (r / 1000).clip(0.05, 20))) * 0.2) + (WhiteNoise.ar * c * 0.3) }],
	["sine fm", { |r, c| SinOsc.ar((r * (1 + (LFNoise0.ar(r * 0.25) * c * 4))).clip(1, 20000)) }],
	["logistic", { |r, c| (Logistic.ar(3.55 + (c * 0.449), r.clip(1, 40000)) * 2 - 1) }],
	["henon", { |r, c| HenonN.ar(r.clip(1, 40000), 1.2 + (c * 0.2), 0.3) * 0.6 }],
	["cusp", { |r, c| CuspN.ar(r.clip(1, 40000), 1, 1.5 + (c * 0.5)) * 0.6 }],
	["gendy", { |r, c| Gendy1.ar(1, 1, 1, 1, r.clip(20, 2000) * 0.5, r.clip(20, 2000), c, c, 12) }]
];

~defs.add({
	SynthDef(\uNoise, { |out, gate = 0, kindA = 1, rateA = 3000, charA = 0.5, levelA = 0.7,
		kindB = 16, rateB = 8000, charB = 0.6, levelB = 0.25, cutoff = 12000, hp = 30, res = 0.1,
		drive = 0, pulse = 0, pulseRate = 4, width = 0.5|
		var env = EnvGen.kr(Env.asr(0.2, 1, 0.8), gate);
		var n = ~noiseKinds.size;
		var layer = { |kind, rate, ch|
			var r = rate.lag(0.05), c = ch.lag(0.05);
			SelectX.ar(kind.lag(0.1).clip(0, n - 1), ~noiseKinds.collect { |k| k[1].value(r, c) })
		};
		var a = LeakDC.ar(layer.(kindA, rateA, charA)) * levelA;
		var b = LeakDC.ar(layer.(kindB, rateB, charB)) * levelB;
		var sig = Pan2.ar(a, width * -0.7) + Pan2.ar(b, width * 0.7);
		sig = RLPF.ar(sig, cutoff.lag(0.05).clip(30, 19000), res.linlin(0, 1, 1, 0.08));
		sig = HPF.ar(sig, hp.lag(0.05).clip(10, 15000));
		sig = SelectX.ar((drive > 0.01).lag(0.05), [sig, (sig * (1 + (drive * 12))).tanh * 0.7]);
		sig = sig * (1 - (pulse * (1 - LFPulse.ar(pulseRate.clip(0.05, 2000), 0, 0.5).lag(0.002))));
		Out.ar(out, sig.clip2(1) * env * 0.6);
	}).add;
});

~voiceTypes[\noise] = ~droneType.(\uNoise, Color(0.8, 0.8, 0.82), [
	~p.(\kindA, 1, [0, ~noiseKinds.size - 1], "kind A"), ~p.(\rateA, 3000, [1, 20000, \exp], "rate A"),
	~p.(\charA, 0.5, [0, 1], "char A"), ~p.(\levelA, 0.7, [0, 1], "level A"),
	~p.(\kindB, 16, [0, ~noiseKinds.size - 1], "kind B"), ~p.(\rateB, 8000, [1, 20000, \exp], "rate B"),
	~p.(\charB, 0.6, [0, 1], "char B"), ~p.(\levelB, 0.25, [0, 1], "level B"),
	~p.(\cutoff, 12000, [30, 19000, \exp]), ~p.(\hp, 30, [10, 15000, \exp], "high pass"), ~p.(\res, 0.1, [0, 1]),
	~p.(\drive, 0, [0, 1]), ~p.(\pulse, 0, [0, 1]), ~p.(\pulseRate, 4, [0.05, 2000, \exp], "pulse rate"),
	~p.(\width, 0.5, [0, 1])
], [\kindA, \cutoff], [[\filter, (cutoff: 9000, drift: 0.4)]],
{ |t, midi| ~tset.(t[\name], \rateA, midi.midicps) });

~voiceTypes[\noise][\sometimes] = ~voiceTypes[\noise][\sometimes] ++ [
	[\soMorph, "morph", { |t|
		// one layer glides to another kind over a bar or two
		var k = [\kindA, \kindB].choose;
		~ramp.(t[\name], k, (~noiseKinds.size - 1).rand.asFloat, [2, 4, 8].choose);
	}, 0.15]
];

~voiceTypes[\noise][\screen] = { |t|
	var names = ~noiseKinds.collect(_[0]);
	var kindMenu = { |key| ~menu.((0 .. names.size - 1), { t[key].round.asInteger }, { |i| ~tset.(t[\name], key, i) }, names) };
	HLayout([~xyPad.(t, \kindA, \cutoff), stretch: 1],
		View().fixedWidth_(150).layout_(VLayout(~lbl.("layer A"), kindMenu.(\kindA), ~lbl.("layer B"), kindMenu.(\kindB), nil).margins_(0)))
};

~voiceTypes[\noise][\clip] = { |t|
	var names = ~noiseKinds.collect(_[0]);
	var kindMenu = { |key| ~menu.((0 .. names.size - 1), { t[key].round.asInteger }, { |i| ~tset.(t[\name], key, i) }, names) };
	var layer = { |l|
		var k = { |key, label| ~tknob.(t, (key ++ l).asSymbol, ~voiceTypes[\noise][\params].detect { |p| p[\key] == (key ++ l).asSymbol }[\spec], label, 50) };
		~panel.("layer " ++ l, t[\color], VLayout(kindMenu.(("kind" ++ l).asSymbol),
			HLayout(k.("kind", "morph"), k.("rate", "rate"), k.("char", "char"), k.("level", "level"), nil))).maxHeight_(150)
	};
	var p = { |key| ~voiceTypes[\noise][\params].detect { |x| x[\key] == key } };
	HLayout(
		[~xyPad.(t, \kindA, \cutoff), stretch: 2],
		[VLayout(
			HLayout(layer.("A"), layer.("B")),
			HLayout(*([\cutoff, \hp, \res, \drive, \pulse, \pulseRate, \width].collect { |key|
				~tknob.(t, key, p.(key)[\spec], p.(key)[\label], 44) } ++ [nil])),
			~soRow.(t),
			~lbl.("add your own kinds: ~noiseKinds in lib/voices/noisegen.scd"),
			nil
		), stretch: 3]
	)
};
