extends TestCase
## Economy M4 tests: conservation, determinism, save/load round-trip, census/indicator contract.

var SAVE_PATH: String = TestCase.save_path("econ.sav")


func test_money_and_goods_conserved_24_months() -> void:
	var sim := EconSim.make_econ_only(11)
	sim.run(24)
	check_eq(sim.world.ledger.total(), 0, "ledger total")
	check(not sim.world.meta.has("violations"), "no violations: %s" % [sim.world.meta.get("violations", [])])
	var errs := EconReport.goods_errors(sim.world)
	check(errs.is_empty(), "goods conservation: %s" % [errs])


func test_same_seed_same_state() -> void:
	var a := EconSim.make_econ_only(5)
	var b := EconSim.make_econ_only(5)
	a.run(18)
	b.run(18)
	check_eq(a.world.state_hash(), b.world.state_hash(), "state hash")


func test_save_load_continue_identical() -> void:
	var ref := EconSim.make_econ_only(7)
	ref.run(10)
	check_eq(SaveIO.save(ref, SAVE_PATH), OK, "save")
	ref.run(8)
	var loaded := EconSim.econ_only_for_load()
	check_eq(SaveIO.load_into(loaded, SAVE_PATH), OK, "load")
	loaded.run(8)
	check_eq(loaded.world.state_hash(), ref.world.state_hash(), "continued state hash")


func test_census_and_indicators_published() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(2)
	var w := sim.world
	var census: Dictionary = w.table("census")
	check(census.size() >= 30, "census cells: %d" % census.size())
	var adults := 0
	for k in census:
		adults += census[k]
		check(PolDefs.OCCUPATIONS.has(k.split("|")[1]), "known occupation in %s" % k)
	check(adults > 1300 and adults < 1800, "voting adults %d" % adults)
	for d in ["ECON_UNEMPLOYMENT_RATE", "ECON_ESSENTIALS_SHARE", "ECON_POLLUTION_INDEX", "ECON_HEALTH_ACCESS", "ECON_CPI_INFLATION"]:
		check(w.indicators.written_this_month(d) or not w.indicators.values[d].is_empty(), "indicator %s written" % d)
	# every concern except GOVERNANCE has at least one econ indicator (pic-core §9)
	var covered := {}
	for d in EconPic.indicators():
		for c in d["concerns"]:
			covered[c] = true
	for c in PolDefs.CONCERNS:
		if not (c in ["GOVERNANCE", "COLONIAL_BURDEN"]):  # political concerns, fed by pol/law indicators
			check(covered.has(c), "concern %s covered" % c)


func test_levers_legislatable_contract() -> void:
	for d in EconPic.levers():
		check(d["implementation"].begins_with("STAFF_T_IMPL_"), "%s implementation class" % d["id"])
		if d["type"] == "NUMBER" and d["legalLevel"] != "CHARTER":
			check(d.has("concerns") and not d["concerns"].is_empty(), "%s concerns hint" % d["id"])
			check(d["default"] >= d["range"][0] and d["default"] <= d["range"][1], "%s default in range" % d["id"])
	check(EconPic.levers().filter(func(x): return x.get("is_tax", false)).size() == 4, "four tax levers flagged")


func test_first_year_economy_sane() -> void:
	var sim := EconSim.make_econ_only(1)
	sim.run(12)
	var s := EconUtil.st(sim.world)
	check(s["food_shortfall"] < 50, "food shortfall %d‰" % s["food_shortfall"])
	var u: int = sim.world.indicators.read("ECON_UNEMPLOYMENT_RATE", "d:1")
	check(u < 25000, "Landing unemployment %d milli-%%" % u)


func test_query_layer_for_ui() -> void:
	var sim := EconSim.make_econ_only(4)
	sim.run(14)
	var w := sim.world
	var b := EconQuery.budget_view(w)
	check(b["lines"].size() == EconQuery.LINE_LABELS.size() and b["treasury"] > 0.0, "budget view")
	check(b["revenue_12m"].has("INCOME_TAX"), "revenue by source")
	check(EconQuery.companies(w).size() >= 15, "company directory")
	var oid: String = EconQuery.companies(w)[0]["id"]
	check(EconQuery.company_profile(w, oid).has("facilities"), "company profile")
	check(EconQuery.market_overview(w).size() == 8, "market overview")
	check(EconQuery.district_economy(w, "d:4").has("ECON_POLLUTION_INDEX"), "district economy")
	var fid: String = EconUtil.sorted_keys(w.table("facility"))[0]
	check(EconQuery.explain_facility(w, fid).has("causes"), "facility explainer")
	check(EconQuery.projects(w).size() >= 3, "projects list")
	check(EconQuery.commission_options(w).size() >= 5, "commission options")
	EconQuery.tenders(w)
	var some := w.facts.query("ECON_")
	if not some.is_empty():
		check(EconQuery.explain_fact(w, some[-1]["id"]).size() >= 1, "fact explainer")
	check_eq(w.state_hash(), w.state_hash(), "stable")
	var before := w.state_hash()
	EconQuery.budget_view(w)
	EconQuery.companies(w)
	EconQuery.shortages(w, 101.0)
	EconQuery.recent_econ_facts(w)
	EconQuery.commission_options(w)
	EconActions.pending(w)
	check_eq(w.state_hash(), before, "queries are read-only")
	# M5: shortage explainer lists producers with causes; commission options list their allowed budget lines
	var sh: Array = EconQuery.shortages(w, 101.0)
	check(sh.any(func(x): return x["good"] == "FOOD" and not x["producers"].is_empty() and x["producers"][0].has("causes")), "shortages: FOOD producers with causes")
	for o in EconQuery.commission_options(w):
		check(o["lines"].size() == 2 and o["lines"][1]["line"] == "ECON_BUDGET_PUBLIC_WORKS", "commission %s may use public works" % o["type"])
	check(not EconActions.apply(w, "ECON_COMMISSION_PROJECT", {"type": "ROAD", "district": "d:1", "line": "ECON_BUDGET_HEALTH"}), "commission rejects a line not allowed for the type")


## E70 (Wilma): consumption smoothing must not be a no-op when jobs are lost, and the benefit floor must reach the unemployed.
func test_e70_smoothing_and_benefit_floor_engage() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(12)
	var w := sim.world
	var with_s := 0
	var without_s := 0
	var bound := 0
	for gid in EconUtil.sorted_keys(w.table("hh")):
		var g: Dictionary = w.table("hh")[gid]
		g["income"]["wages"] = 0  # job-loss shock: income collapses, habit (built on past income) remains
		g["income"]["self"] = 0
		w.meta.erase("disc_smooth_share")
		var a := EconHouseholds.discretionary_budget(w, g)
		w.meta["disc_smooth_share"] = 0.0
		var b := EconHouseholds.discretionary_budget(w, g)
		w.meta.erase("disc_smooth_share")
		with_s += a
		without_s += b
		if a > b:
			bound += 1
	check(bound > 0, "smoothing binds for at least one group after a job-loss shock")
	check(with_s > without_s, "smoothing raises discretionary spending (%d vs %d)" % [with_s, without_s])
	# benefit floor: with the ordinary benefit rate and food assistance at 0, every group with unemployed adults
	# (counted at payment time, i.e. now) receives at least the floor share of its adults' essentials basket
	w.levers["ECON_UNEMPLOYMENT_BENEFIT_RATE"] = 0
	w.levers["ECON_FOOD_ASSISTANCE"] = 0
	var expect := {}
	for gid in EconUtil.sorted_keys(w.table("hh")):
		var g: Dictionary = w.table("hh")[gid]
		g["income"]["benefit"] = 0
		var unemp: int = maxi(0, g["lf"] - EconLabor.employed(g))
		if unemp > 0:
			var ess_pa := float(EconHouseholds.essentials_cost(w, g)) / maxf(1.0, float(EconHouseholds.adults(g)) / 1000.0)
			expect[gid] = int(0.5 * ess_pa * float(unemp) / 1000.0)
	check(expect.size() > 0, "scenario has unemployment")
	EconFinance._benefits(w)
	for gid in expect:
		check(w.table("hh")[gid]["income"]["benefit"] >= expect[gid] and expect[gid] > 0, "benefit floor reaches %s" % gid)
	w.levers["ECON_BENEFIT_FLOOR"] = 0
	var gid0: String = expect.keys()[0]
	w.table("hh")[gid0]["income"]["benefit"] = 0
	EconFinance._benefits(w)
	check_eq(w.table("hh")[gid0]["income"]["benefit"], 0, "floor 0 + rate 0 -> no benefit (lever is live)")


## E72: every commissionable type has at least one allowed budget line whose DEFAULT funds one unit per year.
func test_default_lines_fund_one_unit_per_type() -> void:
	var sim := EconSim.make_econ_only(1)
	var w := sim.world
	for ftype in EconActions.OPERATOR:
		if not EconData.BUILD.has(ftype):
			continue
		var need := EconConstruction.estimate(ftype) * 11 / 10
		var best := 0
		for ln in EconActions.lines_for(ftype):
			best = maxi(best, int(w.lever_defs[ln]["default"]) * 1000 * EconUtil.S)
		check(best >= need, "%s: best default line %d >= one unit %d" % [ftype, best, need])


## Wilma/a9: actions never fail silently. check() explains up front; an apply-time failure emits ECON_ACTION_FAILED.
func test_econ_actions_report_failures() -> void:
	var sim := EconSim.make_econ_only(2)
	sim.run(2)
	var w := sim.world
	var bad := EconActions.check(w, "ECON_COMMISSION_PROJECT", {"type": "HOUSING", "district": "d:1", "line": "ECON_BUDGET_HEALTH"})
	check(not bad["ok"] and "cannot be paid from" in String(bad["error"]), "check explains a disallowed line: %s" % bad["error"])
	var big := EconActions.check(w, "ECON_SUBSIDIZE", {"org": EconUtil.sorted_keys(w.peek("org"))[0], "amount": 999999999})
	check(not big["ok"] and "Subsidies" in String(big["error"]), "check explains missing headroom: %s" % big["error"])
	# two houses in one month on the housing line: both pass check(), the second fails when applied
	var p := {"type": "HOUSING", "district": "d:2", "line": "ECON_BUDGET_HOUSING"}
	w.levers["ECON_BUDGET_HOUSING"] = 2100
	var r1 := EconActions.enqueue(w, "ECON_COMMISSION_PROJECT", p)
	var r2 := EconActions.enqueue(w, "ECON_COMMISSION_PROJECT", {"type": "HOUSING", "district": "d:3", "line": "ECON_BUDGET_HOUSING"})
	check(r1["ok"] and r2["ok"], "both queued (%s / %s)" % [r1["error"], r2["error"]])
	sim.run(1)
	var failed := w.facts.query("ECON_ACTION_FAILED")
	check(failed.size() >= 1, "apply-time failure emits ECON_ACTION_FAILED")
	if not failed.is_empty():
		check(failed[-1]["visibility"] == "OFFICIAL" and String(failed[-1]["data"]["error"]).begins_with("Not enough budget"), "fact is official and carries the reason: %s" % failed[-1]["data"])
	check(not EconActions.last_results(w)[0]["ok"] or not EconActions.last_results(w)[1]["ok"], "action_log records the failure")
