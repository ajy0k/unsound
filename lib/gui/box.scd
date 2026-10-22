// The box: a dense, focus-driven view. Browser on the left (as in the studio), then:
//
//   pads      one per track: click = focus, double-click = mute, right-click = solo. They glow with level.
//   screen    kept small: the focused track's own view (XY pad, drum grid, roll, tape), and beside it
//             a narrow column with a scope, its sometimes, and the 8 encoders
//   chain     the big part: the instrument and its whole effect chain in a row (drop browser entries here)
//   encoders  always the same 8, mapped to the focused track's current page. Pages are made
//             automatically: the instrument's knobs, mix, then one page per device.
//             tab / shift-tab (or ◀ ▶) change page. They're mostly for MIDI controllers.
//
// MIDI: switch on MIDI learn and touch an encoder: what gets learned is *the encoder*, not the
// knob under it, so 8 hardware knobs follow focus everywhere. ◀ ▶ page, ◀ ▶ track, glide, cut and
// play learn the same way (pads or buttons on the controller).

~viewMode = ~viewMode ? \box;
~boxPages = ();   // track name → page index

// ---------------------------------------------------------------- pages

// A page of track settings: entries are [key, spec, label].
~pg = { |t, name, list|
	(name: name, targets: list.collect { |e|
		var tg = ~trackTarget.(t, e[0], e[1], e[2] ? e[0].asString);
		tg[\short] = e[2] ? e[0].asString;
		tg
	})
};

~sendTarget = { |t, ret|
	(tid: "s:%:%".format(t[\name], ret), name: "% send %".format(t[\name], ret), short: "send " ++ ret, spec: ControlSpec(0, 1),
		get: { (~returnOrder.indexOf(ret) !? { |j| t[\sends][j] }) ? 0 }, set: { |x| ~send.(t[\name], ret, x) })
};

~pagesFor = { |t|
	var pages = List[], it = if (t[\kind] == \inst) { ~voiceTypes[t[\type]] }, mix;
	if (it.notNil) {
		case
		{ it[\pages].notNil } { pages.addAll(it[\pages].value(t)) }
		{ it[\params].notNil } {
			it[\params].clump(8).do { |ps, i|
				pages.add(~pg.(t, t[\type].asString ++ (if (i > 0) { " " ++ (i + 1) } { "" }),
					ps.collect { |p| [p[\key], p[\spec], p[\label]] }));
			};
		};
	};
	mix = [[\level, ~levelSpec, "level"], [\pan, [-1, 1], "pan"], [\wander, [0, 1], "wander"]];
	if (it.notNil) { mix = mix.add([\speed, [0.25, 4, \exp], "speed"]) };
	mix = ~pg.(t, "mix", mix);
	if (t[\kind] != \master) {
		~returnOrder.reject { |r| r == t[\name] }.keep(8 - mix[\targets].size).do { |r| mix[\targets] = mix[\targets].add(~sendTarget.(t, r)) };
	};
	pages.add(mix);
	t[\devices].do { |d|
		var dt = ~deviceTypes[d[\type]], label = d[\label] ? d[\type].asString;
		var dtg = { |p| var tg = ~deviceTarget.(t, d, p); tg[\short] = p[\label]; tg };
		if (dt[\pages].notNil) {
			dt[\pages].do { |pg|
				pages.add((name: pg[0], device: d, targets: pg[1].collect { |k| dtg.(dt[\params].detect { |p| p[\key] == k }) }));
			};
		} {
			([~mysteryTarget.(t, d).put(\short, "?")] ++ dt[\params].collect(dtg)).clump(8).do { |tgs, i|
				pages.add((name: label ++ (if (i > 0) { " " ++ (i + 1) } { "" }), device: d, targets: tgs));
			};
		};
	};
	pages
};

~boxPageIndex = { |t| (~boxPages[t[\name]] ? 0) };

~boxPage = {
	var t = ~tracks[~selected] ?? { ~masterTrack }, pages = ~pagesFor.(t);
	pages.clipAt(~boxPageIndex.(t))
};

~boxPageStep = { |dir|
	var t = ~tracks[~selected] ?? { ~masterTrack }, n = ~pagesFor.(t).size;
	~boxPages[t[\name]] = (~boxPageIndex.(t) + dir).wrap(0, n - 1);
	~refreshBoxPage.value;
};

// The 8 encoders as MIDI targets: they follow focus, so learning them once is enough.
~boxTargets = 8.collect { |i|
	var current = { ~boxPage.() !? { |pg| pg[\targets][i] } };
	(tid: "box:" ++ i, name: "encoder " ++ (i + 1), spec: ControlSpec(0, 1),
		get: { current.() !? { |tg| tg[\spec].unmap(tg[\get].value ? tg[\spec].default) } ? 0 },
		set: { |x| current.() !? { |tg| ~setOrHome.(tg[\tid], tg[\spec], tg[\spec].map(x), tg[\set]) } })
};

// Buttons a controller can press (their MIDI mappings are saved with the set).
~boxActions = Dictionary[
	"btn:pagePrev" -> { ~boxPageStep.(-1) }, "btn:pageNext" -> { ~boxPageStep.(1) },
	"btn:trackPrev" -> { ~selectOffset.(-1) }, "btn:trackNext" -> { ~selectOffset.(1) },
	"btn:glide" -> { ~glide.() }, "btn:cut" -> { ~cut.() }, "btn:back" -> { ~back.() },
	"btn:play" -> { if (~running == true) { ~stop.() } { ~start.() } },
	"btn:dice" -> { ~pushHistory.(); ~diceTrack.(~selected) }, "btn:new" -> { ~repatch.(~selected) }
];
~buttonTargets = Dictionary.new;
~btnTarget = { |tid|
	~buttonTargets[tid] ?? {
		~boxActions[tid] !? { |a|
			var tg = (name: tid.drop(4), tid: tid, toggle: { { a.value }.defer });
			~buttonTargets[tid] = tg;
			tg
		}
	}
};
~bbutton = { |label, tid, color|
	var target = ~btnTarget.(tid);
	var b = Button().canFocus_(false).font_(Font(Font.defaultSansFace, 12, true))
		.states_([[label, Color.grey(0.92), color ? Color.grey(0.24)]]);
	b.action = { if (~midiLearn == true) { ~learn.(target) } { target[\toggle].value } };
	b
};

// ---------------------------------------------------------------- scope

~defs.add({
	SynthDef(\uScope, { ScopeOut2.ar(In.ar(\in.kr(0), 2), \buf.kr(0), 4096, 1024) }).add;
});

~scopeOn = { |t|
	if (t.notNil and: { t[\grp].notNil }) {
		~scopeBuf = ~scopeBuf ?? { ScopeBuffer.alloc(s, 2) };
		~scopeSynth !? { |x| x.free };
		~scopeSynth = Synth.tail(t[\grp], \uScope, [in: t[\bus], buf: ~scopeBuf.index]);
	};
};

~scopeView = { |t|
	var v;
	try {
		v = ScopeView().server_(s).bufnum_(~scopeBuf.index).style_(0)
			.waveColors_([t[\color] ? ~accent, (t[\color] ? ~accent).blend(Color.white, 0.4)])
			.background_(Color.grey(0.05)).minSize_(Size(200, 120));
		v.start;
		v.onClose = { v.stop };
	} { v = UserView().background_(Color.grey(0.05)) };
	v
};

// ---------------------------------------------------------------- pads

~pad = { |t|
	var name = t[\name], view = UserView().minSize_(Size(64, 38)).canFocus_(false), glow = 0;
	view.drawFunc = { |uv|
		var b = uv.bounds.moveTo(0, 0), c = t[\color] ? Color.grey(0.6), on = t[\on] != false, sel = ~selected == name;
		var sub = case
		{ t[\kind] == \return } { t[\devices].first !? { |d| d[\label] ? d[\type].asString } ? "" }
		{ on.not } { "muted" }
		{ t[\kind] == \inst } { ~liveBpm.(t).round(0.1).asString }
		{ "" };
		Pen.fillColor = if (on) { c.blend(Color.black, 0.75 - (glow * 0.6)) } { Color.grey(0.12) };
		Pen.addRoundedRect(b.insetBy(1, 1), 4, 4);
		Pen.fill;
		Pen.strokeColor = if (sel) { Color.white } { c.blend(Color.black, 0.4) };
		Pen.width = if (sel) { 2 } { 1 };
		Pen.addRoundedRect(b.insetBy(1, 1), 4, 4);
		Pen.stroke;
		Pen.stringCenteredIn(name.asString, Rect(0, 3, b.width, b.height - 16), Font(Font.defaultSansFace, 11, true),
			if (on) { Color.white } { Color.grey(0.45) });
		Pen.stringCenteredIn(sub, Rect(0, b.height - 15, b.width, 12), Font.monospace(8), Color.grey(0.6));
		if (t[\solo] == true) { Pen.stringAtPoint("S", Point(5, 3), Font(Font.defaultSansFace, 9, true), Color(0.4, 0.7, 1)) };
	};
	view.mouseDownAction = { |uv, x, y, mod, bn, clicks|
		case
		{ bn == 1 or: { mod.isAlt } } { ~tset.(name, \solo, t[\solo] != true) }
		{ clicks == 2 } { ~tset.(name, \on, t[\on].not) }
		{ ~select.(name) };
		uv.refresh;
		nil
	};
	~animated.add({
		if (view.isClosed) { false } {
			glow = (glow * 0.8).max(((t[\meter][0] ? 0).max(t[\meter][1] ? 0)).sqrt);
			view.refresh;
			true
		}
	});
	~dropTarget.(view, { name }, { nil })
};

~padRow = {
	View().fixedHeight_(42).layout_(HLayout(*(
		~voiceOrder.collect { |n| ~pad.(~tracks[n]) } ++ [nil]
		++ ~returnOrder.collect { |n| ~pad.(~tracks[n]) } ++ [~pad.(~masterTrack),
			~button.("+ return", { ~addReturn.(\space) }).fixedWidth_(60)]
	)).spacing_(3).margins_(0))
};

// ---------------------------------------------------------------- focus: screen, encoders, chain

// The 8 encoders, small, two rows of four: ◀ ▶ step through the pages.
~encoderBlock = { |t|
	var pages = ~pagesFor.(t), idx = ~boxPageIndex.(t).clip(0, pages.size - 1), page = pages[idx];
	var encs = 8.collect { |i|
		var tg = page !? { page[\targets][i] };
		if (tg.isNil) { View().fixedSize_(Size(50, 62)) } {
			~knob.(tg[\short] ? tg[\name], tg[\spec], tg[\get], tg[\set], 32, t[\color], tg[\tid], tg[\name], ~boxTargets[i])
		}
	};
	var title = StaticText().align_(\center).font_(Font(Font.defaultSansFace, 10, true)).stringColor_(t[\color] ? Color.white)
		.string_("% (%/%)".format(page !? { page[\name] } ? "", idx + 1, pages.size));
	VLayout(
		HLayout(~bbutton.("◀", "btn:pagePrev").fixedWidth_(26), [title, stretch: 1], ~bbutton.("▶", "btn:pageNext").fixedWidth_(26)).spacing_(2),
		HLayout(*(encs.keep(4) ++ [nil])).spacing_(0),
		HLayout(*(encs.drop(4) ++ [nil])).spacing_(0)
	).spacing_(0)
};

// The visual part of the track: an instrument's `screen` if it has one, else its clip view.
~boxScreen = { |t|
	var it = if (t[\kind] == \inst) { ~voiceTypes[t[\type]] };
	case
	{ it.isNil } { ~scopeView.(t) }
	{ it[\screen].notNil } { View().layout_(it[\screen].value(t)) }
	{ View().layout_(it[\clip].value(t)) }
};

~buildBoxFocus = {
	var t = ~tracks[~selected] ?? { ~masterTrack };
	if (~boxScreenHolder.notNil and: { ~boxScreenHolder.isClosed.not }) {
		~scopeOn.(t);
		~boxScreenHolder.removeAll;
		~boxEncHolder = View().layout_(VLayout().margins_(0));
		~boxScreenHolder.layout = HLayout(
			[ScrollView().hasHorizontalScroller_(false).canvas_(View().layout_(VLayout(~boxScreen.(t)).margins_(0))), stretch: 1],
			View().fixedWidth_(250).layout_(VLayout(
				HLayout(StaticText().string_(t[\name].asString).font_(Font(Font.defaultSansFace, 14, true)).stringColor_(t[\color] ? Color.white),
					nil, ~bbutton.("dice", "btn:dice"), ~bbutton.("new", "btn:new")).spacing_(2),
				if (t[\kind] == \inst) { ~scopeView.(t).fixedHeight_(70) } { View().fixedHeight_(1) },
				if (t[\kind] == \inst) { ~soRow.(t, 50) } { View().fixedHeight_(1) },
				~boxEncHolder,
				nil
			).margins_(0).spacing_(3))
		).margins_(0).spacing_(6);
		~boxChainHolder.removeAll;
		~boxChainHolder.layout = VLayout(~chain.(t)).margins_(0);
	};
	~refreshBoxPage.();
};

~refreshBoxPage = {
	var t = ~tracks[~selected] ?? { ~masterTrack };
	{
		if (~boxEncHolder.notNil and: { ~boxEncHolder.isClosed.not }) {
			~boxEncHolder.removeAll;
			~boxEncHolder.layout = VLayout(~encoderBlock.(t)).margins_(0);
		};
	}.defer;
};

~boxTop = {
	HLayout(
		~toggle.("  play  ", { ~running == true }, { |x| if (x) { ~start.() } { ~stop.() } }, Color(0.35, 0.9, 0.45)),
		~knob.("bpm", ~bpmSpec, { ~tempo }, { |x| ~bpm.(x) }, 26, ~accent),
		~recButton.(),
		~sep.(),
		~bbutton.("glide", "btn:glide"), ~bbutton.("cut", "btn:cut"), ~bbutton.("back", "btn:back"),
		~knob.("distance", [0, 1], { ~lurchDistance }, { |x| ~lurchDistance = x }, 26, ~accent),
		~sometimesW.("glide", "g:glide", { ~events[\soGlide] ? 0 }, { |x| ~events[\soGlide] = x }, Color(0.4, 0.8, 1), 60),
		~sometimesW.("cut", "g:cut", { ~events[\soCut] ? 0 }, { |x| ~events[\soCut] = x }, Color(0.4, 0.8, 1), 60),
		~sep.(),
		~knob.("chaos", [0, 1], { ~m[\chaos] }, { |x| ~set.(\chaos, x) }, 26, ~accent),
		~menu.(~scaleNames, { ~scaleName }, { |x| ~scaleName = x; ~scale = Scale.at(x) }),
		~menu.((0..11), { ~key }, { |x| ~key = x }, ~noteNames),
		~button.("infect", { ~infect.(4) }), ~button.("cure", { ~cure.() }),
		~toggle.("alive", { ~alive }, { |x| ~alive = x }, Color(0.5, 1, 0.6)),
		~toggle.("MIDI learn", { ~midiLearn }, { |x| ~midiLearn = x; if (x.not) { ~learnTarget = nil } }, Color.yellow),
		nil,
		~button.("save set", { Dialog.savePanel({ |p| ~saveSet.(p) }, nil, ~setsDir) }),
		~button.("load set", { Dialog.openPanel({ |p| ~loadSet.(p) }, nil, false, ~setsDir) }),
		~button.("studio", { ~viewMode = \studio; ~refreshGui.() }),
		Button().canFocus_(false).fixedWidth_(24).states_([["?", Color.black, ~accent]]).action_({ ~showHelp.() })
	).spacing_(3)
};

// Drag it up or down to trade screen for chain. The screen scrolls when it's smaller than its contents.
~boxScreenH = ~boxScreenH ? 330;
~splitHandle = {
	var v = UserView().fixedHeight_(7).canFocus_(false), y0;
	v.drawFunc = { |uv|
		var b = uv.bounds.moveTo(0, 0);
		Pen.fillColor = Color.grey(0.25);
		Pen.fillRect(Rect(b.width / 2 - 30, 2, 60, 3));
	};
	// the handle moves with the split, so the grab point stays at y0: just add each move
	v.mouseDownAction = { |uv, x, y| y0 = y; nil };
	v.mouseMoveAction = { |uv, x, y|
		~boxScreenH = (~boxScreenH + (y - y0)).clip(60, 1000);
		~boxScreenHolder.fixedHeight_(~boxScreenH);
		nil
	};
	v
};

// browser | top bar, pads, screen over the chain; the handle between them sets the split
~boxLayout = {
	~boxScreenHolder = View().fixedHeight_(~boxScreenH);
	~boxChainHolder = View().layout_(VLayout().margins_(0));
	HLayout(
		~browser.(),
		VLayout(
			~boxTop.(),
			~padRow.(),
			~boxScreenHolder,
			~splitHandle.(),
			[~boxChainHolder, stretch: 1]
		).spacing_(3)
	).margins_(5).spacing_(5)
};
