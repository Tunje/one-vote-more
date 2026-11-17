extends TestCase
## The four grants (rebuild step 3; sim/economy/grants.gd): paid from the treasury into a plan's account right after
## the plan is made, all or nothing, one per household, only where the programme covers; owed back by a plan given up;
## each programme a time-limited window that the law closes (12.9, 61a). Exact to the last credit; nothing appears or
## vanishes. Otto's plan record and Maja's person record are stood in here by their tables until their pieces are in.

const Grants := preload("res://sim/economy/grants.gd")
const S := CoreUtil.S
const NEEDS := 100000 * 1000   # what a founder must bring in these tests: 100,000 credits


## The real hooks, as month.gd sets them when a game is made; each test puts them back (_unhook), since the hooks are
## static and would otherwise leak this file's stubs into later tests.
var _real_needs := Callable()
var _real_need := Callable()


## A game, then the stubs: making a game sets the real hooks (month.gd's _init), so a stub set before it is replaced.
func _world() -> WorldState:
	var sim := GameSim.make(3)
	_stub()
	return sim.world


func _stub() -> void:
	_real_needs = Grants.needs_fn
	_real_need = Grants.need_fn
	Grants.needs_fn = func(_w, _t, _s, _a): return NEEDS
	Grants.need_fn = Callable()


func _unhook() -> void:
	Grants.needs_fn = _real_needs
	Grants.need_fn = _real_need


func _area(w: WorldState) -> String:
	return String(AreaStore.areas(w)[0]["id"])


## The unit a programme covers for the Landing: its district, or the area itself while no district is drawn.
func _district(w: WorldState) -> String:
	return Grants._district(w, _area(w))


func _cover(w: WorldState, kind: String, districts: Array) -> void:
	var st: Dictionary = w.table("pol")["state"]
	if not st.has("grant_cover"):
		st["grant_cover"] = {}
	st["grant_cover"][kind] = districts


## A plan as Otto's make_plan leaves it (table "plan", the account is the plan id) and its founder as Maja's
## make_founder does (table "founder", ids "founder:N", with the pool the founder came from).
func _plan(w: WorldState, n: int, pool: String, type: String = "FARM", size: String = "FAMILY") -> String:
	var pid := "plan:%d" % n
	var person := "founder:%d" % n
	w.table("founder")[person] = {"id": person, "pool": pool, "account": person}
	w.table("plan")[pid] = {"founder": person, "type": type, "size": size, "area": _area(w), "status": "MADE"}
	w.ledger.open_account(pid)
	return pid


func test_a_grant_is_paid_into_the_plan_exactly() -> void:
	var w := _world()
	check(_district(w) != "", "the Landing can be covered (its district, or itself before districts are drawn)")
	_cover(w, "FARM", [_district(w)])
	var pid := _plan(w, 1, "pool:a")
	var before := w.ledger.balance(CoreUtil.TREASURY)
	var total := w.ledger.total()
	var r := Grants.apply(w, pid)
	check(bool(r["ok"]), "paid (%s)" % r["why"])
	var want := NEEDS * int(w.levers["ECON_FAMILY_FARM_GRANT"]) / 100
	check_eq(int(r["amount"]), want, "the lever's per cent of what the founder must bring")
	check_eq(w.ledger.balance(pid), want, "into the plan's account")
	check_eq(w.ledger.balance(CoreUtil.TREASURY), before - want, "from the treasury")
	check_eq(w.ledger.total(), total, "no money appears or vanishes")
	check_eq(Grants.quote(w, "FARM", _area(w), "pool:b"), want, "the quote said the same")
	check_eq(Logbook.rows(w, {"kind": "GRANT", "what": "grant paid"}).size(), 1, "logged")
	var again := Grants.apply(w, pid)
	check(not bool(again["ok"]), "a plan has one grant")
	check_eq(w.ledger.balance(pid), want, "and is not paid twice")
	_unhook()


func test_refusals_pay_nothing_and_say_why() -> void:
	var w := _world()
	var pid := _plan(w, 1, "pool:a")
	var r := Grants.apply(w, pid)
	check(not bool(r["ok"]) and String(r["why"]).contains("covers"), "no district chosen yet: nothing (%s)" % r["why"])
	_cover(w, "FARM", [_district(w)])
	w.levers["ECON_FAMILY_FARM_GRANT"] = 0
	check(String(Grants.apply(w, pid)["why"]).contains("no programme"), "the lever at 0: nothing")
	check_eq(Grants.quote(w, "FARM", _area(w), "pool:a"), 0, "and the quote says 0")
	w.levers["ECON_FAMILY_FARM_GRANT"] = 50
	check(bool(Grants.apply(w, pid)["ok"]), "now it is paid")
	var p2 := _plan(w, 2, "pool:a")
	check(bool(Grants.apply(w, p2)["ok"]), "another household of the same pool gets its own grant")
	# the same founder's household founding again (Anni's review: the household is the founder's own)
	var p3 := "plan:3"
	w.table("plan")[p3] = {"founder": "founder:1", "type": "FARM", "size": "FAMILY", "area": _area(w), "status": "MADE"}
	w.ledger.open_account(p3)
	check(String(Grants.apply(w, p3)["why"]).contains("household"), "one grant per household")
	check_eq(w.ledger.balance(p3), 0, "nothing paid to the second plan")
	# a household drawn from the pool's granted households (Maja's pick_founder marks it)
	var p4 := _plan(w, 4, "pool:b")
	w.table("founder")["founder:4"]["had_grant"] = true
	check(String(Grants.apply(w, p4)["why"]).contains("household"), "a household that had a grant gets no second one")
	check_eq(Logbook.rows(w, {"kind": "GRANT", "what": "grant refused"}).size(), 4, "each refusal logged")
	_unhook()


func test_a_treasury_that_cannot_pay_it_all_pays_nothing() -> void:
	var w := _world()
	_cover(w, "FARM", [_district(w)])
	var tre := w.ledger.balance(CoreUtil.TREASURY)
	w.ledger.transfer(CoreUtil.TREASURY, Ledger.EXTERNAL, tre - 1000, "TEST_DRAIN", w.month)
	var pid := _plan(w, 1, "pool:a")
	var r := Grants.apply(w, pid)
	check(not bool(r["ok"]) and String(r["why"]).contains("treasury"), "refused (%s)" % r["why"])
	check_eq(w.ledger.balance(pid), 0, "no half grant")
	check_eq(w.ledger.balance(CoreUtil.TREASURY), 1000, "the treasury keeps what it had")
	_unhook()


func test_only_the_four_family_kinds_have_a_grant() -> void:
	var w := _world()
	_cover(w, "FARM", [_district(w)])
	var pid := _plan(w, 1, "pool:a", "FARM", "SMALL")
	check(not bool(Grants.apply(w, pid)["ok"]), "a small farm has no grant")
	var pid2 := _plan(w, 2, "pool:b", "MINE", "FAMILY")
	check(not bool(Grants.apply(w, pid2)["ok"]), "a mine has none")
	check_eq(Logbook.rows(w, {"kind": "GRANT"}).filter(func(r): return String(r["what"]).begins_with("grant")).size(), 0,
		"not a grant decision, so no row")
	check_eq(Grants.kind_of("HAULIER", "FAMILY"), "TRUCKER", "a truck driver is a family haulier")
	check_eq(Grants.kind_of("TRUCKSHOP", "FAMILY"), "TRUCKSHOP", "and the workshop has its own")
	_unhook()


func test_a_plan_given_up_owes_its_grant_back() -> void:
	var w := _world()
	_cover(w, "FARM", [_district(w)])
	var pid := _plan(w, 1, "pool:a")
	var amount := int(Grants.apply(w, pid)["amount"])
	var tre := w.ledger.balance(CoreUtil.TREASURY)
	check_eq(Grants.reclaim(w, pid), amount, "all of it back while the plan holds it")
	check_eq(w.ledger.balance(CoreUtil.TREASURY), tre + amount, "into the treasury")
	check_eq(String(w.peek("grant")[pid]["status"]), "REPAID", "repaid")
	check_eq(Grants.reclaim(w, pid), 0, "not twice")
	# a plan that spent part of it: the founder owes the rest
	var p2 := _plan(w, 2, "pool:b")
	var a2 := int(Grants.apply(w, p2)["amount"])
	w.ledger.transfer(p2, Ledger.EXTERNAL, a2 - 400 * S, "TEST_SPENT", w.month)
	check_eq(Grants.reclaim(w, p2), 400 * S, "what the account still holds")
	var owed := 0
	for lid in w.peek("liability"):
		var l: Dictionary = w.peek("liability")[lid]
		if String(l["debtor"]) == "founder:2" and String(l["kind"]) == "GRANT":
			owed += int(l["amount"])
	check_eq(owed, a2 - 400 * S, "the founder owes the rest to the government")
	check_eq(String(w.peek("grant")[p2]["status"]), "OWED", "owed")
	_unhook()


## Month one has no district: the Landing area stands for itself, and the government can cover it.
func test_an_area_without_a_district_can_be_covered() -> void:
	var w := _world()
	var area := _area(w)
	if preload("res://sim/law/law_query.gd").district_of(w, area) == "":
		check_eq(Grants._district(w, area), area, "the area stands for itself")
	_cover(w, "FARM", [Grants._district(w, area)])
	check(bool(Grants.apply(w, _plan(w, 1, "pool:a"))["ok"]), "and its founders get the grant")
	_unhook()


## A cover chosen for the area itself (no district yet) still holds once a district is drawn over it.
func test_a_cover_survives_a_district_drawn_later() -> void:
	var w := _world()
	var area := _area(w)
	_cover(w, "FARM", [area])
	AreaStore.set_district(w, area, "d:new")
	check(bool(Grants.apply(w, _plan(w, 1, "pool:a"))["ok"]), "the programme still covers the Landing")
	_unhook()


func test_a_grant_lever_says_it_lapses() -> void:
	var w := _world()
	check(String(w.lever_defs["ECON_FAMILY_FARM_GRANT"].get("description", "")).contains("24 months"), "the lever says so")
	Grants.monthly(w)
	var row: Array = Logbook.rows(w, {"kind": "GRANT", "what": "programme opened", "ref": "ECON_FAMILY_FARM_GRANT"})
	check(row.size() == 1 and int(row[0]["why"]["until"]) == w.month + Grants.PROGRAMME_M, "the opening row says until when")
	_unhook()


func test_a_programme_is_a_window_the_law_closes() -> void:
	var w := _world()
	Grants.monthly(w)
	var progs: Dictionary = w.peek(Grants.STATE)["s"]["progs"]
	check_eq(progs.size(), 4, "all four open from month one")
	_cover(w, "FARM", [_district(w)])
	Grants.apply(w, _plan(w, 1, "pool:a"))
	w.month += Grants.PROGRAMME_M
	Grants.monthly(w)
	check_eq(int(w.levers["ECON_FAMILY_FARM_GRANT"]), 0, "the window ran out: the lever is 0, in force at once")
	check_eq(int(LawOps_legal(w).get("ECON_FAMILY_FARM_GRANT", -1)), 0, "and so is its legal value")
	var ended: Array = w.facts.query("ECON_GRANT_PROGRAMME_ENDED")
	check_eq(ended.size(), 4, "a public fact for each programme")
	for f in ended:
		if String(f["data"]["lever"]) == "ECON_FAMILY_FARM_GRANT":
			check_eq(int(f["data"]["paid"]), 1, "it says what it paid")
			check_eq(int(f["data"]["months"]), Grants.PROGRAMME_M, "and how long it ran")
	check(not w.peek(Grants.STATE)["s"]["progs"].has("FARM"), "a new programme needs a new decision")
	Grants.monthly(w)
	check(not w.peek(Grants.STATE)["s"]["progs"].has("FARM"), "nothing reopens it by itself")
	_unhook()


func LawOps_legal(w: WorldState) -> Dictionary:
	return preload("res://sim/law/law_ops.gd").state(w)["legal_values"]


func test_a_government_that_closes_a_programme_early_is_on_record() -> void:
	var w := _world()
	Grants.monthly(w)
	w.month += 3
	w.levers["ECON_FAMILY_BAKERY_GRANT"] = 0
	Grants.monthly(w)
	var ended: Array = w.facts.query("ECON_GRANT_PROGRAMME_ENDED").filter(func(f): return String(f["data"]["kind"]) == "BAKERY")
	check_eq(ended.size(), 1, "the end is public")
	if ended.size() == 1:
		check_eq(String(ended[0]["data"]["how"]), "the government closed it", "and says who ended it")
	_unhook()


func test_the_need_is_published_by_district() -> void:
	var w := _world()
	Grants.need_fn = func(_w, type, _s, _a): return 5000 * S if type == "FARM" else 0
	Grants.monthly(w)
	var n := EconFace.grant_need(w)
	check_eq(int(n["FARM"][_district(w)]), 5000 * S, "the farm founders' work in the district")
	check(not n["BAKERY"].has(_district(w)) or int(n["BAKERY"][_district(w)]) == 0, "no bakery work")
	var ln := EconFace.lever_need(w)
	check_eq(int(ln["ECON_FAMILY_FARM_GRANT"]), 1000, "the farm grant is needed")
	check_eq(int(ln["ECON_FAMILY_BAKERY_GRANT"]), 0, "the bakery grant is not")
	_unhook()


func test_the_levers_and_memos_of_step_3() -> void:
	var w := _world()
	check_eq(int(w.levers["ECON_YEARLY_RAISE_MIN_PCT"]), 2, "the yearly raise starts at 2%")
	for k in Grants.KINDS:
		check(int(w.levers[Grants.lever_of(k)]) > 0, "%s is open from month one" % k)
		check_eq(String(w.lever_defs[Grants.lever_of(k)]["owner"]), "econ", "a lever's facts are ECON_LEVER_EFFECTIVE")
	var EP := preload("res://sim/economy/econ_publish.gd")
	for m in ["LANDING_TREASURY", "LAND_SALE", "LANDING_STOCK_SALE"]:
		check(m in EP.CAPITAL_MEMOS, "%s is capital" % m)
	_unhook()


func test_grants_survive_save_and_load() -> void:
	var sim := GameSim.make(3)
	_stub()
	var w := sim.world
	Grants.monthly(w)
	_cover(w, "FARM", [_district(w)])
	Grants.apply(w, _plan(w, 1, "pool:a"))
	var path := save_path("grants.sav")
	check_eq(SaveIO.save(sim, path), OK, "save")
	var l := GameSim.for_load()
	check_eq(SaveIO.load_into(l, path), OK, "load")
	check_eq(l.world.peek("grant"), w.peek("grant"), "the grants paid")
	check_eq(l.world.peek(Grants.STATE), w.peek(Grants.STATE), "the programmes")
	check_eq(l.world.state_hash(), w.state_hash(), "the same state")
	_unhook()
