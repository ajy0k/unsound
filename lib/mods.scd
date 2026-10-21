// Modulation on anything, including other modulators.
//
// A mod moves one target (any knob: a device param, an instrument param, a send, another mod's
// rate or depth) around a home value. Turning a modulated knob moves its home; the knob shows the
// live value. Right-click (or alt-click) any knob to give it a mod or take it away.
//
// A target is (tid: stable id, name:, spec:, get:, set:). Mods run at 30 Hz on the SystemClock.
//
// Also here: dice (randomize), infect (scatter random mods across the set) and the mystery "?"
// knob every device has, which moves a hidden random handful of that device's params.

~mods = List[];
~modShapes = [\sine, \tri, \square, \saw, \random, \drunk, \chaos, \burst];
~modRate = 30;

~modFor = { |tid| tid !? { ~mods.detect { |m| m[\target][\tid] == tid } } };

~addMod = { |target, shape, rate, depth|
	var m;
	if (~modFor.(target[\tid]).notNil) { ~modFor.(target[\tid]) } {
		~nextModId = (~nextModId ? 0) + 1;
		m = (id: ~nextModId, target: target, shape: shape ?? { ~modShapes.choose },
			rate: rate ?? { exprand(0.04, 1.5) }, depth: depth ?? { rrand(0.1, 0.45) },
			home: target[\spec].unmap(target[\get].value ? target[\spec].default),
			phase: 1.0.rand, val: 0, held: 0, x: 1.0.rand);
		// a mod's own knobs are targets too: that's mods on mods
		m[\rateTarget] = (tid: "m:%:rate".format(m[\id]), name: "rate of " ++ target[\name],
			spec: ControlSpec(0.01, 20, \exp), get: { m[\rate] }, set: { |x| m[\rate] = x });
		m[\depthTarget] = (tid: "m:%:depth".format(m[\id]), name: "depth of " ++ target[\name],
			spec: ControlSpec(0, 1), get: { m[\depth] }, set: { |x| m[\depth] = x });
		~mods.add(m);
		~refreshMods.value;
		m
	}
};

~removeMod = { |m|
	m[\target][\set].value(m[\target][\spec].map(m[\home]));
	~mods.remove(m);
	// mods on this mod go too
	~mods.select { |x| [m[\rateTarget][\tid], m[\depthTarget][\tid]].includes(x[\target][\tid]) }.do { |x| ~removeMod.(x) };
	~refreshMods.value;
};

// Right-click on a knob.
~toggleMod = { |target|
	var m = ~modFor.(target[\tid]);
	if (m.notNil) { ~removeMod.(m) } { ~addMod.(target) };
};

// Remove every mod whose target id starts with a prefix (a track or device going away).
~unmodPrefix = { |prefix| ~mods.select { |m| m[\target][\tid].beginsWith(prefix) }.do { |m| ~removeMod.(m) } };

~cure = { ~mods.copy.do { |m| ~removeMod.(m) } };

~stepMod = { |m, dt|
	var p0 = m[\phase], p, crossed, v;
	p = p0 + (m[\rate] * dt);
	m[\phase] = p;
	crossed = p.floor > p0.floor;
	v = switch (m[\shape])
	{ \sine } { sin(2pi * p) }
	{ \tri } { ((p * 2) % 2 - 1).abs * 2 - 1 }
	{ \square } { if (p.frac < 0.5) { 1 } { -1 } }
	{ \saw } { p.frac * 2 - 1 }
	{ \random } { if (crossed) { m[\held] = 1.0.rand2 }; m[\held] }
	{ \drunk } { m[\x] = (m[\x] + 0.gauss(m[\rate] * dt * 2)).fold(-1, 1); m[\x] }
	{ \chaos } { var x = m[\x].abs.clip(0.01, 0.99); if (crossed) { x = 3.93 * x * (1 - x) }; m[\x] = x; x * 2 - 1 }
	{ \burst } { if (crossed and: { 0.35.coin }) { m[\held] = 1 } { m[\held] = m[\held] * 0.85 }; m[\held] * 2 - 1 }
	{ 0 };
	// a little slew so stepped shapes click less
	m[\val] = m[\val] + ((v - m[\val]) * 0.5);
	m[\target][\set].value(m[\target][\spec].map((m[\home] + (m[\depth] * m[\val])).clip(0, 1)));
};

~startMods = {
	~modTask.stop;
	~modTask = Routine({
		var dt = ~modRate.reciprocal;
		loop {
			~mods.copy.do { |m| try { ~stepMod.(m, dt) } { ~mods.remove(m) } };
			dt.wait;
		}
	}).play(SystemClock);
};

// ---------------------------------------------------------------- targets

~trackTarget = { |t, key, spec, label|
	(tid: "t:%:%".format(t[\name], key), name: "% %".format(t[\name], label ? key), spec: spec.asSpec,
		get: { t[key] }, set: { |x| ~tset.(t[\name], key, x) })
};

~deviceTarget = { |t, d, p|
	(tid: "d:%:%".format(d[\uid], p[\key]), name: "% % %".format(t[\name], d[\label] ? d[\type], p[\label]),
		spec: p[\spec], get: { d[\params][p[\key]] }, set: { |x| ~dparam.(d, p[\key], x) })
};

~mysteryTarget = { |t, d|
	(tid: "d:%:?".format(d[\uid]), name: "% % ?".format(t[\name], d[\label] ? d[\type]),
		spec: ControlSpec(0, 1), get: { d[\q] }, set: { |x| ~dmystery.(d, x) })
};

// Everything that can be modulated without a knob on screen: used by infect.
~allTargets = {
	var out = List[];
	~tracks.do { |t|
		t[\devices].do { |d|
			if (d[\pinned] != true) {
				~deviceTypes[d[\type]][\params].do { |p| if (p[\key] != \mix) { out.add(~deviceTarget.(t, d, p)) } };
				out.add(~mysteryTarget.(t, d));
			};
		};
		if (t[\kind] == \inst) {
			(~voiceTypes[t[\type]][\params] ? []).do { |p| out.add(~trackTarget.(t, p[\key], p[\spec], p[\label])) };
			out.add(~trackTarget.(t, \pan, [-1, 1]));
			out.add(~trackTarget.(t, \tempoDrift, [0, 1]));
		};
	};
	out
};

// Scatter `n` random mods across the set; some of them land on other mods.
~infect = { |n = 6|
	var pool = ~allTargets.().reject { |tg| ~modFor.(tg[\tid]).notNil }.scramble;
	pool.keep(n).do { |tg| ~addMod.(tg) };
	(n * 0.3).round.asInteger.do {
		var m = ~mods.choose;
		if (m.notNil) { ~addMod.([m[\rateTarget], m[\depthTarget]].choose, nil, exprand(0.02, 0.4)) };
	};
};

// ---------------------------------------------------------------- dice and mystery

// Each device gets a hidden map: the "?" knob sweeps 2–4 of its params between random points.
~rollMystery = { |d|
	var params = ~deviceTypes[d[\type]][\params].reject { |p| p[\key] == \mix };
	d[\mystery] = params.scramble.keep(rrand(2, 4).min(params.size)).collect { |p|
		[p[\key], 1.0.rand, 1.0.rand]
	};
	d[\q] = 0.5;
};

~dmystery = { |d, q|
	var params = ~deviceTypes[d[\type]][\params];
	d[\q] = q;
	(d[\mystery] ? []).do { |mk|
		var p = params.detect { |x| x[\key] == mk[0] };
		if (p.notNil and: { ~modFor.("d:%:%".format(d[\uid], p[\key])).isNil }) {
			~dparam.(d, p[\key], p[\spec].map(mk[1] + ((mk[2] - mk[1]) * q)));
		};
	};
};

~diceDevice = { |d|
	if (d[\pinned] != true) {
		~deviceTypes[d[\type]][\params].do { |p|
			if (p[\key] != \mix) { ~dparam.(d, p[\key], p[\spec].map(1.0.rand)) };
		};
		~rollMystery.(d);
	};
};

// New random settings for a track's instrument (if it lists params) and every device on it.
~diceTrack = { |name|
	var t = ~tracks[name];
	if (t.notNil) {
		if (t[\kind] == \inst) {
			(~voiceTypes[t[\type]][\params] ? []).do { |p|
				if (p[\dice] != false) { ~tset.(name, p[\key], p[\spec].map(1.0.rand)) };
			};
			if (~voiceTypes[t[\type]][\params].isNil) { ~repatch.(name) };
		};
		t[\devices].do { |d| ~diceDevice.(d) };
	};
};
