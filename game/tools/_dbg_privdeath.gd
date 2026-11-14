extends SceneTree
## Bob: private-firm survival diagnosis (Wilma). Chronicle defaults, seed, years. For each private/co-op firm that
## reaches LIQUIDATION: sector, age, months alive, last-6-month P&L averages, loans, fines owed, its output's sellers.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if a.size() > 2:
		for fl in a[2].split(","):
			(w.meta["on"] as Array).append(fl)
	var hist := {}  # oid -> [pl dicts]
	var born := {}
	var status := {}
	var deaths: Array = []
	for m in int(a[1]) * 12:
		sim.run(1)
		for oid in EconUtil.sorted_keys(w.table("org")):
			var o: Dictionary = w.table("org")[oid]
			if not (o["type"] in ["PRIVATE", "COOPERATIVE"]):
				continue
			if not born.has(oid):
				born[oid] = w.month
			var h: Array = hist.get(oid, [])
			h.append((o.get("pl_last", {}) as Dictionary).duplicate())
			while h.size() > 6:
				h.pop_front()
			hist[oid] = h
			var st: String = o["status"]
			if st == "LIQUIDATION" and status.get(oid, "") != "LIQUIDATION":
				var types := {}
				for fid in w.table("facility"):
					if w.table("facility")[fid]["org"] == oid:
						types[w.table("facility")[fid]["type"]] = true
				var avg := {}
				for pl in h:
					for k in pl:
						avg[k] = int(avg.get(k, 0)) + int(pl[k]) / maxi(1, h.size())
				var owed := 0
				var kinds := {}
				for lid in w.table("liability"):
					var li: Dictionary = w.table("liability")[lid]
					if li["debtor"] == oid and li["status"] == "OPEN":
						owed += int(li["amount"])
						var kk := "%s→%s" % [li.get("kind", "?"), String(li.get("creditor_acct", li.get("creditor", "?"))).split(":")[0]]
						kinds[kk] = int(kinds.get(kk, 0)) + int(li["amount"]) / 1000000
				if kinds.size() > 0 and "FARM" in types.keys():
					var vk := {}
					for vid in w.peek("violation_track"):
						var v: Dictionary = w.peek("violation_track")[vid]
						if String(v.get("company", "")) == oid and int(v.get("fined_month", -1)) >= 0:
							var kn := String(v.get("kind", v.get("action", "?")))
							vk[kn] = int(vk.get(kn, 0)) + 1
					print("FARM-DEATH %s m%d rev/mo %dk owed by kind %s fined violations %s" % [oid, w.month, int((h[h.size() - 1] as Dictionary).get("rev", 0)) / 1000000, kinds, vk])
				var key: String = String(o.get("key", "?"))
				deaths.append({"m": w.month, "oid": oid, "key": key, "types": types.keys(), "age": w.month - int(born[oid]),
					"contractor": o["is_contractor"], "pl": avg, "debt": EconFinance.debt_of(w, oid) / 1000000, "owed": owed / 1000000})
			status[oid] = st
	var by_type := {}
	for d in deaths:
		var t := "BUILDER" if d["contractor"] else ("/".join(d["types"]) if not d["types"].is_empty() else "NO_PLANT")
		var e: Dictionary = by_type.get(t, {"n": 0, "age": 0, "rev": 0, "cost": 0, "wages": 0, "cogs": 0, "interest": 0, "util": 0, "freight": 0, "rent": 0, "sub": 0, "debt": 0, "owed": 0})
		e["n"] += 1
		e["age"] += int(d["age"])
		var pl: Dictionary = d["pl"]
		e["rev"] += int(pl.get("rev", 0)) / 1000
		e["wages"] += int(pl.get("wages", 0)) / 1000
		e["cogs"] += int(pl.get("cogs", 0)) / 1000
		e["interest"] += int(pl.get("interest", 0)) / 1000
		e["util"] += int(pl.get("util", 0)) / 1000
		e["freight"] += int(pl.get("freight", 0)) / 1000
		e["rent"] += int(pl.get("rent", 0)) / 1000
		e["sub"] += int(pl.get("subsidy", 0)) / 1000
		e["debt"] += int(d["debt"])
		e["owed"] += int(d["owed"])
		by_type[t] = e
	print("deaths %d over %s years (seed %s)" % [deaths.size(), a[1], a[0]])
	for t in by_type:
		var e: Dictionary = by_type[t]
		var n := maxi(1, int(e["n"]))
		print("  %-22s n %3d  age %3dm | per month avg (credits): rev %6d wages %6d cogs %6d util %5d freight %5d rent %5d interest %5d subsidy %5d | debt %dk owed %dk" % [t, e["n"],
			int(e["age"]) / n, int(e["rev"]) / n, int(e["wages"]) / n, int(e["cogs"]) / n, int(e["util"]) / n, int(e["freight"]) / n, int(e["rent"]) / n,
			int(e["interest"]) / n, int(e["sub"]) / n, int(e["debt"]) / n, int(e["owed"]) / n])
	quit()
