extends SceneTree
func _init() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	var w := sim.world
	for fl in ["E146", "E147"]:
		(w.meta["on"] as Array).append(fl)
	sim.run(63)
	for i in 3:
		sim.run(1)
		var s := EconUtil.st(w)
		for fid in EconUtil.sorted_keys(w.table("facility")):
			var f: Dictionary = w.table("facility")[fid]
			if f["type"] != "BAKERY":
				continue
			var oid: String = f["org"]
			var o: Dictionary = w.table("org")[oid]
			var ords := []
			for b in s["orders"]:
				if b["buyer"] == oid:
					ords.append("%s q%d lim%d cls%d" % [b["good"], int(b["qty"]) / 1000, int(b["limit"]), int(b["class"])])
			var causes := []
			for c in EconQuery.explain_facility(w, fid)["causes"]:
				causes.append(c["cause"])
			print("m%d %s %s %s cash %dk wages_last %dk staff %d/%d moth %s orders %s causes %s FOODpx %d" % [w.month, fid, oid, o["status"], w.ledger.balance(EconUtil.acct(oid)) / 1000000,
				int(o["pl_last"].get("wages", 0)) / 1000000, EconLabor.staff_total(f["staff"]) / 1000, _sum(EconLabor.required(f)) / 1000, str(f["mothball"]), str(ords), str(causes), int(s["prices"]["FOOD"])])
	quit()

func _sum(d: Dictionary) -> int:
	var t := 0
	for k in d:
		t += int(d[k])
	return t
