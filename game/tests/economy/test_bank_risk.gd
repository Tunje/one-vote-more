extends TestCase
## The bank loses less, lends against deposits for secured lending and raises capital (planning/design-bank.md,
## EconBankRisk; each part opt-in: BANK_RISK, BANK_SEC, BANK_DEP, BANK_CAP, BANK_EQUITY).

var SAVE_PATH: String = TestCase.save_path("bank_risk.sav")
const S := EconUtil.S


func _sim(extra: Array) -> Simulation:
	var sim := EconSim.make_econ_only(3)
	var on: Array = ["M2", "E140", "E148", "E153"]
	on.append_array(extra)
	sim.world.meta["on"] = on
	return sim


func _private(w: WorldState) -> String:
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if o["type"] == "PRIVATE" and o["status"] == "ACTIVE" and not bool(o.get("is_contractor", false)):
			return oid
	return ""


func _builder(w: WorldState) -> String:
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if bool(o.get("is_contractor", false)) and o["status"] in ["ACTIVE", "DISTRESSED"]:
			return oid
	return ""


func test_off_leaves_the_rate_and_founders_share() -> void:
	var sim := _sim([])
	sim.run(3)
	var w := sim.world
	var oid := _private(w)
	check_eq(EconBankRisk.rate_ppm(w, oid, 5000, 100000 * S, 1000, true), 5000, "BANK_RISK off: the bank's rate unchanged")
	check_eq(EconBankRisk.founder_equity_pm(w), 400, "the founder brings 40% as before")
	check_eq(EconBankRisk.deposit_room(w), 0, "no deposit room without BANK_DEP")


func test_a_poor_record_pays_more_and_a_good_one_less() -> void:
	var sim := _sim(["BANK_RISK"])
	sim.run(6)
	var w := sim.world
	var oid := _private(w)
	if oid == "":
		check(false, "a private firm exists")
		return
	var o: Dictionary = w.table("org")[oid]
	var base := 5000
	var r0 := EconBankRisk.rate_ppm(w, oid, base, 100000 * S, 0, false)
	o["status"] = "DISTRESSED"
	var r1 := EconBankRisk.rate_ppm(w, oid, base, 100000 * S, 0, false)
	check(r1 > r0, "distress adds to the rate (%d → %d)" % [r0, r1])
	check_eq(r1 - r0, base * EconBankRisk.DISTRESS_PM / 1000, "by the distress premium")
	o["status"] = "ACTIVE"


func test_a_new_firm_pays_the_no_record_premium() -> void:
	var sim := _sim(["BANK_RISK"])
	sim.run(1)
	var w := sim.world
	var oid := _private(w)
	if oid == "":
		check(false, "a private firm exists")
		return
	var o: Dictionary = w.table("org")[oid]
	o["pl_ring"] = []
	check(EconAnnual.months(o) < EconAnnual.MIN_M, "no trading record")
	check(EconBankRisk.risk_pm(w, oid) >= EconBankRisk.NEW_PM, "the no-record premium applies")


func test_underbidding_builder_pays_for_the_risk() -> void:
	var sim := _sim(["BANK_RISK"])
	sim.run(3)
	var w := sim.world
	var bid := _builder(w)
	if bid == "":
		check(false, "a builder exists")
		return
	var o: Dictionary = w.table("org")[bid]
	var pid := EconConstruction.create(w, "FARM", "d:1", "gov", "gov", "")
	var p: Dictionary = w.table("project")[pid]
	p["status"] = "ACTIVE"
	p["contractor"] = bid
	p["price"] = int(p["est_cost"]) * 7 / 10  # 30% under the cost estimate
	o["contracts"] = [pid]
	check_eq(EconBankRisk.underbid_pm(w, o), 1000, "all of its open work is underbid")
	var r_low := EconBankRisk.risk_pm(w, bid)
	p["price"] = int(p["est_cost"]) * 12 / 10
	check_eq(EconBankRisk.underbid_pm(w, o), 0, "priced above cost: not underbid")
	check_eq(r_low - EconBankRisk.risk_pm(w, bid), EconBankRisk.UNDERBID_PM, "the underbid premium")


func test_security_lowers_the_premium() -> void:
	var sim := _sim(["BANK_RISK", "BANK_SEC"])
	sim.run(6)
	var w := sim.world
	var oid := _private(w)
	if oid == "":
		check(false, "a private firm exists")
		return
	w.table("org")[oid]["status"] = "DISTRESSED"
	var unsecured_line := EconBankRisk.rate_ppm(w, oid, 5000, 1000000000 * S, 0, false)
	var term := EconBankRisk.rate_ppm(w, oid, 5000, 100000 * S, 0, true)
	check(term < unsecured_line, "a loan secured on its plant pays less than a nearly unsecured line (%d < %d)" % [term, unsecured_line])
	check_eq(EconBankRisk.secured_pm(w, oid, 100000 * S, true), 1000, "a term loan is secured on the plant it builds")


func test_contract_payments_repay_the_builders_line_first() -> void:
	var sim := _sim(["BANK_SEC"])
	sim.run(3)
	var w := sim.world
	var bid := _builder(w)
	if bid == "":
		check(false, "a builder exists")
		return
	w.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(bid), 100000 * S, "GRANT", w.month)
	var lid := w.new_id("loan")
	w.table("loan")[lid] = {"id": lid, "borrower": bid, "principal": 50000 * S, "rate_ppm": 5000, "term_left": 0, "missed": 0, "revolving": true, "full_m": 0}
	var rep := EconBankRisk.assign(w, bid, 40000 * S)
	check_eq(rep, 40000 * S * EconBankRisk.ASSIGN_PM / 1000, "half of the payment goes to the line")
	check_eq(int(w.table("loan")[lid]["principal"]), 50000 * S - rep, "the line is reduced")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_unsold_plant_goes_with_its_debt_instead_of_being_abandoned() -> void:
	var sim := _sim(["BANK_SEC"])
	sim.run(3)
	var w := sim.world
	# a plant of a type someone else also runs, its owner in liquidation with bank debt
	var seller := ""
	var fid := ""
	for f_id in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[f_id]
		var o: Dictionary = w.table("org")[f["org"]]
		if o["type"] != "PRIVATE" or bool(o.get("is_contractor", false)):
			continue
		for f_id2 in w.table("facility"):
			var f2: Dictionary = w.table("facility")[f_id2]
			if f_id2 != f_id and f2["type"] == f["type"] and f2["org"] != f["org"] and w.table("org")[f2["org"]]["type"] in ["PRIVATE", "COOPERATIVE"]:
				seller = f["org"]
				fid = f_id
				break
		if fid != "":
			break
	if fid == "":
		check(false, "a plant type with two private owners exists")
		return
	EconFinance.new_loan(w, seller, 20000 * S, 0, false)
	var debt0 := EconFinance.debt_of(w, seller)
	var ok := EconBankRisk.secured_sale(w, seller, w.table("facility")[fid])
	check(ok, "a firm of its sector takes the plant")
	check(w.table("facility")[fid]["org"] != seller, "the plant changed hands")
	check(EconFinance.debt_of(w, seller) < debt0, "its share of the bank debt moved with it")
	check(not bool(w.table("facility")[fid].get("abandoned", false)), "not abandoned")


func test_deposits_fund_secured_lending_only() -> void:
	var sim := _sim(["BANK_SEC", "BANK_DEP"])
	sim.run(6)
	var w := sim.world
	var dr := EconBankRisk.deposit_room(w)
	check_eq(dr, maxi(0, EconBank.deposits(w) * (1000 - EconBankRisk.RESERVE_PM) / 1000 - EconBank.loans(w)), "deposits less the reserve less loans")
	EconUtil.st(w)["bank_failed"] = true
	check_eq(EconBank.room(w), 0, "a failed bank has no capital room")
	check_eq(EconBankRisk.room_secured(w), dr, "but secured lending may still use deposits")
	EconUtil.st(w)["bank_failed"] = false


func test_shares_raise_capital_and_shareholders_get_dividends() -> void:
	var sim := _sim(["BANK_CAP"])
	sim.run(3)
	var w := sim.world
	EconBank.ensure(w)
	# a loss wave: take 15 of the 16 million capital out of the bank
	w.ledger.transfer(EconUtil.BANK, Ledger.EXTERNAL, EconBank.capital(w) - 1000 * S, "TEST_LOSS", w.month)
	var need := EconBank.capital_need(w)
	check(need > 0, "below the floor: short %d" % need)
	check(not EconMoney.remit_allowed(w), "nothing goes home below the floor")
	while w.month_of_year() != 1:
		w.month += 1
	var cap0 := EconBank.capital(w)
	EconBankRisk.raise_capital(w)
	check(EconBank.capital(w) > cap0, "households bought shares: capital %d → %d" % [cap0, EconBank.capital(w)])
	check(EconBankRisk.float_pm(w) > 0, "the colony now owns part of the bank")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_home_world_recapitalisation_hook() -> void:
	var sim := _sim([])
	sim.run(3)
	var w := sim.world
	EconBank.ensure(w)
	w.ledger.transfer(EconUtil.BANK, Ledger.EXTERNAL, EconBank.capital(w) + 1000 * S, "TEST_LOSS", w.month)
	EconBank.monthly(w)
	check(bool(EconUtil.st(w).get("bank_failed", false)), "the bank failed")
	var need := EconBank.capital_need(w)
	check_eq(EconBank.recapitalise(w, need, "HOME"), need, "the home world pays what is needed")
	check(not bool(EconUtil.st(w).get("bank_failed", false)), "the bank lends again")
	check_eq(EconBank.capital_need(w), 0, "at the floor")
	check(not w.facts.query("ECON_BANK_RECAPITALISED").is_empty(), "news")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_unsecured_founders_bring_more_of_their_own() -> void:
	var sim := _sim(["BANK_EQUITY"])
	check_eq(EconBankRisk.founder_equity_pm(sim.world), EconBankRisk.EQUITY_UNSEC_PM, "without security the founder brings more")
	sim.world.meta["on"] = ["M2", "BANK_EQUITY", "BANK_SEC"]
	check_eq(EconBankRisk.founder_equity_pm(sim.world), EconBankRisk.EQUITY_PM, "with security the bank lends the usual share")


func test_runs_saves_and_loads_identically() -> void:
	var ref := _sim(["BANK_RISK", "BANK_SEC", "BANK_DEP", "BANK_CAP", "BANK_EQUITY"])
	ref.run(14)
	check_eq(SaveIO.save(ref, SAVE_PATH), OK, "save")
	ref.run(10)
	var loaded := EconSim.econ_only_for_load()
	check_eq(SaveIO.load_into(loaded, SAVE_PATH), OK, "load")
	loaded.run(10)
	check_eq(loaded.world.state_hash(), ref.world.state_hash(), "continued state hash with every bank part on")
	check_eq(ref.world.ledger.total(), 0, "ledger closed")
