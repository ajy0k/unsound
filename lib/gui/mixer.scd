// Session mixer: one column per track. Instruments on the left, returns on the right, master,
// then the scene column. Each column: title (click to select), live tempo, sends, pan,
// meter + fader, activator / solo. Drop browser items on a column to add them to that track.

~levelSpec = ControlSpec(0, 1.4, \amp);

~meterView = { |t|
	var view = UserView().fixedWidth_(14).background_(Color.grey(0.08));
	t[\meterShow] = [0, 0];
	view.drawFunc = { |uv|
		var b = uv.bounds;
		2.do { |ch|
			var v = t[\meterShow][ch], h = v.ampdb.linlin(-60, 0, 0, b.height);
			Pen.fillColor = case { v > 0.99 } { Color.red } { v > 0.5 } { Color.yellow } { Color(0.3, 0.9, 0.4) };
			Pen.fillRect(Rect(ch * 7, b.height - h, 6, h));
		};
	};
	~animated.add({
		if (view.isClosed) { false } {
			t[\meterShow] = t[\meterShow].collect { |old, ch| (t[\meter][ch] ? 0).max(old * 0.85) };
			view.refresh;
			true
		}
	});
	view
};

~sendGrid = { |t|
	var cells = ~returnOrder.collect { |r, i|
		if (t[\kind] == \master or: { r == t[\name] }) {
			View().fixedSize_(Size(44, 58))
		} {
			~knob.("→ " ++ r, [0, 1], { t[\sends][i] }, { |x| ~send.(t[\name], r, x) }, 28, ~tracks[r][\color],
				"s:%:%".format(t[\name], r), "% send %".format(t[\name], r))
		}
	};
	VLayout(*(cells.clump(3).collect { |row| HLayout(*(row ++ [nil])).spacing_(0) } ++ [nil])).spacing_(0)
};

~mixerColumn = { |t|
	var name = t[\name], color = t[\color] ? Color.grey(0.6);
	var title = if (t[\kind] == \return) { name.asString ++ " " ++ (t[\devices].first !? { |d| d[\label] ? d[\type] } ? "") } { name.asString };
	var titleButton = Button().canFocus_(false).states_([[title, Color.black, color]]).action_({ ~select.(name) });
	var fader = Slider().canFocus_(false).orientation_(\vertical).fixedSize_(Size(30, 130))
		.value_(~levelSpec.unmap(t[\level])).action_({ |sl| ~tset.(name, \level, ~levelSpec.map(sl.value)) });
	var db = StaticText().align_(\center).font_(Font.monospace(10));
	var tempo = StaticText().align_(\center).font_(Font.monospace(9));
	var col;
	~titleButtons[name] = titleButton;
	~bindings.add({
		if (fader.isClosed) { false } {
			fader.value = ~levelSpec.unmap(t[\level]);
			db.string = if (t[\level] < 0.001) { "-inf" } { t[\level].ampdb.round(0.1).asString ++ " dB" };
			if (t[\kind] == \inst) {
				tempo.string = ~liveBpm.(t).round(0.1).asString ++ " bpm";
				tempo.stringColor = if (t[\sync] != false and: { (t[\tempoDrift] ? 0) == 0 } and: { t[\speed] == 1 }) {
					Color.grey(0.55) } { ~accent };
			};
			true
		}
	});
	col = View().fixedWidth_(140).background_(Color.grey(0.16)).layout_(VLayout(
		titleButton,
		tempo,
		[~sendGrid.(t), stretch: 1],
		[~knob.("pan", [-1, 1], { t[\pan] }, { |x| ~tset.(name, \pan, x) }, 30, color, "t:%:pan".format(name), "% pan".format(name)), align: \center],
		HLayout(nil, ~meterView.(t), fader, nil).spacing_(5),
		db,
		HLayout(*(
			[~toggle.("on", { t[\on] }, { |x| ~tset.(name, \on, x) }, color)]
			++ (if (t[\kind] == \inst) { [~toggle.("S", { t[\solo] }, { |x| ~tset.(name, \solo, x) }, Color(0.3, 0.6, 1))] } { [] })
			++ (if (t[\kind] == \return) { [~toggle.("pre", { t[\pre] }, { |x| ~tset.(name, \pre, x) })] } { [] })
			++ (if (t[\kind] != \master) { [Button().canFocus_(false).fixedWidth_(24).states_([["x"]]).action_({ ~remove.(name) })] } { [] })
		)).spacing_(2)
	).margins_(3).spacing_(3));
	~dropTarget.(col, { name }, { nil })
};

// ---------------------------------------------------------------- scenes column

~sceneColumn = {
	var list = View().layout_(VLayout().margins_(0).spacing_(2));
	~sceneList = list;
	~refreshScenes = { { ~fillScenes.() }.defer };
	~fillScenes.();
	View().fixedWidth_(190).background_(Color.grey(0.16)).layout_(VLayout(
		StaticText().string_("SCENES").font_(Font(Font.defaultSansFace, 11, true)).stringColor_(Color.grey(0.7)),
		~button.("+ capture (C)", { ~capture.() }),
		HLayout(
			~knob.("morph beats", [0, 64, \lin, 1], { ~morphBeats }, { |x| ~morphBeats = x }, 30),
			~toggle.("song", { ~songRoutine.notNil }, { |x| if (x) { ~playSong.() } { ~stopSong.() } }, Color(0.4, 0.8, 1))
		),
		[ScrollView().hasHorizontalScroller_(false).canvas_(list), stretch: 1]
	).margins_(4).spacing_(4))
};

~fillScenes = {
	if (~sceneList.notNil and: { ~sceneList.isClosed.not }) {
		~sceneList.removeAll;
		~sceneList.layout = VLayout(*(~scenes.collect { |sc, i|
			HLayout(
				Button().canFocus_(false).states_([[(i + 1).asString ++ "  " ++ sc[\name],
					Color.black, if (i == ~currentScene) { ~accent } { Color.grey(0.6) }]])
					.action_({ ~launch.(i) }),
				Button().canFocus_(false).fixedWidth_(24).states_([["↻"]]).action_({ ~updateScene.(i) }),
				Button().canFocus_(false).fixedWidth_(22).states_([["x"]]).action_({ ~deleteScene.(i) })
			).spacing_(2)
		} ++ [nil])).margins_(0).spacing_(2);
	};
};

~mixer = {
	var canvas;
	~titleButtons = ();
	canvas = View().layout_(HLayout(*(
		~voiceOrder.collect { |n| ~mixerColumn.(~tracks[n]) }
		++ [nil]
		++ ~returnOrder.collect { |n| ~mixerColumn.(~tracks[n]) }
		++ [~mixerColumn.(~masterTrack)]
	)).margins_(4).spacing_(4));
	~dropTarget.(canvas, { ~selected }, { nil });
	HLayout([ScrollView().canvas_(canvas), stretch: 1], ~sceneColumn.()).spacing_(4)
};
