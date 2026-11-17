extends SceneTree
## M4 gate (Wilma): integrated law + staff + econ + politics, autoplay, N seeds × M months.
##   godot --headless --path game --script res://tools/soak_integrated.gd -- [months] [seeds]   (default 120 months, 6 seeds)
## Seed OK: conservation, no famine, no sovereign default, unemployment 3–25% in ≥ 60% of months.
## Gate (Wilma, 2026-11-11): ≥ 4/6 seeds OK (also reports the old 2/3 on seeds 1–3). Any conservation failure fails.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var months := int(args[0]) if args.size() > 0 else 120
	var seeds := int(args[1]) if args.size() > 1 else 6
	var ok_first3 := 0
	var ok_seeds := 0
	var hard_fail := false
	for seed_v in range(1, seeds + 1):
		var sim := EconSim.make(seed_v, "BALANCED", {}, true)
		print("=== integrated seed %d ===" % seed_v)
		print(EconReport.header())
		var in_band := 0
		var prev := sim.world.levers.duplicate()
		var trace := seed_v == 1 and OS.get_cmdline_user_args().size() > 2
		for m in months:
			sim.step()
			var st: Dictionary = sim.world.table("pol").get("state", {})
			var stress: float = float(st.get("fiscal_stress", 0))
			for k in EconUtil.sorted_keys(sim.world.levers):
				if k.begins_with("ECON_") and prev.get(k) != sim.world.levers[k]:
					print("    m%d lever %s %s -> %s (stress %.2f)" % [sim.world.month - 1, k, prev.get(k), sim.world.levers[k], stress if stress <= 1.0 else stress / 1000.0])
			prev = sim.world.levers.duplicate()
			if trace:
				var ind := sim.world.indicators
				print("    m%d runway %.1f debt%% %.0f bal%% %.0f stress %s treasury %.2fM" % [sim.world.month - 1, ind.read("ECON_TREASURY_RUNWAY") / 1000.0, ind.read("ECON_PUBLIC_DEBT_RATIO") / 1000.0, ind.read("ECON_BUDGET_BALANCE") / 1000.0, st.get("fiscal_stress", "?"), float(sim.world.ledger.balance(EconUtil.TREASURY)) / 1e9])
			var u := _unemp(sim.world)
			if u >= 0.03 and u <= 0.25:
				in_band += 1
			if (m + 1) % 12 == 0:
				print(EconReport.year_line(sim.world) + "  tax%d infra%dk" % [sim.world.levers.get("ECON_INCOME_TAX_RATE", 0), sim.world.levers.get("ECON_BUDGET_INFRASTRUCTURE", 0)])
		var s := EconUtil.st(sim.world)
		var cons_ok: bool = sim.world.ledger.total() == 0 and not sim.world.meta.has("violations") and EconReport.goods_errors(sim.world).is_empty()
		var good: bool = cons_ok and not s["famine"] and not s["sovereign_default"] and in_band >= months * 6 / 10
		if not cons_ok:
			hard_fail = true
		if good:
			ok_seeds += 1
			if seed_v <= 3:
				ok_first3 += 1
		print("  seed %d: conserved=%s famine=%s default=%s months_in_band=%d/%d -> %s" % [seed_v, cons_ok, s["famine"], s["sovereign_default"], in_band, months, "OK" if good else "FAIL"])
		print(PoliticalSim.summary(sim))
	var need := 4 if seeds == 6 else (seeds * 2 + 2) / 3
	var passed := not hard_fail and ok_seeds >= need
	print("  seeds 1-3: %d/3 ok (old gate %s)" % [ok_first3, "PASS" if ok_first3 >= 2 and not hard_fail else "FAIL"])
	print("INTEGRATED GATE %s (%d/%d seeds ok, need %d)" % ["PASS" if passed else "FAIL", ok_seeds, seeds, need])
	quit(0 if passed else 1)


func _unemp(world: WorldState) -> float:
	var lf := 0
	var emp := 0
	for gid in world.table("hh"):
		lf += world.table("hh")[gid]["lf"]
		emp += EconLabor.employed(world.table("hh")[gid])
	return 0.0 if lf == 0 else float(lf - emp) / float(lf)
