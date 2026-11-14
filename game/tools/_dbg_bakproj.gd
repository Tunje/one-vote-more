extends SceneTree
func _init() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	var w := sim.world
	for fl in ["E146", "E147"]:
		(w.meta["on"] as Array).append(fl)
	for m in 40:
		sim.run(1)
		for pid in EconUtil.sorted_keys(w.table("project")):
			var p: Dictionary = w.table("project")[pid]
			if p["type"] != "BAKERY":
				continue
			var o: Dictionary = w.table("org").get(p["owner"], {})
			print("m%d %s %s owner %s(%s) bids %d contractor %s wu %s/%s cash %dk est %dk" % [w.month, pid, p["status"], p["owner"], o.get("status", "?"), (p.get("bids", []) as Array).size(),
				str(p.get("contractor", "")), str(p.get("wu_done", "?")), str(p.get("wu", "?")), w.ledger.balance(EconUtil.acct(p["owner"])) / 1000000, EconConstruction.estimate("BAKERY") / 1000000])
	quit()
