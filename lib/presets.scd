// Your own instruments and chains, like Ableton presets / racks.
//
// An instrument preset is a whole track: the instrument with all its settings (patterns, drawn waves,
// loaded files, sends), its effect chain, and its mods (mods on mods too; links to LFOs are kept if
// that LFO exists when it's loaded). A chain preset is just the effects, to drop on any track.
// They're files in ~/Music/unsound/instruments and ~/Music/unsound/chains, and show up in the
// browser under MY INSTRUMENTS and MY CHAINS.

~presetDir = { |kind| ~recDir +/+ (if (kind == \chain) { "chains" } { "instruments" }) };
~presetExt = (instrument: "inst", chain: "chain");

// Letters, digits and dashes (track names end up inside ids like "t:<name>:key").
~safeName = { |str|
	var s = str.asString.toLower.collect { |c| if (c.isAlphaNum) { c } { $- } };
	while { s.contains("--") } { s = s.replace("--", "-") };
	s = s.select { |c, i| (i == 0 and: { c == $- }).not };
	if (s.isEmpty) { "untitled" } { s }
};

~presets = { |kind|
	var dir = ~presetDir.(kind);
	if (File.exists(dir)) {
		PathName(dir).files.select { |p| p.extension == ~presetExt[kind] }.collect { |p|
			var data = p.fullPath.load;
			(path: p.fullPath, name: data !? { data[\name] } ? p.fileNameWithoutExtension, data: data)
		}.sort { |a, b| a[\name].toLower < b[\name].toLower }
	} { [] }
};

~deviceDescs = { |t| t[\devices].reject { |d| d[\pinned] == true }.collect { |d|
	(type: d[\type], on: d[\on], params: d[\params].copy, label: d[\label]) }.asArray };

// The track's mods (and the mods on them), with ids rewritten so they can land on another track:
// "t:<name>:" → "t:@:", a device by its place in the chain: "d:<uid>:" → "d#<index>:".
~trackModState = { |t|
	var keep = List[], walk;
	walk = { |m| keep.add(m); ~modChildren.(m).do(walk) };
	~mods.select { |m| ~modOnTrack.(m, t) }.do(walk);
	keep.collect { |m|
		var tid = m[\target][\tid], parts = tid.split($:), di;
		tid = case
		{ ["t", "s", "l"].includesEqual(parts[0]) } { ([parts[0], "@"] ++ parts.drop(2)).join($:) }
		{ parts[0] == "d" } {
			di = t[\devices].detectIndex { |d| d[\uid] == parts[1].asInteger };
			("d#" ++ di ++ ":") ++ parts.drop(2).join($:)
		}
		{ tid };
		(id: m[\id], tid: tid, spec: m[\target][\spec].asCompileString, shape: m[\shape], rate: m[\rate],
			depth: m[\depth], home: m[\home], source: m[\source])
	}.asArray
};

~savePreset = { |t, name, chainOnly = false|
	var kind = if (chainOnly or: { t[\kind] != \inst }) { \chain } { \instrument };
	var path, data, f, st;
	name = name.asString;
	File.mkdir(~presetDir.(kind));
	path = ~presetDir.(kind) +/+ ~safeName.(name) ++ "." ++ ~presetExt[kind];
	data = if (kind == \chain) {
		(kind: \chain, name: name, devices: ~deviceDescs.(t))
	} {
		st = ~trackState.(t);
		[\name, \kind, \on, \solo, \devices].do { |k| st.removeAt(k) };
		(kind: \instrument, name: name, type: t[\type], state: st, devices: ~deviceDescs.(t), mods: ~trackModState.(t))
	};
	f = File(path, "w");
	f.write(data.asCompileString);
	f.close;
	"unsound: saved % %".format(kind, path).postln;
	~refreshBrowser.value;
	path
};

// A saved instrument → a new track, exactly as it was saved.
~loadInstrument = { |path|
	var p = path.load, alive = ~alive, name, t, mods, st;
	if (p.isNil or: { ~voiceTypes[p[\type]].isNil }) { "unsound: can't load %".format(path).warn } {
		~alive = false;   // no random mods on top of the saved ones
		name = ~add.(p[\type], (name: ~safeName.(p[\name])));
		~alive = alive;
		t = ~tracks[name];
		st = p[\state].copy;
		st[\devices] = p[\devices];
		~applyTrackState.(t, st);
		mods = (p[\mods] ? []).collect { |ms|
			var tid = ms[\tid], parts;
			tid = case
			{ tid.beginsWith("d#") } {
				parts = tid.drop(2).split($:);
				t[\devices][parts[0].asInteger] !? { |d| "d:%:%".format(d[\uid], parts.drop(1).join($:)) } ? "none"
			}
			{ tid.contains(":@:") } { tid.replace(":@:", ":" ++ name ++ ":") }
			{ tid };
			ms = ms.copy;
			ms[\tid] = tid;
			ms
		};
		~addMods.(mods);
		~select.(name);
		name
	};
};

~deletePreset = { |path| File.delete(path); ~refreshBrowser.value };

// ---------------------------------------------------------------- the save dialog

~saveDialog = { |t|
	var isInst = t[\kind] == \inst, w, field, only, save;
	w = Window("save " ++ (if (isInst) { "instrument" } { "chain" }), Rect(500, 400, 360, 120)).background_(Color.grey(0.15));
	field = TextField().string_(t[\name].asString);
	only = CheckBox().string_("just the effects (save as a chain)").value_(isInst.not).enabled_(isInst);
	save = {
		var name = field.string;
		if (name.size > 0) { ~savePreset.(t, name, only.value) };
		w.close;
	};
	field.action = { save.() };
	w.layout = VLayout(
		StaticText().string_(if (isInst) { "name this instrument (with its effects and mods)" } { "name this chain of effects" })
			.stringColor_(Color.grey(0.85)),
		field, only,
		HLayout(nil, Button().states_([["cancel"]]).action_({ w.close }), Button().states_([["save"]]).action_({ save.() }))
	);
	w.front;
	field.focus(true);
};
