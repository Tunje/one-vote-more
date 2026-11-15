extends TestCase
## EconForecast (E170 stub): the first-year forecast returns its fields and a reason when a plant can't pay.


func test_stub_shape() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(6)
	var f := EconForecast.first_year(sim.world, "FARM", "d:1")
	for k in ["volume", "revenue", "costs", "profit", "reasons", "error_applied"]:
		check(f.has(k), "has %s" % k)
	check_eq(int(f["error_applied"]), 0, "the stub applies no error")
	var bad := EconForecast.first_year(sim.world, "NOPE", "d:1")
	check((bad["reasons"] as Array).has("unknown_type"), "an unknown plant type is declined")
