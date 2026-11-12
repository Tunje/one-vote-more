extends TestCase
## U2 (A41): demands → answers → strikes. No strike without a prior demand; an empty fund collapses a strike; the
## player answers public-sector demands (never auto-settled while they govern); the public-sector strike ban sends
## disputes to arbitration; ledger closed.


func _union(w: WorldState, public: bool) -> Dictionary:
	for u in Unions.active(w):
		if not u["federation"] and ("PUBLIC_SECTOR" in u["sectors"]) == public:
			return u
	return {}


func _demand(w: WorldState, u: Dictionary, employer: String, status: String) -> Dictionary:
	var id := w.new_id("udemand")
	var d := {"id": id, "union": u["id"], "employer": employer, "employer_name": "test", "occ": u["sectors"][0], "kind": "WAGE",
		"size_pm": 50, "made": w.month - 1, "deadline": w.month + 2, "status": status, "answer": "", "counter_pm": 0,
		"player_answer": "", "outcome": "", "award_pm": 0, "strike_start": w.month - 1, "strike_months": 0, "persons": 40, "losses": 0,
		"unlawful": false, "reasons": [], "lockout": false, "ended": -1}
	w.table("union_demand")[id] = d
	return d


func test_no_strike_without_a_demand_and_ledger_closed() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(72)
	var w := sim.world
	check(w.facts.query("UNION_DEMAND").size() > 0, "unions table demands")
	var demanded := {}
	for f in w.facts.query("UNION_DEMAND"):
		demanded[str(f["data"]["demand"])] = int(f.get("month", 0))
	for f in w.facts.query("UNION_STRIKE_CALLED"):
		var did := str(f["data"].get("demand", ""))
		if bool(f["data"].get("general", false)):
			continue
		check(demanded.has(did), "strike %s follows a tabled demand" % did)
	for f in w.facts.query("UNION_SETTLED"):
		check(String(f["data"]["outcome"]) in ["ACCEPTED", "COUNTER", "WON", "COMPROMISE", "LOST", "ARBITRATED"], "known outcome")
	check(w.facts.query("ECON_STRIKE").is_empty(), "no random M9 strikes with U2 on")
	check_eq(w.ledger.total(), 0, "ledger closed (dues, strike pay)")


func test_empty_fund_collapses_the_strike() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(15)
	var w := sim.world
	var u := _union(w, false)
	check(not u.is_empty(), "a private-sector union")
	var emp := EconFinance.org_by_key(w, "MERIDIAN")
	var d := _demand(w, u, emp if emp != "" else "gov", "STRIKE")
	EconUtil.pay_upto(w, u["acct"], EconUtil.TREASURY, w.ledger.balance(u["acct"]), "TEST")  # fund emptied
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	UnionDisputes._strike_month(w, d, rng)
	if d["status"] == "STRIKE":
		UnionDisputes._strike_month(w, d, rng)
	check(d["status"] != "STRIKE", "no strike lasts two months on an empty fund")
	if String(d["outcome"]) == "LOST":
		check(not w.facts.query("UNION_STRIKE_COLLAPSED").is_empty(), "the collapse makes news")
		check(int(u["election_due"]) <= w.month + 1, "a lost strike calls an early leader election")


func test_player_answers_public_demands() -> void:
	var sim := Simulation.new(4)
	sim.world.meta["scenario"] = "BALANCED"
	sim.world.meta["persona"] = {}
	sim.world.meta["autoplay_player"] = false  # the player governs (founding era: the commander)
	sim.world.meta["off"] = []
	EconSim._register(sim)
	sim.new_game()
	for _i in 14:
		sim.step()
	var w := sim.world
	check(EconEssentials.human_governs(w), "the player governs")
	var u := _union(w, true)
	check(not u.is_empty(), "a public servants' union")
	var d := _demand(w, u, "gov", "OPEN")
	d["deadline"] = w.month + 3
	UnionDisputes.monthly(w)
	check_eq(String(d["status"]), "OPEN", "not answered on the player's behalf")
	check(UnionDisputes.pending_demands(w, "gov").has(d), "listed for the player")
	check(EconActions.validate(w, "ECON_ANSWER_UNION_DEMAND", {"demand": d["id"], "answer": "MAYBE"}) != "", "bad answer rejected")
	check_eq(EconActions.validate(w, "ECON_ANSWER_UNION_DEMAND", {"demand": d["id"], "answer": "ACCEPT"}), "", "a valid answer")
	EconActions.apply(w, "ECON_ANSWER_UNION_DEMAND", {"demand": d["id"], "answer": "ACCEPT"})
	UnionDisputes.monthly(w)
	check_eq(String(d["outcome"]), "ACCEPTED", "the player's acceptance settles it")
	check(int(d["award_pm"]) == 50, "the demand is awarded")


func test_public_sector_ban_goes_to_arbitration() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(15)
	var w := sim.world
	w.levers["LAW_PUBLIC_SECTOR_STRIKE"] = 0
	var u := _union(w, true)
	var d := _demand(w, u, "gov", "OPEN")
	d["answer"] = "REFUSE"
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	UnionDisputes._talks_failed(w, d, u, rng)
	check_eq(String(d["outcome"]), "ARBITRATED", "banned public-sector strike → arbitration")
	check(not w.facts.query("ECON_ARBITRATION").is_empty(), "arbitration makes news")
