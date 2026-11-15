extends TestCase
## E160 / E162 family farms and bakeries (EconFamily, opt-in): off by default; grant programmes open and end; grant
## loans are repaid from the surplus and default only after LOAN_DEFAULT_M months with nothing paid; runs close.


func test_off_by_default() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(12)
	var w := sim.world
	for oid in w.table("org"):
		check(not bool(w.table("org")[oid].get("family", false)), "no family firms when off")
	check(not EconUtil.st(w).has("lever_need"), "no need signal when off")
	check(not EconUtil.st(w).has("fam_prog"), "no programmes when off")


func test_programme_opens_and_ends() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E160"]
	sim.run(2)
	w.levers["ECON_FAMILY_FARM_GRANT"] = 50
	sim.run(1)
	check(EconFamily.prog_open(w, "FAMFARM"), "raising the grant from 0 opens a programme")
	var n_end := w.facts.query("ECON_GRANT_PROGRAMME_ENDED").size()
	sim.run(EconFamily.PROG_M + 1)
	check(not EconFamily.prog_open(w, "FAMFARM"), "the window closes after PROG_M months")
	check_eq(int(w.levers["ECON_FAMILY_FARM_GRANT"]), 0, "the lever goes back to 0 by itself")
	check_eq(w.facts.query("ECON_GRANT_PROGRAMME_ENDED").size(), n_end + 1, "a public fact reports the programme")
	check_eq(w.ledger.total(), 0, "ledger closed")


func _family_firm(w: WorldState) -> String:
	var gid: String = EconUtil.sorted_keys(w.table("hh"))[0]
	var id := w.new_id("org")
	w.table("org")[id] = {"id": id, "key": "FAM_" + id, "name": "Test & Family", "type": "PRIVATE", "hq": "d:1", "status": "ACTIVE",
		"ceo": {"mgmt": 45, "risk": 25, "age_m": 456}, "reliability": 0, "is_contractor": false, "crew": {}, "crew_target": {},
		"premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0, "pl": EconFinance.empty_pl(), "pl_last": {},
		"missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0, "admin_months": 0, "liq_months": 0,
		"missed_this_month": false, "owner_group": gid, "sales_ema": {}, "contracts": [], "dividends_ytd": 0, "sold": {},
		"family": true, "family_type": "FAMFARM"}
	w.ledger.open_account(EconUtil.acct(id))
	EconFinance.new_loan(w, id, 20000 * EconUtil.S, 0, true)
	for lid in w.table("loan"):
		if w.table("loan")[lid]["borrower"] == id:
			w.table("loan")[lid]["family"] = true
			w.table("loan")[lid]["zero_m"] = 0
			w.table("loan")[lid]["term_left"] = EconFamily.LOAN_TERM_M
	return id


func test_grant_loan_paid_from_surplus() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E160"]
	sim.run(2)
	var oid := _family_firm(w)
	var debt0 := EconFinance.debt_of(w, oid)
	EconFamily.service_loans(w)
	check(EconFinance.debt_of(w, oid) < debt0, "a surplus pays the loan down")
	# no surplus: nothing paid, interest added, no default before LOAN_DEFAULT_M months
	var acc := EconUtil.acct(oid)
	w.ledger.transfer(acc, Ledger.EXTERNAL, w.ledger.balance(acc), "TEST", w.month)
	for i in EconFamily.LOAN_DEFAULT_M - 1:
		EconFamily.service_loans(w)
	check_eq(w.table("org")[oid]["status"], "ACTIVE", "a bad stretch pays less, it is not a default")
	EconFamily.service_loans(w)
	check(w.table("org")[oid]["status"] != "ACTIVE", "12 months with nothing paid: the family has to sell")


func test_run_closes() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.world.meta["on"] = ["E146", "E160", "E162"]
	sim.world.levers["ECON_FAMILY_FARM_GRANT"] = 50
	sim.run(36)
	check_eq(sim.world.ledger.total(), 0, "ledger closed")
	check(EconPop.check(sim.world).is_empty(), "jobs equal people")


func test_hardship_and_idleness_lower_what_a_family_asks() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E160"]
	sim.run(6)
	var s := EconUtil.st(w)
	var d := "d:1"
	s["fam_sf_hist"] = [0]
	s["food_shortfall"] = 0
	s["food_scarce_d"] = {}
	s["food_unaff_d"] = {}
	var calm := EconFamily.found_mark(w, d)
	check(calm <= EconFamily.FOUND_MARK and calm >= EconFamily.FOUND_FLOOR, "within its bounds (%.2f)" % calm)
	s["food_scarce_d"] = {d: 200}
	check(is_equal_approx(EconFamily.hardship(w, d), 1.0), "a district going without a fifth of its food: full hardship")
	check(EconFamily.found_mark(w, d) < calm - 0.3, "their own farm looks like a way out")
	s["food_scarce_d"] = {}
	var idle := EconFamily.idleness(w, d)
	check(idle >= 0.0 and idle <= 1.0, "idleness is a share (%.2f)" % idle)
	check(is_equal_approx(EconFamily.found_mark(w, d), maxf(EconFamily.FOUND_FLOOR, EconFamily.FOUND_MARK - EconFamily.HOPE_W * EconFamily.hardship(w, d) - EconFamily.IDLE_W * idle)), "unemployment counts against the missing profit")


func test_a_failed_grant_firm_is_news_once() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E160"]
	sim.run(2)
	var id := w.new_id("org")
	w.table("org")[id] = {"id": id, "family": true, "family_type": "FAMFARM", "hq": "d:2", "status": "LIQUIDATION", "grant_paid": 5000000, "grant_month": w.month - 6}
	EconFamily._failed_grantees(w)
	EconFamily._failed_grantees(w)
	var f: Array = w.facts.query("ECON_GRANT_FIRM_FAILED")
	check_eq(f.size(), 1, "reported once")
	if f.size() == 1:
		check(int(f[0]["impact"]["GOVERNANCE"]) < 0, "it reflects on the government")
		check_eq(int(f[0]["data"]["months_since_grant"]), 6, "it says how fresh the grant was")
	w.table("org").erase(id)


func test_a_family_counts_its_own_costs_not_a_companys() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E160"]
	sim.run(6)
	var company := FirmAI.unit_cost(w, "FAMFARM")
	var family := EconFamily.family_unit_cost(w, "FAMFARM", 0)
	check(family < company, "a family that pays itself no wages has a lower cost (%.0f against %.0f)" % [family, company])
	var granted := EconFamily.family_unit_cost(w, "FAMFARM", 80)
	check(granted < family, "a grant for most of the building lowers what is left to recover (%.0f)" % granted)
	check(EconFamily.family_unit_cost(w, "FAMFARM", 100) < granted, "a full grant leaves no building cost")
	check(EconFamily.family_unit_cost(w, "FAMFARM", 100) > 0.0, "inputs and upkeep still cost")
	var s := EconUtil.st(w)
	var notes: Dictionary = (s.get("fam_fail_found", {}) as Dictionary).duplicate(true)
	var h := w.state_hash()
	EconFamily._grant_pct(w, "FAMFARM", "d:1", true)
	check_eq(w.state_hash(), h, "asking what the grant would be changes nothing")
	check_eq(s.get("fam_fail_found", {}), notes, "and notes nothing")


func test_a_family_farms_where_the_land_is() -> void:
	var sim: Simulation = preload("res://sim/economy/econ_sim.gd").make(2, "BALANCED", {}, true)
	sim.run(12)
	var w := sim.world
	var anchors: Dictionary = ColonyLayout.econ_anchors(w)
	var site := EconFamily.farm_site(w, "d:1")
	check(EconData.DISTRICTS.has(site) and EconUtil.connected(site), "a connected district (%s)" % site)
	var land := {}
	for d in anchors:
		land[d] = ColonyLayout.count_near(w, ColonyLayout.as_tile(anchors[d]), ColonyLayout.FAC_TERRAIN["FARM"], EconFamily.SITE_REACH)
	check(int(land.get(site, 0)) > 0, "with farmland around it (%s)" % str(land))
	var h := w.state_hash()
	EconFamily.farm_site(w, "d:1")
	check_eq(w.state_hash(), h, "asking changes nothing")
	# every plot taken everywhere: the family stays home
	var fac: Dictionary = w.table("facility")
	var n := 0
	for d in EconData.DISTRICTS:
		for i in 60:
			n += 1
			fac["test:farm:%d" % n] = {"type": "FARM", "district": d, "org": "", "mothball": false}
	check_eq(EconFamily.farm_site(w, "d:1"), "d:1", "no free land anywhere: its own district")
	for i in n:
		fac.erase("test:farm:%d" % (i + 1))
