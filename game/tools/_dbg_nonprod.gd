extends SceneTree
func _init() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	sim.run(120)
	var w := sim.world
	for tname in ["party", "union", "outlet", "media"]:
		var t: Dictionary = w.peek(tname)
		if t.is_empty():
			print(tname, ": (none)")
			continue
		var k = t.keys()[0]
		print(tname, " n=", t.size(), " first ", k, ": ", JSON.stringify(t[k]).substr(0, 900))
	var accts := {}
	for a in w.ledger.balances.keys() if "balances" in w.ledger else []:
		var p := String(a).split(":")[0]
		accts[p] = int(accts.get(p, 0)) + 1
	print(accts)
	quit()
