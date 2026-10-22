// Clip views: piano roll, step grid, waveform with region selection, and drawable wavetables.

// ---------------------------------------------------------------- piano roll

~noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
~noteName = { |midi| ~noteNames[midi % 12] ++ ((midi div: 12) - 1) };

// Click an empty cell to add a note (and hear it), drag right to lengthen it, click a note to delete it.
// Lighter rows are in the scale; the brightest rows are the key's root.
~rollView = { |t|
	var rows = 24, drag;
	var view = UserView().minHeight_(240).canFocus_(false).background_(Color.grey(0.1));
	var cell = { |x, y|
		var roll = t[\roll], b = view.bounds;
		[(x / (b.width / roll[\len])).floor.asInteger.clip(0, roll[\len] - 1),
			(rows - 1 - (y / (b.height / rows)).floor).asInteger.clip(0, rows - 1)]
	};
	view.drawFunc = { |uv|
		var roll = t[\roll], b = uv.bounds, w = b.width / roll[\len], h = b.height / rows, low = t[\rollLow];
		rows.do { |i|
			var midi = low + i, y = b.height - ((i + 1) * h);
			Pen.fillColor = case
			{ (midi - ~key) % 12 == 0 } { Color.grey(0.3) }
			{ ~inScale.(midi) } { Color.grey(0.21) }
			{ Color.grey(0.12) };
			Pen.fillRect(Rect(0, y, b.width, h - 1));
			if ((midi - ~key) % 12 == 0) {
				Pen.stringAtPoint(~noteName.(midi), 2 @ (y + 1), Font.monospace(8), Color.grey(0.6));
			};
		};
		(roll[\len] + 1).do { |i|
			Pen.strokeColor = Color.grey(if (i % 4 == 0) { 0.42 } { 0.2 });
			Pen.line((i * w) @ 0, (i * w) @ b.height);
			Pen.stroke;
		};
		roll[\notes].do { |n|
			var row = n[\midi] - low;
			if (row >= 0 and: { row < rows }) {
				Pen.fillColor = t[\color];
				Pen.fillRect(Rect(n[\step] * w + 1, b.height - ((row + 1) * h) + 1, (n[\dur] * w - 2).max(2), h - 2));
			};
		};
		if (t[\pos].notNil and: { t[\play] == \roll }) {
			Pen.fillColor = Color(1, 1, 1, 0.13);
			Pen.fillRect(Rect(t[\pos] * w, 0, w, b.height));
		};
	};
	view.mouseDownAction = { |uv, x, y|
		var c = cell.(x, y), step = c[0], midi = t[\rollLow] + c[1];
		var hit = t[\roll][\notes].detect { |n| n[\midi] == midi and: { step >= n[\step] } and: { step < (n[\step] + n[\dur]) } };
		if (hit.notNil) { t[\roll][\notes].remove(hit); drag = nil } {
			drag = (step: step, midi: midi, dur: 1);
			t[\roll][\notes].add(drag);
			~voiceTypes[t[\type]][\note].value(t, midi + (t[\octave] * 12), 0.5);
		};
		uv.refresh;
	};
	view.mouseMoveAction = { |uv, x, y|
		if (drag.notNil) { drag[\dur] = (cell.(x, y)[0] - drag[\step] + 1).max(1); uv.refresh };
	};
	view.mouseUpAction = { drag = nil };
	~animated.add({ if (view.isClosed) { false } { view.refresh; true } });
	view
};

~rollPanel = { |t|
	var roll = ~rollView.(t);
	var refresh = { roll.refresh };
	VLayout(
		~row.(
			~tmenu.(t, \play, [\roll, \wander], ["play roll", "wander"]),
			~tknob.(t, \speed, [0.25, 4, \exp], "roll speed", 44),
			~lbl.("steps"), ~menu.([8, 16, 32, 64], { t[\roll][\len] }, { |n| t[\roll][\len] = n; refresh.() }),
			~button.("oct -", { t[\rollLow] = t[\rollLow] - 12; refresh.() }),
			~button.("oct +", { t[\rollLow] = t[\rollLow] + 12; refresh.() }),
			~button.("suggest", { ~suggestRoll.(t); t[\play] = \roll; refresh.() }),
			~button.("keep wander", { ~keepHeard.(t); refresh.() }),
			~button.("clear", { t[\roll][\notes] = List[]; refresh.() }),
			~tknob.(t, \busy, [0, 1]),
			~tknob.(t, \repeats, [1, 8, \lin, 1]),
			~tknob.(t, \repChance, [0, 1], "repeat %"),
			~tknob.(t, \mutate, [0, 1]),
			~tknob.(t, \octave, [-3, 3, \lin, 1])
		),
		[roll, stretch: 1]
	)
};

// ---------------------------------------------------------------- step grid

~stepView = { |t|
	var view = UserView().minHeight_(60).canFocus_(false).background_(Color.grey(0.1));
	view.drawFunc = { |uv|
		var b = uv.bounds, w = b.width / 16;
		16.do { |i|
			var r = Rect(i * w + 3, 3, w - 6, b.height - 6);
			Pen.fillColor = Color.grey(if (i % 4 == 0) { 0.26 } { 0.18 });
			Pen.fillRect(r);
			if (t[\pat][i] == 1) { Pen.fillColor = t[\color]; Pen.fillRect(r) };
			if (t[\live][i] == 1 and: { t[\pat][i] == 0 }) {
				Pen.strokeColor = t[\color];
				Pen.width = 2;
				Pen.strokeRect(r.insetBy(4, 4));
			};
			if (t[\live][i] == 0 and: { t[\pat][i] == 1 }) {
				Pen.fillColor = Color(0, 0, 0, 0.55);
				Pen.fillOval(Rect.aboutPoint(r.center, 5, 5));
			};
			if (t[\pos] == i) { Pen.fillColor = Color(1, 1, 1, 0.22); Pen.fillRect(r) };
		};
	};
	view.mouseDownAction = { |uv, x|
		var i = (x / (uv.bounds.width / 16)).floor.asInteger.clip(0, 15), on = 1 - t[\pat][i];
		t[\pat][i] = on;
		t[\live][i] = on;
		uv.refresh;
	};
	~animated.add({ if (view.isClosed) { false } { view.refresh; true } });
	view
};

// ---------------------------------------------------------------- waveform

// Shows the track's file (t[\file]). Dragging selects a region: setRegion.(selection, buffer).
// The red cursor shows where the last note or grain played from.
// `follow` (optional function): when it returns true, the view jumps to whichever file is playing.
~waveView = { |t, getRegion, setRegion, onFile, follow|
	var sfv = SoundFileView().canFocus_(false).gridOn_(false).timeCursorOn_(true).timeCursorColor_(Color(1, 0.3, 0.3))
		.waveColors_([t[\color], t[\color]]).background_(Color.grey(0.1)).minHeight_(120)
		.setSelectionColor(0, Color(1, 1, 1, 0.12));
	var shown, lastLoad = 0;
	var names = ~bufs.collect { |b| PathName(b.path ? "?").fileName };
	var load = {
		var buf = ~bufs.wrapAt(t[\file]), sf;
		shown = buf;
		lastLoad = Main.elapsedTime;
		sf = SoundFile.openRead(buf.path);
		if (sf.notNil) {
			sfv.readFile(sf, 0, buf.numFrames.min(sf.numFrames), 64, true);
			sfv.setSelection(0, getRegion.value(buf));
		};
	};
	var pick = { |i|
		t[\file] = i % ~bufs.size;
		onFile.value(~bufs.wrapAt(t[\file]));
		load.();
	};
	sfv.mouseUpAction = {
		var sel = sfv.selection(0);
		if (sel[1] > 64) { setRegion.value(sel, shown) };
	};
	~animated.add({
		var playing;
		if (sfv.isClosed) { false } {
			if (follow.value == true and: { t[\lastBuf].notNil } and: { t[\lastBuf] !== shown }
				and: { Main.elapsedTime - lastLoad > 1.5 }) {
				t[\file] = ~bufs.indexOf(t[\lastBuf]) ? t[\file];
			};
			if (shown !== ~bufs.wrapAt(t[\file]) and: { Main.elapsedTime - lastLoad > 0.3 }) { load.() };
			if (t[\lastBuf] === shown and: { t[\lastPos].notNil }) { sfv.timeCursorPosition = t[\lastPos] };
			true
		}
	});
	load.();
	VLayout(
		~row.(~lbl.("file"), ~menu.((0 .. ~bufs.size - 1), { t[\file] }, pick, names),
			~button.("<", { pick.(t[\file] - 1) }), ~button.(">", { pick.(t[\file] + 1) }),
			~button.("random", { pick.(~bufs.size.rand) })),
		[sfv, stretch: 1]
	)
};

// ---------------------------------------------------------------- drawable wavetable

~waveEditor = { |t, key, label|
	var ms = MultiSliderView().canFocus_(false).size_(64).elasticMode_(1).isFilled_(false).drawLines_(true).drawRects_(false)
		.background_(Color.grey(0.1)).strokeColor_(t[\color]).minHeight_(110);
	var apply = { |points| ~setWave.(t, key, points); ms.value = points.linlin(-1, 1, 0, 1) };
	var shapes = [\sine, \tri, \saw, \square, \harmonics, \noise];
	ms.value = t[key].linlin(-1, 1, 0, 1);
	ms.action = { |m| ~setWave.(t, key, m.value.linlin(0, 1, -1, 1)) };
	VLayout(
		~row.(
			~lbl.(label),
			PopUpMenu().items_(["shape..."] ++ shapes.collect(_.asString))
				.action_({ |m| if (m.value > 0) { apply.(~shapes[shapes[m.value - 1]].()); m.value = 0 } }),
			~button.("smooth", { var p = t[key]; apply.(p.collect { |x, i| (p.wrapAt(i - 1) + x + p.wrapAt(i + 1)) / 3 }) }),
			~button.("fold", { apply.((t[key] * 1.8).fold(-1, 1)) }),
			~button.("nudge", { apply.((t[key] + Array.fill(64, { 0.15.rand2 })).clip(-1, 1)) })
		),
		ms
	)
};

// ---------------------------------------------------------------- drones: XY pad + big knobs

// Drag to move two params at once. The dot shows the live values, so modulation makes it crawl.
~xyPad = { |t, xk, yk|
	var params = ~voiceTypes[t[\type]][\params];
	var px = params.detect { |p| p[\key] == xk }, py = params.detect { |p| p[\key] == yk };
	var trail = List[], c = t[\color];
	var view = UserView().minSize_(Size(380, 320)).canFocus_(false).background_(Color.grey(0.07));
	var put = { |tid, spec, key, u|
		var m = ~modFor.(tid);
		if (m.notNil) { m[\home] = u } { ~tset.(t[\name], key, spec.map(u)) };
	};
	var setXY = { |uv, x, y|
		put.("t:%:%".format(t[\name], xk), px[\spec], xk, (x / uv.bounds.width).clip(0, 1));
		put.("t:%:%".format(t[\name], yk), py[\spec], yk, (1 - (y / uv.bounds.height)).clip(0, 1));
	};
	view.drawFunc = { |uv|
		var b = uv.bounds, pt = Point(px[\spec].unmap(t[xk]) * b.width, (1 - py[\spec].unmap(t[yk])) * b.height);
		trail.add(pt);
		if (trail.size > 160) { trail.removeAt(0) };
		Pen.strokeColor = Color.grey(0.16);
		8.do { |i|
			Pen.line(Point(b.width * i / 8, 0), Point(b.width * i / 8, b.height));
			Pen.line(Point(0, b.height * i / 8), Point(b.width, b.height * i / 8));
		};
		Pen.stroke;
		trail.do { |q, i|
			Pen.fillColor = Color(c.red, c.green, c.blue, i / trail.size * 0.6);
			Pen.fillOval(Rect.aboutPoint(q, 2 + (i / trail.size * 3), 2 + (i / trail.size * 3)));
		};
		Pen.fillColor = c;
		Pen.fillOval(Rect.aboutPoint(pt, 10, 10));
		Pen.stringAtPoint(xk.asString ++ " →", Point(8, b.height - 18), Font(Font.defaultSansFace, 11), Color.grey(0.6));
		Pen.stringAtPoint("↑ " ++ yk.asString, Point(8, 6), Font(Font.defaultSansFace, 11), Color.grey(0.6));
	};
	view.mouseDownAction = { |uv, x, y| setXY.(uv, x, y); nil };
	view.mouseMoveAction = { |uv, x, y| setXY.(uv, x, y); nil };
	~animated.add({ if (view.isClosed) { false } { view.refresh; true } });
	view
};

~droneClip = { |t|
	var it = ~voiceTypes[t[\type]];
	HLayout(
		[~xyPad.(t, it[\xy][0], it[\xy][1]), stretch: 2],
		[VLayout(
			~row.(~button.("dice (/)", { ~diceTrack.(t[\name]) }), ~button.("infect this", {
				it[\params].scramble.keep(2).do { |p| ~addMod.(~trackTarget.(t, p[\key], p[\spec], p[\label])) };
			}), ~lbl.("right-click a knob to make it move by itself")),
			*(it[\params].collect { |p| ~tknob.(t, p[\key], p[\spec], p[\label], 58) }
				.clump(4).collect { |row| HLayout(*(row ++ [nil])) }
				++ [HLayout(~tknob.(t, \busy, [0, 1], "spasms", 58), nil), nil])
		), stretch: 3]
	)
};

// ---------------------------------------------------------------- mods

// Every running modulator. Rate and depth are knobs too: right-click them for mods on mods.
~modsView = {
	var cards = ~mods.collect { |m|
		var tg = m[\target];
		var sources = [\shape] ++ ~voiceOrder.collect { |n| "follow:" ++ n }
			++ ~mods.reject { |x| x === m }.collect { |x| "mod:" ++ x[\id] };
		var srcLabels = ["own shape"] ++ ~voiceOrder.collect { |n| "follows " ++ n }
			++ ~mods.reject { |x| x === m }.collect { |x| "driven by " ++ x[\target][\name] };
		~panel.(tg[\name], Color(0.8, 0.8, 0.85), VLayout(
			~menu.(sources, { m[\source] }, { |x| m[\source] = x }, srcLabels),
			HLayout(
				~menu.(~modShapes, { m[\shape] }, { |x| m[\shape] = x }),
				~knob.("rate", m[\rateTarget][\spec], m[\rateTarget][\get], m[\rateTarget][\set], 40, ~accent,
					m[\rateTarget][\tid], m[\rateTarget][\name]),
				~knob.("depth", m[\depthTarget][\spec], m[\depthTarget][\get], m[\depthTarget][\set], 40, ~accent,
					m[\depthTarget][\tid], m[\depthTarget][\name]),
				nil
			)
		), 260, [Button().canFocus_(false).fixedWidth_(20).states_([["x"]]).action_({ ~removeMod.(m) })])
	};
	var grid = cards.clump(5).collect { |row| HLayout(*(row ++ [nil])) };
	ScrollView().canvas_(View().layout_(VLayout(*([
		~row.(~button.("infect (I)", { ~infect.(4) }), ~button.("cure all (\\)", { ~cure.() }),
			~lbl.("% mods running · right-click any knob anywhere to add one · right-click rate/depth for mods on mods".format(~mods.size)))
	] ++ grid ++ [nil]))))
};

// ---------------------------------------------------------------- drums

~laneH = 52;

// One row per lane: click a cell to toggle a hit, right-click to end the lane there (its length),
// drag across to paint. Darker cells are past the lane's end. Outline = mutation added, dot = removed.
~drumGrid = { |t|
	var lanes = t[\lanes], paint;
	var view = UserView().fixedHeight_(~laneH * lanes.size).canFocus_(false).background_(Color.grey(0.08));
	var cell = { |uv, x, y| [(x / (uv.bounds.width / 32)).floor.asInteger.clip(0, 31), (y / ~laneH).floor.asInteger.clip(0, lanes.size - 1)] };
	view.drawFunc = { |uv|
		var w = uv.bounds.width / 32;
		lanes.do { |ln, row|
			var y = row * ~laneH;
			32.do { |i|
				var r = Rect(i * w + 2, y + 3, w - 4, ~laneH - 6), inside = i < ln[\len];
				Pen.fillColor = case
				{ inside.not } { Color.grey(0.1) }
				{ i % 4 == 0 } { Color.grey(0.25) }
				{ Color.grey(0.17) };
				Pen.fillRect(r);
				if (inside) {
					if (ln[\pat][i] == 1) { Pen.fillColor = if (ln[\mute]) { Color.grey(0.4) } { t[\color] }; Pen.fillRect(r) };
					if (ln[\live][i] == 1 and: { ln[\pat][i] == 0 }) {
						Pen.strokeColor = t[\color]; Pen.width = 2; Pen.strokeRect(r.insetBy(3, 3));
					};
					if (ln[\live][i] == 0 and: { ln[\pat][i] == 1 }) {
						Pen.fillColor = Color(0, 0, 0, 0.55); Pen.fillOval(Rect.aboutPoint(r.center, 4, 4));
					};
					if (ln[\pos] == i) { Pen.fillColor = Color(1, 1, 1, 0.25); Pen.fillRect(r) };
				};
			};
			Pen.fillColor = Color.grey(0.5);
			Pen.fillRect(Rect(ln[\len] * w - 1, y + 2, 2, ~laneH - 4));
		};
	};
	view.mouseDownAction = { |uv, x, y, mod, bn|
		var c = cell.(uv, x, y), ln = lanes[c[1]];
		if (bn == 1 or: { mod.isAlt }) { ln[\len] = c[0] + 1; paint = nil } {
			paint = 1 - ln[\pat][c[0]];
			ln[\pat][c[0]] = paint;
			ln[\live][c[0]] = paint;
		};
		uv.refresh;
		nil
	};
	view.mouseMoveAction = { |uv, x, y|
		var c = cell.(uv, x, y), ln = lanes[c[1]];
		if (paint.notNil) { ln[\pat][c[0]] = paint; ln[\live][c[0]] = paint; uv.refresh };
		nil
	};
	view.mouseUpAction = { paint = nil; nil };
	~animated.add({ if (view.isClosed) { false } { view.refresh; true } });
	view
};

~laneRow = { |t, ln, i|
	var k = { |key, label|
		~knob.(label, ~laneSpecs[key], { ln[key] }, { |x| ln[key] = x }, 20, t[\color],
			"l:%:%:%".format(t[\name], i, key), "% % %".format(t[\name], ln[\name], key))
	};
	View().fixedHeight_(~laneH).layout_(HLayout(
		Button().canFocus_(false).fixedWidth_(56).states_([[ln[\name].asString, Color.black, t[\color]], [ln[\name].asString, Color.grey(0.7), Color.grey(0.25)]])
			.value_(ln[\mute].binaryValue).action_({ |b| ln[\mute] = b.value == 1 }),
		~toggle.("smp", { ln[\src] == \sample }, { |x|
			ln[\src] = if (x) { ln[\grain] = ln[\grain] ?? { ~pickDrumGrain.() }; \sample } { \synth };
		}, Color(0.5, 0.8, 1)).fixedWidth_(36),
		Button().canFocus_(false).fixedWidth_(30).states_([["gen"]]).action_({ ~genLane.(ln, i, t[\style] ? \euclid) }),
		k.(\level, "lvl"), k.(\pitch, "pitch"), k.(\decay, "dec"), k.(\tone, "tone"),
		k.(\mutate, "mut"), k.(\busy, "busy"), k.(\chance, "prob"), k.(\ratchet, "rat"), k.(\hop, "hop"),
		nil
	).margins_(0).spacing_(0))
};

~drumClip = { |t|
	VLayout(
		~row.(
			~lbl.("style"), ~menu.(~drumStyles, { t[\style] }, { |x| t[\style] = x }),
			~button.("generate kit", { ~genKit.(t, t[\style]) }),
			~button.("random style", { ~genKit.(t) }),
			~button.("keep variation", { t[\lanes].do { |ln| ln[\pat] = ln[\live].copy } }),
			~button.("clear", { t[\lanes].do { |ln| ln[\pat] = 0 ! 32; ln[\live] = 0 ! 32 } }),
			~button.("new samples", { ~repatch.(t[\name]) }),
			~tknob.(t, \swing, [0, 0.4], "swing", 30),
			~tknob.(t, \speed, [0.25, 4, \exp], "speed", 30),
			~lbl.("click = hit · drag = paint · right-click = lane length")
		),
		HLayout(
			VLayout(*(t[\lanes].collect { |ln, i| ~laneRow.(t, ln, i) } ++ [nil])).spacing_(0),
			[VLayout(~drumGrid.(t), nil), stretch: 1]
		),
		nil
	)
};
