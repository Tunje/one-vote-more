extends SceneTree
## Bob: part B in the full game. args: seed years [B]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	var arm := "v8"
	if a.size() > 2 and a[2] == "B":
		(w.meta["on"] as Array).append("SUPPORT_B")
		arm = "v8+B"
	for y in int(a[1]):
		sim.run(12)
		if (y + 1) % 5 != 0:
			continue
		var pop := 0
		for gid in w.table("hh"):
			pop += EconHouseholds.persons(w.table("hh")[gid]) / 1000
		var party := 0
		for pid in w.peek("party"):
			if w.ledger.has_account("party:" + pid):
				party += w.ledger.balance("party:" + pid)
		var un := 0
		for uid in w.peek("union"):
			var acc := String(w.peek("union")[uid].get("acct", ""))
			if acc != "" and w.ledger.has_account(acc):
				un += w.ledger.balance(acc)
		var outs := 0
		for id in w.peek("outlet"):
			if String(w.peek("outlet")[id].get("status", "OPEN")) != "CLOSED":
				outs += 1
		print("%s Y%d pop %d u %.1f%% | %s | party cash %dk union funds %dk outlets %d | ledger %d jobs %d" % [arm, y + 1, pop, float(EconQuery.labour(w)["rate_pct"]),
			JSON.stringify(EconHQ.summary(w)), party / 1000000, un / 1000000, outs, w.ledger.total(), EconPop.check(w).size()])
	quit()
