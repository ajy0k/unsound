// Sometimes: "every so often, at random intervals". Each one is a button (do it now) and a slider
// with no numbers (how often). At 0 it never happens; at the top it happens a few times a second.
// Intervals are random (Poisson), so it never settles into a rhythm.
//
// An entry is (id:, get: { 0..1 }, action: { }, last: time it last fired). Ids look like mod target
// ids ("t:<track>:<key>", "d:<uid>:<key>", "g:<name>"), so the sliders can be modulated too.
// Tracks register theirs from the instrument's `sometimes` list; every device gets "jump"; the
// transport has glide and cut. Nothing fires while the transport is stopped.

~soEntries = List[];

// Mean seconds between firings for a slider value: 0 → never, 0.01 → about a minute, 1 → 0.25 s.
~soInterval = { |v| 60 * ((0.25 / 60) ** v) };

~soAdd = { |id, get, action|
	var e;
	~soRemove.(id);
	e = (id: id, get: get, action: action, last: 0);
	~soEntries.add(e);
	e
};

~soRemove = { |id| ~soEntries.removeAllSuchThat { |e| e[\id] == id } };
~soRemovePrefix = { |prefix| ~soEntries.removeAllSuchThat { |e| e[\id].beginsWith(prefix) } };
~soFor = { |id| ~soEntries.detect { |e| e[\id] == id } };

~soFire = { |e|
	e[\last] = Main.elapsedTime;
	try { e[\action].value } { |err| "unsound: sometimes % failed: %".format(e[\id], err.errorString).postln };
};

~startSometimes = {
	~soTask.stop;
	~soTask = Routine({
		var dt = 0.05;
		loop {
			if (~running == true) {
				~soEntries.copy.do { |e|
					var v = (e[\get].value ? 0).clip(0, 1);
					if (v > 0.001 and: { (dt / ~soInterval.(v)).coin }) { { ~soFire.(e) }.defer };
				};
			};
			dt.wait;
		}
	}).play(SystemClock);
};

// A track's sometimes: the instrument's own list, plus "new sound" for every instrument.
// Values live on the track (so scenes, dice and morphs carry them).
~soTrack = { |t|
	~soList.(t).do { |so|
		if (t[so[0]].isNil) { t[so[0]] = so[3] ? 0 };
		~soAdd.("t:%:%".format(t[\name], so[0]), { t[so[0]] }, { so[2].value(t) });
	};
};

// [key, label, action, default] for a track.
~soList = { |t|
	var it = ~voiceTypes[t[\type]];
	(it[\sometimes] ? []) ++ [[\soNew, "new sound", { |t| ~repatch.(t[\name]) }, 0]]
};

// Every device: "jump" throws its mystery knob somewhere new (unless a mod is moving it).
~soDevice = { |t, d|
	d[\params][\soJump] = d[\params][\soJump] ? 0;
	~soAdd.("d:%:soJump".format(d[\uid]), { d[\params][\soJump] }, {
		if (~modFor.("d:%:?".format(d[\uid])).isNil) { ~dmystery.(d, 1.0.rand) };
	});
};

~soGlobal = {
	~soAdd.("g:glide", { ~events[\soGlide] ? 0 }, { ~glide.() });
	~soAdd.("g:cut", { ~events[\soCut] ? 0 }, { ~cut.() });
	~soAdd.("g:back", { ~events[\soBack] ? 0 }, { ~back.(~morphBeats) });
};
