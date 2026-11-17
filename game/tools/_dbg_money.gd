extends SceneTree
## Bob (backlog 31, Wilma): where does the money sit? Every 5 years, ledger balances grouped by holder.
## args: seed years [on-list]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if a.size() > 2 and a[2] != "-":
		w.meta["on"] = Array(a[2].split(","))
	for y in int(a[1]):
		sim.run(12)
		if (y + 1) % 5 != 0:
			continue
		var by := {}
		for acc in EconUtil.sorted_keys(w.ledger.balances):
			var b := int(w.ledger.balances[acc])
			var k := "other:" + str(acc).split(":")[0]
			if str(acc).begins_with("hh:"):
				var gid := str(acc).substr(3)
				var g: Dictionary = w.table("hh").get(gid, {})
				k = "hh:" + str(g.get("band", "?"))
			elif str(acc) == EconUtil.TREASURY:
				k = "treasury"
			elif str(acc) == EconUtil.BANK:
				k = "bank"
			elif str(acc).begins_with("co:"):
				var oid := str(acc).substr(3)
				var o: Dictionary = w.table("org").get(oid, {})
				if o.is_empty():
					k = "org:?"
				else:
					k = "firms:" + str(o["type"]) + ("/builder" if o["is_contractor"] else "") + ("/dead" if o["status"] in ["LIQUIDATION", "DISSOLVED"] else "")
			by[k] = int(by.get(k, 0)) + b
		var pop := PopStore.total(w)
		var hh := 0
		for k2 in by:
			if str(k2).begins_with("hh:"):
				hh += int(by[k2])
		var spend := 0
		for gid in w.table("hh"):
			var g2: Dictionary = w.table("hh")[gid]
			spend += int(g2.get("spent_goods", 0)) + int(g2.get("svc_spent", 0)) + int(g2.get("rent_paid", 0)) + maxi(0, int(g2.get("util_paid", 0)))
		var line := []
		for k in EconUtil.sorted_keys(by):
			line.append("%s %d" % [k, int(by[k]) / 1000000])
		print("Y%d pop %d | hh money %dM (per person %d) | hh spend/month %dM | velocity %.2f | wage G %d" % [y + 1, pop, hh / 1000000, hh / maxi(1, pop) / 1000, spend / 1000000, float(spend) / maxf(1.0, float(hh)), int(EconUtil.st(w)["wage"]["G"]) / 1000])
		print("    " + " | ".join(line))
	quit()
