extends SceneTree
## Bob (Wilma's demand-cap question): where does household discretionary money fail to find something to buy?
## Every 5 years: household money, discretionary budgets, goods wanted vs filled (CONSUMER, D2), services capacity
## sold vs spare, hub targets. args: seed years [off-list]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if a.size() > 2 and a[2] != "-":
		w.meta["off"] = Array(a[2].split(","))
	for y in int(a[1]):
		sim.run(12)
		if (y + 1) % 5 != 0:
			continue
		var s := EconUtil.st(w)
		var hh_m := 0
		var disc := 0
		var svc := 0
		for gid in w.table("hh"):
			var g: Dictionary = w.table("hh")[gid]
			hh_m += w.ledger.balance(EconUtil.hh_acct(gid))
			disc += EconHouseholds.discretionary_budget(w, g)
			svc += int(g.get("svc_spent", 0))
		var goods := []
		for good in ["CONSUMER", "CLOTHING", "FURNISHINGS", "FINE_FOOD"]:
			var m: Dictionary = s.get("market_stats", {}).get(good, {})
			goods.append("%s want %d got %d" % [good.substr(0, 4), int(m.get("wanted", 0)) / 1000, int(m.get("filled", 0)) / 1000])
		var cap_left := 0
		var sold := 0
		var hubs := 0
		var t_sum := 0
		for fid in w.table("facility"):
			var f: Dictionary = w.table("facility")[fid]
			if f["type"] == "SERVICEHUB" and not f["mothball"]:
				hubs += 1
				cap_left += int(f.get("svc_cap", 0))
				sold += int(f.get("svc_sold", 0))
				t_sum += int(f["T"])
		print("Y%d hh money %dM | disc budget/month %dM | services spent %dM | hubs %d T_avg %d sold %d spare %d | %s | wage G %d" % [y + 1,
			hh_m / 1000000, disc / 1000000, svc / 1000000, hubs, t_sum / maxi(1, hubs), sold / 1000, cap_left / 1000, " | ".join(goods), int(s["wage"]["G"]) / 1000])
	quit()
