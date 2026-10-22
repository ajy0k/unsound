// Tape: always recording what you hear, the last `~tapeMinutes` of it, in a ring buffer.
// Nothing to arm. `keep` saves what's on the tape (or the last N seconds) to
// ~/Music/unsound/keep-<date>.wav, so you can play for half an hour and cut it up later.
//
// It's in memory: 15 minutes of stereo at 48 kHz is about 350 MB.

~tapeMinutes = ~tapeMinutes ? 15;
~tapeHead = 0;      // write position (frames), reported by the server ~10 times a second
~tapeFilled = 0;    // frames recorded so far (stops growing once the tape has gone round once)

~defs.add({
	SynthDef(\uTape, { |in = 0, buf = 0|
		var frames = BufFrames.kr(buf), pos = Phasor.ar(0, 1, 0, frames);
		BufWr.ar(In.ar(in, 2), buf, pos);
		SendReply.kr(Impulse.kr(10), '/uTape', A2K.kr(pos));
	}).add;
});

OSCdef(\uTape, { |msg|
	var pos = msg[3].asInteger, frames = ~tapeBuf !? { |b| b.numFrames } ? 1;
	if (pos < ~tapeHead) { ~tapeWrapped = true };
	~tapeHead = pos;
	~tapeFilled = if (~tapeWrapped == true) { frames } { pos };
}, '/uTape');

// Called when the graph is built (and rebuilt after Cmd-.). The buffer survives Cmd-.; the head restarts.
~startTape = {
	~tapeBuf = ~tapeBuf ?? { Buffer.alloc(s, (s.sampleRate ? 48000) * 60 * ~tapeMinutes, 2) };
	~tapeHead = 0;
	~tapeFilled = 0;
	~tapeWrapped = false;
	~tapeSynth = Synth.tail(s, \uTape, [in: ~out, buf: ~tapeBuf]);
};

~tapeSecs = { ~tapeFilled / (s.sampleRate ? 48000) };

// Save the last `secs` (nil = everything on the tape). Runs in the background; posts the path.
~keep = { |secs|
	var buf = ~tapeBuf, sr = s.sampleRate ? 48000, head = ~tapeHead, n, tmp, path, start;
	if (buf.isNil or: { ~tapeFilled < 64 }) { "unsound: nothing on the tape yet".postln } {
		n = (secs !? { |x| (x * sr).asInteger } ? ~tapeFilled).min(~tapeFilled).max(64);
		start = head - n;
		File.mkdir(~recDir);
		path = ~recDir +/+ "keep-" ++ Date.getDate.stamp ++ ".wav";
		fork {
			tmp = Buffer.alloc(s, n, 2);
			s.sync;
			// the ring may wrap: copy the part before the start of the buffer, then the rest
			// (copyData copies from the receiver into the argument)
			if (start < 0) {
				buf.copyData(tmp, 0, buf.numFrames + start, start.neg);
				buf.copyData(tmp, start.neg, 0, head);
			} { buf.copyData(tmp, 0, start, n) };
			s.sync;
			tmp.write(path, "wav", "int24");
			s.sync;
			tmp.free;
			~lastRec = path;
			~lastKeep = Main.elapsedTime;
			~sessionMark.("keep → " ++ PathName(path).fileName);
			"unsound: kept % (% s)".format(path, (n / sr).round(0.1)).postln;
		};
		path
	};
};

// ---------------------------------------------------------------- the session: everything, to disk
//
// While the transport plays, everything you hear goes to ~/Music/unsound/sessions/session-<date>-<n>.wav
// (24-bit, about 1 GB an hour). It starts on the first play and pauses a few seconds after you stop
// (so tails are kept). Every `~sessionPartMinutes` it starts a new part, overlapping the old one by
// two seconds so nothing falls between them, and keeps the files a safe size if anything crashes.
// `keep` writes a marker into session-<date>.txt: which part, and how far into it.
// Set `~sessionOn = false` before loading to turn it off.

~sessionOn = ~sessionOn ? true;
~sessionPartMinutes = ~sessionPartMinutes ? 30;
~sessionDir = { ~recDir +/+ "sessions" };   // a function: ~recDir is set later (lib/motion.scd)

~defs.add({
	SynthDef(\uSession, { |in = 0, buf = 0| DiskOut.ar(buf, In.ar(in, 2)) }).add;
});

// One part: a buffer streaming to its own file, and the synth feeding it.
~sessionPartOpen = {
	var part, path, buf;
	~sessionPartN = (~sessionPartN ? 0) + 1;
	path = ~sessionDir.() +/+ "session-%-%.wav".format(~sessionStamp, ~sessionPartN);
	buf = Buffer.alloc(s, 65536 * 2, 2, { |b| b.writeMsg(path, "wav", "int24", 0, 0, true) });
	s.sync;
	part = (buf: buf, path: path, n: ~sessionPartN, secs: 0,
		synth: Synth.tail(s, \uSession, [in: ~out, buf: buf]));
	if (~running != true) { part[\synth].run(false) };
	part
};

~sessionPartClose = { |part|
	part !? {
		part[\synth].free;
		part[\buf].close;
		part[\buf].free;
	};
};

~sessionMark = { |text|
	var f, secs = (~sessionPart !? { |p| p[\secs] } ? 0).asInteger;
	if (~sessionPart.notNil) {
		f = File(~sessionDir.() +/+ "session-%.txt".format(~sessionStamp), "a");
		f.write("part %  %:%  %\n".format(~sessionPart[\n], secs div: 60, (secs % 60).asString.padLeft(2, "0"), text));
		f.close;
	};
};

// Starts the session (first play), or resumes it. Runs inside a Routine.
~sessionGo = {
	if (~sessionOn) {
		if (~sessionPart.isNil) {
			File.mkdir(~sessionDir.());
			~sessionStamp = ~sessionStamp ?? { Date.getDate.stamp };
			~sessionPart = ~sessionPartOpen.();
			"unsound: recording the session to %".format(~sessionPart[\path]).postln;
			~sessionTicker.();
		} {
			~sessionPart[\synth].run(true);
		};
	};
};

// Counts playing time, and starts a new part when this one is long enough.
~sessionTicker = {
	~sessionTask.stop;
	~sessionTask = Routine({
		var old;
		loop {
			1.wait;
			if (~running == true and: { ~sessionPart.notNil }) {
				~sessionPart[\secs] = ~sessionPart[\secs] + 1;
				~sessionTotal = (~sessionTotal ? 0) + 1;
				if (~sessionPart[\secs] >= (~sessionPartMinutes * 60)) {
					old = ~sessionPart;
					~sessionPart = ~sessionPartOpen.();
					2.wait;   // both parts record for two seconds
					~sessionPartClose.(old);
				};
			};
		}
	}).play(SystemClock);
};

~sessionPause = {
	var stamp = Main.elapsedTime;
	~sessionStopAt = stamp;
	// keep the tails: pause a few seconds after stopping, if it's still stopped
	{ if (~running != true and: { ~sessionStopAt == stamp }) { ~sessionPart !? { |p| p[\synth].run(false) } } }.defer(5);
};

// After Cmd-. the synth is gone: close that part and start the next one.
~sessionRebuild = {
	if (~sessionPart.notNil) {
		fork {
			var old = ~sessionPart;
			old[\buf].close; old[\buf].free;
			~sessionPart = ~sessionPartOpen.();
		};
	};
};

~sessionEnd = {
	~sessionTask.stop;
	~sessionPartClose.(~sessionPart);
	~sessionPart = nil;
};

// close the file properly when SuperCollider quits (replacing the hook from a previous load)
~sessionShutdown !? { |f| ShutDown.remove(f) };
~sessionShutdown = { ~sessionEnd.value };
ShutDown.add(~sessionShutdown);

~revealSessions = { File.mkdir(~sessionDir.()); ("open " ++ ~sessionDir.().quote).unixCmd };
