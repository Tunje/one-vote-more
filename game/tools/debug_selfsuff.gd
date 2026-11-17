extends SceneTree
## M12 self-sufficiency probe: yearly food / utilities / strategic goods / reserve / treasury, plus the month the
## famine flag is set. Usage: godot --headless --path . --script res://tools/debug_selfsuff.gd -- [seed] [years]


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var seed_v := int(a[0]) if a.size() > 0 else 1
	var years := int(a[1]) if a.size() > 1 else 20
	var sim := EconSim.make(seed_v)
	var w := sim.world
	var famine_m := -1
	for m in years * 12:
		sim.run(1)
		var s := EconUtil.st(w)
		if s["famine"] and famine_m < 0:
			famine_m = w.month
			print("FAMINE set at m%d: short %d farms_out %d E %d/%d W %d/%d pFood %d" % [w.month, s["food_shortfall"], _farm_out(w), s["util_supply"]["E"] / 1000,
				s["util_demand"]["E"] / 1000, s["util_supply"]["W"] / 1000, s["util_demand"]["W"] / 1000, s["prices"]["FOOD"] / 1000])
		if (m + 1) % 12 != 0:
			continue
		var need := 0
		var poor_cash := 0
		for gid in w.table("hh"):
			var g: Dictionary = w.table("hh")[gid]
			need += int(EconHouseholds.persons(g) * EconData.NEED["FOOD"]) / 1000
			if g["band"] in ["I1", "I2"]:
				poor_cash += w.ledger.balance(EconUtil.hh_acct(gid)) / 1000000
		var power := []
		for fid in EconUtil.sorted_keys(w.table("facility")):
			var f: Dictionary = w.table("facility")[fid]
			if f["type"] == "POWER":
				power.append("%s:c%d u%d%s" % [f["org"].substr(4), f["condition"] / 1000, f["util"], "M" if f["mothball"] else ""])
		print("y%d pop %d food_out %d need %d short %d pFood %d | E %d/%d W %d/%d | power %s | pMat %d pComp %d mktMAT %s | reserve F%d M%d C%d | treas %dk poorcash %dk" % [
			(m + 1) / 12, PopStore.total(w), _farm_out(w), need, s["food_shortfall"], s["prices"]["FOOD"] / 1000, s["util_supply"]["E"] / 1000, s["util_demand"]["E"] / 1000,
			s["util_supply"]["W"] / 1000, s["util_demand"]["W"] / 1000, str(power), s["prices"]["MATERIAL"] / 1000, s["prices"]["COMPONENT"] / 1000,
			str(s.get("market_stats", {}).get("MATERIAL", {})), EconUtil.inv_get(w, "gov", "FOOD", "d:1") / 1000, EconUtil.inv_get(w, "gov", "MATERIAL", "d:1") / 1000,
			EconUtil.inv_get(w, "gov", "COMPONENT", "d:1") / 1000, w.ledger.balance(EconUtil.TREASURY) / 1000000, poor_cash])
	quit()


func _farm_out(w: WorldState) -> int:
	var t := 0
	for fid in w.table("facility"):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "FARM":
			t += f["out_last"] / 1000
	return t
