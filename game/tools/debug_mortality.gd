extends SceneTree
## Firm mortality probe: who enters insolvency/liquidation and their state at that moment (integrated run).
##   godot --headless --path . --script res://tools/debug_mortality.gd -- [seed] [months]
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 3
	var months := int(args[1]) if args.size() > 1 else 72
	var sim := EconSim.make(seed_v, "BALANCED", {}, true)
	var w := sim.world
	var prev := {}
	for m in months:
		sim.step()
		for oid in EconUtil.sorted_keys(w.peek("org")):
			var o: Dictionary = w.peek("org")[oid]
			if prev.get(oid, "ACTIVE") != o["status"]:
				var sectors := {}
				for f in w.peek("facility").values():
					if f["org"] == oid:
						sectors[f["type"]] = true
				var pl: Dictionary = o["pl_last"]
				print("m%3d %s %-14s %s -> %s  cash %dk debt %dk  rev %dk cogs %dk wages %dk  sectors %s crew %d" % [w.month, oid, o["type"], prev.get(oid, "ACTIVE"), o["status"],
					w.ledger.balance(EconUtil.acct(oid)) / 1000000, EconFinance.debt_of(w, oid) / 1000000, pl.get("rev", 0) / 1000000, pl.get("cogs", 0) / 1000000, pl.get("wages", 0) / 1000000,
					str(sectors.keys()), EconLabor.staff_total(o["crew"]) / 1000])
			prev[oid] = o["status"]
	quit(0)
