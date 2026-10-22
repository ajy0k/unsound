// Main window, full screen: browser on the left; transport, mixer (+ scenes) and the detail view
// for the selected track on the right. Detail = Clip (piano roll / steps / waveform) or Devices
// (instrument + insert chain; drop browser entries here).

~scaleNames = [\minor, \major, \dorian, \phrygian, \lydian, \mixolydian, \harmonicMinor,
	\minorPentatonic, \majorPentatonic, \whole, \chromatic];
~scaleName = ~scaleName ? \minor;
~detailMode = ~detailMode ? \clip;

~help = [
	["play", [
		["space", "play / stop"],
		["A W S E D F T G Y H U J K O L P ;", "notes on the selected track (drums: one lane per white key)"],
		["Z  /  X", "keyboard octave down / up"],
		[",  /  .", "master tempo down / up (3%, no limits)"]]],
	["tracks", [
		["1 – 9", "select instrument track"], ["0", "select master"], ["←  /  →", "previous / next track"],
		["↑  /  ↓", "volume of the selected track"], ["shift ↑  /  ↓", "tempo of the selected track (unsyncs it)"],
		["M", "mute the selected track"], ["R", "resync the selected track to the master clock"],
		["tab", "clip → devices → mods"]]],
	["somewhere else", [
		["Q", "glide: lurch toward somewhere new over the morph time"],
		["=", "cut: jump somewhere new on a dime"],
		["-", "back: undo the last glide / cut / dice"],
		["distance", "(knob) how far a glide or cut goes"],
		["events", "(toggle) every N bars, by chance: glide, cut, back, dice, drop-outs, solos"]]],
	["chaos", [
		["N", "new sound on the selected track"], ["/", "dice: randomize the selected track and its devices"],
		["I", "infect: scatter random modulators"], ["\\", "cure: remove every modulator"],
		["B  (hold)", "stutter the master"], ["V  (hold)", "freeze the master"]]],
	["record", [["● record", "records exactly what you hear to ~/Music/unsound/ (24-bit wav); \"show\" opens it in Finder"]]],
	["scenes", [["C", "capture a scene"], ["[  /  ]", "previous / next scene"]]],
	["help", [["?", "this window"]]],
	["mouse", [
		["right-click a knob", "give it a modulator / take it away (also alt-click)"],
		["drag a knob", "up / down · shift = fine · scroll wheel · double-click resets"],
		["double-click in the browser", "add to the end of the selected track's chain"],
		["drag from the browser", "onto a strip, the device area, or a device (inserts before it)"],
		["drum grid", "click = hit · drag = paint · right-click = lane length"],
		["scroll wheel over the mixer", "scrolls sideways"]]],
	["MIDI", [
		["MIDI learn", "switch it on, touch a control on screen, then move a hardware control"],
		["notes", "play the selected track (GM drum notes work on drums)"]]]
];

~showHelp = {
	var rows;
	if (~helpWin.notNil and: { ~helpWin.isClosed.not }) { ~helpWin.close } {
		rows = ~help.collect { |sec|
			[[StaticText().string_(sec[0].toUpper).font_(Font(Font.defaultSansFace, 12, true)).stringColor_(~accent), columns: 2]]
			++ sec[1].collect { |kv|
				[StaticText().string_(kv[0]).font_(Font.monospace(12)).stringColor_(Color.white),
					StaticText().string_(kv[1]).font_(Font(Font.defaultSansFace, 12)).stringColor_(Color.grey(0.75))]
			}
		}.flatten(1);
		~helpWin = Window("unsound — keys", Rect(200, 120, 720, 760)).background_(Color.grey(0.12));
		~helpWin.layout = VLayout(GridLayout.rows(*rows).hSpacing_(18).vSpacing_(4), nil);
		~helpWin.front;
	};
};

// The record button shows how long it's been recording; "show" reveals the last file in Finder.
~recButton = {
	var b = Button().canFocus_(false).fixedWidth_(86);
	var label = { |on| if (on) {
		var secs = (Main.elapsedTime - (~recStart ? 0)).asInteger;
		[["● " ++ (secs div: 60).asString.padLeft(2, "0") ++ ":" ++ (secs % 60).asString.padLeft(2, "0"), Color.white, Color(0.85, 0.1, 0.1)]]
	} { [["● record", Color(1, 0.4, 0.4), Color.grey(0.24)]] } };
	b.states = label.(false);
	b.action = { ~record.((~recording == true).not); b.states = label.(~recording == true) };
	~bindings.add({ if (b.isClosed) { false } { if (~recording == true) { b.states = label.(true) }; true } });
	HLayout(b, ~button.("show", { ~revealRec.() }).fixedWidth_(44)).spacing_(1)
};

~sep = { View().fixedWidth_(1).background_(Color.grey(0.3)) };

~transport = {
	var oct = StaticText().font_(Font.monospace(10)).stringColor_(Color.grey(0.6));
	~bindings.add({ if (oct.isClosed) { false } { oct.string = "kb oct " ++ (~kbOctave - 1); true } });
	VLayout(
		HLayout(
			~toggle.("  play  ", { ~running == true }, { |x| if (x) { ~start.() } { ~stop.() } }, Color(0.35, 0.9, 0.45)),
			~knob.("bpm", ~bpmSpec, { ~tempo }, { |x| ~bpm.(x) }, 34, ~accent),
			~recButton.(),
			~sep.(),
			~knob.("chaos", [0, 1], { ~m[\chaos] }, { |x| ~set.(\chaos, x) }, 34, ~accent),
			~menu.(~scaleNames, { ~scaleName }, { |x| ~scaleName = x; ~scale = Scale.at(x) }),
			~menu.((0..11), { ~key }, { |x| ~key = x }, ~noteNames),
			~sep.(),
			~button.("glide (Q)", { ~glide.() }),
			~button.("cut (=)", { ~cut.() }),
			~button.("back (-)", { ~back.() }),
			~knob.("distance", [0, 1], { ~lurchDistance }, { |x| ~lurchDistance = x }, 34, ~accent),
			~toggle.("events", { ~events[\on] }, { |x| ~events[\on] = x }, Color(0.4, 0.8, 1)),
			~knob.("every", [1, 64, \lin, 1], { ~events[\every] }, { |x| ~events[\every] = x }, 34, Color(0.4, 0.8, 1)),
			~knob.("chance", [0, 1], { ~events[\chance] }, { |x| ~events[\chance] = x }, 34, Color(0.4, 0.8, 1)),
			~sep.(),
			~button.("new sounds", { ~newSounds.() }),
			~button.("infect", { ~infect.(4) }),
			~button.("cure", { ~cure.() }),
			~toggle.("alive", { ~alive }, { |x| ~alive = x }, Color(0.5, 1, 0.6)),
			~sep.(),
			~toggle.("MIDI learn", { ~midiLearn }, { |x| ~midiLearn = x; if (x.not) { ~learnTarget = nil } }, Color.yellow),
			~button.("save set", { Dialog.savePanel({ |p| ~saveSet.(p) }, nil, ~setsDir) }),
			~button.("load set", { Dialog.openPanel({ |p| ~loadSet.(p) }, nil, false, ~setsDir) }),
			nil,
			oct,
			Button().canFocus_(false).fixedWidth_(30).states_([["?", Color.black, ~accent]]).action_({ ~showHelp.() }),
			~lbl.("unsound", 16)
		)
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
	~hscroll.(ScrollView().hasVerticalScroller_(false).canvas_(canvas))
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
			~knob.("own bpm", ~bpmSpec, { if (t[\sync] != false) { ~tempo } { t[\bpm] } },
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
			[View().fixedHeight_(330).layout_(~mixer.().margins_(0)), stretch: 0],
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
