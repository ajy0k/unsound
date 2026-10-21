// Melodic instruments (keys, fm) share this: a piano roll, a wander mode, repeats, and
// mutation. Mutation never edits your roll; it varies what gets played from it.
//
// Track settings used here:
//   play       \roll plays the piano roll, \wander improvises in the scale
//   roll       (len: steps, notes: List[(step:, midi:, dur:)]) — steps are 16ths
//   rollLow    lowest midi note shown in the roll
//   busy       wander: how often it plays
//   repeats    how many times a note repeats inside its length (when it repeats)
//   repChance  chance a note repeats
//   mutate     chance a note gets shifted, octaved, skipped or doubled
//   octave     transposes everything

~scale = Scale.minor;
~key = 0;   // 0 = C

~inScale = { |midi| ~scale.degrees.includes((midi - ~key) % 12) };
~snap = { |midi| (midi - ~key).nearestInScale(~scale.degrees) + ~key };

~melodicInit = { |t|
	t[\roll] = (len: 16, notes: List[]);
	t[\rollLow] = t[\root];
	t[\heard] = List[];
	t[\deg] = 0;
	t[\abs] = 0;
};

// Random walk through scale degrees; chaos allows bigger leaps.
~stepDeg = { |t|
	var c = ~m[\chaos];
	t[\deg] = (t[\deg] + [0, 1, -1, 2, -2, 4, -3, 7].wchoose([1, 3, 3, 2, 2, 1, 1, c * 2].normalizeSum)).fold(-7, 14);
};

~midiFor = { |t, offset = 0| ~scale.performDegreeToKey(t[\deg] + offset) + ~key + t[\root] };

~durFor = { |t|
	var b = t[\busy];
	[1, 0.5, 0.25, 0.75, 1.5, 2].wchoose([1, 2, b * 3, 1, 1 - b, (1 - b) * 2].normalizeSum)
};

~fitRoll = { |t, midi|
	while { midi < t[\rollLow] } { midi = midi + 12 };
	while { midi > (t[\rollLow] + 23) } { midi = midi - 12 };
	midi
};

// Play one note through the instrument's note function, with mutation and repeats.
~playNote = { |t, midi, beats, noteFn|
	var rep = 1, play = true;
	if ((t[\mutate] * 0.5).coin) {
		switch ([\shift, \octave, \skip, \double].wchoose([4, 1, 2, 2].normalizeSum))
		{ \shift } { midi = ~snap.(midi + [-2, -1, 1, 2].choose) }
		{ \octave } { midi = midi + [-12, 12].choose }
		{ \skip } { play = false }
		{ \double } { rep = 2 };
	};
	if (t[\repChance].coin) { rep = t[\repeats].asInteger.max(1) };
	midi = midi + (t[\octave] * 12);
	if (play) {
		if (rep <= 1) { noteFn.(t, midi, beats) } {
			Routine({ rep.do { noteFn.(t, midi, beats / rep); ~vwait.(t, beats / rep) } }).play(~clock);
		};
	};
};

~melodicMover = { |t, noteFn|
	var step = 0, dur, midi, roll;
	loop {
		if (t[\play] == \roll) {
			roll = t[\roll];
			step = step % roll[\len];
			t[\pos] = step;
			roll[\notes].do { |n| if (n[\step] == step) { ~playNote.(t, n[\midi], n[\dur] * 0.25, noteFn) } };
			step = step + 1;
			t[\abs] = t[\abs] + 1;
			~vwait.(t, 0.25);
		} {
			t[\pos] = nil;
			dur = ~durFor.(t);
			if ((0.3 + (t[\busy] * 0.65)).coin) {
				~stepDeg.(t);
				midi = ~midiFor.(t);
				~playNote.(t, midi, dur, noteFn);
				t[\heard].add((abs: t[\abs], midi: midi, dur: (dur * 4).round.max(1)));
				if (t[\heard].size > 256) { t[\heard].removeAt(0) };
			};
			t[\abs] = t[\abs] + (dur * 4).round;
			~vwait.(t, dur);
		};
	}
};

// Fill the roll with a phrase in the current scale.
~suggestRoll = { |t|
	var roll = t[\roll], step = 0, d;
	roll[\notes] = List[];
	while { step < roll[\len] } {
		d = [1, 1, 2, 2, 3, 4].choose.min(roll[\len] - step);
		if (0.65.coin) {
			~stepDeg.(t);
			roll[\notes].add((step: step, midi: ~fitRoll.(t, ~midiFor.(t)), dur: d));
		};
		step = step + d;
	};
};

// Copy what wander mode just improvised into the roll, and switch to playing it.
~keepHeard = { |t|
	var roll = t[\roll], start = t[\abs] - roll[\len];
	var recent = t[\heard].select { |n| n[\abs] >= start };
	if (recent.notEmpty) {
		roll[\notes] = List.newFrom(recent.collect { |n|
			(step: (n[\abs] - start).asInteger.clip(0, roll[\len] - 1), midi: ~fitRoll.(t, n[\midi]), dur: n[\dur].asInteger)
		});
		t[\play] = \roll;
	};
};
