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
			"unsound: kept % (% s)".format(path, (n / sr).round(0.1)).postln;
		};
		path
	};
};
