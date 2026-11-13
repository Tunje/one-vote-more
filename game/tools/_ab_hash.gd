extends SceneTree
## Bob: determinism A/B — run a seed N months with and without a switch, compare the full saved state. args: seed months switch
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var hs := []
	for off in [[], [a[2]]]:
		var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
		sim.world.meta["off"] = off
		var t0 := Time.get_ticks_usec()
		sim.run(int(a[1]))
		var t1 := Time.get_ticks_usec()
		sim.world.meta["off"] = []
		hs.append(var_to_str(SaveIO.encode_ordered(sim.to_dict())).hash())
		print("off=%s  %.1fs  hash %d" % [str(off), (t1 - t0) / 1e6, hs[-1]])
	print("IDENTICAL" if hs[0] == hs[1] else "DIFFERENT")
	quit()
