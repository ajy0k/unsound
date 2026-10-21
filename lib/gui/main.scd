// Main window, full screen: browser on the left; transport, mixer (+ scenes) and the detail view
// for the selected track on the right. Detail = Clip (piano roll / steps / waveform) or Devices
// (instrument + insert chain; drop browser entries here).

~scaleNames = [\minor, \major, \dorian, \phrygian, \lydian, \mixolydian, \harmonicMinor,
	\minorPentatonic, \majorPentatonic, \whole, \chromatic];
~scaleName = ~scaleName ? \minor;
~detailMode = ~detailMode ? \clip;

~keyHelp = "keys: A–; notes · Z/X oct · space play · 1–9 / ←→ tracks · ↑↓ vol (⇧ tempo) · tab clip/devices/mods · "
	++ "N new · / dice · I infect · \\ cure · M mute · R resync · B stutter · V freeze · Q lurch · C capture · [ ] scenes · , . bpm"
	++ "   ·   right-click any knob = modulate it";

~transport = {
	var oct = StaticText().font_(Font.monospace(10)).stringColor_(Color.grey(0.6));
	~bindings.add({ if (oct.isClosed) { false } { oct.string = "kb oct " ++ (~kbOctave - 1); true } });
	VLayout(
		HLayout(
			~toggle.("  play  ", { ~running == true }, { |x| if (x) { ~start.() } { ~stop.() } }, Color(0.35, 0.9, 0.45)),
			~knob.("bpm", [40, 300], { ~tempo }, { |x| ~bpm.(x) }, 34, ~accent),
			~knob.("chaos", [0, 1], { ~m[\chaos] }, { |x| ~set.(\chaos, x) }, 34, ~accent),
			~lbl.("scale"),
			~menu.(~scaleNames, { ~scaleName }, { |x| ~scaleName = x; ~scale = Scale.at(x) }),
			~lbl.("key"),
			~menu.((0..11), { ~key }, { |x| ~key = x }, ~noteNames),
			~button.("lurch", { ~lurch.() }),
			~button.("infect", { ~infect.(4) }),
			~button.("cure", { ~cure.() }),
			~toggle.("rec", { ~recording == true }, { |x| ~record.(x) }, Color(0.9, 0.2, 0.2)),
			~toggle.("MIDI learn", { ~midiLearn }, { |x| ~midiLearn = x; if (x.not) { ~learnTarget = nil } }, Color.yellow),
			~button.("save set", { Dialog.savePanel({ |p| ~saveSet.(p) }, nil, ~setsDir) }),
			~button.("load set", { Dialog.openPanel({ |p| ~loadSet.(p) }, nil, false, ~setsDir) }),
			nil,
			oct,
			~lbl.("unsound", 16)
		),
		~lbl.(~keyHelp, 9).stringColor_(Color.grey(0.5))
	).spacing_(2)
};

~devicePanel = { |t, d|
	var dt = ~deviceTypes[d[\type]];
	var knobs = [~qknob.(t, d)] ++ dt[\params].collect { |p| ~dknob.(t, d, p, t[\color]) };
	var title = d[\label] ? d[\type].asString;
	var extras = [~toggle.("on", { d[\on] }, { |x| if (x != d[\on]) { ~dbypass.(d) } }),
		Button().canFocus_(false).fixedWidth_(34).states_([["dice"]]).action_({ ~diceDevice.(d) })];
	var rows, panel;
	if (d[\pinned] != true) {
		extras = extras ++ [
			Button().canFocus_(false).fixedWidth_(20).states_([["<"]]).action_({ ~dmove.(t[\name], d, -1) }),
			Button().canFocus_(false).fixedWidth_(20).states_([[">"]]).action_({ ~dmove.(t[\name], d, 1) }),
			Button().canFocus_(false).fixedWidth_(20).states_([["x"]]).action_({ ~drem.(t[\name], d) })
		];
	} { title = title ++ " (always)" };
	rows = knobs.clump(3).collect { |row| HLayout(*(row ++ [nil])) };
	if (d[\type] == \drive) {
		rows = rows.add(StaticText().font_(Font.monospace(9)).stringColor_(Color.grey(0.65))
			.string_("mode: " ++ ~driveModes.collect { |m, i| "%=%".format(i, m) }.join(" ")));
	};
	if (dt[\gui].notNil) { rows = rows.add(HLayout(*dt[\gui].value(t, d))) };
	panel = ~panel.(title, Color.grey(0.62), VLayout(*rows), 210, extras);
	// dropping a browser entry on a device inserts before it
	~dropTarget.(panel, { t[\name] }, { t[\devices].indexOf(d) })
};

~chain = { |t|
	var panels = (if (t[\kind] == \inst) { ~voiceTypes[t[\type]][\device].value(t) } { [] })
		++ t[\devices].collect { |d| ~devicePanel.(t, d) }
		++ [StaticText().string_("drop effects here\nor use + in the browser").stringColor_(Color.grey(0.45))
			.align_(\center).fixedWidth_(170)];
	var canvas = View().layout_(HLayout(*(panels ++ [nil])).margins_(2).spacing_(6));
	~dropTarget.(canvas, { t[\name] }, { nil });
	ScrollView().hasVerticalScroller_(false).canvas_(canvas)
};

~detailFor = { |t|
	var mode = if (t[\kind] == \inst or: { ~detailMode == \mods }) { ~detailMode } { \devices };
	var content = switch (mode)
	{ \clip } { View().layout_(~voiceTypes[t[\type]][\clip].value(t)) }
	{ \mods } { ~modsView.() }
	{ ~chain.(t) };
	var header = [StaticText().string_(t[\name].asString).font_(Font(Font.defaultSansFace, 16, true)).stringColor_(t[\color] ? Color.white)];
	header = header ++ (if (t[\kind] == \inst) {
		[~toggle.("clip", { ~detailMode == \clip }, { ~detailMode = \clip; ~refreshDetail.() })] } { [] }) ++ [
		~toggle.("devices", { ~detailMode == \devices or: { t[\kind] != \inst and: { ~detailMode == \clip } } },
			{ ~detailMode = \devices; ~refreshDetail.() }),
		~toggle.("mods", { ~detailMode == \mods }, { ~detailMode = \mods; ~refreshDetail.() }, Color.white),
		~button.("dice (/)", { ~diceTrack.(t[\name]) })
	];
	if (t[\kind] == \inst) {
		header = header ++ [
			~button.("new sound (N)", { ~repatch.(t[\name]) }),
			~toggle.("sync", { t[\sync] != false }, { |x| ~tset.(t[\name], \sync, x); if (x) { ~resync.(t[\name]) } }, Color(0.4, 0.8, 1)),
			~knob.("own bpm", [40, 300], { if (t[\sync] != false) { ~tempo } { t[\bpm] } },
				{ |x| t[\sync] = false; ~tset.(t[\name], \bpm, x) }, 34, t[\color], "t:%:bpm".format(t[\name]), "% bpm".format(t[\name])),
			~tknob.(t, \tempoDrift, [0, 1], "tempo drift", 34),
			~tknob.(t, \speed, [0.25, 4, \exp], "speed", 34),
			~button.("resync (R)", { ~resync.(t[\name]) }),
			~tknob.(t, \wander, [0, 1], "wander", 34),
			~tknob.(t, \drift, [0, 1], "drift", 34)
		];
	};
	View().background_(Color.grey(0.14)).layout_(VLayout(HLayout(*(header ++ [nil])), [content, stretch: 1]).margins_(6))
};

~buildDetail = {
	var t = ~tracks[~selected] ?? { ~masterTrack };
	if (~detailView.notNil) { ~detailView.remove };
	~detailView = ~detailFor.(t);
	~detailHolder.layout.add(~detailView);
	~titleButtons.keysValuesDo { |n, b|
		var st = b.states[0];
		b.states = [[st[0], if (n == t[\name]) { Color.white } { Color.black }, st[2]]];
	};
};

~select = { |name| ~selected = name; ~refreshDetail.() };

~refreshDetail = {
	if (~gui == true and: { ~win.notNil } and: { ~win.isClosed.not }) { { ~buildDetail.() }.defer };
};

~refreshGui = {
	if (~gui == true and: { ~win.notNil } and: { ~win.isClosed.not }) { { ~makeGui.() }.defer };
};

~makeGui = {
	var bounds = Window.availableBounds;
	if (~win.notNil and: { ~win.isClosed.not }) {
		bounds = ~win.bounds;
		~win.onClose = nil;
		~win.close;
	};
	try { QtGUI.palette = QPalette.dark };
	~bindings = List[];
	~animated = List[];
	~win = Window("unsound", bounds).background_(Color.grey(0.11));
	~detailHolder = View().layout_(VLayout().margins_(0));
	~detailView = nil;
	~win.layout = HLayout(
		~browser.(),
		VLayout(
			~transport.(),
			[View().fixedHeight_(470).layout_(~mixer.().margins_(0)), stretch: 0],
			[~detailHolder, stretch: 1]
		).spacing_(6)
	).margins_(6).spacing_(6);
	~buildDetail.();
	~refreshMods = { if (~detailMode == \mods) { ~refreshDetail.() } };
	~win.front;
	~installKeys.();
	~startTick.();
	~win.onClose = { ~tick.stop };
};
