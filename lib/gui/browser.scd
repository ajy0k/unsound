// The browser (left side, like Ableton's): instruments, effects by category, and whole chains.
// Double-click an entry to add it to the end of the selected track's chain (instruments make a
// new track). Or drag it onto a mixer strip, the device area, or onto a device to insert before it.

~catColors = ('my instruments': Color(1, 0.85, 0.4), 'my chains': Color(1, 0.85, 0.4), instruments: Color(0.35, 0.75, 0.9), distortion: Color(0.95, 0.45, 0.3), filter: Color(0.95, 0.8, 0.3),
	time: Color(0.45, 0.85, 0.55), glitch: Color(0.85, 0.45, 0.95), dynamics: Color(0.7, 0.7, 0.75),
	chains: Color(1, 0.6, 0.75), digital: Color(0.3, 0.95, 0.85));

~browserEntry = { |label, obj, color, rightClick|
	var v = UserView().fixedHeight_(19).canFocus_(false), down, over = false, flash = 0;
	v.drawFunc = { |uv|
		var b = uv.bounds.moveTo(0, 0);
		Pen.fillColor = Color.grey(if (over) { 0.28 } { 0.19 }).blend(color, flash);
		Pen.fillRect(b);
		Pen.fillColor = color;
		Pen.fillRect(Rect(0, 0, 4, b.height));
		Pen.stringAtPoint(label, Point(10, 2), Font(Font.defaultSansFace, 11), Color.grey(0.92));
	};
	v.toolTip = ~descFor.(obj);
	v.beginDragAction = { obj };
	v.dragLabel = label;
	v.mouseDownAction = { |uv, x, y, mod, bn, clicks|
		case
		{ bn == 1 and: { rightClick.notNil } } { rightClick.value; down = nil }
		{ clicks == 2 } {
			~dropOn.(~selected, obj);
			flash = 0.6;
			{ 4.do { flash = flash * 0.5; uv.refresh; 0.06.wait } }.fork(AppClock);
			down = nil;
		}
		{ down = Point(x, y) };
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

// Categories fold up: click a header. Which ones are folded is remembered (in ~/Music/unsound/unsound-prefs.scd).
~prefsPath = { ~recDir +/+ "unsound-prefs.scd" };
~loadPrefs = { ~prefs = (if (File.exists(~prefsPath.())) { ~prefsPath.().load } ? ()) ? () };
~savePrefs = {
	var f;
	File.mkdir(~recDir);
	f = File(~prefsPath.(), "w");
	f.write(~prefs.asCompileString);
	f.close;
};

~browserSection = { |cat, entries|
	var folded = (~prefs[\folded] ? []).includes(cat), body, head;
	body = View().layout_(VLayout(*entries).margins_(0).spacing_(1)).visible_(folded.not);
	head = UserView().fixedHeight_(16).canFocus_(false);
	head.drawFunc = { |uv|
		Pen.stringAtPoint((if (body.visible) { "▾ " } { "▸ " }) ++ cat.asString.toUpper ++ " (" ++ entries.size ++ ")",
			Point(2, 1), Font(Font.defaultSansFace, 10, true), ~catColors[cat] ? Color.grey(0.7));
	};
	head.toolTip = "click to fold / unfold";
	head.mouseDownAction = {
		body.visible = body.visible.not;
		~prefs[\folded] = (~prefs[\folded] ? []).reject { |c| c == cat } ++ (if (body.visible) { [] } { [cat] });
		~savePrefs.();
		head.refresh;
		nil
	};
	[head, body]
};

// Right-click on one of your own instruments / chains.
~presetMenu = { |path|
	{
		Menu(
			MenuAction("show in Finder", { ("open -R " ++ path.quote).unixCmd }),
			MenuAction("delete", { ~deletePreset.(path) })
		).front;
	}
};

~browserContent = {
	var items = List[], mine, chains;
	if (~prefs.isNil) { ~loadPrefs.() };
	items.addAll(~browserSection.(\instruments, ~voiceTypes.keys.asArray.sort.collect { |type|
		~browserEntry.(type.asString, (kind: \inst, type: type), ~voiceTypes[type][\color])
	}));
	mine = ~presets.(\instrument);
	items.addAll(~browserSection.('my instruments', if (mine.isEmpty) {
		[StaticText().string_("  (save one with \"save\" by the track's name)").font_(Font(Font.defaultSansFace, 9)).stringColor_(Color.grey(0.5))]
	} {
		mine.collect { |p| ~browserEntry.(p[\name], (kind: \preset, path: p[\path], name: p[\name]), ~catColors['my instruments'], ~presetMenu.(p[\path])) }
	}));
	~browserItems.do { |cat|
		items.addAll(~browserSection.(cat[0], cat[1].collect { |item| ~browserEntry.(item[0], (kind: \item, item: item), ~catColors[cat[0]]) }));
	};
	chains = ~presets.(\chain).collect { |p|
		var data = p[\data];
		~browserEntry.(p[\name], (kind: \item, item: [p[\name], (data !? { data[\devices] } ? []).collect { |d| [d[\type], d[\params]] }], mine: true),
			~catColors['my chains'], ~presetMenu.(p[\path]))
	};
	items.addAll(~browserSection.('my chains', if (chains.isEmpty) {
		[StaticText().string_("  (save a chain with \"save\")").font_(Font(Font.defaultSansFace, 9)).stringColor_(Color.grey(0.5))]
	} { chains }));
	View().layout_(VLayout(*(items ++ [nil])).margins_(3).spacing_(1))
};

~browser = {
	~browserScroll = ScrollView().fixedWidth_(165).background_(Color.grey(0.13)).hasHorizontalScroller_(false)
		.canvas_(~browserContent.());
	~browserScroll
};

~refreshBrowser = {
	{ if (~browserScroll.notNil and: { ~browserScroll.isClosed.not }) { ~browserScroll.canvas = ~browserContent.() } }.defer;
};
