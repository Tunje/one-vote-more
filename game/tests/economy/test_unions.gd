extends TestCase
## M9 interest groups, economy side (spec-politics-v2 §5): union density, strike/lockout/mass-layoff facts, donation offers.


func _sim(months: int) -> Simulation:
	var sim := EconSim.make_econ_only(4)
	sim.run(months)
	return sim


func _private_org(w: WorldState) -> String:
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if o["type"] == "PRIVATE" and o["status"] == "ACTIVE" and not EconUnions._org_workforce(w, oid)["facs"].is_empty():
			return oid
	return ""


func test_union_density_published_and_driven_by_rights() -> void:
	var sim := _sim(3)
	var w := sim.world
	for occ in EconUnions.BASE_DENSITY:
		var v: int = w.indicators.read("ECON_UNION_DENSITY", occ, -1)
		check(v > 0 and v <= 100000, "%s density %d in range" % [occ, v])
	check(w.indicators.read("ECON_UNION_DENSITY", "PUBLIC_SECTOR") > w.indicators.read("ECON_UNION_DENSITY", "SERVICES"), "public sector more unionised than services")
	var emp := EconUnions.employed_by_occ(w)
	var total := 0
	for occ in EconUnions.BASE_DENSITY:
		total += emp.get(occ, 0)
	w.levers["ECON_UNION_RIGHTS"] = 10
	var lo := EconUnions.target_density(w, "MANUFACTURING", emp, total)
	w.levers["ECON_UNION_RIGHTS"] = 90
	var hi := EconUnions.target_density(w, "MANUFACTURING", emp, total)
	check(hi > lo * 2, "union rights drive density (%d vs %d)" % [hi, lo])


func test_labor_law_cut_is_a_grievance_blamed_on_government() -> void:
	var sim := _sim(2)
	var w := sim.world
	check_eq(EconUnions.law_grievance(w, "MANUFACTURING"), 0.0, "no grievance at start")
	w.levers["ECON_MIN_WAGE"] = 40
	w.levers["ECON_UNION_RIGHTS"] = 50
	EconUnions._track_levers(w)
	w.levers["ECON_UNION_RIGHTS"] = 20  # enacted cut
	EconUnions._track_levers(w)
	check(EconUnions.law_grievance(w, "MANUFACTURING") >= 0.5, "cut of union rights is a grievance: %f" % EconUnions.law_grievance(w, "MANUFACTURING"))
	w.levers["ECON_UNION_RIGHTS"] = 60  # pro-worker change adds nothing
	EconUnions._track_levers(w)
	check_eq(EconUnions._u(w)["law_hits"].size(), 1, "only the adverse change is recorded")
	# a strike caused by labor law: public fact, government responsible, production cut, wage gain
	var oid := _private_org(w)
	check(oid != "", "has an active private producer")
	w.table("org")[oid]["ceo"]["risk"] = 0  # no lockout
	var wf := EconUnions._org_workforce(w, oid)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	EconUnions._strike(w, oid, wf, "MANUFACTURING", 20 * EconUtil.S, "LABOR_LAW", rng)
	var f: Dictionary = w.facts.query("ECON_STRIKE")[-1]
	check_eq(f["visibility"], "PUBLIC", "strike is public")
	check_eq(f["responsible"][0]["actor"]["id"], "government", "government responsible for a labor-law strike")
	check(f["impact"].get("JOBS", 0) < 0, "strike carries concern impacts")
	var fac: Dictionary = w.table("facility")[wf["facs"][0]]
	w.month += 1
	check_eq(EconUnions.work_factor(w, fac), EconUnions.STRIKE_WORK, "strike cuts labor effectiveness next month")
	check(EconProduction._plan(w, fac)["u"] <= EconUnions.STRIKE_WORK + 0.001, "production plan sees the strike")
	check(int(w.table("org")[oid]["union_pm"]) > 0, "workers win a wage premium")
	w.month += 3
	check_eq(EconUnions.work_factor(w, fac), 1.0, "strike ends")


func test_lockout_and_mass_layoffs() -> void:
	var sim := _sim(2)
	var w := sim.world
	var oid := _private_org(w)
	var o: Dictionary = w.table("org")[oid]
	o["ceo"]["risk"] = 100
	w.levers["ECON_UNION_RIGHTS"] = 0
	var wf := EconUnions._org_workforce(w, oid)
	# find a seed whose first draw triggers the lockout (P = 0.75 here), then replay it
	var rng := RandomNumberGenerator.new()
	var sd := 0
	for k in 50:
		rng.seed = k
		if rng.randf() < 0.75:
			sd = k
			break
	rng.seed = sd
	EconUnions._strike(w, oid, wf, "MANUFACTURING", 20 * EconUtil.S, "REAL_WAGES", rng)
	var lo: Array = w.facts.query("ECON_LOCKOUT")
	check_eq(lo.size(), 1, "hard-line employer locks out")
	if not lo.is_empty():
		check_eq(lo[0]["responsible"][0]["actor"]["id"], oid, "lockout blamed on the company")
	w.month += 1
	check_eq(EconUnions.work_factor(w, w.table("facility")[wf["facs"][0]]), EconUnions.LOCKOUT_WORK, "lockout stops work")
	check_eq(int(o.get("union_pm", 0)), 0, "no wage gain from a lockout")
	# mass layoffs: an org sheds 40% of its staff in one month
	var oid2 := ""
	for x in EconUtil.sorted_keys(w.table("org")):
		if x != oid and w.table("org")[x]["status"] == "ACTIVE" and not w.table("org")[x]["type"] in EconData.PUBLIC_TYPES:
			var n := 0
			for occ in EconUnions._org_workforce(w, x)["occ"]:
				n += EconUnions._org_workforce(w, x)["occ"][occ]
			if n >= 30 * EconUtil.S:
				oid2 = x
				break
	check(oid2 != "", "an org with 30+ staff")
	var staff := 0
	for occ in EconUnions._org_workforce(w, oid2)["occ"]:
		staff += EconUnions._org_workforce(w, oid2)["occ"][occ]
	EconUtil.st(w)["layoffs_m"] = {oid2 + "|" + w.table("org")[oid2]["hq"]: staff * 2 / 3}
	EconUnions.industrial_action(w)
	var ml: Array = w.facts.query("ECON_LAYOFFS_MASS")
	check(not ml.is_empty() and ml[-1]["data"]["org"] == oid2, "mass layoff fact for %s" % oid2)
	if not ml.is_empty():
		check(ml[-1]["visibility"] == "PUBLIC" and ml[-1]["impact"]["JOBS"] < 0, "public, with JOBS impact")
	EconUnions.industrial_action(w)
	check_eq(w.facts.query("ECON_LAYOFFS_MASS").size(), ml.size(), "one mass-layoff fact per org per 6 months")


func test_donation_offers_contract() -> void:
	var sim := _sim(14)
	var w := sim.world
	var seen := 0
	for m in 12:
		sim.run(1)
		var tbl: Dictionary = w.peek("donation_offer")
		for oid in tbl:
			var d: Dictionary = tbl[oid]
			seen += 1
			check_eq(d["from"], oid, "offer keyed by company")
			check(w.table("org")[oid]["type"] in ["PRIVATE", "COOPERATIVE"], "only private firms and co-ops donate")
			check(d["amount_milli"] is int and d["amount_milli"] >= EconUnions.DONATION_MIN, "amount int ≥ minimum")
			check(d["amount_milli"] <= w.ledger.balance(EconUtil.acct(oid)), "offer is covered by company cash")
			check(not d["prefers"].is_empty(), "offer states preferences")
			for ax in d["prefers"]:
				check(PolDefs.AXES.has(ax) and absi(d["prefers"][ax]) == 1, "prefers {axis: ±1}: %s" % [d["prefers"]])
	check(seen > 0, "companies make offers in a year (%d)" % seen)
	check_eq(w.ledger.total(), 0, "offers move no money by themselves")
