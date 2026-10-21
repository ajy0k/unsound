// The browser (left side, like Ableton's): instruments, effects by category, and whole chains.
// Drag an entry onto a mixer strip, the device area, or between devices. Or press + to add it
// to the selected track (instruments always make a new track).

~catColors = (instruments: Color(0.35, 0.75, 0.9), distortion: Color(0.95, 0.45, 0.3), filter: Color(0.95, 0.8, 0.3),
	time: Color(0.45, 0.85, 0.55), glitch: Color(0.85, 0.45, 0.95), dynamics: Color(0.7, 0.7, 0.75),
	chains: Color(1, 0.6, 0.75));

~browserEntry = { |label, obj, color|
	var src = DragSource().object_(obj).string_(label).dragLabel_(label).canFocus_(false)
		.background_(Color.grey(0.21)).stringColor_(Color.grey(0.92)).fixedHeight_(22);
	var add = Button().fixedSize_(Size(24, 22)).canFocus_(false).states_([["+", Color.black, color]])
		.action_({ ~dropOn.(~selected, obj) });
	HLayout(add, src).spacing_(3)
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
	ScrollView().fixedWidth_(200).background_(Color.grey(0.13)).hasHorizontalScroller_(false)
		.canvas_(View().layout_(VLayout(*(items ++ [nil])).margins_(4).spacing_(2)))
};
