extends SceneTree
## Bob (Wilma's perf item): per-call cost of COMPANY_AI. Snapshots at the given years, then profiles 12 months from each.
## args: seed years(comma list, e.g. 10,30,50) [save_dir]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sd := int(a[0]) if a.size() > 0 else 2
	var years: Array = Array((a[1] if a.size() > 1 else "10,30,50").split(","))
	var dir: String = a[2] if a.size() > 2 else OS.get_user_data_dir().path_join("prof")
	var sim: Simulation = EconSim.make(sd, "BALANCED", {}, true)
	var done_m := 0
	for ys in years:
		var target := int(ys) * 12
		var path := dir.path_join("seed%d_y%d.save" % [sd, int(ys)])
		if FileAccess.file_exists(path):
			var s2: Simulation = EconSim.make(sd, "BALANCED", {}, true)
			if SaveIO.load_into(s2, path) == OK:
				sim = s2
				done_m = target
		while done_m < target:
			sim.run(1)
			done_m += 1
		SaveIO.save(sim, path)
		var prof := {}
		sim.world.meta["prof"] = prof
		var t0 := Time.get_ticks_usec()
		sim.run(12)
		var tot := Time.get_ticks_usec() - t0
		sim.world.meta.erase("prof")
		done_m += 12
		var keys := prof.keys()
		keys.sort_custom(func(x, y): return int(prof[x]) > int(prof[y]))
		var ca := 0
		for k in keys:
			if not str(k).begins_with("FirmAI.") or str(k) == "FirmAI.run":
				ca += int(prof[k])
		print("== seed %d Y%d→Y%d: whole year %.1fs, COMPANY_AI %.1fs  orgs %d facilities %d projects %d" % [sd, int(ys), int(ys) + 1, tot / 1e6, ca / 1e6,
			sim.world.table("org").size(), sim.world.table("facility").size(), sim.world.table("project").size()])
		for k in keys:
			if int(prof[k]) >= 50000:
				print("   %-45s %7.2fs" % [k, int(prof[k]) / 1e6])
		# reload the snapshot so the next segment continues the same game unprofiled (the extra 12 months are fine)
	quit()
