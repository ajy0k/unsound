// Tracks, Ableton-style. Three kinds:
//   \inst    an instrument → insert devices → mixer strip
//   \return  sends from any track → insert devices → mixer strip (returns can send to other returns)
//   \master  everything → insert devices → strip → speakers
//
// Every strip has volume, pan, wander (pan movement), an activator, solo, a meter, and one send
// per return. Sends are post-fader unless that return is switched to pre.

~maxReturns = 8;
~voiceTypes = ();         // instrument types, from lib/voices/*.scd
~tracks = ();             // name → track, every kind
~voiceOrder = List[];     // instrument tracks, left to right
~returnOrder = List[];    // return tracks, left to right
~meterIds = ();           // meter reply id → track

~defs.add({
	var n = ~maxReturns;
	SynthDef(\uStrip, {
		var sig = In.ar(\in.kr(0), 2), gate = \gate.kr(1, 0.02), wander = \wander.kr(0, 0.5);
		var sends = \send.kr(0 ! n, 0.05), buses = \fxBus.kr(0 ! n), pre = \pre.kr(0 ! n);
		var preSig = sig * gate, post;
		post = Balance2.ar(sig[0], sig[1],
			(\pan.kr(0, 0.05) + (LFNoise2.kr(0.1 + (wander * 1.5)) * wander)).clip(-1, 1));
		post = post * \amp.kr(0.7, 0.05) * gate;
		Out.ar(\out.kr(0), post);
		n.do { |i| Out.ar(buses[i], ((post * (1 - pre[i])) + (preSig * pre[i])) * sends[i]) };
		SendPeakRMS.kr(post, 15, 3, '/uMeter', \id.kr(0));
	}).add;

	// Return input: sends from tracks arrive on `in`; sends from other returns arrive a block
	// late on `fb`, so returns can feed each other in any order.
	SynthDef(\uThru, { Out.ar(\out.kr(0), In.ar(\in.kr(0), 2) + InFeedback.ar(\fb.kr(0), 2)) }).add;
});

OSCdef(\uMeter, { |msg|
	var t = ~meterIds[msg[2].asInteger];
	if (t.notNil) { t[\meter] = [msg[3], msg[5]] };
}, '/uMeter');

~newName = { |base|
	var i = 1, name = base.asSymbol;
	while { ~tracks[name].notNil } { i = i + 1; name = (base ++ i).asSymbol };
	name
};

~newTrack = { |name, kind|
	var t;
	~nextMeterId = (~nextMeterId ? 0) + 1;
	t = (name: name, kind: kind, on: true, solo: false, level: 0.7, pan: 0, wander: 0,
		sends: 0 ! ~maxReturns, devices: List[], meter: [0, 0], id: ~nextMeterId);
	~meterIds[~nextMeterId] = t;
	t
};

// ---------------------------------------------------------------- strip plumbing

~gateFor = { |t|
	var anySolo = ~tracks.any { |x| x[\kind] == \inst and: { x[\solo] } };
	case
	{ t[\on].not } { 0 }
	{ anySolo and: { t[\kind] == \inst } and: { t[\solo].not } } { 0 }
	{ 1 }
};

~sendBuses = { |t|
	Array.fill(~maxReturns, { |i|
		var r = ~tracks[~returnOrder[i] ? \none];
		case
		{ r.isNil } { ~nullBus.index }
		{ t[\kind] == \return } { r[\fbBus].index }
		{ r[\inBus].index }
	})
};

~sendLevels = { |t|
	Array.fill(~maxReturns, { |i|
		if (t[\kind] == \master or: { ~returnOrder[i] == t[\name] }) { 0 } { t[\sends][i] }
	})
};

~preFlags = {
	Array.fill(~maxReturns, { |i|
		var r = ~tracks[~returnOrder[i] ? \none];
		if (r.notNil and: { r[\pre] == true }) { 1 } { 0 }
	})
};

~stripArgs = { |t|
	[amp: t[\level], pan: t[\pan], wander: t[\wander], gate: ~gateFor.(t),
		fxBus: ~sendBuses.(t), send: ~sendLevels.(t), pre: ~preFlags.()]
};

~refreshStrip = { |t| t[\strip].set(*~stripArgs.(t)) };
~refreshAllStrips = { ~tracks.do { |t| ~refreshStrip.(t) } };
~updateGates = { ~tracks.do { |t| t[\strip].set(\gate, ~gateFor.(t)) } };

// Build a track's nodes on the server (also used to rebuild everything after Cmd-.).
~buildTrack = { |t|
	var target = switch (t[\kind]) { \inst } { ~tracksGrp } { \return } { ~returnsGrp } { \master } { ~masterGrp };
	t[\grp] = Group.tail(target);
	t[\src] = Group.head(t[\grp]);
	if (t[\kind] == \return) { Synth.tail(t[\src], \uThru, [in: t[\inBus], fb: t[\fbBus], out: t[\bus]]) };
	t[\fxg] = Group.tail(t[\grp]);
	t[\devices].do { |d| ~buildDevice.(t, d) };
	t[\strip] = Synth.tail(t[\grp], \uStrip,
		[in: t[\bus], out: if (t[\kind] == \master) { ~out } { ~master }, id: t[\id]] ++ ~stripArgs.(t));
};

// ---------------------------------------------------------------- adding and removing

// ~add.(\fm)  or  ~add.(\keys, (busy: 0.9, speed: 1.5))
~add = { |type, settings|
	var it = ~voiceTypes[type], t;
	if (it.isNil) { "unsound: no instrument %".format(type).warn; nil } {
		t = ~newTrack.(~newName.((settings ? ())[\name] ? type), \inst);
		t[\type] = type;
		t.putAll((busy: 0.5, speed: 1, drift: 0.3, color: it[\color],
			sync: true, bpm: ~tempo, tempoDrift: 0, stray: 0, hop: 0));
		t.putAll(it[\defaults] ? ());
		(settings ? ()).keysValuesDo { |k, v| if (k != \name) { t[k] = v } };
		t[\sends] = (t[\sends] ++ (0 ! ~maxReturns)).keep(~maxReturns);
		t[\bus] = Bus.audio(s, 2);
		~tracks[t[\name]] = t;
		~voiceOrder.add(t[\name]);
		it[\init].value(t);
		~buildTrack.(t);
		(it[\chain] ? []).do { |c| ~dev.(t[\name], c[0], nil, c[1]) };
		if (~running == true) { ~startTrack.(t) };
		~selected = t[\name];
		~refreshGui.();
		t[\name]
	}
};

// ~addReturn.(\echo) → \C (or the next free letter)
~addReturn = { |deviceType, name|
	var t;
	if (~returnOrder.size >= ~maxReturns) { "unsound: % returns max".format(~maxReturns).warn; nil } {
		name = name ?? { "ABCDEFGH".as(Array).collect(_.asSymbol).detect { |l| ~tracks[l].isNil } };
		t = ~newTrack.(name, \return);
		t.putAll((level: 0.8, pre: false, color: Color.grey(0.6)));
		t[\inBus] = Bus.audio(s, 2);
		t[\fbBus] = Bus.audio(s, 2);
		t[\bus] = Bus.audio(s, 2);
		~tracks[name] = t;
		~returnOrder.add(name);
		~buildTrack.(t);
		if (deviceType.notNil) { ~dev.(name, deviceType) };
		~refreshAllStrips.();
		~refreshGui.();
		name
	}
};

~remove = { |name|
	var t = ~tracks[name], i;
	if (t.notNil and: { t[\kind] != \master }) {
		~stopTrack.(t);
		t[\grp].free;
		if (t[\kind] == \inst) { ~voiceTypes[t[\type]][\free].value(t); ~voiceOrder.remove(name) };
		if (t[\kind] == \return) {
			i = ~returnOrder.indexOf(name);
			~returnOrder.remove(name);
			~tracks.do { |x| x[\sends] = x[\sends].reject { |v, j| j == i } ++ [0] };
		};
		~tracks.removeAt(name);
		~meterIds.removeAt(t[\id]);
		{ [t[\bus], t[\inBus], t[\fbBus]].do { |b| b !? { b.free } } }.defer(5);
		~refreshAllStrips.();
		if (~selected == name) { ~selected = ~voiceOrder.first };
		~refreshGui.();
	};
};

// ---------------------------------------------------------------- settings

// ~tset.(\keys, \busy, 0.9)   — any track or instrument setting
~tset = { |name, key, val|
	var t = ~tracks[name];
	if (t.notNil) {
		t[key] = val;
		switch (key)
		{ \level } { t[\strip].set(\amp, val) }
		{ \pan } { t[\strip].set(\pan, val) }
		{ \wander } { t[\strip].set(\wander, val) }
		{ \on } { ~updateGates.() }
		{ \solo } { ~updateGates.() }
		{ \pre } { ~refreshAllStrips.() };
	};
};

// ~send.(\keys, \B, 0.6)
~send = { |name, ret, val|
	var t = ~tracks[name], i = ~returnOrder.indexOf(ret);
	if (t.notNil and: { i.notNil }) {
		t[\sends][i] = val;
		t[\strip].seti(\send, i, ~sendLevels.(t)[i]);
	};
};

~repatch = { |name|
	var t = ~tracks[name];
	if (t.notNil and: { t[\kind] == \inst }) { ~voiceTypes[t[\type]][\repatch].value(t) };
};

// Glide a numeric setting over some beats: ~ramp.(\fm, \speed, 3, 16)
~ramp = { |name, key, to, beats = 8|
	var t = ~tracks[name], from = t[key], steps = (beats * 8).asInteger.max(1);
	t[\ramps] = t[\ramps] ? ();
	t[\ramps][key].stop;
	t[\ramps][key] = Routine({
		steps.do { |i|
			var x = (i + 1) / steps;
			~tset.(name, key, if (key == \speed) { from * ((to / from) ** x) } { from + ((to - from) * x) });
			0.125.wait;
		};
	}).play(~clock);
};

// ---------------------------------------------------------------- running

// ---------------------------------------------------------------- per-track tempo
//
// Every instrument track runs at its own tempo: the master bpm when `sync` is on, otherwise its
// own `bpm`. Either way `tempoDrift` lets it wander (up to half an octave of tempo either way at 1)
// and `speed` multiplies the result. Waits are converted to the shared clock, so a track at
// 90 bpm really plays at 90 against a 132 master.

~liveBpm = { |t|
	(if (t[\sync] != false) { ~tempo } { t[\bpm] }) * (2 ** (t[\tdrift] ? 0)) * (t[\speed] ? 1).max(0.05)
};

// Seconds for some beats at the track's live tempo.
~beatSecs = { |t, beats| beats * 60 / ~liveBpm.(t) };

~driftTempo = { |t, secs|
	var d = t[\tempoDrift] ? 0, x = t[\tdrift] ? 0;
	t[\tdrift] = if (d > 0) { (x + 0.gauss(d * 0.04 * secs.sqrt)).fold(d * -0.5, d * 0.5) } { x * 0.9 };
};

// Wait some beats on the track's own tempo.
~vwait = { |t, beats|
	var secs = ~beatSecs.(t, beats);
	~driftTempo.(t, secs);
	(secs * ~clock.tempo).wait;
};

// Restart a track's mover on the next bar, back in phase with the master.
~resync = { |name|
	var t = ~tracks[name];
	if (t.notNil and: { ~running == true }) {
		t[\tdrift] = 0;
		t[\routine].stop;
		t[\routine] = Routine({ ~voiceTypes[t[\type]][\mover].value(t) }).play(~clock, quant: 4);
	};
};

~startTrack = { |t|
	~stopTrack.(t);
	if (t[\kind] == \inst) {
		t[\routine] = Routine({ ~voiceTypes[t[\type]][\mover].value(t) }).play(~clock, quant: 4);
	};
	t[\devices].do { |d| ~startDevice.(t, d) };
};

~stopTrack = { |t|
	t[\routine].stop;
	t[\ramps].do(_.stop);
	t[\devices].do { |d| d[\routine].stop };
};
