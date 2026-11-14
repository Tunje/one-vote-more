extends SceneTree
func _init() -> void:
	var sim := EconSim.make_econ_only(1)
	var w := sim.world
	w.meta["on"] = ["CARE"]
	sim.run(24)
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] in ["ELDERCARE", "CHILDCARE"]:
			print("%s %s %s scale %d fscale %.3f req %s staff %s enrolled %d clients %d" % [fid, f["type"], f["district"], f["scale"], EconUtil.fscale(f), EconLabor.required(f), f["staff"], f["enrolled"], f["clients"]])
	quit()
