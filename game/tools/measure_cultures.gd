extends SceneTree
## Political culture across colonies (real economy, month 48): overall lean and how each class splits.
const EconSim := preload("res://sim/economy/econ_sim.gd")

func _initialize() -> void:
	for seed_v in [1, 2, 3, 4, 5, 6]:
		var sim: Simulation = EconSim.make(seed_v, "BALANCED", {})
		while sim.world.month < 48:
			sim.step()
		var w := sim.world
		var by := {}
		for c in w.peek("cell").values():
			var econ := (float(c["ideology"]["ECON_ROLE"]) + float(c["ideology"]["REDISTRIBUTION"])) / 2000.0
			var k := "L" if econ > 10.0 else ("R" if econ < -10.0 else "C")
			for g in ["ALL", c["occ"]]:
				if not by.has(g): by[g] = {"L": 0.0, "C": 0.0, "R": 0.0}
				by[g][k] += c["pop"]
		var line := "seed %d | " % seed_v
		for g in ["ALL", "INDUSTRY", "AGRICULTURE", "PUBLIC_SECTOR", "SERVICES"]:
			if by.has(g):
				var t: float = by[g]["L"] + by[g]["C"] + by[g]["R"]
				line += "%s L%.0f/C%.0f/R%.0f  " % [g.substr(0, 4), 100 * by[g]["L"] / t, 100 * by[g]["C"] / t, 100 * by[g]["R"] / t]
		var e: Dictionary = w.peek("election").values()[0] if not w.peek("election").is_empty() else {}
		var res: Array = []
		for pid in e.get("votes", {}):
			res.append("%s %.0f" % [w.peek("party")[pid]["name"].get_slice(" ", 0), 100.0 * e["votes"][pid] / e["total"]])
		print(line + "| " + ", ".join(res))
	quit(0)
