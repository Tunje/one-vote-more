extends SceneTree
## Post-collapse probe: power plants, their owner, staff, condition, upkeep stocks and cold-start state.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim := EconSim.make(int(a[0]) if a.size() > 0 else 1)
	var w := sim.world
	for m in [300, 348, 360, 384, 420]:
		sim.run(m - w.month)
		var s := EconUtil.st(w)
		print("== m%d E %d/%d blackout_m %d treas %dk" % [w.month, s["util_supply"]["E"] / 1000, s["util_demand"]["E"] / 1000, s.get("blackout_m", 0), w.ledger.balance(EconUtil.TREASURY) / 1000000])
		for fid in EconUtil.sorted_keys(w.table("facility")):
			var f: Dictionary = w.table("facility")[fid]
			if f["type"] in ["POWER", "WATERWORKS", "PROCESSING", "COMPONENTS", "MINE"]:
				var o: Dictionary = w.table("org").get(f["org"], {})
				print("  %s %s %s/%s T%d util%d staff%d mb%s cu%s law%s cond%d ovh%d mat%d comp%d cash%dk" % [fid, f["type"], o.get("key", "?"), String(o.get("status", "?")).substr(0, 4), f["T"], f["util"],
					EconLabor.staff_total(f["staff"]) / 1000, str(f["mothball"]).substr(0, 1), str(f.get("closed_unsafe", false)).substr(0, 1), str(f.get("law_closed", false)).substr(0, 1), f["condition"] / 1000,
					f.get("overhaul_frac", -1), EconUtil.inv_get(w, f["org"], "MATERIAL", f["district"]) / 1000, EconUtil.inv_get(w, f["org"], "COMPONENT", f["district"]) / 1000,
					w.ledger.balance(EconUtil.acct(f["org"])) / 1000000 if f["org"] != "" else 0])
	quit()
