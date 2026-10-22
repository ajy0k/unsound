// LFOs, Serum / Vital style: shapes you draw, at a rate you set (synced to the tempo or free),
// dragged onto any knob. Any number of them.
//
// An LFO is (id, color, points, sync, beats, hz, phase, val). `points` is a list of [x, y, curve]:
// x and y run 0..1, the first point is at x = 0 and the last at x = 1, and `curve` bends the
// segment that starts at that point (0 = straight). The output (`val`) is bipolar, -1..1.
//
// Using one: drop its handle on a knob. That knob gets a mod whose source is "lfo:<id>"; drag the
// knob's outer ring (or cmd-drag the knob) to set how much. The mods panel lists it like any mod.
// An LFO's own rate is a knob too, so LFOs can modulate LFOs.

~lfos = List[];
~lfoColors = [Color(0.35, 0.85, 1), Color(1, 0.45, 0.85), Color(0.6, 1, 0.35), Color(1, 0.8, 0.25),
	Color(0.75, 0.55, 1), Color(1, 0.55, 0.35), Color(0.4, 1, 0.8), Color(0.95, 0.95, 0.95)];
~lfoSyncs = [32, 16, 8, 4, 2, 1, 0.5, 0.25, 0.125];
~lfoSyncNames = ["8 bars", "4 bars", "2 bars", "1 bar", "1/2", "1/4", "1/8", "1/16", "1/32"];

~lfoShapes = (
	sine: { 17.collect { |i| [i / 16, 0.5 + (0.5 * sin(2pi * i / 16)), 0] } },
	tri: { [[0, 0.5, 0], [0.25, 1, 0], [0.75, 0, 0], [1, 0.5, 0]] },
	sawUp: { [[0, 0, 0], [1, 1, 0]] },
	sawDown: { [[0, 1, 0], [1, 0, 0]] },
	square: { [[0, 1, 0], [0.5, 1, 0], [0.501, 0, 0], [1, 0, 0]] },
	pluck: { [[0, 1, -6], [1, 0, 0]] },
	swell: { [[0, 0, 5], [1, 1, 0]] },
	steps: { var n = 8; n.collect { |i| [[i / n, i / (n - 1), 0], [(i + 1) / n - 0.001, i / (n - 1), 0]] }.flatten(1) ++ [[1, 1, 0]] },
	random: { var n = rrand(3, 9); [[0, 1.0.rand, 0]] ++ (1 .. n - 1).collect { |i| [i / n + 0.05.rand2, 1.0.rand, 6.rand2] } ++ [[1, 1.0.rand, 0]] }
);
~lfoShapeNames = [\sine, \tri, \sawUp, \sawDown, \square, \pluck, \swell, \steps, \random];

~newLfo = { |shape|
	var l;
	~nextLfoId = (~nextLfoId ? 0) + 1;
	l = (id: ~nextLfoId, sync: true, beats: [4, 2, 8, 1].wrapAt(~nextLfoId - 1), hz: 1, phase: 0, val: 0,
		color: ~lfoColors.wrapAt(~nextLfoId - 1));
	l[\points] = ~lfoShapes[shape ? \sine].value.collect(_.copy);
	~lfos.add(l);
	~refreshLfos.value;
	l
};

~removeLfo = { |l|
	var src = "lfo:" ++ l[\id];
	~mods.select { |m| m[\source] == src }.do { |m| ~removeMod.(m) };
	~lfos.remove(l);
	~refreshLfos.value;
};

~lfoFor = { |id| ~lfos.detect { |l| l[\id] == id } };

// The shape's value at x (0..1), in 0..1.
~lfoAt = { |l, x|
	var pts = l[\points], i = 0, a, b, t, c, f;
	x = x.clip(0, 1);
	while { i < (pts.size - 2) and: { pts[i + 1][0] < x } } { i = i + 1 };
	a = pts[i]; b = pts[i + 1] ? a;
	t = if (b[0] - a[0] > 1e-6) { ((x - a[0]) / (b[0] - a[0])).clip(0, 1) } { 1 };
	c = a[2] ? 0;
	f = if (c.abs < 0.01) { t } { (exp(c * t) - 1) / (exp(c) - 1) };
	a[1] + ((b[1] - a[1]) * f)
};

~stepLfo = { |l, dt|
	l[\phase] = if (l[\sync]) {
		((~clock !? { |c| c.beats } ? 0) / l[\beats].max(0.001)).frac
	} {
		(l[\phase] + (l[\hz] * dt)).frac
	};
	l[\val] = ~lfoAt.(l, l[\phase]) * 2 - 1;
};

// Point an LFO at a target (any knob's target). Reuses the knob's mod if it has one.
~assignLfo = { |id, target|
	var m = ~modFor.(target[\tid]) ?? { ~addMod.(target, \sine, 1, 0.3) };
	m[\source] = "lfo:" ++ id;
	~refreshMods.value;
	m
};

~lfoTarget = { |l|
	(tid: "lfo:%:hz".format(l[\id]), name: "LFO % rate".format(l[\id]), spec: ControlSpec(0.01, 30, \exp),
		get: { l[\hz] }, set: { |x| l[\hz] = x; l[\sync] = false })
};

~lfoState = { ~lfos.collect { |l| (id: l[\id], sync: l[\sync], beats: l[\beats], hz: l[\hz], points: l[\points].deepCopy) }.asArray };

~applyLfos = { |list|
	~lfos = List.newFrom(list.collect { |e|
		~nextLfoId = (~nextLfoId ? 0).max(e[\id]);
		(id: e[\id], sync: e[\sync], beats: e[\beats], hz: e[\hz], points: e[\points].deepCopy, phase: 0, val: 0,
			color: ~lfoColors.wrapAt(e[\id] - 1))
	});
	~refreshLfos.value;
};

~startLfos = { 3.do { |i| ~newLfo.([\sine, \sawDown, \steps][i]) } };
