// Noise instruments. Knob names are deliberately vague: each one moves several things at once.
//
//   creature  chaotic generators (Gendy, Latoocarfian, feedback FM, crackle) tangled together
//   bytebeat  integer formulas on a counter, the 8-bit way; `a b c` are shift amounts
//   hum       a self-oscillating four-delay feedback network

~defs.add({
	SynthDef(\uCreature, { |out, gate = 0, pitch = 40, hunger = 0.5, tangle = 0.4, grit = 0.3, breath = 0.5,
		fever = 0.3, rot = 0.2, body = 0.4|
		var env = EnvGen.kr(Env.asr(0.3, 1, 1.5), gate);
		var fb = LocalIn.ar(2);
		var slow = LFNoise2.kr([0.07, 0.13] * (1 + (fever * 12)));
		var f = (pitch.lag(0.3) + (slow * fever * 12)).midicps;
		var gendy = Gendy3.ar((hunger * 6).round, (grit * 6).round, 1, 1, f, 0.2 + (hunger * 0.6), 0.1 + (grit * 0.6), 12);
		var latoo = LatoocarfianC.ar((f * (4 + (tangle * 60))).clip(20, 20000), 1 + (slow[1] * tangle * 2),
			3 - tangle, 0.5 + (fever * 1.2), 0.5) * 0.5;
		var fm = SinOsc.ar(f, (fb * tangle * 8) + (latoo * tangle * 4));
		var crack = Crackle.ar(1.5 + (grit * 0.49)) * grit * 0.5;
		var sig = (gendy * (1 - (tangle * 0.6))) + (fm * (0.2 + tangle)) + (latoo * hunger) + crack;
		sig = (sig * (1 + (rot * 10))).fold2(1) / (1 + (rot * 2));
		sig = RLPF.ar(sig, (breath.linexp(0, 1, 120, 14000) * (1 + (slow * breath))).clip(60, 18000), 0.3 + ((1 - body) * 0.6));
		sig = sig + (CombC.ar(sig, 0.06, (f * 0.5).reciprocal.clip(0.0005, 0.05), body * 3) * body * 0.4);
		LocalOut.ar(DelayC.ar(sig.reverse, 0.5, (0.003 + (tangle * 0.25) + (slow.abs * fever * 0.05)).clip(0.001, 0.49)) * tangle * 0.9);
		Out.ar(out, (LeakDC.ar(sig) * 1.5).tanh * env * 0.5);
	}).add;

	SynthDef(\uBytebeat, { |out, gate = 0, rate = 8000, a = 5, b = 8, c = 3, formula = 0, width = 0.5|
		var env = EnvGen.kr(Env.asr(0.05, 1, 0.5), gate);
		var t = PulseCount.ar(Impulse.ar(rate.lag(0.05).clip(100, 48000)));
		var ai = a.round, bi = b.round, ci = c.round;
		var forms = [
			t * ((t >> ai) | (t >> bi)),
			(t * ci) & (t >> ai),
			t * (((t >> bi) | (t >> ai)) & (63 & (t >> ci))),
			((t >> ai) * (t >> bi)) | (t >> ci),
			(t * (t >> ai)).bitXor(t >> bi),
			(t * ((t >> 9) | (t >> ai))) & (t >> bi),
			(t & (t >> ai)) * ci,
			((t >> ai) & (t >> bi)) * (t & (t >> ci))
		];
		var v = Select.ar(formula.round.clip(0, forms.size - 1), forms) & 255;
		var sig = LeakDC.ar((v / 127.5) - 1);
		Out.ar(out, [sig, DelayN.ar(sig, 0.02, width * 0.02)] * env * 0.3);
	}).add;

	SynthDef(\uHum, { |out, gate = 0, pitch = 36, tension = 0.6, size = 0.4, tint = 0.5, unrest = 0.3, swell = 0.2|
		var env = EnvGen.kr(Env.asr(1, 1, 2), gate);
		var fb = LocalIn.ar(4);
		var excite = (PinkNoise.ar(swell * 0.05) + (Dust2.ar(unrest * 20) * swell)) * env;
		var base = pitch.lag(0.5).midicps.reciprocal * size.linexp(0, 1, 1, 24);
		var wob = ({ LFNoise2.kr(unrest * 2 + 0.01) } ! 4) * unrest * 0.1;
		var d = DelayC.ar(fb + excite, 0.5, (base * [1, 1.37, 1.71, 2.19] * (1 + wob)).clip(0.0002, 0.5));
		d = BPF.ar(d, (tint.linexp(0, 1, 80, 8000) * [1, 1.5, 2.25, 3.1]).clip(30, 16000), 0.6) * 2;
		d = (d * tension.linlin(0, 1, 0.8, 6)).tanh;
		LocalOut.ar([d[1] + d[2], d[2] - d[3], d[3] + d[0], d[0] - d[1]] * 0.62);
		Out.ar(out, LeakDC.ar([d[0] + d[2], d[1] + d[3]]) * env * 0.4);
	}).add;
});

~voiceTypes[\creature] = ~droneType.(\uCreature, Color(0.85, 0.35, 0.6), [
	~p.(\pitch, 40, [20, 80, \lin, 1]), ~p.(\hunger, 0.5, [0, 1]), ~p.(\tangle, 0.4, [0, 1]), ~p.(\grit, 0.3, [0, 1]),
	~p.(\breath, 0.5, [0, 1]), ~p.(\fever, 0.3, [0, 1]), ~p.(\rot, 0.2, [0, 1]), ~p.(\body, 0.4, [0, 1])
], [\tangle, \breath], [[\drive, (mode: 3, gain: 2, mix: 0.4)]],
{ |t, midi| ~tset.(t[\name], \pitch, midi.clip(20, 80)) });

~voiceTypes[\bytebeat] = ~droneType.(\uBytebeat, Color(0.45, 0.9, 0.3), [
	~p.(\rate, 8000, [500, 32000, \exp]), ~p.(\a, 5, [1, 16, \lin, 1]), ~p.(\b, 8, [1, 16, \lin, 1]),
	~p.(\c, 3, [1, 16, \lin, 1]), ~p.(\formula, 0, [0, 7, \lin, 1]), ~p.(\width, 0.5, [0, 1])
], [\a, \b], [[\filter, (cutoff: 5000, res: 0.3, drift: 0.5)], [\echo, (time: 0.375, mix: 0.2)]],
{ |t, midi| ~tset.(t[\name], \rate, 8000 * (midi - 60).midiratio) });

~voiceTypes[\hum] = ~droneType.(\uHum, Color(0.95, 0.85, 0.35), [
	~p.(\pitch, 36, [20, 80, \lin, 1]), ~p.(\tension, 0.6, [0, 1]), ~p.(\size, 0.4, [0, 1]), ~p.(\tint, 0.5, [0, 1]),
	~p.(\unrest, 0.3, [0, 1]), ~p.(\swell, 0.2, [0, 1])
], [\tension, \tint], [[\chop, (rate: 0.5, depth: 0.4, mix: 1)]],
{ |t, midi| ~tset.(t[\name], \pitch, midi.clip(20, 80)) });
