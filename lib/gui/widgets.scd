// GUI building blocks. Every control is bound to a getter/setter and follows the value when
// something else (a ramp, a mover, MIDI, a scene) changes it. Nothing takes keyboard focus,
// so the computer keyboard always plays (see lib/control.scd).

~bindings = List[];   // run every tick; each returns false once its view is gone
~animated = List[];

~accent = Color(1, 0.6, 0.2);

~fmt = { |val|
	case
	{ val.isNumber.not } { val.asString }
	{ val.abs >= 10000 } { (val / 1000).round(0.1).asString ++ "k" }
	{ val.abs >= 100 } { val.round(1).asInteger.asString }
	{ val.round(0.01).asString }
};

~lbl = { |str, size = 10| StaticText().string_(str).font_(Font(Font.defaultSansFace, size)) };

~button = { |str, action| Button().canFocus_(false).states_([[str]]).action_(action) };

~row = { |...items| HLayout(*(items ++ [nil])).spacing_(4) };

~isMapped = { |target| ~midiMap.any { |m| m[\target] === target } };

// A drawn knob: drag up/down (shift = fine), scroll wheel, double-click resets.
// Right-click (or alt-click) gives it a modulator, or takes it away. A modulated knob shows its
// range as a thin outer arc; turning it moves the home the mod swings around.
// In MIDI learn mode, touching it makes it the learn target (yellow ring).
// `tid` is a stable id (so mods survive the GUI being rebuilt); `name` labels it in the mods view.
~knob = { |label, spec, get, set, size = 40, color, tid, name, learnAs|
	var w = size + 18, view = UserView().fixedSize_(Size(w, size + 30)).canFocus_(false);
	var val, def, touched = 0, y0, v0, center, target, change;
	spec = spec.asSpec;
	val = spec.unmap(get.value ? spec.default);
	def = val;
	center = if (spec.minval < 0 and: { spec.maxval > 0 }) { spec.unmap(0) } { 0 };
	color = color ? ~accent;
	target = (tid: tid ? label, name: name ? label, spec: spec, get: get, set: set);
	change = { |x|
		var m = ~modFor.(target[\tid]);
		val = x.clip(0, 1);
		touched = Main.elapsedTime;
		if (m.notNil) { m[\home] = val } { set.(spec.map(val)) };
		view.refresh;
	};
	view.drawFunc = { |uv|
		var c = Point(w / 2, 15 + (size / 2)), r = size / 2 - 3, a0 = 0.75pi, sw = 1.5pi;
		var a = a0 + (sw * val), ac = a0 + (sw * center), m = ~modFor.(target[\tid]), lo, hi;
		if (label.notNil) {
			Pen.stringCenteredIn(label, Rect(0, 0, w, 13), Font(Font.defaultSansFace, 9), Color.grey(0.72));
		};
		Pen.fillColor = Color.grey(0.17);
		Pen.addOval(Rect.aboutPoint(c, r - 4, r - 4));
		Pen.fill;
		Pen.width = 4;
		Pen.strokeColor = Color.grey(0.3);
		Pen.addArc(c, r, a0, sw);
		Pen.stroke;
		Pen.strokeColor = color;
		Pen.addArc(c, r, min(a, ac), (a - ac).abs.max(0.02));
		Pen.stroke;
		if (m.notNil) {
			lo = (m[\home] - m[\depth]).clip(0, 1);
			hi = (m[\home] + m[\depth]).clip(0, 1);
			Pen.width = 2;
			Pen.strokeColor = Color(1, 1, 1, 0.55);
			Pen.addArc(c, r + 4, a0 + (sw * lo), (sw * (hi - lo)).max(0.02));
			Pen.stroke;
			Pen.fillColor = Color(1, 1, 1, 0.8);
			Pen.addOval(Rect.aboutPoint(c + (Point((a0 + (sw * m[\home])).cos, (a0 + (sw * m[\home])).sin) * (r + 4)), 2.5, 2.5));
			Pen.fill;
		};
		Pen.width = 2;
		Pen.strokeColor = Color.grey(0.92);
		Pen.line(c + (Point(a.cos, a.sin) * (r * 0.25)), c + (Point(a.cos, a.sin) * (r - 5)));
		Pen.stroke;
		if (~learnTarget === (learnAs ? target)) {
			Pen.strokeColor = Color.yellow;
			Pen.width = 2;
			Pen.addOval(Rect.aboutPoint(c, r + 2, r + 2));
			Pen.stroke;
		};
		if (~isMapped.(learnAs ? target)) {
			Pen.fillColor = Color(0.4, 0.8, 1);
			Pen.addOval(Rect.aboutPoint(Point(w - 6, 18), 3, 3));
			Pen.fill;
		};
		Pen.stringCenteredIn(~fmt.(spec.map(val)), Rect(0, size + 16, w, 13), Font.monospace(9), Color.grey(0.88));
	};
	view.mouseDownAction = { |uv, x, y, mod, bn, clicks|
		case
		{ bn == 1 or: { mod.isAlt } } { ~toggleMod.(target); y0 = nil; uv.refresh }
		{ clicks == 2 } { change.(def) }
		{ y0 = y; v0 = (~modFor.(target[\tid]) !? { |m| m[\home] }) ? val; ~learn.(learnAs ? target) };
		nil
	};
	view.mouseMoveAction = { |uv, x, y, mod|
		if (y0.notNil) { change.(v0 + ((y0 - y) / (if (mod.isShift) { 900 } { 180 }))) };
		nil
	};
	view.mouseUpAction = { y0 = nil; nil };
	view.mouseWheelAction = { |uv, x, y, mod, dx, dy| change.(val + (dy.sign * (if (mod.isShift) { 0.002 } { 0.015 }))); true };
	~bindings.add({
		var nv;
		if (view.isClosed) { false } {
			if (Main.elapsedTime - touched > 0.5 or: { ~modFor.(target[\tid]).notNil and: { y0.isNil } }) {
				nv = get.value;
				if (nv.isNumber) {
					nv = spec.unmap(nv);
					if ((nv - val).abs > 0.0005) { val = nv; view.refresh };
				};
			};
			if (~midiLearn) { view.refresh };
			true
		}
	});
	view
};

// A slider with no numbers. Drag (or click) along it; right-click gives it a modulator, like a knob.
// `glow` (optional function) returns 0..1 to light it up (sometimes uses it to flash when it fires).
~bar = { |spec, get, set, color, tid, name, width = 90, glow|
	var view = UserView().fixedHeight_(18).minWidth_(width).canFocus_(false), val = 0, touched = 0, target, change, dragging = false;
	spec = spec.asSpec;
	color = color ? ~accent;
	target = (tid: tid, name: name, spec: spec, get: get, set: set);
	val = spec.unmap(get.value ? spec.default);
	change = { |x|
		var m = ~modFor.(tid);
		val = x.clip(0, 1);
		touched = Main.elapsedTime;
		if (m.notNil) { m[\home] = val } { set.(spec.map(val)) };
		view.refresh;
	};
	view.drawFunc = { |uv|
		var b = uv.bounds.moveTo(0, 0), m = ~modFor.(tid), g = (glow.value ? 0).clip(0, 1);
		Pen.fillColor = Color.grey(0.13).blend(color, g * 0.5);
		Pen.fillRect(b);
		Pen.fillColor = color.copy.alpha_(0.85);
		Pen.fillRect(Rect(0, 3, b.width * val, b.height - 6));
		if (m.notNil) {
			Pen.fillColor = Color(1, 1, 1, 0.35);
			Pen.fillRect(Rect(b.width * (m[\home] - m[\depth].abs).clip(0, 1), 0,
				b.width * ((m[\home] + m[\depth].abs).clip(0, 1) - (m[\home] - m[\depth].abs).clip(0, 1)), 2));
		};
		if (g > 0.05) {
			Pen.strokeColor = Color.white.alpha_(g);
			Pen.width = 2;
			Pen.strokeRect(b.insetBy(1, 1));
		};
		if (~learnTarget === target) { Pen.strokeColor = Color.yellow; Pen.width = 2; Pen.strokeRect(b.insetBy(1, 1)) };
		if (~isMapped.(target)) { Pen.fillColor = Color(0.4, 0.8, 1); Pen.fillOval(Rect(b.width - 7, 2, 5, 5)) };
	};
	view.mouseDownAction = { |uv, x, y, mod, bn, clicks|
		case
		{ bn == 1 or: { mod.isAlt } } { ~toggleMod.(target); uv.refresh }
		{ clicks == 2 } { change.(0) }
		{ dragging = true; ~learn.(target); change.(x / uv.bounds.width) };
		nil
	};
	view.mouseMoveAction = { |uv, x| if (dragging) { change.(x / uv.bounds.width) }; nil };
	view.mouseUpAction = { dragging = false; nil };
	view.mouseWheelAction = { |uv, x, y, mod, dx, dy| change.(val + (dy.sign * 0.02)); true };
	~animated.add({
		var nv;
		if (view.isClosed) { false } {
			if (Main.elapsedTime - touched > 0.5) {
				nv = get.value;
				if (nv.isNumber) { val = spec.unmap(nv) };
			};
			view.refresh;
			true
		}
	});
	view
};

// "Every so often": a button that does it now, and a slider (no numbers) for how often.
~sometimesW = { |label, id, get, set, color, width = 90|
	var glow = { (~soFor.(id) !? { |e| 1 - ((Main.elapsedTime - e[\last]) / 0.6) } ? 0).max(0) };
	var b = Button().canFocus_(false).font_(Font(Font.defaultSansFace, 10))
		.states_([[label, Color.grey(0.85), Color.grey(0.24)]])
		.action_({ ~soFor.(id) !? { |e| ~soFire.(e) } });
	HLayout(b, ~bar.([0, 1], get, set, color, id, label, width, glow)).spacing_(2).margins_(0)
};

// Sometimes bound to a track key.
~tsometimes = { |t, key, label, width = 90|
	~sometimesW.(label, "t:%:%".format(t[\name], key), { t[key] }, { |x| ~tset.(t[\name], key, x) }, t[\color], width)
};

// Knob bound to a track setting.
~tknob = { |t, key, spec, label, size = 40|
	~knob.(label ? key.asString, spec, { t[key] }, { |x| ~tset.(t[\name], key, x) }, size, t[\color],
		"t:%:%".format(t[\name], key), "% %".format(t[\name], label ? key))
};

// Knob bound to a device parameter.
~dknob = { |t, d, p, color|
	~knob.(p[\label], p[\spec], { d[\params][p[\key]] }, { |x| ~dparam.(d, p[\key], x) }, 38, color,
		"d:%:%".format(d[\uid], p[\key]), "% % %".format(t[\name], d[\label] ? d[\type], p[\label]))
};

// The mystery knob: sweeps a hidden handful of the device's params.
~qknob = { |t, d|
	~knob.("?", [0, 1], { d[\q] }, { |x| ~dmystery.(d, x) }, 38, Color.white,
		"d:%:?".format(d[\uid]), "% % ?".format(t[\name], d[\label] ? d[\type]))
};

~menu = { |items, get, set, labels|
	var m = PopUpMenu().canFocus_(false).items_((labels ? items).collect(_.asString));
	m.value = items.indexOfEqual(get.value) ? 0;
	m.action = { set.(items[m.value]) };
	~bindings.add({
		var i;
		if (m.isClosed) { false } {
			i = items.indexOfEqual(get.value);
			if (i.notNil and: { i != m.value }) { m.value = i };
			true
		}
	});
	m
};

~tmenu = { |t, key, items, labels| ~menu.(items, { t[key] }, { |x| ~tset.(t[\name], key, x) }, labels) };

// Two-state button bound to a boolean. MIDI-learnable.
~toggle = { |label, get, set, onColor|
	var b = Button().canFocus_(false)
		.states_([[label, Color.grey(0.75), Color.grey(0.24)], [label, Color.black, onColor ? ~accent]]);
	var target = (name: label, toggle: { set.(get.value != true) });
	b.value = (get.value == true).binaryValue;
	b.action = { set.(b.value == 1); ~learn.(target) };
	~bindings.add({
		var v;
		if (b.isClosed) { false } {
			v = (get.value == true).binaryValue;
			if (v != b.value) { b.value = v };
			true
		}
	});
	b
};

// An Ableton-ish device box: coloured title bar, then the controls.
~panel = { |title, color, content, width, extras|
	var v = View().background_(Color.grey(0.19));
	if (width.notNil) { v.fixedWidth_(width) };
	v.layout_(VLayout(
		View().background_(color ? Color.grey(0.5)).fixedHeight_(22).layout_(
			HLayout(*([StaticText().string_(title).stringColor_(Color.black).font_(Font(Font.defaultSansFace, 11, true))]
				++ [nil] ++ (extras ? []))).margins_([6, 0, 2, 0]).spacing_(2)
		),
		content,
		nil
	).margins_(3).spacing_(3))
};

// ---------------------------------------------------------------- pop-out windows

// Any device, or a whole track, can live in its own window, as many as you like, like plugin
// windows in a DAW (Cmd-` cycles them). A window closes itself when its device or track goes away.
// `rebuild`: the window is rebuilt when the track changes (devices added / removed).
~popups = ();

~popOut = { |key, title, build, alive, rebuild = false|
	var p = ~popups[key], w, holder, n = ~popups.size;
	if (p.notNil and: { p[\win].isClosed.not }) { p[\win].front } {
		holder = View().layout_(VLayout(build.value).margins_(4));
		w = Window(title, Rect(80 + (n * 26), 120 + (n * 26), 420, 300)).background_(Color.grey(0.12));
		w.layout = VLayout(holder).margins_(0);
		w.onClose = { ~popups.removeAt(key) };
		{ var sz = holder.sizeHint; w.setInnerExtent(sz.width.clip(260, 1600), sz.height.clip(120, 1000)) }.defer(0.05);
		w.front;
		~popups[key] = (win: w, holder: holder, build: build, alive: alive, rebuild: rebuild);
		~bindings.add({ if (w.isClosed) { false } { if (alive.value != true) { w.close; false } { true } } });
	};
};

~refreshPopups = {
	~popups.do { |p|
		if (p[\rebuild] and: { p[\win].isClosed.not } and: { p[\alive].value == true }) {
			p[\holder].removeAll;
			p[\holder].layout = VLayout(p[\build].value).margins_(4);
		};
	};
};

~closePopups = { ~popups.copy.do { |p| if (p[\win].isClosed.not) { p[\win].close } } };

// ⧉ on a device's title bar.
~popButton = { |t, d|
	Button().canFocus_(false).fixedWidth_(20).states_([["⧉"]]).action_({
		~popOut.("d:%".format(d[\uid]), "% · %".format(t[\name], d[\label] ? d[\type]), { ~devicePanel.(t, d) },
			{ ~tracks[t[\name]] === t and: { t[\devices].includes(d) } });
	})
};

// A whole track in its own window: its screen and its chain.
~popTrack = { |t|
	~popOut.("t:%".format(t[\name]), t[\name].asString, {
		VLayout([~boxScreen.(t), stretch: 1], [~chain.(t), stretch: 1])
	}, { ~tracks[t[\name]] === t }, true);
};

// Make a view accept things dragged from the browser. nameFn → track name, indexFn.(x, y) → chain index.
~dropTarget = { |view, nameFn, indexFn|
	view.canReceiveDragHandler_({ View.currentDrag.isKindOf(Event) })
		.receiveDragHandler_({ |v, x, y| ~dropOn.(nameFn.value, View.currentDrag, indexFn.value(x, y)) })
};

~dropOn = { |name, obj, index|
	switch (obj[\kind])
	{ \inst } { ~add.(obj[\type]) }
	{ \item } { if (name.notNil) { ~addItem.(name, obj[\item], index) } };
};

// A ScrollView that scrolls sideways with the ordinary scroll wheel (no shift needed).
~hscroll = { |sv|
	sv.mouseWheelAction = { |v, x, y, mod, dx, dy|
		var o = v.visibleOrigin;
		v.visibleOrigin = Point((o.x - (dy * 3) - (dx * 3)).max(0), o.y);
		true
	};
	sv
};

~startTick = {
	~tick.stop;
	~tick = Routine({
		loop {
			// in place: select/reject hand back Arrays, and adding to those can silently drop things
			~bindings.removeAllSuchThat { |f| f.value.not };
			~animated.removeAllSuchThat { |f| f.value.not };
			0.05.wait;
		}
	}).play(AppClock);
};
