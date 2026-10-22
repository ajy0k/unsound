// Kick: a 16-step pattern you draw. Mutation plays a variation of it (`live`) and drifts back
// home to yours; `mutate` 0 plays exactly what you drew. `busy` sets how many hits a mutation
// aims for.

~defs.add({
	SynthDef(\uKick, { |out, amp = 0.9, freq = 48, sweep = 4, decay = 0.45, click = 0.2, drive = 2|
		var pitch = freq * (1 + (sweep * EnvGen.ar(Env.perc(0.0005, 0.06, curve: -6))));
		var body = SinOsc.ar(pitch, 0.5pi) * EnvGen.ar(Env.perc(0.001, decay, curve: -4), doneAction: 2);
		var clk = HPF.ar(WhiteNoise.ar, 3000) * EnvGen.ar(Env.perc(0.0005, 0.008)) * click;
		OffsetOut.ar(out, (((body + clk) * drive).tanh * amp).dup);
	}).add;
});

~kick = { |t, amp = 1|
	var c = ~m[\chaos];
	s.bind {
		Synth(\uKick, [out: t[\bus], amp: amp * 0.9, freq: t[\tone] + t[\toneOff], decay: t[\decay],
			sweep: t[\sweep] * (1 + (c * 0.5).rand), click: t[\click], drive: t[\drive] * (1 + c.rand)], t[\src])
	};
};

// Pick a step to add a hit on, preferring quarters and eighths unless chaos is high.
~pickStep = { |steps|
	var c = ~m[\chaos];
	steps.wchoose(steps.collect { |i|
		case { i % 4 == 0 } { 5 } { i.even } { 3 } { 0.4 + (c * 2) }
	}.normalizeSum)
};

~mutateKick = { |t|
	var c = ~m[\chaos], live = t[\live], target = (t[\busy] * 8).round.asInteger.max(1);
	if ((t[\mutate] * (0.5 + c)).coin) {
		((t[\mutate] + c * 2).rand.round.asInteger + 1).do {
			var on = (1..15).select { |i| live[i] == 1 };
			var off = (1..15).select { |i| live[i] == 0 };
			var count = on.size + live[0];
			case
			{ count < target and: { off.notEmpty } } { live[~pickStep.(off)] = 1 }
			{ count > target and: { on.notEmpty } } { live[on.choose] = 0 }
			{ on.notEmpty and: { off.notEmpty } } { live[on.choose] = 0; live[~pickStep.(off)] = 1 };
		};
	} {
		if ((1 - t[\mutate]).coin) { t[\live] = t[\pat].copy };   // home
	};
	t[\toneOff] = (t[\toneOff] + 0.gauss(t[\drift] * 2)).fold(-8, 8);
};

~voiceTypes[\kick] = (
	color: Color(0.9, 0.35, 0.3),
	chain: [[\drive, (mode: 1, gain: 3, mix: 0.6)]],
	key: { |t, midi| ~kick.(t) },
	defaults: (level: 0.9, wander: 0, drift: 0.2, swing: 0, mutate: 0.3,
		tone: 48, decay: 0.45, sweep: 4, click: 0.2, drive: 2, ratchet: 0.1),
	init: { |t|
		t[\pat] = [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0];
		t[\live] = t[\pat].copy;
		t[\toneOff] = 0;
	},
	repatch: { |t|
		t[\tone] = rrand(40, 56);
		t[\decay] = rrand(0.25, 0.7);
		t[\sweep] = rrand(2, 8);
		t[\live] = Array.fill(16, { |i| if (i == 0) { 1 } { (t[\busy] * 0.4).coin.asInteger } });
	},
	mover: { |t|
		var step = 0, n, dur;
		loop {
			if (step == 0) { ~mutateKick.(t) };
			t[\pos] = step;
			dur = 0.25 * (1 + (t[\swing] * (if (step.even) { 1 } { -1 })));
			n = if (t[\live][step] == 1) {
				if ((t[\ratchet] * (0.5 + ~m[\chaos])).coin) { rrand(2, 4) } { 1 }
			} { 0 };
			if (n == 0) { ~vwait.(t, dur) } {
				n.do { |i| ~kick.(t, 1 - (i / n * 0.6)); ~vwait.(t, dur / n) };
			};
			step = (step + 1) % 16;
		}
	},
	pages: { |t| [
		~pg.(t, "kick", [[\tone, [30, 80, \exp]], [\decay, [0.05, 2, \exp]], [\sweep, [0, 12]], [\click, [0, 1]],
			[\drive, [0.5, 10, \exp]], [\swing, [0, 0.4]], [\ratchet, [0, 1]], [\mutate, [0, 1]]])
	] },
	clip: { |t|
		VLayout(
			~row.(
				~button.("clear", { t[\pat] = 0 ! 16; t[\live] = t[\pat].copy }),
				~button.("four", { t[\pat] = [1, 0, 0, 0] ! 4; t[\pat] = t[\pat].flat; t[\live] = t[\pat].copy }),
				~button.("random", { t[\pat] = Array.fill(16, { |i| (i == 0 or: { 0.3.coin }).binaryValue }); t[\live] = t[\pat].copy }),
				~button.("keep variation", { t[\pat] = t[\live].copy }),
				~lbl.("solid = yours · outline = mutation added · dot = mutation removed"),
				~tknob.(t, \speed, [0.25, 4, \exp]),
				~tknob.(t, \mutate, [0, 1]),
				~tknob.(t, \busy, [0, 1])
			),
			[~stepView.(t), stretch: 1]
		)
	},
	device: { |t|
		[~panel.("kick", t[\color], ~row.(
			~tknob.(t, \tone, [30, 80, \exp]),
			~tknob.(t, \decay, [0.05, 2, \exp]),
			~tknob.(t, \sweep, [0, 12]),
			~tknob.(t, \click, [0, 1]),
			~tknob.(t, \drive, [0.5, 10, \exp]),
			~tknob.(t, \swing, [0, 0.4]),
			~tknob.(t, \ratchet, [0, 1]),
			~tknob.(t, \busy, [0, 1]),
			~tknob.(t, \mutate, [0, 1]),
			~tknob.(t, \drift, [0, 1])
		))]
	}
);
