extends SceneTree
## Who lives in the colony (real economy), and how they vote.
##   godot --headless --path game --script res://tools/measure_society.gd
const EconSim := preload("res://sim/economy/econ_sim.gd")


func _initialize() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {})
	for m in [1, 24, 48]:
		while sim.world.month < m:
			sim.step()
		_report(sim.world)
	quit(0)


func _report(w: WorldState) -> void:
	var occ := {}
	var band := {}
	var tot := 0
	for key in w.peek("census"):
		var parts: PackedStringArray = key.split("|")
		var p: int = w.peek("census")[key]
		occ[parts[1]] = occ.get(parts[1], 0) + p
		band[parts[2]] = band.get(parts[2], 0) + p
		tot += p
	var o: Array = []
	for k in occ:
		o.append("%s %.0f%%" % [k, 100.0 * occ[k] / tot])
	var b: Array = []
	for k in band:
		b.append("%s %.0f%%" % [k, 100.0 * band[k] / tot])
	print("\nMonth %d, population %d" % [w.month, tot])
	print("  occupations: " + ", ".join(o))
	print("  income bands: " + ", ".join(b))
	# Ideology spread across voter cells (population-weighted share left/right on the economic axes)
	var left := 0.0
	var right := 0.0
	var centre := 0.0
	for c in w.peek("cell").values():
		var econ := (float(c["ideology"]["ECON_ROLE"]) + float(c["ideology"]["REDISTRIBUTION"])) / 2000.0
		if econ > 10.0: left += c["pop"]
		elif econ < -10.0: right += c["pop"]
		else: centre += c["pop"]
	var cp := maxf(1.0, left + right + centre)
	if not w.peek("cell").is_empty():
		print("  voters by economic lean: left %.0f%%, centre %.0f%%, right %.0f%%" % [100 * left / cp, 100 * centre / cp, 100 * right / cp])
	for e in w.peek("election").values():
		var parts2: Array = []
		for pid in e["votes"]:
			parts2.append("%s %.0f%%" % [w.peek("party")[pid]["name"], 100.0 * e["votes"][pid] / maxf(1, e["total"])])
		print("  election m%d: %s" % [e["month"], ", ".join(parts2)])
