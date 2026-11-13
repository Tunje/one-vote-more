extends SceneTree
## Bob (Wilma's perf flag): full game, one seed, flags on; times every provider × phase plus the econ prof keys.
## args: seed years flags(base | comma list) [from_year — profile only from this year]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sd := int(a[0])
	var years := int(a[1])
	var flag: String = a[2]
	var from_y := int(a[3]) if a.size() > 3 else 0
	var sim: Simulation = EconSim.make(sd, "BALANCED", {}, true)
	var w := sim.world
	w.meta["on"] = [] if flag == "base" else Array(flag.split(","))
	var prof := {}
	var t_all := Time.get_ticks_usec()
	var t_prof := 0
	var per_y: Array = []
	var tl := t_all
	for m in years * 12:
		var profiling := m >= from_y * 12
		if profiling:
			w.meta["prof"] = prof
		var ts := Time.get_ticks_usec()
		for ph in TickPhase.ORDER:
			w.current_phase = ph
			for p in sim._by_phase.get(ph, []):
				var t0 := Time.get_ticks_usec()
				p.run_phase(ph, w)
				if profiling:
					var k := "P %s/%d" % [p.owner_id(), ph]
					prof[k] = int(prof.get(k, 0)) + Time.get_ticks_usec() - t0
			if ph == TickPhase.RECORD:
				var t1 := Time.get_ticks_usec()
				sim._record()
				if profiling:
					prof["P _record"] = int(prof.get("P _record", 0)) + Time.get_ticks_usec() - t1
		w.current_phase = 0
		w.month += 1
		if profiling:
			t_prof += Time.get_ticks_usec() - ts
		if (m + 1) % 12 == 0:
			var now := Time.get_ticks_usec()
			per_y.append(int((now - tl) / 12000))
			tl = now
	var nm := (years - from_y) * 12
	print("%s seed %d: per-year ms/month %s | profiled %.0f ms/month | facilities %d hh %d facts %d" % [flag, sd, per_y, t_prof / 1000.0 / nm,
		w.table("facility").size(), w.table("hh").size(), w.facts.query("").size() if false else -1])
	var keys := prof.keys()
	keys.sort_custom(func(x, y): return int(prof[x]) > int(prof[y]))
	for k in keys:
		if int(prof[k]) / nm >= 3000:
			print("   %-45s %6.0f ms/month" % [k, int(prof[k]) / 1000.0 / nm])
	quit()
