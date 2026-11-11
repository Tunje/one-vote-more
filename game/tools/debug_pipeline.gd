extends SceneTree
## Public project pipeline at given months (status, contractor, progress, blockers, bids) in an integrated run.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 3
	var marks: Array = Array((args[1] if args.size() > 1 else "36,48,60").split(",")).map(func(x): return int(x))
	var sim := EconSim.make(seed_v, "BALANCED", {}, true)
	var w := sim.world
	for m in marks.max():
		sim.step()
		if not (w.month in marks):
			continue
		print("== m%d  u %.0f%%  PW headroom %dk  INFRA headroom %dk  HOUSING headroom %dk" % [w.month, 100.0 * FirmAI.colony_unemployment(w),
			EconActions.headroom(w, "ECON_BUDGET_PUBLIC_WORKS") / 1000000, EconActions.headroom(w, "ECON_BUDGET_INFRASTRUCTURE") / 1000000, EconActions.headroom(w, "ECON_BUDGET_HOUSING") / 1000000])
		for p in EconQuery.projects(w, ""):
			if p["status"] in ["DONE", "CANCELLED"]:
				continue
			var pr: Dictionary = w.peek("project")[p["project"]]
			print("  %s %s %s %s line %s  %.0f%% contractor %s bids %d  %s" % [p["project"], p["type"], p["district"], p["status"], pr.get("line", "-"), p["progress_pct"], p["contractor"], pr["bids"].size(),
				"; ".join(p["blockers"].map(func(c): return c["cause"] + " " + c["detail"]))])
		for oid in EconUtil.sorted_keys(w.peek("org")):
			var o: Dictionary = w.peek("org")[oid]
			if o["is_contractor"] and o["status"] != "DISSOLVED":
				print("  contractor %s %s crew %d target %s contracts %d cash %dk" % [oid, o["status"], EconLabor.staff_total(o["crew"]) / 1000, str(o["crew_target"]), o["contracts"].size(), w.ledger.balance(EconUtil.acct(oid)) / 1000000])
	quit(0)
