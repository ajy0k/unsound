// Drones: instruments that sound continuously instead of playing notes. One synth per track runs
// while the transport runs; its knobs are listed in `params` (so they can be diced, infected and
// modulated). The mover makes it spasm: it throws one or two params somewhere random for a moment,
// then lets them fall back home. Keys / MIDI notes set `keyParam`.

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
		mover: { |t|
			var ps, hold;
			loop {
				if ((t[\busy] * 0.4 + (~m[\chaos] * 0.3)).coin) {
					ps = params.select { |p| p[\dice] != false }.scramble.keep(rrand(1, 2));
					hold = [0.25, 0.5, 1, 2].choose;
					s.bind { ps.do { |p| t[\voice].set(p[\key], p[\spec].map(1.0.rand)) } };
					~vwait.(t, hold);
					s.bind { ps.do { |p| t[\voice].set(p[\key], t[p[\key]]) } };
				};
				~vwait.(t, [1, 2, 4].choose);
			}
		},
		clip: { |t| ~droneClip.(t) },
		device: { |t|
			[~panel.(t[\type].asString, t[\color], VLayout(*(params.collect { |p|
				~tknob.(t, p[\key], p[\spec], p[\label], 44)
			}.clump(4).collect { |row| HLayout(*(row ++ [nil])) } ++ [~tknob.(t, \busy, [0, 1], "spasms", 44)])))]
		}
	)
};
