extends SceneTree
## Famine probe: food market + every farm with causes at given months of an integrated run.
##   godot --headless --path . --script res://tools/debug_famine.gd -- [seed] [months_csv]
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 3
	var marks: Array = Array((args[1] if args.size() > 1 else "24,40,60,84").split(",")).map(func(x): return int(x))
	var sim := EconSim.make(seed_v, "BALANCED", {}, true)
	var w := sim.world
	for m in marks.max():
		sim.step()
		if not (w.month in marks):
			continue
		var s := EconUtil.peek_st(w)
		var ms: Dictionary = s.get("market_stats", {}).get("FOOD", {})
		print("== m%d FOOD price %d base %d  S %d D %d wanted %d filled %d  shortfall %s  reserve %d" % [w.month, s["prices"]["FOOD"], s["base"]["FOOD"],
			ms.get("S", 0) / 1000, ms.get("D", 0) / 1000, ms.get("wanted", 0) / 1000, ms.get("filled", 0) / 1000, s.get("food_shortfall", 0), EconUtil.inv_get(w, "gov", "FOOD", "d:1") / 1000])
		var lv: Array = []
		for k in ["ECON_FOOD_ASSISTANCE", "ECON_UNEMPLOYMENT_BENEFIT_RATE", "ECON_BENEFIT_FLOOR", "ECON_PENSION_RATE", "ECON_INCOME_TAX_RATE", "ECON_SALES_TAX", "ECON_BUDGET_INFRASTRUCTURE", "ECON_UTILITY_TARIFF_WATER", "ECON_UTILITY_TARIFF_ENERGY"]:
			lv.append("%s=%s" % [k.trim_prefix("ECON_"), str(w.levers.get(k))])
		print("  levers ", " ".join(lv))
		var by := {}
		for b in s.get("orders", []):
			if b["good"] == "FOOD":
				by[b["class"]] = by.get(b["class"], 0) + b["qty"] / 1000
		var need := 0
		for g in w.peek("hh").values():
			need += int(EconHouseholds.persons(g) * EconData.NEED["FOOD"]) / 1000
		print("  FOOD orders now by class %s  hh need %d" % [str(by), need])
		var cpw := EconFinance.org_by_key(w, "CPW")
		var co: Dictionary = w.peek("org")[cpw]
		print("  CPW %s status %s cash %dk wages %dk" % [cpw, co["status"], w.ledger.balance(EconUtil.acct(cpw)) / 1000000, co["pl_last"].get("wages", 0) / 1000000])
		for g2 in ["MATERIAL", "COMPONENT"]:
			var m2: Dictionary = s.get("market_stats", {}).get(g2, {})
			var inv := 0
			var ords := 0
			for d2 in EconData.DISTRICTS:
				inv += EconUtil.inv_get(w, cpw, g2, d2)
			for b in s.get("orders", []):
				if b["good"] == g2 and b["buyer"] == cpw:
					ords += b["qty"]
			print("    %s price %d S %d wanted %d filled %d | CPW inv %d ordering %d" % [g2, s["prices"][g2] / 1000, m2.get("S", 0) / 1000, m2.get("wanted", 0) / 1000, m2.get("filled", 0) / 1000, inv / 1000, ords / 1000])
		var hh_cash := 0
		for g in w.peek("hh").values():
			hh_cash += w.ledger.balance(EconUtil.hh_acct(g["id"]))
		print("  freight cap %d used %d deferred %s  hh cash %dk" % [s.get("freight_cap", 0) / 1000, s.get("freight_used", 0) / 1000, str(s.get("freight_deferred", {})), hh_cash / 1000000])
		for fid in EconUtil.sorted_keys(w.peek("facility")):
			var f: Dictionary = w.peek("facility")[fid]
			if f["type"] == "DEPOT":
				print("  %s DEPOT %s util %d staff %d cond %d %s" % [fid, f["district"], f["util"], EconLabor.staff_total(f["staff"]) / 1000, f["condition"] / 1000,
					"; ".join(EconQuery.explain_facility(w, fid)["causes"].slice(0, 3).map(func(c): return c["cause"] + " " + c["detail"]))])
		print("  util supply/demand E %d/%d W %d/%d  treasury %dk  benefit paid/m %dk  food_aid_streak %d" % [s.get("util_supply", {}).get("E", 0) / 1000, s.get("util_demand", {}).get("E", 0) / 1000,
			s.get("util_supply", {}).get("W", 0) / 1000, s.get("util_demand", {}).get("W", 0) / 1000, w.ledger.balance(EconUtil.TREASURY) / 1000000,
			w.peek("hh").values().reduce(func(a, g): return a + g["income"].get("benefit", 0), 0) / 1000000, s.get("aid_streak", 0)])
		for fid in EconUtil.sorted_keys(w.peek("facility")):
			var f: Dictionary = w.peek("facility")[fid]
			if f["type"] in ["POWER", "WATERWORKS"]:
				var o2: Dictionary = w.peek("org").get(f["org"], {})
				print("  %s %s %s util %d staff %d cond %d %s" % [fid, f["type"], o2.get("status", "?"), f["util"], EconLabor.staff_total(f["staff"]) / 1000, f["condition"] / 1000,
					"; ".join(EconQuery.explain_facility(w, fid)["causes"].slice(0, 3).map(func(c): return c["cause"] + " " + c["detail"]))])
			if f["type"] != "FARM":
				continue
			var o: Dictionary = w.peek("org").get(f["org"], {})
			var ex := EconQuery.explain_facility(w, fid)
			print("  %s %s %s org %s(%s %s) util %d T %d staff %d cash %d  %s" % [fid, f["district"], "MOTH" if f["mothball"] else "", f["org"], o.get("type", "?"), o.get("status", "?"),
				f["util"], f["T"], EconLabor.staff_total(f["staff"]) / 1000, w.ledger.balance(EconUtil.acct(f["org"])) / 1000000,
				"; ".join(ex["causes"].slice(0, 3).map(func(c): return c["cause"] + " " + c["detail"]))])
	quit(0)
