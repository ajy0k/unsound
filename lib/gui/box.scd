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
	if (t[\kind] == \wall) {
		pages.add(~pg.(t, "wall", [[\pick, [0, ~wallTypes.size - 1, \lin, 1], "wall"], [\dens, [0, 1]], [\grit, [0, 1]],
			[\motion, [0, 1]], [\swap, [0, 30, 4], "swap"]]));
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
	"btn:dice" -> { ~pushHistory.(); ~diceTrack.(~selected) }, "btn:new" -> { ~repatch.(~selected) },
	"btn:keep" -> { ~keep.() }, "btn:wall" -> { ~tset.(\wall, \in, (~tracks[\wall] !? { |w| w[\in] } ? true).not) }
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
	var name = t[\name], view = UserView().minSize_(Size(52, 46)).canFocus_(false), glow = 0;
	view.drawFunc = { |uv|
		var b = uv.bounds.moveTo(0, 0), c = t[\color] ? Color.grey(0.6), on = t[\on] != false, sel = ~selected == name;
		var sub = case
		{ t[\kind] == \wall } { if (t[\in]) { ~wallTypes[t[\playing] ? 0][0] } { "out" } }
		{ t[\kind] == \return } { t[\devices].first !? { |d| d[\label] ? d[\type].asString } ? "" }
		{ on.not } { "muted" }
		{ t[\kind] == \inst } { ~liveBpm.(t).round(0.1).asString }
		{ "" };
		Pen.fillColor = if (on and: { t[\in] != false }) { c.blend(Color.black, 0.75 - (glow * 0.6)) } { Color.grey(0.12) };
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
		{ clicks == 2 } { if (t[\kind] == \wall) { ~tset.(name, \in, t[\in].not) } { ~tset.(name, \on, t[\on].not) } }
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
	~dropTarget.(view, { name }, { nil });
	View().fixedHeight_(50).layout_(HLayout(
		view,
		VLayout(
			// on the wall, M fades it in and out instead of cutting it
			if (t[\kind] == \wall) { ~toggle.("M", { t[\in].not }, { |x| ~tset.(name, \in, x.not) }, Color(1, 0.8, 0.2)).fixedSize_(Size(22, 22)) }
				{ ~toggle.("M", { t[\on].not }, { |x| ~tset.(name, \on, x.not) }, Color(1, 0.8, 0.2)).fixedSize_(Size(22, 22)) },
			if (t[\kind] == \inst) { ~toggle.("S", { t[\solo] == true }, { |x| ~tset.(name, \solo, x) }, Color(0.3, 0.6, 1)).fixedSize_(Size(22, 22)) }
				{ View().fixedSize_(Size(22, 22)) }
		).spacing_(1).margins_(0),
		~knob.(nil, ~levelSpec, { t[\level] }, { |x| ~tset.(name, \level, x) }, 18, t[\color] ? Color.grey(0.6),
			"t:%:level".format(name), "% volume".format(name))
	).spacing_(1).margins_(0))
};

~padRow = {
	View().fixedHeight_(52).layout_(HLayout(*(
		~wallList.().collect { |n| ~pad.(~tracks[n]) } ++ ~voiceOrder.collect { |n| ~pad.(~tracks[n]) } ++ [nil]
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
	{ t[\kind] == \wall } { View().layout_(~wallScreen.(t)) }
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
					nil, ~button.("⧉", { ~popTrack.(t) }).fixedWidth_(22), ~bbutton.("dice", "btn:dice"), ~bbutton.("new", "btn:new")).spacing_(2),
				if ([\inst, \wall].includes(t[\kind])) { ~scopeView.(t).fixedHeight_(70) } { View().fixedHeight_(1) },
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

// Tape: how much is on it, and keep (everything / the last minute). Return / shift-return do the same.
~tapeControls = {
	var shown = StaticText().font_(Font.monospace(9)).stringColor_(Color.grey(0.7)).fixedWidth_(64);
	var keep = ~bbutton.("keep", "btn:keep", Color(0.5, 0.15, 0.15))
		.toolTip_("save what's on the tape (up to 15 min) to ~/Music/unsound/ · return · shift-return = last minute");
	~bindings.add({
		var secs = ~tapeSecs.().asInteger;
		if (shown.isClosed) { false } {
			shown.string = "tape %:%".format(secs div: 60, (secs % 60).asString.padLeft(2, "0"));
			shown.stringColor = if (Main.elapsedTime - (~lastKeep ? -10) < 2) { Color.white } { Color.grey(0.7) };
			true
		}
	});
	HLayout(shown, keep).spacing_(2)
};

// Takeover: a slider (no numbers) for the selected track, and ∞ (hold) to push it all the way.
~takeoverControls = {
	var hold = UserView().fixedSize_(Size(28, 20)).canFocus_(false);
	hold.drawFunc = { |uv|
		Pen.fillColor = if (~takeoverHeld == true) { Color(1, 0.25, 0.1) } { Color(0.35, 0.1, 0.08) };
		Pen.fillRect(uv.bounds.moveTo(0, 0));
		Pen.stringCenteredIn("∞", uv.bounds.moveTo(0, 0), Font(Font.defaultSansFace, 14, true), Color.white);
	};
	hold.mouseDownAction = { ~holdTakeover.(true); hold.refresh; nil };
	hold.mouseUpAction = { ~holdTakeover.(false); hold.refresh; nil };
	hold.toolTip = "hold: the focused track goes all the way to infinity (or hold the ' key)";
	HLayout(
		~bar.([0, 1], { ~takeoverAmt }, { |x| ~setTakeover.(x) }, Color(1, 0.3, 0.1), "g:takeover",
			"takeover: the focused track takes over (drive + level up, everything else ducks)", 90, nil, "takeover"),
		hold).spacing_(2)
};

~boxTop = {
	HLayout(
		~toggle.("  play  ", { ~running == true }, { |x| if (x) { ~start.() } { ~stop.() } }, Color(0.35, 0.9, 0.45)),
		~knob.("bpm", ~bpmSpec, { ~tempo }, { |x| ~bpm.(x) }, 26, ~accent),
		~tapeControls.(),
		~sep.(),
		~takeoverControls.(),
		~bbutton.("glide", "btn:glide"), ~bbutton.("cut", "btn:cut"), ~bbutton.("back", "btn:back"),
		~knob.("distance", [0, 1], { ~lurchDistance }, { |x| ~lurchDistance = x }, 26, ~accent),
		~sometimesW.("glide", "g:glide", { ~events[\soGlide] ? 0 }, { |x| ~events[\soGlide] = x }, Color(0.4, 0.8, 1), 40),
		~sometimesW.("cut", "g:cut", { ~events[\soCut] ? 0 }, { |x| ~events[\soCut] = x }, Color(0.4, 0.8, 1), 40),
		~sep.(),
		~knob.("chaos", [0, 1], { ~m[\chaos] }, { |x| ~set.(\chaos, x) }, 26, ~accent),
		~button.("infect", { ~infect.(4) }), ~button.("cure", { ~cure.() }),
		~toggle.("MIDI", { ~midiLearn }, { |x| ~midiLearn = x; if (x.not) { ~learnTarget = nil } }, Color.yellow),
		nil,
		~button.("save", { Dialog.savePanel({ |p| ~saveSet.(p) }, nil, ~setsDir) }),
		~button.("load", { Dialog.openPanel({ |p| ~loadSet.(p) }, nil, false, ~setsDir) }),
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
