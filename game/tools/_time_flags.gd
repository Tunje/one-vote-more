extends SceneTree
## Bob (Wilma's perf flag): econ-only, one seed, ms per month with one opt-in flag on; prof breakdown over all months.
## args: seed years flag (base | E134 | PAYOUT | SUPPORT_T | WORKLOAD | ... comma list)
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sd := int(a[0])
	var years := int(a[1])
	var flag: String = a[2]
	var sim := EconSim.make_econ_only(sd)
	var w := sim.world
	w.meta["on"] = [] if flag == "base" else Array(flag.split(","))
	var prof := {}
	w.meta["prof"] = prof
	var t0 := Time.get_ticks_usec()
	var tl := t0
	var per_y: Array = []
	for m in years * 12:
		w.levers["ECON_INCOME_TAX_RATE"] = 24
		w.levers["ECON_SALES_TAX"] = 8
		sim.run(1)
		if (m + 1) % 12 == 0:
			var now := Time.get_ticks_usec()
			per_y.append(int((now - tl) / 12000))
			tl = now
	var tot := Time.get_ticks_usec() - t0
	print("%s seed %d: %.0f ms/month  per-year ms/month %s  facilities %d hh %d" % [flag, sd, tot / 1000.0 / (years * 12), per_y, w.table("facility").size(), w.table("hh").size()])
	var keys := prof.keys()
	keys.sort_custom(func(x, y): return int(prof[x]) > int(prof[y]))
	for k in keys:
		if int(prof[k]) >= 200000:
			print("   %-45s %6.0f ms/month" % [k, int(prof[k]) / 1000.0 / (years * 12)])
	quit()
