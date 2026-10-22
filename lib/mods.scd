// Modulation on anything, including other modulators.
//
// A mod moves one target (any knob: a device param, an instrument param, a send, another mod's
// rate or depth) around a home value. Turning a modulated knob moves its home; the knob shows the
// live value. Right-click (or alt-click) any knob to give it a mod or take it away.
//
// A target is (tid: stable id, name:, spec:, get:, set:). Mods run at 30 Hz on the SystemClock.
//
// A mod's `source` is what moves it: \shape (its own LFO/random/chaos shape), "follow:<track>"
// (that track's loudness — negative depth ducks), or "mod:<id>" (another mod's output, so
// everything can drive everything). Depth runs from -1 to 1; negative inverts.
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
		m = (id: ~nextModId, target: target, shape: shape ?? { ~modShapes.choose }, source: \shape,
			rate: rate ?? { exprand(0.04, 1.5) }, depth: depth ?? { rrand(0.1, 0.45) },
			home: target[\spec].unmap(target[\get].value ? target[\spec].default),
			phase: 1.0.rand, val: 0, held: 0, x: 1.0.rand);
		// a mod's own knobs are targets too: that's mods on mods
		m[\rateTarget] = (tid: "m:%:rate".format(m[\id]), name: "rate of " ++ target[\name],
			spec: ControlSpec(0.01, 20, \exp), get: { m[\rate] }, set: { |x| m[\rate] = x });
		m[\depthTarget] = (tid: "m:%:depth".format(m[\id]), name: "depth of " ++ target[\name],
			spec: ControlSpec(-1, 1), get: { m[\depth] }, set: { |x| m[\depth] = x });
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

~sourceValue = { |m|
	var src = m[\source].asString, t, other;
	case
	{ src.beginsWith("follow:") } {
		t = ~tracks[src.drop(7).asSymbol];
		t !? { ((t[\meter][0] ? 0).max(t[\meter][1] ? 0) + 1e-6).ampdb.linlin(-48, 0, -1, 1) }
	}
	{ src.beginsWith("mod:") } {
		other = ~mods.detect { |x| x[\id] == src.drop(4).asInteger };
		other !? { other[\val] }
	}
};

~stepMod = { |m, dt|
	var p0 = m[\phase], p, crossed, v, ext = ~sourceValue.(m);
	p = p0 + (m[\rate] * dt);
	m[\phase] = p;
	crossed = p.floor > p0.floor;
	v = if (ext.notNil) { ext } { switch (m[\shape])
	{ \sine } { sin(2pi * p) }
	{ \tri } { ((p * 2) % 2 - 1).abs * 2 - 1 }
	{ \square } { if (p.frac < 0.5) { 1 } { -1 } }
	{ \saw } { p.frac * 2 - 1 }
	{ \random } { if (crossed) { m[\held] = 1.0.rand2 }; m[\held] }
	{ \drunk } { m[\x] = (m[\x] + 0.gauss(m[\rate] * dt * 2)).fold(-1, 1); m[\x] }
	{ \chaos } { var x = m[\x].abs.clip(0.01, 0.99); if (crossed) { x = 3.93 * x * (1 - x) }; m[\x] = x; x * 2 - 1 }
	{ \burst } { if (crossed and: { 0.35.coin }) { m[\held] = 1 } { m[\held] = m[\held] * 0.85 }; m[\held] * 2 - 1 }
	{ 0 } };
	// a little slew so stepped shapes click less (followers: `rate` sets how fast they follow)
	m[\val] = m[\val] + ((v - m[\val]) * (if (ext.notNil) { (m[\rate] * 0.1).clip(0.02, 1) } { 0.5 }));
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

// Everything on a track that can be modulated without a knob on screen: used by infect.
// The master is never in here: it's yours, by hand.
~targetsOf = { |t|
	var out = List[];
	if (t[\kind] != \master) {
		t[\devices].do { |d|
			if (d[\pinned] != true) {
				~deviceTypes[d[\type]][\params].do { |p| if (p[\key] != \mix and: { p[\dice] != false }) { out.add(~deviceTarget.(t, d, p)) } };
				out.add(~mysteryTarget.(t, d));
			};
		};
		if (t[\kind] == \inst) {
			(~voiceTypes[t[\type]][\params] ? []).do { |p| out.add(~trackTarget.(t, p[\key], p[\spec], p[\label])) };
			~voiceTypes[t[\type]][\targets] !? { |f| out.addAll(f.value(t)) };
			out.add(~trackTarget.(t, \pan, [-1, 1]));
			out.add(~trackTarget.(t, \tempoDrift, [0, 1]));
		};
	};
	out
};

~allTargets = { ~tracks.values.collect { |t| ~targetsOf.(t) }.flatten(1) };

// "alive": new tracks and devices arrive already moving.
~alive = true;
~infectTrack = { |t, n = 2|
	~targetsOf.(t).reject { |tg| ~modFor.(tg[\tid]).notNil }.scramble.keep(n).do { |tg| ~addMod.(tg) };
};
~infectDevice = { |t, d|
	var pool = ~deviceTypes[d[\type]][\params].reject { |p| p[\key] == \mix or: { p[\dice] == false } }.collect { |p| ~deviceTarget.(t, d, p) }
		++ [~mysteryTarget.(t, d)];
	~addMod.(pool.choose);
};

// Scatter `n` random mods across the set; some of them land on other mods, some follow
// another track's loudness, some are driven by another mod.
~infect = { |n = 6|
	var pool = ~allTargets.().reject { |tg| ~modFor.(tg[\tid]).notNil }.scramble;
	pool.keep(n).do { |tg|
		var m = ~addMod.(tg), others = ~voiceOrder.reject { |v| tg[\tid].contains(v.asString) };
		case
		{ 0.2.coin and: { others.notEmpty } } { m[\source] = "follow:" ++ others.choose; m[\rate] = exprand(1, 10) }
		{ 0.15.coin and: { ~mods.size > 1 } } { m[\source] = "mod:" ++ (~mods.reject { |x| x === m }.choose[\id]) };
	};
	(n * 0.3).round.asInteger.do {
		var m = ~mods.choose;
		if (m.notNil) { ~addMod.([m[\rateTarget], m[\depthTarget]].choose, nil, exprand(0.02, 0.4)) };
	};
};

// ---------------------------------------------------------------- dice and mystery

// Each device gets a hidden map: the "?" knob sweeps 2–4 of its params between random points.
~rollMystery = { |d|
	var params = ~deviceTypes[d[\type]][\params].reject { |p| p[\key] == \mix or: { p[\dice] == false } };
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

// Set something, or if a mod is moving it, move the mod's home instead (dice and lurch use this).
~setOrHome = { |tid, spec, val, setFn|
	var m = ~modFor.(tid);
	if (m.notNil) { m[\home] = spec.unmap(val) } { setFn.(val) };
};

~diceDevice = { |d|
	if (d[\pinned] != true) {
		~deviceTypes[d[\type]][\params].do { |p|
			if (p[\key] != \mix and: { p[\dice] != false }) {
				~setOrHome.("d:%:%".format(d[\uid], p[\key]), p[\spec], p[\spec].map(1.0.rand), { |x| ~dparam.(d, p[\key], x) });
			};
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
				if (p[\dice] != false) {
					~setOrHome.("t:%:%".format(name, p[\key]), p[\spec], p[\spec].map(1.0.rand), { |x| ~tset.(name, p[\key], x) });
				};
			};
			~voiceTypes[t[\type]][\dice] !? { |f| f.value(t) };
			if (~voiceTypes[t[\type]][\params].isNil and: { ~voiceTypes[t[\type]][\dice].isNil }) { ~repatch.(name) };
		};
		t[\devices].do { |d| ~diceDevice.(d) };
	};
};

// ---------------------------------------------------------------- saving mods

// Find a target from its id (used when loading sets and scenes). `spec` is used for track settings.
~resolveTarget = { |tid, spec|
	var parts = tid.split($:), t, d, p, ln, ret, i;
	switch (parts[0])
	{ "t" } {
		t = ~tracks[parts[1].asSymbol];
		t !? {
			if (parts[2] == "bpm") {
				(tid: tid, name: "% bpm".format(t[\name]), spec: spec, get: { if (t[\sync] != false) { ~tempo } { t[\bpm] } },
					set: { |x| t[\sync] = false; ~tset.(t[\name], \bpm, x) })
			} { ~trackTarget.(t, parts[2].asSymbol, spec) }
		}
	}
	{ "d" } {
		~tracks.do { |x| x[\devices].do { |y| if (y[\uid] == parts[1].asInteger) { t = x; d = y } } };
		d !? {
			case
			{ parts[2] == "?" } { ~mysteryTarget.(t, d) }
			{ parts[2] == "soJump" } {
				(tid: tid, name: "% jump".format(d[\type]), spec: ControlSpec(0, 1), get: { d[\params][\soJump] ? 0 },
					set: { |x| d[\params][\soJump] = x })
			} {
				p = ~deviceTypes[d[\type]][\params].detect { |q| q[\key] == parts[2].asSymbol };
				p !? { ~deviceTarget.(t, d, p) }
			}
		}
	}
	{ "l" } {
		t = ~tracks[parts[1].asSymbol];
		t !? { ~voiceTypes[t[\type]][\targets].value(t).detect { |x| x[\tid] == tid } }
	}
	{ "s" } {
		t = ~tracks[parts[1].asSymbol];
		ret = parts[2].asSymbol;
		t !? {
			(tid: tid, name: "% send %".format(t[\name], ret), spec: ControlSpec(0, 1),
				get: { (~returnOrder.indexOf(ret) !? { |j| t[\sends][j] }) ? 0 }, set: { |x| ~send.(t[\name], ret, x) })
		}
	}
	{ "box" } { ~boxTargets[parts[1].asInteger] }
	{ "btn" } { ~btnTarget.(tid) }
	{ "g" } {
		(tid: tid, name: parts[1], spec: ControlSpec(0, 1), get: { ~events[("so" ++ parts[1].capitalize).asSymbol] ? 0 },
			set: { |x| ~events[("so" ++ parts[1].capitalize).asSymbol] = x })
	}
	{ ~globalTargets.()[tid] };
};

~globalTargets = {
	Dictionary[
		"bpm" -> (tid: "bpm", name: "bpm", spec: ~bpmSpec, get: { ~tempo }, set: { |x| ~bpm.(x) }),
		"chaos" -> (tid: "chaos", name: "chaos", spec: ControlSpec(0, 1), get: { ~m[\chaos] }, set: { |x| ~set.(\chaos, x) })
	]
};

~bpmSpec = ControlSpec(1, 20000, \exp);

~modState = {
	~mods.collect { |m|
		(id: m[\id], tid: m[\target][\tid], spec: m[\target][\spec].asCompileString, shape: m[\shape],
			rate: m[\rate], depth: m[\depth], home: m[\home], source: m[\source])
	}.asArray
};

// Replace every mod with saved ones. Mods on mods and "mod:" sources are re-linked to new ids.
~applyMods = { |list|
	var newIds = (), later = List[];
	~cure.();
	list.do { |ms|
		var tg, m;
		if (ms[\tid].beginsWith("m:")) { later.add(ms) } {
			tg = ~resolveTarget.(ms[\tid], ms[\spec].interpret);
			if (tg.notNil) {
				m = ~addMod.(tg, ms[\shape], ms[\rate], ms[\depth]);
				m[\home] = ms[\home];
				m[\source] = ms[\source];
				newIds[ms[\id]] = m;
			};
		};
	};
	later.do { |ms|
		var parts = ms[\tid].split($:), owner = newIds[parts[1].asInteger], m;
		if (owner.notNil) {
			m = ~addMod.(owner[(parts[2] ++ "Target").asSymbol], ms[\shape], ms[\rate], ms[\depth]);
			m[\home] = ms[\home];
			m[\source] = ms[\source];
			newIds[ms[\id]] = m;
		};
	};
	~mods.do { |m|
		var src = m[\source].asString;
		if (src.beginsWith("mod:")) {
			m[\source] = newIds[src.drop(4).asInteger] !? { |x| "mod:" ++ x[\id] } ? \shape;
		};
	};
	~refreshMods.value;
};
