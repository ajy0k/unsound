// Headless smoke test: boots unsound silently (output on a private bus), presses play, runs an
// optional script, records what it heard, prints each track's peak level, and quits.
//
//   tools/run.sh                         just boot, play 6 s, meters
//   tools/run.sh my-test.scd             my-test.scd sets ~testScript = { … } (runs in a Routine)
//
// Inside a test: defer anything that touches the GUI ({ … }.defer). For a picture of the window,
// stop the GUI tick first or Image.fromWindow can deadlock:
//   { ~tick.stop }.defer; 0.4.wait; { Image.fromWindow(~win).write(path); ~startTick.() }.defer;

var dir = thisProcess.nowExecutingPath.dirname;
var out = "/tmp/unsound-smoke";
File.mkdir(out);
~folder = ~folder ? "/System/Library/Sounds";
~out = 40;                       // a private bus: nothing plays aloud
~recDir = out;                   // keeps, sessions and prefs go here, not ~/Music
~sessionOn = false;
~meters = { |tag| (tag ++ ": " ++ (~wallList.() ++ ~voiceOrder ++ ~returnOrder ++ [\master]).collect { |n|
	"% %".format(n, (~tracks[n][\meter].maxItem.ampdb).round(1)) }.join("  ")).postln };
~onReady = {
	fork {
		2.wait;
		{ ~start.() }.defer;
		s.record(out +/+ "smoke.wav", ~out, 2);
		(~testScript ? { 6.wait }).value;
		~meters.("meters");
		s.stopRecording;
		1.wait;
		"TEST DONE".postln;
		0.exit;
	};
};
~testFile !? { |p| p.load };
(dir +/+ "../unsound.scd").load;
