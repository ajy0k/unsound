// Drones: instruments that sound continuously instead of playing notes. One synth per track runs
// while the transport runs; its knobs are listed in `params` (so they can be diced, infected and
// modulated). Every so often (the "spasm" sometimes, set by `busy`) it throws one or two params
// somewhere random for a moment, then lets them fall back home. Keys / MIDI notes call `keyFn`.

~droneType = { |def, color, params, xy, chain, keyFn|
	(
		color: color, params: params, xy: xy, chain: chain, key: keyFn,
		defaults: (level: 0.6, wander: 0.2, busy: 0.4, sends: [0.2, 0.15, 0, 0.1]),
		init: { |t| },
		build: { |t|
			t[\voice] = Synth(def, [out: t[\bus], gate: (~running == true).binaryValue]
				++ params.collect { |p| [p[\key], t[p[\key]]] }.flatten, t[\src]);
		},
		repatch: { |t|
			params.do { |p|
				if (p[\dice] != false) {
					~setOrHome.("t:%:%".format(t[\name], p[\key]), p[\spec], p[\spec].map(1.0.rand), { |x| ~tset.(t[\name], p[\key], x) });
				};
			};
		},
		// spasms happen "every so often" (see lib/sometimes.scd); `busy` is how often
		sometimes: [[\busy, "spasm", { |t| Routine({ ~spasm.(t, params) }).play(~clock) }, 0.4]],
		mover: { |t| loop { ~vwait.(t, 4) } },
		clip: { |t| ~droneClip.(t) },
		screen: { |t| HLayout(~xyPad.(t, xy[0], xy[1])) },
		device: { |t|
			[~panel.(t[\type].asString, t[\color], VLayout(*(params.collect { |p|
				~tknob.(t, p[\key], p[\spec], p[\label], 44)
			}.clump(4).collect { |row| HLayout(*(row ++ [nil])) } ++ [~soRow.(t)])))]
		}
	)
};

// Throw one or two params somewhere random for a moment, then let them fall back home.
~spasm = { |t, params|
	var ps = params.select { |p| p[\dice] != false }.scramble.keep(rrand(1, 2)), hold = [0.25, 0.5, 1, 2].choose;
	s.bind { ps.do { |p| t[\voice].set(p[\key], p[\spec].map(1.0.rand)) } };
	~vwait.(t, hold);
	s.bind { ps.do { |p| t[\voice].set(p[\key], t[p[\key]]) } };
};
