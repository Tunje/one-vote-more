extends SceneTree
## temp: pd5 scenario with and without E127; union elections count
func _init() -> void:
	for off in [[], ["E127"]]:
		var a := EconSim.make_econ_only(5)
		var b := EconSim.make_econ_only(5)
		a.world.meta["off"] = off
		b.world.meta["off"] = off
		a.run(2)
		b.run(2)
		for i in 11:
			EconUtil.st(a.world)["wage"]["G"] = EconUtil.st(b.world)["wage"]["G"] * 3 / 2
			a.run(1)
			b.run(1)
		var hi_a := PopStore.count(a.world, {"status": "EMPLOYED", "inc": ["I4", "I5"]}, "skill:G")
		var hi_b := PopStore.count(b.world, {"status": "EMPLOYED", "inc": ["I4", "I5"]}, "skill:G")
		var emp_a := maxi(1, PopStore.count(a.world, {"status": "EMPLOYED"}, "skill:G"))
		var emp_b := maxi(1, PopStore.count(b.world, {"status": "EMPLOYED"}, "skill:G"))
		print("off=%s raise %d/%d no-raise %d/%d | food price a %d b %d" % [str(off), hi_a, emp_a, hi_b, emp_b, int(EconUtil.st(a.world)["prices"]["FOOD"]) / 1000, int(EconUtil.st(b.world)["prices"]["FOOD"]) / 1000])
	quit()
