extends TestCase
## R8 step 4 (EconBuilders, opt-in R8 + R8_BUILDERS): builders under the eight rules: margin, refusable quotes, crews to
## the book, entry, public builders.

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


func _owner(w: WorldState) -> String:
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if o["type"] == "PRIVATE" and not bool(o.get("is_contractor", false)) and o["status"] == "ACTIVE":
			return oid
	return ""


func _bid(p: Dictionary, oid: String, price: int, wait: int = 0) -> void:
	p["bids"] = [{"org": oid, "price": price, "duration": 12, "reliability": 50, "wait": wait}]


func test_switch_alone_changes_nothing() -> void:
	var a := EconSim.make_econ_only(3)
	var b := EconSim.make_econ_only(3)
	b.world.meta["on"] = ["R8_BUILDERS"]  # without R8 the sector is off
	a.run(24)
	b.run(24)
	var sa := EconUtil.st(a.world)
	var sb := EconUtil.st(b.world)
	for g in EconUtil.sorted_keys(sa["prices"]):
		check_eq(int(sb["prices"][g]), int(sa["prices"][g]), "same price for %s" % g)
	for acct in [EconUtil.TREASURY, EconUtil.BANK]:
		check_eq(b.world.ledger.balance(acct), a.world.ledger.balance(acct), "same balance for %s" % acct)
	check_eq(PopStore.total(b.world), PopStore.total(a.world), "same population")
	for oid in b.world.table("org"):
		check(not b.world.table("org")[oid].has("r8b"), "no builder state while off")


func test_margin_steps() -> void:
	var w := _sim(["R8", "R8_BUILDERS"]).world
	var oid := _builder(w)
	var o: Dictionary = w.table("org")[oid]
	w.month = (w.month / 3 + 1) * 3
	for pid in o["contracts"].duplicate():
		o["contracts"].erase(pid)  # no jobs in hand: job_margin 0
	var m0 := int(EconBuilders._r(o)["margin"])
	o["r8b"]["log"] = {str(w.month - 1): [5, 4]}  # wins 80% of its bids
	EconBuilders.step_margins(w)
	check_eq(int(o["r8b"]["margin"]), m0 + EconBuilders.STEP_PM, "rule 1: a builder winning most bids raises its margin")
	o["r8b"]["log"] = {}
	o["r8b"]["wait_m"] = w.month - 1
	o["r8b"]["wait_w"] = 30
	EconBuilders.step_margins(w)
	check_eq(int(o["r8b"]["margin"]), m0 + 2 * EconBuilders.STEP_PM, "rule 1: turned down for its wait, it raises its margin")
	o["r8b"]["refused_m"] = w.month - 1
	EconBuilders.step_margins(w)
	check_eq(int(o["r8b"]["margin"]), m0 + EconBuilders.STEP_PM, "rule 2: a quote refused on price lowers it")
	o["r8b"]["refused_m"] = -999
	o["r8b"]["wait_m"] = -999
	o["r8b"]["log"] = {str(w.month - 1): [10, 1]}  # wins 10%
	EconBuilders.step_margins(w)
	check_eq(int(o["r8b"]["margin"]), m0, "rule 2: a builder losing its bids lowers its margin")
	o["r8b"]["margin"] = 0
	EconBuilders.step_margins(w)
	check_eq(int(o["r8b"]["margin"]), 0, "never below zero: no bid below cost")
	o["r8b"]["margin"] = 1000
	o["r8b"]["log"] = {str(w.month - 1): [5, 5]}
	EconBuilders.step_margins(w)
	check_eq(int(o["r8b"]["margin"]), 1000 + EconBuilders.STEP_PM, "no ceiling of ours: only the clients' refusals stop it")


func test_private_refusal_reopens_and_waits() -> void:
	var w := _sim(["R8", "R8_BUILDERS"]).world
	var bid := _builder(w)
	var own := _owner(w)
	var pid := EconConstruction.create(w, "TEXTILE", "d:1", own, own, "")
	var p: Dictionary = w.table("project")[pid]
	var est := EconBuilders.owner_estimate(w, p)
	_bid(p, bid, est * 3)
	EconBuilders.award_round(w)
	check_eq(p["status"], "TENDER", "refused, the tender stays open")
	check(p["bids"].is_empty(), "the quotes are dropped")
	check_eq(int(p["reopen_m"]), w.month + EconBuilders.QUOTE_REOPEN_M, "it reopens later")
	check_eq(int(EconUtil.st(w)["r8b_stats"]["refused_priv_price"]), 1, "counted as a private price refusal")
	check_eq(int(w.table("org")[bid]["r8b"]["refused_m"]), w.month, "the builder knows it was refused")
	EconConstruction.bid_round(w)
	check(p["bids"].is_empty(), "no new bids before it reopens")
	_bid(p, bid, est)
	EconBuilders.award_round(w)
	check_eq(p["status"], "ACTIVE", "a fair price is accepted")
	_bid(p, bid, est)
	var pid2 := EconConstruction.create(w, "TEXTILE", "d:1", own, own, "")
	_bid(w.table("project")[pid2], bid, est / 2, 400)
	EconBuilders.award_round(w)
	check_eq(w.table("project")[pid2]["status"], "TENDER", "a start far beyond the owner's horizon is refused")
	check_eq(int(EconUtil.st(w)["r8b_stats"]["refused_priv_wait"]), 1, "counted as a wait refusal")
	check_eq(EconBuilders.wait_refused(w, w.table("org")[bid]), 400, "the builder knows the wait it was refused for")


func test_refused_plan_is_not_cancelled() -> void:
	var w := _sim(["R8", "R8_BUILDERS", "E165", "E165Q"]).world
	var bid := _builder(w)
	var id := w.new_id("org")
	w.table("org")[id] = {"id": id, "key": "NEW_" + id, "name": "Plan Ltd", "type": "PRIVATE", "hq": "d:1", "status": "FORMING",
		"ceo": {"mgmt": 50, "risk": 50, "age_m": 480}, "reliability": 0, "is_contractor": false, "crew": {}, "crew_target": {},
		"premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0, "pl": EconFinance.empty_pl(), "pl_last": {},
		"missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0, "admin_months": 0, "liq_months": 0,
		"missed_this_month": false, "owner_group": "", "sales_ema": {}, "contracts": [], "dividends_ytd": 0, "sold": {},
		"entry_type": "TEXTILE", "planned_month": w.month}
	w.ledger.open_account(EconUtil.acct(id))
	var pid := EconConstruction.create(w, "TEXTILE", "d:1", id, id, "")
	var p: Dictionary = w.table("project")[pid]
	_bid(p, bid, EconBuilders.owner_estimate(w, p) * 3)
	EconBuilders.award_round(w)
	check_eq(w.table("org")[id]["status"], "FORMING", "the plan waits after a refusal")
	check_eq(p["status"], "TENDER", "its tender is open again")


func test_government_refusal_is_a_fact() -> void:
	var w := _sim(["R8", "R8_BUILDERS"]).world
	var bid := _builder(w)
	w.levers["ECON_BUDGET_INFRASTRUCTURE"] = 0  # no headroom on the line
	var pid := EconConstruction.create(w, "CLINIC", "d:1", "gov", "gov", "ECON_BUDGET_INFRASTRUCTURE")
	var p: Dictionary = w.table("project")[pid]
	var n0 := w.facts.query("ECON_PUBLIC_QUOTE_REFUSED").size()
	_bid(p, bid, int(p["est_cost"]) * 2)
	EconBuilders.award_round(w)
	check_eq(p["status"], "TENDER", "the government refuses an overrun its line can't pay")
	var facts: Array = w.facts.query("ECON_PUBLIC_QUOTE_REFUSED")
	check_eq(facts.size(), n0 + 1, "a public fact")
	var d: Dictionary = facts[-1]["data"]
	check(d.has("price") and d.has("estimate") and d.has("line") and d.has("headroom"), "with price, estimate, line, headroom")
	check_eq(String(d["reason"]), "budget", "reason: budget")
	_bid(p, bid, int(p["est_cost"]))
	EconBuilders.award_round(w)
	check_eq(p["status"], "ACTIVE", "a bid within the estimate is accepted")


func test_crews_follow_the_work() -> void:
	var w := _sim(["R8", "R8_BUILDERS"]).world
	var oid := _builder(w)
	var o: Dictionary = w.table("org")[oid]
	EconBuilders._r(o)
	var t := EconBuilders.crew_target(w, oid, o, 500.0, 40.0, 30.0, false)
	check_eq(t, 500.0, "rule 5: crews to the work due, no founding-crew multiple and no monthly cap (%f)" % t)
	t = EconBuilders.crew_target(w, oid, o, 0.0, 40.0, 30.0, false)
	check_eq(t, 0.0, "rule 6: no work due and no refusals: no crew kept of ours")
	o["r8b"]["fill"] = {"m": w.month, "MATERIAL": [100 * S, 40 * S]}
	t = EconBuilders.crew_target(w, oid, o, 500.0, 40.0, 30.0, true)
	check_eq(t, 200.0, "rule 6: the crew is what its material supports (40% filled)")
	o["r8b"]["fill"] = {}
	o["r8b"]["floor"] = 25
	t = EconBuilders.crew_target(w, oid, o, 0.0, 40.0, 30.0, false)
	check_eq(t, 25.0, "a crew ordered by the government is kept")


func test_wait_refusal_grows_the_crew() -> void:
	var w := _sim(["R8", "R8_BUILDERS"]).world
	var oid := _builder(w)
	var o: Dictionary = w.table("org")[oid]
	EconBuilders._r(o)
	var own := _owner(w)
	for pid in o["contracts"].duplicate():
		o["contracts"].erase(pid)
	var pid := EconConstruction.create(w, "TEXTILE", "d:1", own, own, "")
	var p: Dictionary = w.table("project")[pid]
	_bid(p, oid, EconBuilders.owner_estimate(w, p), 0)
	EconBuilders.award_round(w)
	check_eq(p["status"], "ACTIVE", "awarded")
	p["start_month"] = w.month + 20  # queued far ahead: not due now
	var pid2 := EconConstruction.create(w, "TEXTILE", "d:1", own, own, "")
	_bid(w.table("project")[pid2], oid, EconBuilders.owner_estimate(w, p), 400)
	EconBuilders.award_round(w)
	check_eq(EconBuilders.wait_refused(w, o), 400, "the refused wait is the builder's signal")
	o["r8b"]["wait_w"] = 10
	check(EconBuilders.job_margin(w, oid) >= 0, "its job pays at today's costs")
	var t := EconBuilders.crew_target(w, oid, o, 0.0, 0.0, 30.0, false)
	var bk := EconBuilders.book(w, o)
	var per := 0.9 + 0.002 * float(o["ceo"]["mgmt"])
	check(absf(t - float(int(bk[0]) + int(bk[1])) / float(S) / per / 10.0) < 0.01, "rule 5: crews to clear the book within the refused wait (%f)" % t)
	p["price"] = 1  # the job now loses money
	check(EconBuilders.job_margin(w, oid) < 0, "a job at a loss")
	check_eq(EconBuilders.crew_target(w, oid, o, 0.0, 0.0, 30.0, false), 0.0, "no growth on jobs that lose at today's costs")


func test_fill_and_quotes() -> void:
	var w := _sim(["R8", "R8_BUILDERS"]).world
	var oid := _builder(w)
	var o: Dictionary = w.table("org")[oid]
	check_eq(EconBuilders.fill_pm(o), 1000, "nothing ordered: nothing refused it")
	EconBuilders.note_fill(w, oid, "MATERIAL", 100 * S, 30 * S)
	EconBuilders.note_fill(w, oid, "MATERIAL", 100 * S, 70 * S)
	check_eq(EconBuilders.fill_pm(o), 500, "half its material")
	EconBuilders.note_fill(w, oid, "COMPONENT", 10 * S, 0)
	check_eq(EconBuilders.fill_pm(o), 500, "no components: half the work at most (as _progress_fill)")
	w.month += 1
	EconBuilders.note_fill(w, oid, "MATERIAL", 10 * S, 10 * S)
	check_eq(EconBuilders.fill_pm(o), 1000, "a new month starts a new count")


func test_entry_rules_7_8() -> void:
	var w := _sim(["R8", "R8_BUILDERS"]).world
	var sg := {"builders": {}, "colony": {"private_cap": 100 * S, "unbuilt_wu": 0, "fill_pm": 1000, "job_margin": 1, "spare_wu": 0}}
	check_eq(EconBuilders.entry_reason(w, sg), "no_waiting_work", "rule 8: no work waits for a builder")
	sg["colony"]["unbuilt_wu"] = 500 * S
	sg["colony"]["fill_pm"] = 600
	check_eq(EconBuilders.entry_reason(w, sg), "no_material", "rule 8: builders can't get their material")
	sg["colony"]["fill_pm"] = 1000
	sg["colony"]["job_margin"] = -1
	check_eq(EconBuilders.entry_reason(w, sg), "work_loses", "rule 8: the work loses at today's costs")
	sg["colony"]["job_margin"] = 1
	sg["colony"]["spare_wu"] = 999999 * S
	check_eq(EconBuilders.entry_reason(w, sg), "incumbents_spare", "rule 8: incumbents' crews can start it within the wait")
	sg["builders"] = {"x": {"wait_refused": 20}}
	check_eq(EconBuilders.entry_reason(w, sg), "", "rule 7: clients turned quotes down for the wait: a new builder")
	sg["builders"] = {}
	sg["colony"]["spare_wu"] = 0
	check_eq(EconBuilders.entry_reason(w, sg), "", "rule 7: unbuilt work beyond the incumbents' spare crews")


func test_public_builder_found_and_enlarge() -> void:
	var w := _sim(["R8", "R8_BUILDERS"]).world
	var t0 := w.ledger.balance(EconUtil.TREASURY)
	var id := EconBuilders.found_public_builder(w, "d:2")
	check(id != "", "founded")
	var o: Dictionary = w.table("org")[id]
	check(o["type"] == "PUBLIC_ENTERPRISE" and bool(o["is_contractor"]), "a public builder")
	check_eq(w.ledger.balance(EconUtil.acct(id)), EconData.BUILDER_EQUITY * S, "capital from the treasury")
	check(w.ledger.balance(EconUtil.TREASURY) < t0 or EconFinance.debt_of(w, "gov") > 0, "the treasury paid")
	check(EconBuilders.enlarge_public_builder(w, id, 60), "enlarged")
	check_eq(int(o["r8b"]["floor"]), 60, "the ordered crew is its floor")
	var pid := EconConstruction.create(w, "SERVICEHUB", "d:2", "gov", "gov", "ECON_BUDGET_INFRASTRUCTURE")  # small enough for a new crew
	EconConstruction.bid_round(w)
	var bidders: Array = []
	for b in w.table("project")[pid]["bids"]:
		bidders.append(b["org"])
	check(id in bidders, "a public builder bids on public work from the first round")
	w.meta["on"] = []
	check_eq(EconBuilders.found_public_builder(w, "d:2"), "", "off: no action")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_lever_hidden_without_flag() -> void:
	var found := false
	for d in EconPic.levers():
		if d["id"] == EconBuilders.LEVER_AT_COST:
			found = true
			check_eq(d["requires"], ["R8_BUILDERS"], "the lever needs the flag")
	check(found, "the lever is defined")


func test_run_closes() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.world.meta["on"] = ["R8", "R8_BUILDERS"]
	sim.run(36)
	var w := sim.world
	check_eq(w.ledger.total(), 0, "ledger closed")
	check(EconPop.check(w).is_empty(), "jobs equal people")
	var sg: Dictionary = EconUtil.st(w)["r8"]["builders"]
	check(not (sg["builders"] as Dictionary).is_empty(), "builders measured")
	check(sg["colony"].has("job_margin") and sg["colony"].has("fill_pm") and sg["colony"].has("unbuilt_wu"), "colony row")
	check(EconConstruction.quoted_wait(w, "FARM", "d:1") >= 0, "a quoted wait")
	for oid in w.table("org"):
		var o: Dictionary = w.table("org")[oid]
		if o.has("r8b"):
			check(int(o["r8b"]["margin"]) >= 0, "margin never below cost")
