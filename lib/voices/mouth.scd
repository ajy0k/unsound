// mouth: a talking machine. A buzzing throat (glottal pulses) through five formant filters, the
// shapes of the vowels, plus hiss for s / sh / f, bursts for p / t / k, and a nose for m / n.
// More Speak & Spell than human.
//
//   talk   \babble  random syllables, forever
//          \text    speaks what you type, in a loop (letters → sounds, very roughly)
//          \hold    just holds a vowel: `mouth` sweeps a → e → i → o → u (a drone)
//   rate   syllables per beat          pitch  the voice's note    sing  0 = speech contour, 1 = sings the scale
//   throat bigger or smaller head      breath aspiration          robot monotone, no vibrato
//   lofi   down to 8-bit, 8 kHz        glide  how long sounds take to move into each other
// Keys / MIDI: a note sets the pitch and says one syllable.

// Formants (tenor): freq, amp (dB), bandwidth, for a e i o u.
~vowelTable = (
	f: [[650, 1080, 2650, 2900, 3250], [400, 1700, 2600, 3200, 3580], [290, 1870, 2800, 3250, 3540],
		[400, 800, 2600, 2800, 3000], [350, 600, 2700, 2900, 3300]],
	db: [[0, -6, -7, -8, -22], [0, -14, -12, -14, -20], [0, -15, -18, -20, -30],
		[0, -10, -12, -12, -26], [0, -20, -17, -14, -26]],
	bw: [[80, 90, 120, 130, 140], [70, 80, 100, 120, 120], [40, 90, 100, 120, 120],
		[40, 80, 100, 120, 120], [40, 60, 100, 120, 120]]
);

~defs.add({
	SynthDef(\uMouth, { |out, gate = 0, pitch = 48, throat = 1, mouth = 0, breath = 0.1, robot = 0, lofi = 0,
		glide = 0.3, width = 0.3, talking = 1|
		var lagT = glide.linexp(0, 1, 0.01, 0.3);
		var vowel = Select.kr(talking, [mouth, \vseq.kr(0)]).lag(lagT);
		var voice = \voice.kr(0).lag(lagT * 0.5), fric = \fric.kr(0).lag(lagT * 0.3), fricF = \fricF.kr(5000).lag(lagT * 0.3);
		var nasal = \nasal.kr(0).lag(lagT), burst = \burst.tr(0), burstF = \burstF.kr(2000);
		var env = EnvGen.kr(Env.asr(0.05, 1, 0.3), gate);
		var vib = SinOsc.kr(5.3 + LFNoise1.kr(0.3), 0, 0.25 * (1 - robot)) + (LFNoise1.kr(8) * 0.08 * (1 - robot));
		var f0 = (pitch.lag(lagT) + vib).midicps;
		var src = Blip.ar(f0, (SampleRate.ir * 0.45 / f0).clip(1, 200)) + (PinkNoise.ar * breath * 0.6);
		var forms = 5.collect { |k|
			var f = LinSelectX.kr(vowel, ~vowelTable[\f].collect(_[k])) * throat;
			var a = LinSelectX.kr(vowel, ~vowelTable[\db].collect(_[k])).dbamp;
			var bw = LinSelectX.kr(vowel, ~vowelTable[\bw].collect(_[k]));
			Resonz.ar(src, f.clip(50, 18000), (bw / f).clip(0.005, 1)) * a
		};
		var voiced = Mix(forms) * 4 * voice;
		var nose = LPF.ar(src, 350 * throat) * nasal * 0.6;
		var hiss = BPF.ar(WhiteNoise.ar, fricF.clip(200, 16000), 0.35) * fric * 1.5;
		var pop = BPF.ar(WhiteNoise.ar, burstF, 0.6) * EnvGen.ar(Env.perc(0.001, 0.03), burst) * 3;
		var sig = ((voiced * (1 - (nasal * 0.7))) + nose + hiss + pop).softclip;
		var low = Latch.ar(sig, Impulse.ar(lofi.linexp(0, 1, 44100, 6000))).round(2 ** (lofi.linlin(0, 1, -16, -5)));
		sig = SelectX.ar(lofi.clip(0, 1).sqrt, [sig, low]);
		Out.ar(out, Pan2.ar(LeakDC.ar(sig), LFNoise1.kr(0.2) * width) * env * 1.2);
	}).add;
});

// ---------------------------------------------------------------- letters → sounds (very roughly)

// A sound: v = vowel position (0 a, 1 e, 2 i, 3 o, 4 u), voice, fric (hiss), fricF, nasal, burst (Hz), len.
~phone = { |v, voice = 1, fric = 0, fricF = 5000, nasal = 0, burst, len = 1|
	(v: v, voice: voice, fric: fric, fricF: fricF, nasal: nasal, burst: burst, len: len)
};
~phones = (
	a: ~phone.(0), e: ~phone.(1), i: ~phone.(2), o: ~phone.(3), u: ~phone.(4),
	y: ~phone.(2, len: 0.4), w: ~phone.(4, len: 0.4),
	s: ~phone.(nil, 0, 1, 6500, len: 0.6), z: ~phone.(nil, 0.4, 0.7, 6000, len: 0.6),
	sh: ~phone.(nil, 0, 1, 3000, len: 0.7), f: ~phone.(nil, 0, 0.7, 9000, len: 0.5), v: ~phone.(nil, 0.4, 0.5, 8000, len: 0.5),
	th: ~phone.(nil, 0.1, 0.5, 5000, len: 0.5), h: ~phone.(nil, 0.1, 0.4, 1500, len: 0.4),
	p: ~phone.(nil, 0, burst: 800, len: 0.3), t: ~phone.(nil, 0, burst: 4000, len: 0.3), k: ~phone.(nil, 0, burst: 2000, len: 0.3),
	b: ~phone.(nil, 0.4, burst: 600, len: 0.3), d: ~phone.(nil, 0.4, burst: 3000, len: 0.3), g: ~phone.(nil, 0.4, burst: 1500, len: 0.3),
	m: ~phone.(4, 0.6, nasal: 1, len: 0.6), n: ~phone.(2, 0.6, nasal: 1, len: 0.6),
	l: ~phone.(3, 0.8, len: 0.5), r: ~phone.(1, 0.8, len: 0.5),
	space: ~phone.(nil, 0, len: 1)
);

~textToPhones = { |str|
	var s = str.toLower, out = List[], i = 0, two, c;
	var digraphs = (sh: [\sh], ch: [\t, \sh], th: [\th], ng: [\n], ee: [\i], oo: [\u], ai: [\a, \i],
		ou: [\a, \u], ph: [\f], ck: [\k], qu: [\k, \w]);
	while { i < s.size } {
		two = s.copyRange(i, i + 1);
		if (digraphs[two.asSymbol].notNil) {
			out.addAll(digraphs[two.asSymbol]); i = i + 2;
		} {
			c = s[i];
			case
			{ c.isAlpha.not } { out.add(\space) }
			{ c == $c } { out.add(if ("eiy".includes(s[i + 1] ? Char.space)) { \s } { \k }) }
			{ c == $q } { out.add(\k) }
			{ c == $x } { out.addAll([\k, \s]) }
			{ c == $j } { out.addAll([\d, \i]) }
			{ out.add(c.asSymbol) };
			i = i + 1;
		};
	};
	out.collect { |p| ~phones[p] ? ~phones[\space] }
};

// A random syllable: consonant (or two) + vowel, sometimes a consonant after.
~babble = {
	var cons = [\p, \t, \k, \b, \d, \g, \m, \n, \l, \r, \s, \sh, \f, \v, \h, \w, \y, \z];
	var out = List[];
	if (0.85.coin) { out.add(cons.choose) };
	if (0.15.coin) { out.add([\l, \r, \w].choose) };
	out.add([\a, \e, \i, \o, \u].choose);
	if (0.35.coin) { out.add(cons.choose) };
	if (0.2.coin) { out.add(\space) };
	out.collect { |p| ~phones[p] }
};

// Say one sound on a track (sets the synth, waits its length).
~say = { |t, ph, beats|
	var v = t[\voice];
	s.bind {
		v.set(\voice, ph[\voice], \fric, ph[\fric], \fricF, ph[\fricF], \nasal, ph[\nasal], \talking, 1);
		if (ph[\v].notNil) { v.set(\vseq, ph[\v]) };
		if (ph[\burst].notNil) { v.set(\burstF, ph[\burst], \burst, 1) };
	};
	~vwait.(t, beats * ph[\len]);
};

// The phrase's melody: speech falls a little over a phrase; `sing` snaps to the scale and leaps.
~mouthPitch = { |t, i, n|
	var base = t[\pitch], p;
	p = if (t[\sing].coin) { ~snap.(base + [0, 2, 3, 5, 7, 10, 12, -5].choose) } { base + (3 * (1 - (i / n.max(1)))) + 1.0.rand2 };
	t[\voice].set(\pitch, p);
};

~voiceTypes[\mouth] = (
	color: Color(1, 0.55, 0.6),
	chain: [[\drive, (mode: 2, gain: 3, mix: 0.4)], [\echo, (time: 0.375, fb: 0.4, mix: 0.25)]],
	params: [
		~p.(\pitch, 48, [24, 84]), ~p.(\throat, 1, [0.5, 2, \exp]), ~p.(\mouth, 0, [0, 4], "mouth (a-u)"),
		~p.(\breath, 0.1, [0, 1]), ~p.(\rate, 2, [0.25, 16, \exp], "rate"), ~p.(\glide, 0.3, [0, 1]),
		~p.(\sing, 0.3, [0, 1]), ~p.(\robot, 0, [0, 1]), ~p.(\lofi, 0.3, [0, 1]), ~p.(\width, 0.3, [0, 1])
	],
	defaults: (level: 0.7, wander: 0.1, sends: [0.15, 0.1, 0, 0], talk: \babble, text: "unsound is a broken machine"),
	init: { |t| },
	build: { |t|
		t[\voice] = Synth(\uMouth, [out: t[\bus], gate: (~running == true).binaryValue,
			talking: (t[\talk] != \hold).binaryValue, voice: (t[\talk] == \hold).binaryValue]
			++ [\pitch, \throat, \mouth, \breath, \robot, \lofi, \glide, \width].collect { |k| [k, t[k]] }.flatten, t[\src]);
	},
	onSet: { |t, key, val|
		if (key == \talk) {
			t[\voice] !? { |v| v.set(\talking, (val != \hold).binaryValue, \voice, if (val == \hold) { 1 } { 0 }, \fric, 0, \nasal, 0) };
		};
	},
	repatch: { |t|
		[\pitch, \throat, \breath, \sing, \lofi].do { |k|
			var p = ~voiceTypes[\mouth][\params].detect { |x| x[\key] == k };
			~setOrHome.("t:%:%".format(t[\name], k), p[\spec], p[\spec].map(1.0.rand), { |x| ~tset.(t[\name], k, x) });
		};
	},
	key: { |t, midi|
		Routine({
			t[\voice].set(\pitch, midi.clip(24, 84));
			~babble.().do { |ph| ~say.(t, ph, 0.25) };
		}).play(~clock);
	},
	sometimes: [
		[\soShout, "shout", { |t|
			Routine({
				t[\voice].set(\pitch, t[\pitch] + 12, \breath, 0.6);
				~vwait.(t, [1, 2].choose);
				t[\voice].set(\pitch, t[\pitch], \breath, t[\breath]);
			}).play(~clock);
		}, 0.05],
		[\soHush, "hush", { |t| Routine({ t[\hushed] = true; ~vwait.(t, [2, 4, 8].choose); t[\hushed] = false }).play(~clock) }, 0.03]
	],
	mover: { |t|
		var phrase, i;
		loop {
			case
			{ t[\talk] == \hold } { ~vwait.(t, 1) }
			{ t[\hushed] == true } { s.bind { t[\voice].set(\voice, 0, \fric, 0) }; ~vwait.(t, 1) }
			{
				phrase = if (t[\talk] == \text) { ~textToPhones.(t[\text] ? "") ++ [~phones[\space]] } {
					Array.fill(rrand(2, 6), { ~babble.() }).flatten ++ [~phones[\space]]
				};
				phrase.do { |ph, j|
					if (j % 3 == 0) { s.bind { ~mouthPitch.(t, j, phrase.size) } };
					~say.(t, ph, 1 / t[\rate].max(0.05));
				};
			};
		}
	},
	pages: { |t| [
		~pg.(t, "mouth", [[\pitch, [24, 84]], [\throat, [0.5, 2, \exp]], [\mouth, [0, 4], "mouth"], [\breath, [0, 1]],
			[\rate, [0.25, 16, \exp]], [\glide, [0, 1]], [\sing, [0, 1]], [\lofi, [0, 1]]])
	] },
	screen: { |t| ~mouthScreen.(t) },
	clip: { |t| ~mouthScreen.(t) },
	device: { |t|
		[~panel.("mouth", t[\color], VLayout(*(~voiceTypes[\mouth][\params].collect { |p|
			~tknob.(t, p[\key], p[\spec], p[\label], 34)
		}.clump(5).collect { |row| HLayout(*(row ++ [nil])).spacing_(0) } ++ [~soRow.(t)])))]
	}
);

// Talk mode, the text it speaks, and an XY pad: mouth shape (a → u) × throat.
~mouthScreen = { |t|
	var field = TextField().string_(t[\text] ? "").action_({ |f| t[\text] = f.string; ~tset.(t[\name], \talk, \text) });
	VLayout(
		~row.(
			~tmenu.(t, \talk, [\babble, \text, \hold], ["babble", "say the text", "hold a vowel"]),
			~lbl.("text:"), [field.minWidth_(300), stretch: 1],
			~button.("say it", { t[\text] = field.string; ~tset.(t[\name], \talk, \text) })
		),
		[~xyPad.(t, \mouth, \throat), stretch: 1]
	).spacing_(3)
};
