// The first column of every chain: the track's mix (volume, pan, sends, like an Ableton strip)
// and its mods, drawn as a tree. A mod's rate and depth are knobs too: right-click one and the mod
// that moves it appears indented underneath it. That's mods into mods, as deep as you like.

~mixPanel = { |t|
	var name = t[\name], color = t[\color] ? Color.grey(0.6);
	var top = [~tknob.(t, \level, ~levelSpec, "volume", 30), ~tknob.(t, \pan, [-1, 1], "pan", 30)]
		++ (if ([\inst, \wall].includes(t[\kind])) { [~tknob.(t, \wander, [0, 1], "wander", 30)] } { [] });
	var sends = if (t[\kind] == \master) { [] } {
		~returnOrder.reject { |r| r == name }.collect { |r|
			var label = r.asString ++ (~tracks[r][\devices].first !? { |d| " " ++ (d[\label] ? d[\type]) } ? "");
			~knob.(label, [0, 1], { (~returnOrder.indexOf(r) !? { |i| t[\sends][i] }) ? 0 }, { |x| ~send.(name, r, x) },
				26, ~tracks[r][\color], "s:%:%".format(name, r), "% send %".format(name, r))
		}
	};
	~panel.("mix", color, VLayout(*(
		[HLayout(*(top ++ [nil])).spacing_(0)]
		++ (if (sends.notEmpty) { [~lbl.("sends", 9)] ++ sends.clump(4).collect { |row| HLayout(*(row ++ [nil])).spacing_(0) } } { [] })
	)).spacing_(1), 270)
};

// ---------------------------------------------------------------- mods as a tree

~modHolders = List[];

// Does this mod sit on something that belongs to track t (its knobs, lanes, sends or devices)?
~modOnTrack = { |m, t|
	var tid = m[\target][\tid], n = t[\name].asString;
	["t:", "s:", "l:"].any { |p| tid.beginsWith(p ++ n ++ ":") }
		or: { t[\devices].any { |d| tid.beginsWith("d:%:".format(d[\uid])) } }
};

// Mods whose target is m's rate or depth.
~modChildren = { |m| ~mods.select { |x| [m[\rateTarget][\tid], m[\depthTarget][\tid]].includes(x[\target][\tid]) } };

~modRow = { |t, m, depth|
	var tg = m[\target];
	var label = tg[\name].asString.replace(t[\name].asString ++ " ", "");
	var sources = [\shape] ++ ~lfos.collect { |l| "lfo:" ++ l[\id] } ++ ~voiceOrder.collect { |n| "follow:" ++ n }
		++ ~mods.reject { |x| x === m }.collect { |x| "mod:" ++ x[\id] };
	var srcLabels = ["own shape"] ++ ~lfos.collect { |l| "LFO " ++ l[\id] } ++ ~voiceOrder.collect { |n| "follows " ++ n }
		++ ~mods.reject { |x| x === m }.collect { |x| "driven by " ++ x[\target][\name] };
	View().layout_(HLayout(
		View().fixedWidth_(depth * 12),
		VLayout(
			HLayout(
				StaticText().string_((if (depth > 0) { "↳ " } { "" }) ++ label).font_(Font(Font.defaultSansFace, 9, true))
					.stringColor_(if (depth > 0) { Color(1, 0.8, 0.5) } { Color.grey(0.9) }),
				nil,
				Button().canFocus_(false).fixedSize_(Size(16, 16)).states_([["x"]]).action_({ ~removeMod.(m) })
					.toolTip_("remove this mod (and the mods on it)")
			).spacing_(1),
			HLayout(
				~menu.(~modShapes, { m[\shape] }, { |x| m[\shape] = x }).fixedWidth_(64),
				~knob.("rate", m[\rateTarget][\spec], m[\rateTarget][\get], m[\rateTarget][\set], 20, ~accent,
					m[\rateTarget][\tid], m[\rateTarget][\name]),
				~knob.("depth", m[\depthTarget][\spec], m[\depthTarget][\get], m[\depthTarget][\set], 20, ~accent,
					m[\depthTarget][\tid], m[\depthTarget][\name]),
				~menu.(sources, { m[\source] }, { |x| m[\source] = x }, srcLabels).fixedWidth_(80),
				nil
			).spacing_(1)
		).spacing_(0)
	).margins_(0).spacing_(0)).background_(Color.grey(0.16 + (depth * 0.03)))
};

~fillMods = { |holder, t|
	var rows = List[];
	var walk = { |m, depth| rows.add(~modRow.(t, m, depth)); ~modChildren.(m).do { |c| walk.(c, depth + 1) } };
	~mods.select { |m| ~modOnTrack.(m, t) }.do { |m| walk.(m, 0) };
	holder.removeAll;
	holder.layout = VLayout(*([
		~lbl.("right-click any knob = add a mod\nright-click a mod's rate / depth = a mod on the mod", 9),
		HLayout(~button.("infect", { ~infectTrack.(t, 3) }).toolTip_("give 3 random knobs on this track a mod"),
			~button.("cure", { ~mods.select { |m| ~modOnTrack.(m, t) }.do { |m| ~removeMod.(m) } }).toolTip_("remove this track's mods"),
			nil).spacing_(2)
	] ++ rows ++ [nil])).spacing_(2).margins_(0);
};

~modsPanel = { |t|
	var holder = View();
	~modHolders.add((view: holder, t: t));
	~fillMods.(holder, t);
	~panel.("mods", Color(0.8, 0.8, 0.85), ScrollView().hasHorizontalScroller_(false).minHeight_(200).canvas_(holder), 270)
};

// Mods change a lot at once (infect adds a dozen): redraw once, a moment later.
~refreshMods = {
	if (~modsPending != true) {
		~modsPending = true;
		{
			~modsPending = false;
			~modHolders.removeAllSuchThat { |e| e[\view].isClosed };
			~modHolders.do { |e| ~fillMods.(e[\view], e[\t]) };
			if (~viewMode == \studio and: { ~detailMode == \mods }) { ~refreshDetail.() };
		}.defer(0.1);
	};
};

~trackColumn = { |t| VLayout(~mixPanel.(t), [~modsPanel.(t), stretch: 1]).spacing_(6) };
