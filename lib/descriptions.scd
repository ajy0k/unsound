// One-line descriptions: the browser's hover tooltips. Keys are instrument and device types.

~descs = (
	// instruments
	bytebeat: "the bitmeister: 8-bit integer formulas on a counter. a b c shift the bits, rate is the clock",
	grains: "flings little bits of your sample folder around: clouds, ratchets, smears",
	noise: "noise generator: two layers sweeping through 20 kinds of noise, then filter, drive, pulse",
	creature: "chaotic oscillators tangled together: hunger, tangle, grit, fever",
	hum: "a self-oscillating feedback network that drones and swells",
	deck: "tape player: open a file, varispeed −8× to 8×, tape stops, spin backs, chewed tape",
	osc3: "3xOsc: three oscillators that mix, ring, FM or AM each other; plays notes",
	atari: "Atari 2600 sound chip: the real waveforms, out-of-tune notes, sound effects",
	drums: "8-lane drum machine: synth, FM or sampled lanes, polymeter, mutation",
	kick: "a kick you draw on a 16-step grid",
	keys: "a sample region played like a synth (one-shot or looped as an oscillator)",
	fm: "FM synth with waveforms you draw",
	mouth: "a talking machine: babbles, says what you type, or holds a vowel. formants, hiss, pops",

	// devices
	drive: "distortion with 8 modes: soft, tube, hard, fold, fuzz, rectify, sine, crunch",
	crush: "bit depth and sample-rate reduction",
	dirt: "crackle and hiss that follow the input",
	band: "just lows and highs: drag the edges, drag the middle to move both, scroll = resonance",
	filter: "resonant low / high / band pass, can drift by itself",
	eq: "three-band EQ",
	eq8: "EQ Eight: 8 bands you drag around, like Ableton's",
	comb: "tuned comb: everything rings at one note",
	resonator: "four resonant partials, harmonic to bell-like",
	ring: "ring modulator",
	shift: "frequency shifter with feedback: barber-pole spirals",
	space: "reverb",
	echo: "ping-pong tape echo; change time and the pitch warps",
	chorus: "chorus / flanger",
	tape: "wow, flutter, saturation, age, hiss",
	pitch: "pitch shifter",
	reverse: "plays the last moment backwards, chunk after chunk",
	smear: "granular smear of the last 3 seconds",
	stutter: "loops the last moment (hold B on the master)",
	chop: "rhythmic gate",
	freeze: "spectral freeze (hold V on the master)",
	scramble: "scrambles the spectrum",
	blur: "smears the spectrum",
	feedback: "a feedback loop through delay, band pass and drive: it can scream by itself",
	compressor: "compressor",
	gate: "noise gate",
	width: "stereo width and autopan",
	limiter: "limiter",
	bitmask: "the signal as 16-bit integers, XOR / AND / OR with a sweeping bit mask",
	alias: "sample-and-hold with no filter: aliasing on purpose; loud bits push the rate up",
	bins: "stretch and shift the spectrum; thin throws bins away",
	codec: "a bad stream: only the spectral peaks survive, frames warble, packets drop",
	overflow: "integer wraparound: push it and loud turns into its opposite",
	skip: "a scratched CD: sticks on tiny chunks of the last two seconds",
	vst: "a VST plugin (needs the VSTPlugin extension)"
);

~descFor = { |item|
	var how = "double-click: add to the focused track · drag: onto a track or before a device";
	case
	{ item[\kind] == \preset } { "your instrument: " ++ item[\name] ++ "\ndouble-click or drag: a new track, as you saved it · right-click: show / delete" }
	{ item[\kind] == \inst } { (~descs[item[\type]] ? item[\type].asString) ++ "\ndouble-click or drag: new track" }
	{ item[\item][1].isKindOf(Symbol) } { (~descs[item[\item][1]] ? item[\item][1].asString) ++ "\n" ++ how }
	{ "a chain: " ++ item[\item][1].collect { |c| c[0] }.join(" → ") ++ "\n" ++ how }
};
