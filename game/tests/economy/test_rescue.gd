extends TestCase
## E166 part 1 (EconPlanRescue + EconShares, opt-in on top of E165): plans in trouble sell a stake, get the bank's
## help or the state's, or are withdrawn; the share register splits dividends.

const S := EconUtil.S


func _sim(on: Array) -> Simulation:
	var sim := EconSim.make_econ_only(3)
	sim.run(3)
	sim.world.meta["on"] = on
	return sim


func _builder(w: WorldState) -> String:
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if bool(o.get("is_contractor", false)) and o["status"] in ["ACTIVE", "DISTRESSED"]:
			return oid
	return ""


## A plan building `ftype`, started, with `cash` and a contract price of `price` of which nothing is paid yet.
func _plan(w: WorldState, ftype: String, cash: int, price: int) -> String:
	var id := w.new_id("org")
	var gid: String = EconUtil.sorted_keys(w.table("hh"))[0]
	w.table("org")[id] = {"id": id, "key": "NEW_" + id, "name": "Plan Ltd", "type": "PRIVATE", "hq": "d:1", "status": "FORMING",
		"ceo": {"mgmt": 50, "risk": 50, "age_m": 480}, "reliability": 0, "is_contractor": false, "crew": {}, "crew_target": {},
		"premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0, "pl": EconFinance.empty_pl(), "pl_last": {},
		"missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0, "admin_months": 0, "liq_months": 0,
		"missed_this_month": false, "owner_group": gid, "sales_ema": {}, "contracts": [], "dividends_ytd": 0, "sold": {},
		"entry_type": ftype, "planned_month": w.month}
	w.ledger.open_account(EconUtil.acct(id))
	if cash > 0:
		w.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(id), cash, "TEST", w.month)
	var pid := EconConstruction.create(w, ftype, "d:1", id, id, "")
	var p: Dictionary = w.table("project")[pid]
	var b := _builder(w)
	p["status"] = "ACTIVE"
	p["contractor"] = b
	p["start_month"] = w.month - 1
	p["bid_duration"] = 12
	p["price"] = price
	p["paid"] = 0
	w.table("org")[b]["contracts"].append(pid)
	return id


func _rich_household(w: WorldState, amount: int) -> String:
	for gid in EconUtil.sorted_keys(w.table("hh")):
		if String(w.table("hh")[gid].get("band", "")) in ["I3", "I4", "I5"]:
			w.ledger.transfer(Ledger.EXTERNAL, EconUtil.hh_acct(gid), amount, "TEST", w.month)
			return gid
	return ""


func _drain_households(w: WorldState) -> void:
	for gid in w.table("hh"):
		var b := w.ledger.balance(EconUtil.hh_acct(gid))
		if b > 0:
			w.ledger.transfer(EconUtil.hh_acct(gid), Ledger.EXTERNAL, b, "TEST", w.month)


func test_register() -> void:
	var o := {"owner_group": "g1"}
	check_eq(EconShares.outside_pm(o), 0, "no register: all the founder's")
	check_eq(EconShares.add_stake(o, "hh:g2", 300), 300, "a 30% stake")
	check_eq(EconShares.add_stake(o, "bank", 400), 190, "outside holders capped at 49%")
	check_eq(EconShares.held_pm(o, "hh:g1"), 510, "the founder keeps the majority")
	var o2 := {"owner_group": "g1"}
	check_eq(EconShares.add_stake(o2, "bank", 400), EconShares.BANK_STAKE_CAP_PM, "the bank's stake is capped at 30%")


func test_dividends_split() -> void:
	var w := _sim([]).world
	var oid := ""
	for k in EconUtil.sorted_keys(w.table("org")):
		if w.table("org")[k]["type"] == "PRIVATE" and String(w.table("org")[k].get("owner_group", "")) != "":
			oid = k
			break
	var o: Dictionary = w.table("org")[oid]
	w.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(oid), 1000 * S, "TEST", w.month)
	check_eq(EconShares.pay_others(w, oid, 1000 * S), 1000 * S, "no register: nothing moves")
	EconShares.add_stake(o, "gov", 250)
	var t0 := w.ledger.balance(EconUtil.TREASURY)
	var rest := EconShares.pay_others(w, oid, 1000 * S)
	check_eq(rest, 750 * S, "the founder's part")
	check_eq(w.ledger.balance(EconUtil.TREASURY) - t0, 250 * S, "the state's 25%")


func test_off_no_windows() -> void:
	var w := _sim(["E165"]).world
	var oid := _plan(w, "SERVICEHUB", 0, 100000 * S)
	EconInsolvency.check_all(w)
	check(not w.table("org")[oid].has("rescue"), "flag off: no rescue window")


func test_stake_rescue() -> void:
	var w := _sim(["E165", "E166"]).world
	var big := _plan(w, "SERVICEHUB", 1000 * S, 40000 * S)  # a gap far above what a minority stake in it is worth
	var oid := _plan(w, "SERVICEHUB", 30000 * S, 40000 * S)
	_rich_household(w, 10000000 * S)
	EconPlanRescue.monthly(w)
	var ob: Dictionary = w.table("org")[big]
	check(ob.has("rescue") and EconShares.outside_pm(ob) == EconShares.OUTSIDE_MAX_PM, "a partial stake, capped at 49%: the window stays open")
	var o: Dictionary = w.table("org")[oid]
	check(not o.has("rescue"), "the window closed")
	check(String(o.get("rescued", {}).get("kind", "")).begins_with("shares_"), "saved by a stake")
	check(EconShares.outside_pm(o) > 0 and EconShares.outside_pm(o) <= EconShares.OUTSIDE_MAX_PM, "a minority stake")
	check(w.ledger.balance(EconUtil.acct(oid)) >= 40000 * S, "the money it lacked arrived")
	check_eq(w.facts.query("COMP_STAKE_SOLD").size(), 2, "public facts")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_no_rescue_withdraws() -> void:
	var w := _sim(["E165", "E166"]).world
	_drain_households(w)
	var oid := _plan(w, "SERVICEHUB", 0, 1000000000 * S)  # beyond any buyer and the bank
	for i in EconPlanRescue.RESCUE_M + 1:
		EconPlanRescue.monthly(w)
		w.month += 1
	var o: Dictionary = w.table("org")[oid]
	check_eq(o["status"], "DISSOLVED", "withdrawn after the window")
	check_eq(int(EconUtil.st(w)["plan_stats"].get("abandoned_no_rescue", 0)), 1, "cause no_rescue")
	check_eq(int(EconUtil.st(w)["rescue_stats"]["failed"]), 1, "counted")


func test_bank_grace_from_opening() -> void:
	var w := _sim(["E165", "E166"]).world
	_drain_households(w)
	var oid := _plan(w, "SERVICEHUB", 0, 5000 * S)
	EconFinance.new_loan(w, oid, 1000 * S, 0, false)
	var o: Dictionary = w.table("org")[oid]
	o["rescue"] = {"since": w.month - 1, "shortfall": EconPlanRescue.shortfall(w, oid), "tried": ["shares"]}
	EconPlanRescue._bank(w, oid, o, "SERVICEHUB")
	var any_grace := false
	for lid in w.table("loan"):
		var l: Dictionary = w.table("loan")[lid]
		if l["borrower"] == oid:
			any_grace = any_grace or l.has("grace_after_open")
	check(any_grace, "interest-only months promised from the opening")
	EconPlanRescue.on_open(w, oid)
	for lid in w.table("loan"):
		var l: Dictionary = w.table("loan")[lid]
		if l["borrower"] == oid and l.has("ext_given"):
			check(int(l.get("grace_until", -1)) >= w.month + EconPlanRescue.EXT_M - 1 or int(l["principal"]) == 0, "grace set at opening")


func test_government_rescue() -> void:
	var w := _sim(["E165", "E166"]).world
	var oid := _plan(w, "FARM", 0, 20000 * S)
	var o: Dictionary = w.table("org")[oid]
	o["rescue"] = {"since": w.month, "shortfall": EconPlanRescue.shortfall(w, oid), "tried": ["shares"]}
	check(EconActions.validate(w, "ECON_RESCUE_PLAN", {"org": oid, "form": "LOAN", "amount": 20000}) != "", "not before the bank was tried")
	o["rescue"]["tried"] = ["shares", "bank"]
	check_eq(EconActions.validate(w, "ECON_RESCUE_PLAN", {"org": oid, "form": "LOAN", "amount": 20000}), "", "a needed plant may be rescued")
	check(EconActions.apply(w, "ECON_RESCUE_PLAN", {"org": oid, "form": "LOAN", "amount": 20000}), "applied")
	check(o.has("gov_loan") and int(o["gov_loan"]["principal"]) > 0, "the state's loan is on the firm")
	check(not o.has("rescue"), "saved")
	check_eq(w.facts.query("ECON_PLAN_BAILOUT").size(), 1, "a public bailout fact")
	# after opening and the grace, it repays the treasury
	o["status"] = "ACTIVE"
	EconPlanRescue.on_open(w, oid)
	w.month += EconPlanRescue.EXT_M
	w.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(oid), 100000 * S, "TEST", w.month)
	var t0 := w.ledger.balance(EconUtil.TREASURY)
	EconPlanRescue._gov_loans(w)
	check(w.ledger.balance(EconUtil.TREASURY) > t0, "the loan is repaid to the treasury")
	var p2 := _plan(w, "TEXTILE", 0, 20000 * S)
	w.table("org")[p2]["rescue"] = {"since": w.month, "shortfall": 20000 * S, "tried": ["shares", "bank"]}
	check(EconActions.validate(w, "ECON_RESCUE_PLAN", {"org": p2, "form": "STAKE", "amount": 20000}) != "" or EconPlanRescue.needed(w, "TEXTILE"),
		"a plant the colony doesn't need gets no bailout")


func test_run_closes() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.world.meta["on"] = ["E165", "E165B", "E166", "E169"]
	sim.run(36)
	check_eq(sim.world.ledger.total(), 0, "ledger closed")
	check(EconPop.check(sim.world).is_empty(), "jobs equal people")
