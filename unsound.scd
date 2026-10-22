// unsound — loader. Don't evaluate this directly; load it from play.scd.
//
// Signal flow (Ableton-style):
//   instrument → insert devices → strip ─┬─▶ master bus → master devices → master strip → speakers
//                                        └─▶ sends ─▶ returns (A, B, …) → devices → strip ─▶ master bus
//                                                       (returns can send to each other too)

~root = thisProcess.nowExecutingPath.dirname;

~folder = ~folder ? "/System/Library/Sounds";
~out = ~out ? 0;
~maxFiles = ~maxFiles ? 300;      // random subset if the folder is bigger
~maxSecs = ~maxSecs ? 20;         // only read the first N seconds of each file
~gui = ~gui ? true;
~tempo = ~tempo ? 132;
~startVoices = ~startVoices ? [\bytebeat, \bytebeat, \grains];
// each return: a device, or a list of [device, settings] (the sends are overdriven too)
~startReturns = ~startReturns ? [
	[[\echo, (fb: 0.7)], [\drive, (mode: 4, gain: 8, mix: 0.6)]],
	[[\space, (size: 0.95)], [\drive, (mode: 2, gain: 4, mix: 0.4)]],
	\shift, \smear
];
~startWall = ~startWall ? true;

~m = (chaos: 0.4);   // the one global macro: widens every random walk, raises every probability

// Reloading: clear out the previous instance before redefining everything.
if (s.serverRunning) {
	if (~graphFunc.notNil) { ServerTree.remove(~graphFunc, s) };
	~stop.value;
	s.freeAll;
};
~win !? { |w| if (w.isClosed.not) { w.onClose = nil; w.close } };

~defs = List[];   // each module adds a function that builds its SynthDefs

[
	"lib/corpus.scd",
	"lib/tracks.scd",
	"lib/devices.scd",
	"lib/melody.scd",
	"lib/mods.scd",
	"lib/sometimes.scd",
	"lib/lfos.scd",
	"lib/tape.scd",
	"lib/wall.scd",
	"lib/drones.scd",
	"lib/scenes.scd",
	"lib/presets.scd",
	"lib/control.scd",
	"lib/voices/grains.scd",
	"lib/voices/kick.scd",
	"lib/voices/keys.scd",
	"lib/voices/fm.scd",
	"lib/voices/noise.scd",
	"lib/voices/drums.scd",
	"lib/voices/noisegen.scd",
	"lib/voices/deck.scd",
	"lib/voices/osc3.scd",
	"lib/voices/atari.scd",
	"lib/voices/mouth.scd",
	"lib/motion.scd",
	"lib/descriptions.scd",
	"lib/gui/widgets.scd",
	"lib/gui/clips.scd",
	"lib/gui/browser.scd",
	"lib/gui/mixer.scd",
	"lib/gui/eq.scd",
	"lib/gui/mixmods.scd",
	"lib/gui/lfoview.scd",
	"lib/gui/box.scd",
	"lib/gui/main.scd"
].do { |file| (~root +/+ file).load };

// Groups run in this order: instrument tracks → returns → master.
~buildGraph = {
	~tracksGrp = Group.tail(s);
	~returnsGrp = Group.tail(s);
	~masterGrp = Group.tail(s);
	~tracks[\wall] !? { |w| ~buildTrack.(w) };
	~voiceOrder.do { |name| ~buildTrack.(~tracks[name]) };
	~returnOrder.do { |name| ~buildTrack.(~tracks[name]) };
	~buildTrack.(~masterTrack);
	~startTape.();
	~sessionRebuild.();
};

s.options.numInputBusChannels = 0;   // no mic needed, and it avoids input/output sample-rate mismatches
s.options.memSize = 2 ** 17;

s.waitForBoot {
	~defs.do(_.value);
	~loadCorpus.(~folder);
	~master = Bus.audio(s, 2);
	~nullBus = Bus.audio(s, 2);
	s.sync;
	if (~clock.isNil or: { ~clock.isRunning.not }) { ~clock = TempoClock(~tempo / 60) };

	~masterTrack = ~newTrack.(\master, \master);
	~masterTrack.putAll((level: 0.8, bus: ~master, color: Color.grey(0.85)));
	~tracks[\master] = ~masterTrack;

	// rebuild the graph after Cmd-. so there's always somewhere for sound to go
	~graphFunc = { ~running = false; ~buildGraph.() };
	ServerTree.add(~graphFunc, s);
	~buildGraph.();
	s.sync;

	// master: stutter → filter → light drive → limiter (pinned: always there, always last).
	// Nothing on the master moves by itself: it's for your hands.
	~booted = false;
	~dev.(\master, \stutter, nil, (auto: 0));
	~dev.(\master, \filter);
	~dev.(\master, \drive, nil, (mode: 0, gain: 1.5, mix: 0.3), "warmth");
	~dev.(\master, \limiter)[\pinned] = true;
	~startReturns.do { |r|
		if (r.isKindOf(Symbol)) { ~addReturn.(r) } {
			var name = ~addReturn.(nil);
			r.do { |dv| ~dev.(name, dv[0], nil, dv[1]) };
		};
	};
	if (~startWall) { ~makeWall.() };
	~startVoices.do { |type| ~add.(type) };
	// two bitmeisters shouldn't start out identical
	~voiceOrder.select { |n| ~tracks[n][\type] == \bytebeat }.drop(1).do { |n| ~diceTrack.(n) };
	~selected = ~voiceOrder.first;
	~initMidi.();
	~startLfos.();
	~startMods.();
	~soGlobal.();
	~startSometimes.();
	~infect.(6);   // start alive
	~booted = true;
	s.sync;

	if (~gui) { { ~makeGui.() }.defer };
	"unsound: ready. ~start.() or press play".postln;
	~onReady.value;
};
