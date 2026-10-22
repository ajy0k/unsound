// Transport, tempo, recording, and big gestures: lurch toward somewhere new (a glide), cut there
// (instantly), go back (undo), and events that do those things by themselves every few bars.

~set = { |key, val| ~m[key] = val };

// No upper limit. At absurd tempos rhythms turn into pitches; waits bottom out at 2 ms
// (see ~vwait) so the language keeps breathing.
~bpm = { |bpm|
	~tempo = bpm.max(0.1);
	~clock.tempo = ~tempo / 60;
	~retimeDevices.();
};

~start = {
	~stop.();
	if (~clock.isNil or: { ~clock.isRunning.not }) { ~clock = TempoClock(~tempo / 60) };
	~running = true;
	~tracks.do { |t| ~startTrack.(t) };
	~startEvents.();
};

~stop = {
	~running = false;
	~eventTask.stop;
	~tracks.do { |t|
		~stopTrack.(t);
		t[\devices].do { |d| if (d[\type] == \stutter) { d[\synth].set(\stut, 0) } };
	};
};

// New sounds on most instruments at once (keeps patterns and settings).
~newSounds = { ~voiceOrder.do { |name| if (0.7.coin) { ~repatch.(name) } } };

// ---------------------------------------------------------------- recording

// Records exactly what you hear (the master output) to ~/Music/unsound/unsound-<date>.wav, 24-bit.
~recDir = ~recDir ?? { "~/Music/unsound".standardizePath };

~record = { |on|
	if (on) {
		File.mkdir(~recDir);
		~recPath = ~recDir +/+ "unsound-" ++ Date.getDate.stamp ++ ".wav";
		s.recHeaderFormat = "wav";
		s.recSampleFormat = "int24";
		s.record(~recPath, ~out, 2);
		~recStart = Main.elapsedTime;
		~recording = true;
	} {
		s.stopRecording;
		~recording = false;
		~lastRec = ~recPath;
		"unsound: recorded %".format(~recPath).postln;
	};
};

~revealRec = { ~lastRec !? { |p| ("open -R " ++ p.quote).unixCmd } };

// ---------------------------------------------------------------- history, lurch, cut

~history = List[];
~pushHistory = {
	~history.add(~snapshot.());
	if (~history.size > 50) { ~history.removeAt(0) };
};

// Go back to how it was before the last lurch / cut / dice.
~back = { |beats = 0|
	if (~history.notEmpty) { ~applyState.(~history.pop, beats) };
};

~lurchDistance = 0.6;   // how far a lurch goes: 0 = nowhere, 1 = anywhere

// Blend two snapshots: numbers move `amt` of the way from a to b; everything else comes from b.
~blendState = { |a, b, amt|
	var mix = { |x, y| if (x.isNumber and: { y.isNumber }) { x + ((y - x) * amt) } { y } };
	var out = b.deepCopy;
	out[\tracks].do { |tb, i|
		var ta = a[\tracks].detect { |x| x[\name] == tb[\name] };
		if (ta.notNil) {
			tb.keysValuesDo { |k, v| if (v.isNumber) { tb[k] = mix.(ta[k], v) } };
			tb[\devices].do { |db, j|
				var da = ta[\devices][j];
				if (da.notNil and: { da[\type] == db[\type] }) {
					db[\params].keysValuesDo { |k, v| db[\params][k] = mix.(da[\params][k], v) };
				};
			};
		};
	};
	out[\mods].do { |mb|
		var ma = a[\mods].detect { |x| x[\tid] == mb[\tid] };
		if (ma.notNil) { [\home, \rate, \depth].do { |k| mb[k] = mix.(ma[k], mb[k]) } };
	};
	out
};

// Somewhere new: dice every track (never the master), measure where that lands, put everything
// back, then go `~lurchDistance` of the way there over `beats` (0 = cut on a dime).
~lurchTo = { |beats|
	var a, b;
	beats = beats ? ~morphBeats;
	~pushHistory.();
	a = ~snapshot.();
	(~voiceOrder ++ ~returnOrder).do { |n| ~diceTrack.(n) };
	b = ~snapshot.();
	~applyState.(a, 0);
	~applyState.(~blendState.(a, b, ~lurchDistance), beats);
};

~glide = { ~lurchTo.(~morphBeats.max(1)) };
~cut = { ~lurchTo.(0) };

// ---------------------------------------------------------------- events at intervals

// Every `every` bars, with probability `chance`, something big happens. Kinds are weighted.
~events = (on: false, every: 8, chance: 0.5,
	kinds: (glide: 3, cut: 2, back: 1, dice: 2, drop: 2, solo: 1, newSounds: 1));

~doEvent = { |kind|
	var names = ~voiceOrder.asArray;
	switch (kind)
	{ \glide } { ~glide.() }
	{ \cut } { ~cut.() }
	{ \back } { ~back.(~morphBeats) }
	{ \dice } { ~pushHistory.(); ~diceTrack.(names.choose) }
	{ \newSounds } { ~newSounds.() }
	{ \drop } {
		// everything but one track drops out for a bar or two
		var keep = names.choose, bars = [1, 2].choose;
		names.do { |n| if (n != keep) { ~tset.(n, \on, false) } };
		~clock.sched(bars * 4, { names.do { |n| ~tset.(n, \on, true) }; nil });
	}
	{ \solo } {
		var n = names.choose;
		~tset.(n, \solo, true);
		~clock.sched([2, 4, 8].choose, { ~tset.(n, \solo, false); nil });
	};
	~lastEvent = kind;
};

~startEvents = {
	~eventTask.stop;
	~eventTask = Routine({
		loop {
			(~events[\every].max(1) * 4).wait;
			if (~events[\on] and: { ~events[\chance].coin }) {
				{ ~doEvent.(~events[\kinds].keys.asArray.wchoose(~events[\kinds].values.asArray.normalizeSum)) }.defer;
			};
		}
	}).play(~clock, quant: 4);
};
