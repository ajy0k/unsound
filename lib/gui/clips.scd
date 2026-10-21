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
