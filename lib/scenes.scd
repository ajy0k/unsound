// Scenes and song structure.
//
// A scene is a snapshot of everything you can set: every track's settings, sends, piano roll,
// step pattern and waveforms, every device chain, and tempo, chaos, scale and key.
// Launching a scene morphs numeric settings to it over `~morphBeats`, and swaps everything else
// at the start (device chains are rebuilt only if they differ).
//
// A song is a list of [scene index, bars]; ~playSong steps through it, morphing as it goes.
// A saved set is the current state plus all scenes and the song, in one file.

~scenes = List[];
~song = List[];          // e.g. [[0, 16], [1, 8], [0, 8], [2, 32]]
~morphBeats = 4;

// Settings that are runtime state, not something you set.
~runtimeKeys = [\id, \meter, \meterShow, \pos, \abs, \deg, \cursor, \head, \lastBuf, \lastPos, \tdrift,
	\toneOff, \barAcc, \color, \heard, \routine, \ramps, \strip, \grp, \src, \fxg, \bus, \inBus, \fbBus,
	\carBuf, \modBuf, \devices, \sends, \live, \held, \voice];

~storable = { |v|
	v.isNumber or: { v.isKindOf(Symbol) } or: { v.isKindOf(Boolean) }
		or: { v.isKindOf(String) } or: { v.isArray and: { v.every(_.isNumber) } }
};

~trackState = { |t|
	var st = ();
	t.keysValuesDo { |k, v|
		if (~runtimeKeys.includes(k).not and: { ~storable.(v) }) { st[k] = v.copy };
	};
	if (t[\roll].notNil) { st[\roll] = t[\roll].deepCopy };
	if (t[\lanes].notNil) {
		st[\lanes] = t[\lanes].collect { |ln|
			var e = ();
			ln.keysValuesDo { |k, v| if ([\grain, \pos, \flash].includes(k).not) { e[k] = v.copy } };
			e
		};
	};
	st[\sends] = ();
	~returnOrder.do { |r, i| st[\sends][r] = t[\sends][i] };
	st[\devices] = t[\devices].collect { |d|
		(type: d[\type], on: d[\on], params: d[\params].copy, label: d[\label], pinned: d[\pinned], uid: d[\uid])
	}.asArray;
	st
};

~snapshot = {
	(tempo: ~tempo, chaos: ~m[\chaos], scaleName: ~scaleName, key: ~key, mods: ~modState.(),
		tracks: (~voiceOrder ++ ~returnOrder ++ [\master]).collect { |n| ~trackState.(~tracks[n]) }.asArray)
};

~sameChain = { |t, descs|
	t[\devices].size == descs.size and: { t[\devices].every { |d, i| d[\type] == descs[i][\type] } }
};

// Apply a snapshot. `beats` > 0 morphs numbers there; `exact` also creates missing tracks and
// removes tracks the snapshot doesn't have (used when loading a set).
~applyState = { |state, beats = 0, exact = false|
	var glides = List[], names;
	if (exact) {
		names = state[\tracks].collect { |ts| ts[\name] };
		(~voiceOrder.copy ++ ~returnOrder.copy).do { |n| if (names.includes(n).not) { ~remove.(n) } };
		state[\tracks].do { |ts|
			if (~tracks[ts[\name]].isNil) {
				switch (ts[\kind])
				{ \inst } { ~add.(ts[\type], (name: ts[\name])) }
				{ \return } { ~addReturn.(nil, ts[\name]) };
			};
		};
	};
	~m[\chaos] = state[\chaos];
	~scaleName = state[\scaleName];
	~scale = Scale.at(~scaleName);
	~key = state[\key];
	if (beats > 0) { glides.add([{ |x| ~bpm.(x) }, ~tempo, state[\tempo]]) } { ~bpm.(state[\tempo]) };

	state[\tracks].do { |ts|
		var t = ~tracks[ts[\name]];
		if (t.notNil) {
			ts.keysValuesDo { |k, v|
				case
				{ [\name, \kind, \type, \devices, \sends].includes(k) } { }
				{ k == \roll } { t[\roll] = v.deepCopy }
				{ k == \lanes } { v.do { |lv, i| t[\lanes][i] !? { |ln| lv.keysValuesDo { |kk, vv| ln[kk] = vv.copy } } } }
				{ k == \pat } { t[\pat] = v.copy; t[\live] = v.copy }
				{ [\carWave, \modWave].includes(k) } { ~setWave.(t, k, v.copy) }
				{ beats > 0 and: { v.isNumber } and: { t[k].isNumber } and: { v != t[k] } } {
					glides.add([{ |x| ~tset.(t[\name], k, x) }, t[k], v]);
				}
				{ ~tset.(t[\name], k, v.copy) };
			};
			ts[\sends].keysValuesDo { |r, v|
				var i = ~returnOrder.indexOf(r);
				if (i.notNil) {
					if (beats > 0) { glides.add([{ |x| ~send.(t[\name], r, x) }, t[\sends][i], v]) } { ~send.(t[\name], r, v) };
				};
			};
			if (~sameChain.(t, ts[\devices])) {
				t[\devices].do { |d, i|
					var target = ts[\devices][i];
					target[\uid] !? { |u| d[\uid] = u; ~nextUid = (~nextUid ? 0).max(u) };
					if (d[\on] != target[\on]) { ~dbypass.(d) };
					target[\params].keysValuesDo { |k, v|
						if (beats > 0 and: { v.isNumber } and: { v != d[\params][k] }) {
							glides.add([{ |x| ~dparam.(d, k, x) }, d[\params][k], v]);
						} { ~dparam.(d, k, v) };
					};
				};
			} { ~setChain.(t[\name], ts[\devices]) };
		};
	};

	// mods last, once every device they point at exists
	state[\mods] !? { |ms| ~applyMods.(ms) };

	~morph.stop;
	if (glides.notEmpty) {
		~morph = Routine({
			var steps = (beats * 8).asInteger.max(1);
			steps.do { |i|
				var x = (i + 1) / steps;
				glides.do { |g| g[0].value(g[1] + ((g[2] - g[1]) * x)) };
				0.125.wait;
			};
		}).play(~clock);
	};
	~refreshDetail.();
};

~capture = { |name|
	~scenes.add((name: name ?? { "scene " ++ (~scenes.size + 1) }, state: ~snapshot.()));
	~refreshScenes.value;
	~scenes.size - 1
};

~launch = { |i, beats|
	var sc = ~scenes[i];
	if (sc.notNil) {
		~currentScene = i;
		~applyState.(sc[\state], beats ? ~morphBeats);
		~refreshScenes.value;
	};
};

~updateScene = { |i| if (~scenes[i].notNil) { ~scenes[i][\state] = ~snapshot.() } };
~deleteScene = { |i| if (~scenes[i].notNil) { ~scenes.removeAt(i); ~refreshScenes.value } };

// Play the song: each entry is [scene index, bars]. Loops when `loop` is true.
~playSong = { |loop = true|
	~songRoutine.stop;
	if (~song.notEmpty) {
		~songRoutine = Routine({
			var go = true;
			while { go } {
				~song.do { |entry| ~launch.(entry[0]); (entry[1] * 4).wait };
				go = loop;
			};
		}).play(~clock, quant: 4);
	};
};
~stopSong = { ~songRoutine.stop; ~songRoutine = nil };

// ---------------------------------------------------------------- sets on disk

~setsDir = ~root +/+ "sets";

~saveSet = { |path|
	var f;
	path = path ?? { ~setsDir +/+ Date.getDate.stamp ++ ".unsound" };
	File.mkdir(path.dirname);
	f = File(path, "w");
	f.write((state: ~snapshot.(), scenes: ~scenes.asArray, song: ~song.asArray, morphBeats: ~morphBeats,
		midi: ~midiState.(), events: ~events, lurchDistance: ~lurchDistance).asCompileString);
	f.close;
	"unsound: saved %".format(path).postln;
	path
};

~loadSet = { |path|
	var set = path.load;
	if (set.isNil) { "unsound: couldn't read %".format(path).warn } {
		~scenes = List.newFrom(set[\scenes]);
		~song = List.newFrom(set[\song]);
		~morphBeats = set[\morphBeats] ? 4;
		set[\events] !? { |e| ~events = e };
		~lurchDistance = set[\lurchDistance] ? ~lurchDistance;
		~applyState.(set[\state], 0, true);
		set[\midi] !? { |m| ~applyMidi.(m) };
		~refreshGui.();
		"unsound: loaded %".format(path).postln;
	};
};
