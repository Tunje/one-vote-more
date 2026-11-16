extends TestCase
## Under E165 a family's farm or bakery is a plan first: no grant, loan or savings until a builder's quote is accepted
## (EconFamily.fund_plan, called from Otto's award), and counted as founded when it opens. Without E165, as before.

const S := EconUtil.S


func _sim(extra: Array) -> Simulation:
	var sim := EconSim.make_econ_only(1)
	var on: Array = EconSim.DEFAULT_ON.duplicate()
	on.append_array(extra)
	sim.world.meta["on"] = on
	sim.run(3)
	return sim


func _gid(w: WorldState) -> String:
	var best := ""
	var cash := -1
	for gid in EconUtil.sorted_keys(w.table("hh")):
		var c := w.ledger.balance(EconUtil.hh_acct(gid))
		if c > cash:
			cash = c
			best = gid
	return best


func _newest_family(w: WorldState) -> String:
	var last := ""
	for oid in EconUtil.sorted_keys(w.table("org")):
		if bool(w.table("org")[oid].get("family", false)):
			last = oid
	return last


func test_a_plan_commits_no_money_until_a_builder_accepts() -> void:
	var sim := _sim(["E165"])
	var w := sim.world
	var gid := _gid(w)
	var hh0 := w.ledger.balance(EconUtil.hh_acct(gid))
	var tre0 := w.ledger.balance(EconUtil.TREASURY)
	var n0 := w.table("loan").size()
	var fd0 := int(EconUtil.st(w).get("fam_founded", {}).get("FAMFARM", 0))
	check(EconFamily._start(w, "FAMFARM", "d:2", gid, 60), "the plan is made")
	var oid := _newest_family(w)
	var o: Dictionary = w.table("org")[oid]
	check_eq(String(o["status"]), "FORMING", "a plan, not yet a company")
	check(bool(o.get("fund_on_award", false)), "waiting for a builder before it applies")
	check_eq(w.ledger.balance(EconUtil.acct(oid)), 0, "no grant, loan or savings in it")
	check_eq(w.ledger.balance(EconUtil.hh_acct(gid)), hh0, "the family's savings untouched")
	check_eq(w.ledger.balance(EconUtil.TREASURY), tre0, "no grant paid")
	check_eq(w.table("loan").size(), n0, "no loan")
	check_eq(int(EconUtil.st(w).get("fam_founded", {}).get("FAMFARM", 0)), fd0, "not counted as founded")
	check(EconConstruction.has_open_project(w, oid, "FAMFARM"), "its project is out to tender")
	# the award: now it applies
	check(EconFamily.fund_plan(w, oid, ""), "funded at the award")
	check(w.ledger.balance(EconUtil.acct(oid)) > 0, "the money is in the plan's account")
	check(int(o.get("grant_paid", 0)) > 0 or w.table("loan").size() > n0, "grant or loan as the family rules give")
	check(not o.has("fund_on_award"), "applied once")
	check(EconFamily.fund_plan(w, oid, ""), "a second call changes nothing")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_no_money_no_award() -> void:
	var sim := _sim(["E165"])
	var w := sim.world
	var gid := _gid(w)
	EconFamily._start(w, "FAMFARM", "d:2", gid, 0)  # no grant: savings and a build loan
	var oid := _newest_family(w)
	w.ledger.transfer(EconUtil.hh_acct(gid), Ledger.EXTERNAL, w.ledger.balance(EconUtil.hh_acct(gid)), "TEST", w.month)
	EconUtil.st(w)["bank_failed"] = true
	check(not EconFamily.fund_plan(w, oid, ""), "no savings and no bank room: not funded (Otto reverts the award)")
	EconUtil.st(w)["bank_failed"] = false


func test_founded_counted_at_the_opening() -> void:
	var sim := _sim(["E165"])
	var w := sim.world
	var gid := _gid(w)
	EconFamily._start(w, "FAMFARM", "d:2", gid, 60)
	var oid := _newest_family(w)
	EconFamily.fund_plan(w, oid, "")
	var fd0 := int(EconUtil.st(w).get("fam_founded", {}).get("FAMFARM", 0))
	var fid := w.new_id("facility")
	w.table("facility")[fid] = {"id": fid, "type": "FAMFARM", "district": "d:2", "org": oid, "staff": {}, "mothball": false, "condition": 100 * S, "scale": 1000, "T": 1000}
	EconFamily.on_open(w, oid, fid)
	check_eq(int(EconUtil.st(w).get("fam_founded", {}).get("FAMFARM", 0)), fd0 + 1, "counted when the farm opens")
	check(not w.table("org")[oid].has("fam_plan"), "once")


func test_without_e165_founding_as_before() -> void:
	var sim := _sim([])
	var w := sim.world
	var gid := _gid(w)
	var fd0 := int(EconUtil.st(w).get("fam_founded", {}).get("FAMFARM", 0))
	if not EconFamily._start(w, "FAMFARM", "d:2", gid, 60):
		check(false, "founded")
		return
	var oid := _newest_family(w)
	check(not w.table("org")[oid].has("fund_on_award"), "no plan step")
	check(w.ledger.balance(EconUtil.acct(oid)) > 0, "funded at founding")
	check_eq(int(EconUtil.st(w).get("fam_founded", {}).get("FAMFARM", 0)), fd0 + 1, "counted at founding")


func test_funding_follows_the_accepted_price() -> void:
	var sim := _sim(["E165"])
	var w := sim.world
	var gid := _gid(w)
	w.ledger.transfer(Ledger.EXTERNAL, EconUtil.hh_acct(gid), 100000000 * S, "TEST", w.month)
	EconFamily._start(w, "FAMFARM", "d:2", gid, 50)
	var oid := _newest_family(w)
	var est := int(EconFamily.startup_cost(w, "FAMFARM")["build"])
	var price := est * 3
	check(EconFamily.fund_plan(w, oid, "", price), "funded")
	var c := EconFamily.startup_cost(w, "FAMFARM")
	var total := price + int(c["wc"]) + int(c["course"])
	check(w.ledger.balance(EconUtil.acct(oid)) >= total - 2, "the plan holds what the contract costs at the accepted price (%d of %d)" % [w.ledger.balance(EconUtil.acct(oid)) / S, total / S])
	check(absi(int(w.table("org")[oid].get("grant_paid", 0)) - total * 50 / 100) <= 2, "the grant is half of that total (%d of %d)" % [int(w.table("org")[oid].get("grant_paid", 0)) / S, total / 2 / S])
