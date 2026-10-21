// Corpus: a folder of samples cut into grains.
// A grain is [buffer, startFrame, numFrames, sampleRate, rms].

~findFiles = { |dir|
	var exts = #["wav", "aif", "aiff", "flac", "caf"];
	var root = PathName(dir.standardizePath);
	if (File.exists(root.fullPath)) {
		root.deepFiles.select { |p| exts.includesEqual(p.extension.toLower) }.collect(_.fullPath)
	} { [] }
};

// Rough RMS of channel 0, sampling at most 256 points.
~grainRms = { |data, nch, start, len|
	var step = (len / 256).asInteger.max(1), sum = 0, count = 0, i = start;
	while { i < (start + len) } {
		sum = sum + data[i * nch].squared;
		count = count + 1;
		i = i + step;
	};
	(sum / count.max(1)).sqrt
};

// Load one file (channel 0 only) and cut it into grains of random length, skipping silence.
~sliceFile = { |path|
	var sf = SoundFile.openRead(path), frames, sr, nch, data, buf, pos = 0, len, rms, floor;
	if (sf.notNil) {
		sr = sf.sampleRate;
		nch = sf.numChannels;
		frames = sf.numFrames.min((~maxSecs * sr).asInteger);
		if (frames > 1000) {
			data = FloatArray.newClear(frames * nch);
			sf.readData(data);
			floor = ~grainRms.(data, nch, 0, frames) * 0.05;
			buf = Buffer.readChannel(s, path, 0, frames, [0]);
			~bufs.add(buf);
			while { pos < frames } {
				len = (exprand(0.03, 0.6) * sr).asInteger.min(frames - pos);
				rms = ~grainRms.(data, nch, pos, len);
				if (len > (sr * 0.01) and: { rms > floor }) { ~grains.add([buf, pos, len, sr, rms]) };
				pos = pos + len;
			};
		};
		sf.close;
	};
};

// Must run inside a Routine (it waits on the server).
~loadCorpus = { |dir|
	var paths = ~findFiles.(dir), old = ~bufs;
	if (paths.isEmpty) {
		"unsound: no audio files in %, using system sounds".format(dir).warn;
		paths = ~findFiles.("/System/Library/Sounds");
	};
	paths = paths.scramble.keep(~maxFiles);
	~bufs = List[];
	~grains = List[];
	paths.do { |path, i|
		~sliceFile.(path);
		if (i % 20 == 19) { s.sync };   // don't flood the server with reads
	};
	s.sync;
	~bufs.do(_.normalize(0.9));
	s.sync;
	// longer grains make better sample-synth patches
	~keyGrains = ~grains.select { |g| g[2] / g[3] > 0.1 };
	if (~keyGrains.isEmpty) { ~keyGrains = ~grains };
	// voices may still be playing the old corpus, so free it a little later
	if (old.notNil) { fork { 5.wait; old.do(_.free) } };
	"unsound: % files, % grains".format(~bufs.size, ~grains.size).postln;
};

~reload = { |dir| fork { ~loadCorpus.(dir) } };
