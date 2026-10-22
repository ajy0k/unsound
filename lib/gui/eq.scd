// EQ Eight's panel: the curve is the real response of the eight biquads (same RBJ formulas the
// B* filters use). Drag a dot: left/right = freq, up/down = gain. Scroll on a dot = Q.
// Double-click a dot = band on/off. Click a number below to pick a band; its type, freq, gain
// and Q are knobs there (so they can be modulated and mapped like any other knob).

~eqColors = [Color(0.95, 0.4, 0.4), Color(0.95, 0.65, 0.3), Color(0.95, 0.9, 0.35), Color(0.5, 0.9, 0.4),
	Color(0.35, 0.85, 0.85), Color(0.4, 0.6, 1), Color(0.7, 0.5, 1), Color(0.95, 0.5, 0.85)];

// Magnitude in dB of one band at frequency `hz`.
~eqBandDb = { |type, f, g, q, hz, sr = 48000|
	var w0 = 2pi * f.clip(10, sr * 0.49) / sr, cw = cos(w0), sw = sin(w0), a = 10 ** (g / 40);
	var alpha = sw / (2 * q.max(0.05)), sa = 2 * a.sqrt * (sw / 2 * 2.sqrt);
	var c = switch (type.round.asInteger)
	{ 0 } { [(1 + cw) / 2, (1 + cw).neg, (1 + cw) / 2, 1 + alpha, -2 * cw, 1 - alpha] }
	{ 1 } { [a * ((a + 1) - ((a - 1) * cw) + sa), 2 * a * ((a - 1) - ((a + 1) * cw)), a * ((a + 1) - ((a - 1) * cw) - sa),
		(a + 1) + ((a - 1) * cw) + sa, -2 * ((a - 1) + ((a + 1) * cw)), (a + 1) + ((a - 1) * cw) - sa] }
	{ 2 } { [1 + (alpha * a), -2 * cw, 1 - (alpha * a), 1 + (alpha / a), -2 * cw, 1 - (alpha / a)] }
	{ 3 } { [1, -2 * cw, 1, 1 + alpha, -2 * cw, 1 - alpha] }
	{ 4 } { [a * ((a + 1) + ((a - 1) * cw) + sa), -2 * a * ((a - 1) + ((a + 1) * cw)), a * ((a + 1) + ((a - 1) * cw) - sa),
		(a + 1) - ((a - 1) * cw) + sa, 2 * ((a - 1) - ((a + 1) * cw)), (a + 1) - ((a - 1) * cw) - sa] }
	{ [(1 - cw) / 2, 1 - cw, (1 - cw) / 2, 1 + alpha, -2 * cw, 1 - alpha] };
	var w = 2pi * hz / sr;
	var num = (c[0] + (c[1] * cos(w)) + (c[2] * cos(2 * w))).squared + ((c[1] * sin(w)) + (c[2] * sin(2 * w))).squared;
	var den = (c[3] + (c[4] * cos(w)) + (c[5] * cos(2 * w))).squared + ((c[4] * sin(w)) + (c[5] * sin(2 * w))).squared;
	10 * log10(num.max(1e-12) / den.max(1e-12))
};

~eqKey = { |k, n| (k ++ n).asSymbol };

~eq8Graph = { |t, d, getSel, setSel|
	var view = UserView().fixedSize_(Size(456, 190)).canFocus_(false).background_(Color.grey(0.08));
	var fSpec = ControlSpec(20, 20000, \exp), dbRange = 24, drag, sr = s.sampleRate ? 48000;
	var pr = d[\params];
	var xOf = { |f, w| fSpec.unmap(f) * w }, yOf = { |db, h| h / 2 - (db / dbRange * (h / 2)) };
	var dotY = { |n, h| var ty = pr[~eqKey.(\t, n)].round; if ([0, 3, 5].includes(ty)) { h / 2 } { yOf.(pr[~eqKey.(\g, n)], h) } };
	var put = { |key, val, spec|
		~setOrHome.("d:%:%".format(d[\uid], key), spec.asSpec, val, { |x| ~dparam.(d, key, x) });
	};
	var hitBand = { |x, y, b|
		(1..8).detect { |n| Point(xOf.(pr[~eqKey.(\f, n)], b.width), dotY.(n, b.height)).dist(Point(x, y)) < 10 }
	};
	view.drawFunc = { |uv|
		var b = uv.bounds.moveTo(0, 0), pts;
		// grid: octaves and 6 dB lines
		Pen.strokeColor = Color.grey(0.2);
		[50, 100, 200, 500, 1000, 2000, 5000, 10000].do { |f|
			Pen.line(Point(xOf.(f, b.width), 0), Point(xOf.(f, b.width), b.height));
		};
		[-18, -12, -6, 6, 12, 18].do { |db| Pen.line(Point(0, yOf.(db, b.height)), Point(b.width, yOf.(db, b.height))) };
		Pen.stroke;
		Pen.strokeColor = Color.grey(0.35);
		Pen.line(Point(0, b.height / 2), Point(b.width, b.height / 2));
		Pen.stroke;
		[100, 1000, 10000].do { |f|
			Pen.stringAtPoint(if (f >= 1000) { (f div: 1000).asString ++ "k" } { f.asString },
				Point(xOf.(f, b.width) + 2, b.height - 12), Font.monospace(8), Color.grey(0.45));
		};
		// the curve
		pts = (0..112).collect { |i|
			var hz = fSpec.map(i / 112), db = 0;
			(1..8).do { |n|
				if (pr[~eqKey.(\on, n)] > 0.5) {
					db = db + ~eqBandDb.(pr[~eqKey.(\t, n)], pr[~eqKey.(\f, n)], pr[~eqKey.(\g, n)], pr[~eqKey.(\q, n)], hz, sr);
				};
			};
			Point(i / 112 * b.width, yOf.(db.clip(-40, 40), b.height))
		};
		Pen.width = 2;
		Pen.strokeColor = t[\color] ? ~accent;
		Pen.moveTo(pts[0]);
		pts.drop(1).do { |p| Pen.lineTo(p) };
		Pen.stroke;
		Pen.fillColor = (t[\color] ? ~accent).copy.alpha_(0.12);
		Pen.moveTo(Point(0, b.height / 2));
		pts.do { |p| Pen.lineTo(p) };
		Pen.lineTo(Point(b.width, b.height / 2));
		Pen.fill;
		// the dots
		(1..8).do { |n|
			var on = pr[~eqKey.(\on, n)] > 0.5, c = ~eqColors[n - 1], p = Point(xOf.(pr[~eqKey.(\f, n)], b.width), dotY.(n, b.height));
			Pen.fillColor = if (on) { c } { Color.grey(0.3) };
			Pen.fillOval(Rect.aboutPoint(p, 7, 7));
			if (getSel.value == n) { Pen.strokeColor = Color.white; Pen.width = 2; Pen.strokeOval(Rect.aboutPoint(p, 9, 9)) };
			Pen.stringCenteredIn(n.asString, Rect.aboutPoint(p, 7, 7), Font(Font.defaultSansFace, 9, true), Color.black);
		};
	};
	view.mouseDownAction = { |uv, x, y, mod, bn, clicks|
		var n = hitBand.(x, y, uv.bounds);
		if (n.notNil) {
			setSel.(n);
			if (clicks == 2) { put.(~eqKey.(\on, n), 1 - pr[~eqKey.(\on, n)].round, [0, 1]); drag = nil } { drag = n };
		} { drag = nil };
		nil
	};
	view.mouseMoveAction = { |uv, x, y|
		var b = uv.bounds;
		if (drag.notNil) {
			put.(~eqKey.(\f, drag), fSpec.map((x / b.width).clip(0, 1)), fSpec);
			if ([0, 3, 5].includes(pr[~eqKey.(\t, drag)].round).not) {
				put.(~eqKey.(\g, drag), ((b.height / 2 - y) / (b.height / 2) * dbRange).clip(-18, 18), [-18, 18]);
			};
		};
		nil
	};
	view.mouseUpAction = { drag = nil; nil };
	view.mouseWheelAction = { |uv, x, y, mod, dx, dy|
		var n = hitBand.(x, y, uv.bounds) ? getSel.value, k = ~eqKey.(\q, n);
		put.(k, (pr[k] * (1.1 ** dy.sign)).clip(0.1, 18), [0.1, 18, \exp]);
		true
	};
	~animated.add({ if (view.isClosed) { false } { view.refresh; true } });
	view
};

~eq8Panel = { |t, d|
	var sel = d[\eqSel] ? 2, knobs = View().layout_(HLayout().margins_(0).spacing_(2)), fill, graph, picks;
	var params = ~deviceTypes[\eq8][\params];
	var pk = { |key| params.detect { |p| p[\key] == key } };
	fill = {
		var n = sel;
		knobs.removeAll;
		knobs.layout = HLayout(*([
			~menu.((0..5), { d[\params][~eqKey.(\t, n)].round }, { |x| ~dparam.(d, ~eqKey.(\t, n), x) }, ~eq8Types),
			~toggle.("on", { d[\params][~eqKey.(\on, n)] > 0.5 }, { |x| ~dparam.(d, ~eqKey.(\on, n), x.binaryValue) }, ~eqColors[n - 1])
		] ++ [\f, \g, \q].collect { |k| ~dknob.(t, d, pk.(~eqKey.(k, n)), ~eqColors[n - 1]) }
		++ [~dknob.(t, d, pk.(\out), Color.grey(0.7)), nil])).margins_(0).spacing_(2);
	};
	picks = (1..8).collect { |n|
		Button().canFocus_(false).fixedWidth_(26).states_([[n.asString, Color.black, ~eqColors[n - 1]]])
			.action_({ sel = n; d[\eqSel] = n; fill.() })
	};
	graph = ~eq8Graph.(t, d, { sel }, { |n| if (n != sel) { sel = n; d[\eqSel] = n; fill.() } });
	fill.();
	VLayout(graph, HLayout(*(picks ++ [nil])).spacing_(2), knobs).spacing_(3)
};
