extends TestCase
## E169 (EconUnfinished, opt-in): half-built buildings are left behind, taken over for the same use or repurposed,
## paid to their holder (the bank first), and decay unsold.

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


func _org(w: WorldState, status: String, cash: int) -> String:
	var id := w.new_id("org")
	var gid: String = EconUtil.sorted_keys(w.table("hh"))[0]
	w.table("org")[id] = {"id": id, "key": "NEW_" + id, "name": "Test Ltd", "type": "PRIVATE", "hq": "d:1", "status": status,
		"ceo": {"mgmt": 50, "risk": 50, "age_m": 480}, "reliability": 0, "is_contractor": false, "crew": {}, "crew_target": {},
		"premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0, "pl": EconFinance.empty_pl(), "pl_last": {},
		"missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0, "admin_months": 0, "liq_months": 0,
		"missed_this_month": false, "owner_group": gid, "sales_ema": {}, "contracts": [], "dividends_ytd": 0, "sold": {},
		"entry_type": "TEXTILE", "planned_month": w.month}
	w.ledger.open_account(EconUtil.acct(id))
	if cash > 0:
		w.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(id), cash, "TEST", w.month)
	return id


## A project of `ftype` for `owner`, half built and half paid.
func _half_built(w: WorldState, owner: String, ftype: String) -> Dictionary:
	var pid := EconConstruction.create(w, ftype, "d:1", owner, owner, "ECON_BUDGET_INFRASTRUCTURE" if owner == "gov" else "")
	var p: Dictionary = w.table("project")[pid]
	var b := _builder(w)
	p["status"] = "ACTIVE"
	p["contractor"] = b
	p["start_month"] = w.month - 6
	p["bid_duration"] = 12
	p["price"] = int(p["est_cost"])
	p["paid"] = int(p["est_cost"]) / 2
	p["wu_done"] = int(p["wu_total"]) / 2
	w.table("org")[b]["contracts"].append(pid)
	return p


func test_off_leaves_nothing() -> void:
	var w := _sim(["E165"]).world
	var oid := _org(w, "FORMING", 10000 * S)
	_half_built(w, oid, "TEXTILE")
	EconInsolvency.abandon_plan(w, oid, "limit")
	check(w.peek("unfinished").is_empty(), "flag off: an abandoned plan's work is lost as before")


func test_abandoned_plan_leaves_a_shell_held_by_the_bank() -> void:
	var w := _sim(["E165", "E169"]).world
	var oid := _org(w, "FORMING", 0)
	EconFinance.new_loan(w, oid, 30000 * S, 0, true)
	var p := _half_built(w, oid, "TEXTILE")
	w.ledger.transfer(EconUtil.acct(oid), Ledger.EXTERNAL, w.ledger.balance(EconUtil.acct(oid)), "TEST", w.month)  # spent on the build
	var b: String = p["contractor"]
	EconInsolvency.abandon_plan(w, oid, "limit")
	var t := w.peek("unfinished")
	check_eq(t.size(), 1, "one half-built building")
	var u: Dictionary = t[t.keys()[0]]
	check_eq(u["type"], "TEXTILE", "its type")
	check_eq(int(u["book"]), int(p["paid"]), "its book is what the builder was paid")
	check_eq(int(u["bank_cap"]), 30000 * S, "the bank holds it up to its write-off")
	check(not (w.table("org")[b]["contracts"] as Array).has(p["id"]), "the job leaves the builder's book")
	check_eq(w.facts.query("ECON_UNFINISHED_LEFT").size(), 1, "a public fact")


func test_same_use_takeover() -> void:
	var w := _sim(["E165", "E169"]).world
	var old := _org(w, "FORMING", 0)
	EconFinance.new_loan(w, old, 30000 * S, 0, true)
	var p := _half_built(w, old, "TEXTILE")
	w.ledger.transfer(EconUtil.acct(old), Ledger.EXTERNAL, w.ledger.balance(EconUtil.acct(old)), "TEST", w.month)
	var full_wu: int = int(p["wu_total"])
	var done: int = int(p["wu_done"])
	var book: int = int(p["paid"])
	EconInsolvency.abandon_plan(w, old, "limit")
	var nw := _org(w, "FORMING", 5000000 * S)
	var bank0 := w.ledger.balance(EconUtil.BANK)
	var pid := EconConstruction.create(w, "TEXTILE", "d:1", nw, nw, "")
	var q: Dictionary = w.table("project")[pid]
	check_eq(int(q["wu_total"]), full_wu - done, "only the remaining work is tendered")
	check_eq(int(q["book_carry"]), book * EconUnfinished.SAME_PRICE_PM / 1000, "60% of book paid")
	var price := book * EconUnfinished.SAME_PRICE_PM / 1000
	check_eq(w.ledger.balance(EconUtil.BANK) - bank0, mini(price, 30000 * S), "the bank recovers up to its write-off")
	check_eq(int(EconUtil.st(w)["e169_stats"]["paid_rest"]), price - mini(price, 30000 * S), "the rest goes to the founder household")
	check(w.peek("unfinished").is_empty(), "taken off the market")
	check_eq(int(EconUtil.st(w)["e169_stats"]["taken_same"]), 1, "counted as same use")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_repurposed_and_unaffordable() -> void:
	var w := _sim(["E169"]).world
	var old := _org(w, "ACTIVE", 0)
	var p := _half_built(w, old, "PROCESSING")
	p["wu_done"] = int(p["wu_total"]) * 9 / 10
	var book: int = int(p["paid"])
	var u_id := EconUnfinished.leave(w, p, EconUtil.acct(old))
	check(u_id != "", "left")
	var poor := _org(w, "ACTIVE", 1 * S)
	var pid0 := EconConstruction.create(w, "TEXTILE", "d:1", poor, poor, "")
	check(not w.table("project")[pid0].has("took_over"), "an owner who can't pay doesn't take it over")
	var rich := _org(w, "ACTIVE", 5000000 * S)
	var tex_wu := int(EconData.BUILD["TEXTILE"][0]) * S
	var pid := EconConstruction.create(w, "TEXTILE", "d:1", rich, rich, "")
	var q: Dictionary = w.table("project")[pid]
	check_eq(String(q.get("took_over", "")), u_id, "repurposed for another type")
	check_eq(int(q["wu_total"]), tex_wu - tex_wu / 2, "credit capped at half the new plant's work")
	check_eq(int(q["book_carry"]), book * EconUnfinished.REPURPOSE_PRICE_PM / 1000, "30% of book, paid to the old owner")
	check_eq(int(EconUtil.st(w)["e169_stats"]["taken_repurpose"]), 1, "counted as repurposed")


func test_public_shell_and_decay() -> void:
	var w := _sim(["E169"]).world
	var p := _half_built(w, "gov", "CLINIC")
	check(EconActions.apply(w, "ECON_CANCEL_PROJECT", {"project": p["id"]}), "cancelled")
	check_eq(w.peek("unfinished").size(), 1, "a cancelled public job leaves a public shell")
	var t0 := w.ledger.balance(EconUtil.TREASURY)
	var pid := EconConstruction.create(w, "CLINIC", "d:1", "gov", "gov", "ECON_BUDGET_INFRASTRUCTURE")
	check(w.table("project")[pid].has("took_over"), "the government takes its own clinic back")
	check_eq(w.ledger.balance(EconUtil.TREASURY), t0, "no money moves to buy back its own shell")
	var old := _org(w, "ACTIVE", 0)
	EconUnfinished.leave(w, _half_built(w, old, "TEXTILE"), EconUtil.acct(old))
	w.month += EconUnfinished.DECAY_M
	EconUnfinished.monthly(w)
	check(w.peek("unfinished").is_empty(), "unsold for 5 years: written off")
	check_eq(int(EconUtil.st(w)["e169_stats"]["decayed"]), 1, "counted as decayed")


func test_run_closes() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.world.meta["on"] = ["E165", "E165B", "E169"]
	sim.run(36)
	check_eq(sim.world.ledger.total(), 0, "ledger closed")
	check(EconPop.check(sim.world).is_empty(), "jobs equal people")


func test_dead_holder_paid_to_its_owner() -> void:
	var w := _sim(["E169"]).world
	var old := _org(w, "ACTIVE", 0)
	var p := _half_built(w, old, "TEXTILE")
	EconUnfinished.leave(w, p, EconUtil.acct(old))
	w.table("org")[old]["status"] = "DISSOLVED"
	var gid: String = w.table("org")[old]["owner_group"]
	var h0 := w.ledger.balance(EconUtil.hh_acct(gid))
	var nw := _org(w, "ACTIVE", 5000000 * S)
	var pid := EconConstruction.create(w, "TEXTILE", "d:1", nw, nw, "")
	check(w.table("project")[pid].has("took_over"), "taken over")
	check_eq(w.ledger.balance(EconUtil.acct(old)), 0, "nothing paid into the dead firm")
	check(w.ledger.balance(EconUtil.hh_acct(gid)) > h0, "its owner household is paid instead")
	var poor := _org(w, "ACTIVE", 0)
	EconUnfinished.leave(w, _half_built(w, poor, "TEXTILE"), EconUtil.acct(poor))
	var u: Dictionary = w.peek("unfinished")[w.peek("unfinished").keys()[0]]
	var shell_only := _org(w, "ACTIVE", int(u["book"]) * EconUnfinished.SAME_PRICE_PM / 1000 + S)
	var pid2 := EconConstruction.create(w, "TEXTILE", "d:1", shell_only, shell_only, "")
	check(not w.table("project")[pid2].has("took_over"), "an owner who could pay the shell but not the rest doesn't take it")
