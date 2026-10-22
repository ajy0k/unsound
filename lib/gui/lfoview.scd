// The LFO row: one card per LFO, + LFO for another. Each card: a drag handle (drop it on any knob),
// the shape (drag points, drag the dot halfway along a segment to bend it, double-click to add or
// remove a point), sync or free rate, a preset menu, ⧉ for a big editor, x to remove.

~lfoGraph = { |l, w = 180, h = 64|
	var view = UserView().minSize_(Size(w, h)).canFocus_(false).background_(Color.grey(0.07));
	var grab, kind, y0, c0;
	var px = { |b, p| Point(p[0] * b.width, (1 - p[1]) * b.height) };
	var mid = { |b, i| var a = l[\points][i], x = (a[0] + l[\points][i + 1][0]) / 2; Point(x * b.width, (1 - ~lfoAt.(l, x)) * b.height) };
	view.drawFunc = { |uv|
		var b = uv.bounds.moveTo(0, 0), pts = l[\points], n = 96, c = l[\color];
		Pen.strokeColor = Color.grey(0.18);
		[0.25, 0.5, 0.75].do { |x| Pen.line(Point(x * b.width, 0), Point(x * b.width, b.height)) };
		Pen.line(Point(0, b.height / 2), Point(b.width, b.height / 2));
		Pen.stroke;
		// the shape, filled
		Pen.moveTo(Point(0, b.height));
		(n + 1).do { |i| Pen.lineTo(Point(i / n * b.width, (1 - ~lfoAt.(l, i / n)) * b.height)) };
		Pen.lineTo(Point(b.width, b.height));
		Pen.fillColor = c.copy.alpha_(0.18);
		Pen.fill;
		Pen.width = 2;
		Pen.strokeColor = c;
		Pen.moveTo(Point(0, (1 - ~lfoAt.(l, 0)) * b.height));
		(n + 1).do { |i| Pen.lineTo(Point(i / n * b.width, (1 - ~lfoAt.(l, i / n)) * b.height)) };
		Pen.stroke;
		// points, and the bend handles halfway along each segment
		pts.do { |p| Pen.fillColor = Color.white; Pen.fillOval(Rect.aboutPoint(px.(b, p), 3.5, 3.5)) };
		(pts.size - 1).do { |i| Pen.strokeColor = c; Pen.width = 1; Pen.strokeOval(Rect.aboutPoint(mid.(b, i), 3, 3)) };
		// where it is now
		Pen.fillColor = Color.white;
		Pen.fillOval(Rect.aboutPoint(Point(l[\phase] * b.width, (1 - ((l[\val] + 1) / 2)) * b.height), 4.5, 4.5));
	};
	view.mouseDownAction = { |uv, x, y, mod, bn, clicks|
		var b = uv.bounds.moveTo(0, 0), pts = l[\points], hit, seg;
		hit = pts.detectIndex { |p| px.(b, p).dist(Point(x, y)) < 7 };
		seg = if (hit.isNil) { (pts.size - 1).collect { |i| i }.detect { |i| mid.(b, i).dist(Point(x, y)) < 7 } };
		case
		{ clicks == 2 and: { hit.notNil } } {
			if (hit > 0 and: { hit < (pts.size - 1) }) { pts.removeAt(hit) };
			grab = nil;
		}
		{ clicks == 2 } {
			// add a point where you clicked
			var nx = (x / b.width).clip(0.001, 0.999), i = pts.detectIndex { |p| p[0] > nx } ? pts.size;
			l[\points] = pts.insert(i, [nx, (1 - (y / b.height)).clip(0, 1), 0]);
			grab = nil;
		}
		{ hit.notNil } { grab = hit; kind = \point }
		{ seg.notNil } { grab = seg; kind = \bend; y0 = y; c0 = pts[seg][2] ? 0 }
		{ grab = nil };
		uv.refresh;
		nil
	};
	view.mouseMoveAction = { |uv, x, y|
		var b = uv.bounds.moveTo(0, 0), pts = l[\points], p, lo, hi, dir;
		if (grab.notNil) {
			if (kind == \point) {
				p = pts[grab];
				lo = if (grab == 0) { 0 } { pts[grab - 1][0] + 0.001 };
				hi = if (grab == (pts.size - 1)) { 1 } { pts[grab + 1][0] - 0.001 };
				// the ends stay at the ends
				p[0] = if (grab == 0) { 0 } { if (grab == (pts.size - 1)) { 1 } { (x / b.width).clip(lo, hi) } };
				p[1] = (1 - (y / b.height)).clip(0, 1);
			} {
				dir = if (pts[grab + 1][1] >= pts[grab][1]) { 1 } { -1 };
				pts[grab][2] = (c0 + ((y - y0) / 12 * dir)).clip(-12, 12);
			};
			uv.refresh;
		};
		nil
	};
	view.mouseUpAction = { grab = nil; nil };
	~animated.add({ if (view.isClosed) { false } { view.refresh; true } });
	view
};

// Drag this onto any knob (or every-so-often slider) to modulate it with this LFO.
~lfoHandle = { |l|
	var v = UserView().fixedSize_(Size(46, 18)).canFocus_(false), down;
	v.drawFunc = { |uv|
		var b = uv.bounds.moveTo(0, 0);
		Pen.fillColor = l[\color];
		Pen.addRoundedRect(b, 4, 4);
		Pen.fill;
		Pen.stringCenteredIn("✥ drag", b, Font(Font.defaultSansFace, 10, true), Color.black);
	};
	v.toolTip = "drag onto any knob to modulate it with LFO " ++ l[\id] ++ "\nthen drag that knob's outer ring up / down for how much";
	v.beginDragAction = { (kind: \lfo, id: l[\id]) };
	v.dragLabel = "LFO " ++ l[\id];
	v.mouseDownAction = { |uv, x, y| down = Point(x, y); nil };
	v.mouseMoveAction = { |uv, x, y| if (down.notNil and: { Point(x, y).dist(down) > 3 }) { down = nil; uv.beginDrag(x, y) }; nil };
	v.mouseUpAction = { down = nil; nil };
	v
};

~lfoCard = { |l, big = false|
	var rateHolder = View().layout_(HLayout().margins_(0)), fillRate;
	var shape = PopUpMenu().canFocus_(false).items_(["shape…"] ++ ~lfoShapeNames.collect(_.asString)).fixedWidth_(64)
		.action_({ |m| if (m.value > 0) { l[\points] = ~lfoShapes[~lfoShapeNames[m.value - 1]].value.collect(_.copy); m.value = 0 } });
	var count = StaticText().font_(Font(Font.defaultSansFace, 9)).stringColor_(Color.grey(0.6));
	fillRate = {
		rateHolder.removeAll;
		rateHolder.layout = HLayout(if (l[\sync]) {
			~menu.(~lfoSyncs, { l[\beats] }, { |x| l[\beats] = x }, ~lfoSyncNames).fixedWidth_(64)
		} {
			var tg = ~lfoTarget.(l);
			~knob.(nil, tg[\spec], tg[\get], tg[\set], 16, l[\color], tg[\tid], tg[\name])
		}).margins_(0);
	};
	fillRate.();
	~bindings.add({
		if (count.isClosed) { false } {
			count.string = "→ " ++ ~mods.count { |m| m[\source] == ("lfo:" ++ l[\id]) };
			true
		}
	});
	View().background_(Color.grey(0.17)).fixedWidth_(if (big) { 620 } { 210 }).layout_(VLayout(
		HLayout(
			StaticText().string_("LFO " ++ l[\id]).font_(Font(Font.defaultSansFace, 10, true)).stringColor_(l[\color]),
			~lfoHandle.(l), count, nil,
			Button().canFocus_(false).fixedSize_(Size(18, 16)).states_([["⧉"]]).toolTip_("a big editor")
				.action_({ ~popOut.("lfo:" ++ l[\id], "LFO " ++ l[\id], { ~lfoCard.(l, true) }, { ~lfos.includes(l) }) }),
			Button().canFocus_(false).fixedSize_(Size(16, 16)).states_([["x"]]).toolTip_("remove this LFO (and what it's moving)")
				.action_({ ~removeLfo.(l) })
		).spacing_(3),
		if (big) { [~lfoGraph.(l, 600, 260), stretch: 1] } { ~lfoGraph.(l, 194, 50).fixedHeight_(50) },
		HLayout(
			~toggle.("sync", { l[\sync] }, { |x| l[\sync] = x; { fillRate.() }.defer }, l[\color]).fixedWidth_(40),
			rateHolder, shape, nil
		).spacing_(2)
	).margins_(3).spacing_(2))
};

~lfoHolders = List[];

~lfoRow = {
	var holder = View();
	~lfoHolders.add(holder);
	~fillLfoRow.(holder);
	~hscroll.(ScrollView().hasVerticalScroller_(false).fixedHeight_(128).canvas_(holder))
};

~fillLfoRow = { |holder|
	holder.removeAll;
	holder.layout = HLayout(*(~lfos.collect { |l| ~lfoCard.(l) } ++ [
		Button().canFocus_(false).states_([["+ LFO"]]).fixedSize_(Size(60, 40)).toolTip_("another LFO (as many as you like)")
			.action_({ ~newLfo.(\sine) }),
		nil
	])).margins_(2).spacing_(4);
};

~refreshLfos = {
	{
		~lfoHolders.removeAllSuchThat(_.isClosed);
		~lfoHolders.do { |h| ~fillLfoRow.(h) };
	}.defer;
};
