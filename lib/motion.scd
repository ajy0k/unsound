// Transport, the chaos macro, tempo, scale, recording, and big gestures.

~set = { |key, val| ~m[key] = val };

~bpm = { |bpm|
	~tempo = bpm;
	~clock.tempo = bpm / 60;
	~retimeDevices.();
};

~start = {
	~stop.();
	if (~clock.isNil or: { ~clock.isRunning.not }) { ~clock = TempoClock(~tempo / 60) };
	~running = true;
	~tracks.do { |t| ~startTrack.(t) };
};

~stop = {
	~running = false;
	~tracks.do { |t|
		~stopTrack.(t);
		t[\devices].do { |d| if (d[\type] == \stutter) { d[\synth].set(\stut, 0) } };
	};
};

// A big shove: most instruments get a new sound at once.
~lurch = { ~voiceOrder.do { |name| if (0.7.coin) { ~repatch.(name) } } };

// Records the master to SuperCollider's recordings folder (Platform.recordingsDir).
~record = { |on|
	~recording = on;
	if (on) { s.record } { s.stopRecording };
};
