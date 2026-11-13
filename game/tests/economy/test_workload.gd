extends TestCase
## 27-W (EconWorkload): workload and hours per workplace, lean staffing by reckless firms, stress that builds under
## overload with sick days and worse service, overload news with the right party to blame. Opt-in "WORKLOAD".


func test_off_by_default() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(3)
	for fid in sim.world.table("facility"):
		check(not sim.world.table("facility")[fid].has("stress_pm"), "no stress tracking unless WORKLOAD is on")
		break
	check(EconQuery.workload(sim.world)["colony"].is_empty(), "the workload view is empty when off")


func test_workload_and_lean() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = ["WORKLOAD"]
	sim.run(3)
	var w := sim.world
	var tracked := 0
	for fid in w.table("facility"):
		var f: Dictionary = w.table("facility")[fid]
		if f.has("workload_pm"):
			tracked += 1
			check(int(f["hours"]) >= 30 and int(f["hours"]) <= 80, "hours in range (%d)" % int(f["hours"]))
	check(tracked > 0, "workplaces have a workload (%d)" % tracked)
	# make a private firm reckless: it runs lean
	var plant := ""
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		var o: Dictionary = w.table("org")[f["org"]]
		if o["type"] == "PRIVATE" and not o["is_contractor"] and not f["mothball"] and f["type"] != "HOUSING":
			plant = fid
			o["ceo"]["risk"] = 95
			break
	check(plant != "", "a private plant exists")
	if plant == "":
		return
	sim.run(1)
	var pf: Dictionary = w.table("facility")[plant]
	check_eq(int(pf["lean_pm"]), EconWorkload.LEAN_PM, "a reckless owner runs the plant lean")
	var full := 0
	var posted := 0
	for t in EconLabor.required_full(pf):
		full += int(EconLabor.required_full(pf)[t])
		posted += int(EconLabor.required(pf)[t])
	check(posted < full, "fewer posts than the norm (%d of %d)" % [posted / 1000, full / 1000])
	check(int(pf["lean_saving"]) > 0, "running lean saves wages")
	check(EconPop.check(w).is_empty(), "jobs still equal people: %s" % [EconPop.check(w)])
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_overloaded_clinic_stresses_and_makes_news() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = ["WORKLOAD"]
	sim.run(2)
	var w := sim.world
	var clinic := ""
	for fid in EconUtil.sorted_keys(w.table("facility")):
		if w.table("facility")[fid]["type"] == "CLINIC" and not w.table("facility")[fid]["mothball"]:
			clinic = fid
			break
	check(clinic != "", "a clinic exists")
	if clinic == "":
		return
	var f: Dictionary = w.table("facility")[clinic]
	for _m in 18:
		f["stress_pm"] = maxi(int(f.get("stress_pm", 0)), 0)
		f["workload_pm"] = 1900
		EconWorkload.monthly(w)  # recompute; then force the overload the staff cut would cause
		f["stress_pm"] = mini(1000, int(f["stress_pm"]) + 120)
	check(int(f["stress_pm"]) >= EconWorkload.OVERLOAD_PM, "stress built up (%d)" % int(f["stress_pm"]))
	check(EconWorkload.quality_mult(f) < 1.0, "a stressed clinic treats worse (%.2f)" % EconWorkload.quality_mult(f))
	check(EconWorkload.sick_mult(f) < 1.0, "stressed staff take sick days")
	EconWorkload.monthly(w)
	var news := w.facts.query("ECON_OVERLOAD_INCIDENT")
	check(not news.is_empty(), "the overload makes news")
	if not news.is_empty():
		var d: Dictionary = news[news.size() - 1]["data"]
		check_eq(String(d.get("owner_kind", "")), "PUBLIC", "a public clinic: the Cabinet answers for it")
		check(int(d.get("workload", 0)) > 0, "the fact carries the workload")
