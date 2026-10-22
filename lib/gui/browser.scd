// The browser (left side, like Ableton's): instruments, effects by category, and whole chains.
// Double-click an entry to add it to the end of the selected track's chain (instruments make a
// new track). Or drag it onto a mixer strip, the device area, or onto a device to insert before it.

~catColors = (instruments: Color(0.35, 0.75, 0.9), distortion: Color(0.95, 0.45, 0.3), filter: Color(0.95, 0.8, 0.3),
	time: Color(0.45, 0.85, 0.55), glitch: Color(0.85, 0.45, 0.95), dynamics: Color(0.7, 0.7, 0.75),
	chains: Color(1, 0.6, 0.75));

~browserEntry = { |label, obj, color|
	var v = UserView().fixedHeight_(19).canFocus_(false), down, over = false, flash = 0;
	v.drawFunc = { |uv|
		var b = uv.bounds.moveTo(0, 0);
		Pen.fillColor = Color.grey(if (over) { 0.28 } { 0.19 }).blend(color, flash);
		Pen.fillRect(b);
		Pen.fillColor = color;
		Pen.fillRect(Rect(0, 0, 4, b.height));
		Pen.stringAtPoint(label, Point(10, 2), Font(Font.defaultSansFace, 11), Color.grey(0.92));
	};
	v.beginDragAction = { obj };
	v.dragLabel = label;
	v.mouseDownAction = { |uv, x, y, mod, bn, clicks|
		if (clicks == 2) {
			~dropOn.(~selected, obj);
			flash = 0.6;
			{ 4.do { flash = flash * 0.5; uv.refresh; 0.06.wait } }.fork(AppClock);
			down = nil;
		} { down = Point(x, y) };
		nil
	};
	v.mouseMoveAction = { |uv, x, y|
		if (down.notNil and: { Point(x, y).dist(down) > 4 }) { down = nil; uv.beginDrag(x, y) };
		nil
	};
	v.mouseUpAction = { down = nil; nil };
	v.mouseEnterAction = { over = true; v.refresh };
	v.mouseLeaveAction = { over = false; v.refresh };
	v
};

~browser = {
	var items = List[];
	var header = { |cat| StaticText().string_(cat.asString.toUpper).font_(Font(Font.defaultSansFace, 10, true))
		.stringColor_(~catColors[cat] ? Color.grey(0.6)) };
	items.add(header.(\instruments));
	~voiceTypes.keys.asArray.sort.do { |type|
		items.add(~browserEntry.(type.asString, (kind: \inst, type: type), ~voiceTypes[type][\color]));
	};
	~browserItems.do { |cat|
		items.add(header.(cat[0]));
		cat[1].do { |item| items.add(~browserEntry.(item[0], (kind: \item, item: item), ~catColors[cat[0]])) };
	};
	ScrollView().fixedWidth_(165).background_(Color.grey(0.13)).hasHorizontalScroller_(false)
		.canvas_(View().layout_(VLayout(*(items ++ [nil])).margins_(3).spacing_(1)))
};
