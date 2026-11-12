extends SceneTree
## Wilma: time each provider × phase over N months (where does a month's cost go?). args: months seed
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var months := int(args[0]) if args.size() > 0 else 60
	var sim: Simulation = EconSim.make(int(args[1]) if args.size() > 1 else 11, "BALANCED", {}, true)
	var w := sim.world
	var tot := {}
	var block := 0
	var t_block := Time.get_ticks_usec()
	for m in months:
		for ph in TickPhase.ORDER:
			w.current_phase = ph
			for p in sim._by_phase.get(ph, []):
				var t0 := Time.get_ticks_usec()
				p.run_phase(ph, w)
				var k := "%s/%s" % [p.get_script().resource_path.get_file(), TickPhase.ORDER.find(ph)]
				tot[k] = int(tot.get(k, 0)) + Time.get_ticks_usec() - t0
			if ph == TickPhase.RECORD:
				var t1 := Time.get_ticks_usec()
				sim._record()
				tot["_record"] = int(tot.get("_record", 0)) + Time.get_ticks_usec() - t1
		w.current_phase = 0
		w.month += 1
		if (m + 1) % 12 == 0:
			print("year %d: %.1fs  facts=%d  pop=%d voters=%d" % [(m + 1) / 12, (Time.get_ticks_usec() - t_block) / 1e6, w.facts.facts.size(), PopStore.total(w), PolVoters.all(w).size()])
			var big := 0
			var bigk := {}
			for v in PolVoters.all(w):
				var L := var_to_str(v).length()
				if L > big:
					big = L
					bigk = {}
					for k in v:
						bigk[k] = var_to_str(v[k]).length()
			var nv := 0
			var nh := 0
			for id in w.indicators.defs:
				nv += w.indicators.values[id].size() if w.indicators.values.has(id) else 0
				nh += w.indicators.history[id].size() if w.indicators.history.has(id) else 0
			var t2 := Time.get_ticks_usec()
			for _r in 10:
				PolVoters.all(w)
			print("   indicators=%d values=%d history=%d  all()x10=%.0fms" % [w.indicators.defs.size(), nv, nh, (Time.get_ticks_usec() - t2) / 1000.0])
			var yk := tot.keys()
			yk.sort_custom(func(a, b): return tot[a] > tot[b])
			print("   " + ", ".join(yk.slice(0, 6).map(func(k): return "%s=%.1f" % [k, tot[k] / 1e6])))
			tot.clear()
			t_block = Time.get_ticks_usec()
	var keys := tot.keys()
	keys.sort_custom(func(a, b): return tot[a] > tot[b])
	for k in keys.slice(0, 15):
		print("%-40s %8.1fs" % [k, tot[k] / 1e6])
	quit()
