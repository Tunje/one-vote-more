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


func _cover(w: WorldState, kind: String, districts: Array, sum: int = 1000 * NEEDS) -> void:
	var st: Dictionary = w.table("pol")["state"]
	if not st.has("grant_cover"):
		st["grant_cover"] = {}
	st["grant_cover"][kind] = districts
	if not st.has("grant_sum"):
		st["grant_sum"] = {}
	st["grant_sum"][kind] = {"kind": kind, "sum": sum, "start": w.month}   # a sum far above these tests' grants


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
	check_eq(Grants.quote(w, "FARM", _area(w), "pool:a"), 0, "the quote says no grant, so nobody is picked on it")
	var pid := _plan(w, 1, "pool:a")
	var r := Grants.apply(w, pid)
	check(not bool(r["ok"]) and String(r["why"]).contains("treasury"), "refused (%s)" % r["why"])
	check_eq(w.ledger.balance(pid), 0, "no half grant")
	check_eq(w.ledger.balance(CoreUtil.TREASURY), 1000, "the treasury keeps what it had")
	_unhook()


## The user (61b): the government puts a sum into a programme, from how many plants it wants and a little extra.
func test_the_government_sets_the_sum_when_a_programme_opens() -> void:
	var w := _world()
	var st: Dictionary = w.table("pol")["state"]
	st.erase("grant_prog")
	st.erase("grant_sum")
	w.table(Grants.STATE)["s"] = {"progs": {}, "need": {"FARM": {_district(w): 1000}}, "seen": {}}
	GovBuilder._grant_cover(w, st)
	var b: Dictionary = GovBuilder.grant_sum(w).get("FARM", {})
	var persons := 0
	for hb in preload("res://sim/population/households.gd").buyers(w):
		persons += int(hb["persons"])
	var out := preload("res://sim/economy/type_table.gd").output_milli("FARM", "FAMILY")
	var farms := (persons * 1000 + out - 1) / out
	check(persons > 0 and farms > 0, "a colony to feed (%d persons, %d farms)" % [persons, farms])
	check_eq(int(b.get("wanted", -1)), farms, "farms wanted: what feeds the colony at full output")
	var grant := NEEDS * int(w.levers["ECON_FAMILY_FARM_GRANT"]) / 100
	check_eq(int(b.get("grant", -1)), grant, "the grant it is planned on")
	check_eq(int(b.get("extra", -1)), farms * grant / 10, "a tenth extra")
	check_eq(int(b.get("sum", -1)), farms * grant + farms * grant / 10, "the sum")
	check_eq(int(GovBuilder.grant_sum(w)["TRUCKER"]["wanted"]), AreaStore.areas(w).size(), "truck drivers: one in each area")
	var rows := Logbook.rows(w, {"kind": "GRANT", "what": "sum set", "ref": "ECON_FAMILY_FARM_GRANT"})
	check_eq(rows.size(), 1, "the decision is logged once")
	if rows.size() == 1:
		check_eq(int(rows[0]["why"]["wanted"]), farms, "with how many it wanted")
		check_eq(int(rows[0]["why"]["to_feed"]), farms, "how many feed the colony")
		check_eq(int(rows[0]["why"]["standing"]) + int(rows[0]["why"]["planned"]), 0, "none standing or planned yet")
		check_eq(int(rows[0]["why"]["sum"]), int(b["sum"]), "and the sum")
	# how many MORE (Wilma): a plan signed and a small farm standing count for what they would grow
	w.table("plan")["plan:90"] = {"founder": "", "type": "FARM", "size": "FAMILY", "area": _area(w), "status": "SIGNED"}
	w.table("plan")["plan:91"] = {"founder": "", "type": "FARM", "size": "FAMILY", "area": _area(w), "status": "GIVEN_UP"}
	var Co := preload("res://sim/economy/company.gd")
	var cid := Co.create(w, "FARM", "SMALL", {"kind": "HOME_WORLD", "holders": {"home_world": 1000}}, "Greenacre", {"area": _area(w)})
	Co.add_plant(w, cid, "SMALL")
	var small := preload("res://sim/economy/type_table.gd").output_milli("FARM", "SMALL")
	var more := Grants.wanted(w, "FARM")
	check_eq(int(more["standing"]), 1, "one farm stands")
	check_eq(int(more["planned"]), 1, "one plan signed (a plan given up does not count)")
	check_eq(int(more["wanted"]), (maxi(0, persons * 1000 - out - small) + out - 1) / out, "fewer wanted by what they grow")
	check_eq(int(Grants.wanted(w, "TRUCKER")["wanted"]), AreaStore.areas(w).size(), "no truck driver stands: still one each")
	var tre := w.ledger.balance(CoreUtil.TREASURY)
	w.levers["ECON_FAMILY_FARM_GRANT"] = 0
	GovBuilder._grant_cover(w, st)
	check(not GovBuilder.grant_sum(w).has("FARM"), "the programme ends: its sum goes with it")
	check_eq(w.ledger.balance(CoreUtil.TREASURY), tre, "a limit, not money set aside: nothing moves")
	_unhook()


func test_a_spent_sum_pays_no_more_grants() -> void:
	var w := _world()
	var grant := NEEDS * int(w.levers["ECON_FAMILY_FARM_GRANT"]) / 100
	_cover(w, "FARM", [_district(w)], 2 * grant + grant / 2)
	check(bool(Grants.apply(w, _plan(w, 1, "pool:a"))["ok"]), "the first grant")
	check(bool(Grants.apply(w, _plan(w, 2, "pool:a"))["ok"]), "the second")
	check_eq(Grants.sum_left(w, "FARM"), grant / 2, "half a grant left")
	check_eq(Grants.quote(w, "FARM", _area(w), "pool:a"), 0, "the quote says no grant")
	var tre := w.ledger.balance(CoreUtil.TREASURY)
	var p3 := _plan(w, 3, "pool:a")
	var r := Grants.apply(w, p3)
	check(not bool(r["ok"]) and String(r["why"]).contains("sum"), "the third is refused (%s)" % r["why"])
	check_eq(w.ledger.balance(p3), 0, "nothing paid")
	check_eq(w.ledger.balance(CoreUtil.TREASURY), tre, "the treasury keeps it")
	var rows := Logbook.rows(w, {"kind": "GRANT", "what": "grant refused"})
	check(rows.size() == 1 and int(rows[0]["why"]["sum_left"]) == grant / 2 / S, "logged with what was left")
	# a plan given up pays its grant back: the sum is refilled by what came back (Wilma)
	var back := Grants.reclaim(w, "plan:1")
	check_eq(back, grant, "the first plan's grant came back whole")
	check_eq(Grants.sum_left(w, "FARM"), grant / 2 + grant, "and refills the sum")
	check_eq(Grants.quote(w, "FARM", _area(w), "pool:a"), grant, "so a grant can be quoted again")
	(w.table("pol")["state"]["grant_sum"] as Dictionary).erase("FARM")
	check(String(Grants.apply(w, _plan(w, 4, "pool:a"))["why"]).contains("no sum"), "no sum set, no grant")
	_unhook()


## Rule 7 sees the plans that have accepted a grant (the user, 15a): paid, and neither opened nor given up.
func test_rule_7_reads_the_plans_that_accepted_a_grant() -> void:
	var w := _world()
	_cover(w, "FARM", [_district(w)])
	check(Grants.granted_plans(w).is_empty(), "none before a grant is paid")
	var p1 := _plan(w, 1, "pool:a")
	var p2 := _plan(w, 2, "pool:a")
	var p3 := _plan(w, 3, "pool:a")
	for p in [p1, p2, p3]:
		Grants.apply(w, p)
	_plan(w, 4, "pool:a")   # made, no grant applied for
	check_eq(Grants.granted_plans(w), {p1: true, p2: true, p3: true}, "the three that accepted one")
	w.table("plan")[p2]["status"] = "SIGNED"
	w.table("plan")[p3]["status"] = "OPEN"
	Grants.reclaim(w, p1)
	w.table("plan")[p1]["status"] = "GIVEN_UP"
	var h := w.state_hash()
	check_eq(Grants.granted_plans(w), {p2: true}, "signed counts; opened (a plant now) and given up do not")
	check_eq(w.state_hash(), h, "reading it changes nothing")
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
	# a founder with money of its own pays from it before anything becomes a debt (Wilma, 60b)
	var p3 := _plan(w, 3, "pool:c")
	var a3 := int(Grants.apply(w, p3)["amount"])
	w.ledger.transfer(p3, Ledger.EXTERNAL, a3 - 400 * S, "TEST_SPENT", w.month)
	w.ledger.open_account("founder:3")
	w.ledger.transfer(Ledger.EXTERNAL, "founder:3", 300 * S, "TEST", w.month)
	var t3 := w.ledger.balance(CoreUtil.TREASURY)
	check_eq(Grants.reclaim(w, p3), 700 * S, "the plan's 400, then the founder's own 300")
	check_eq(w.ledger.balance("founder:3"), 0, "the founder's money first")
	check_eq(w.ledger.balance(CoreUtil.TREASURY), t3 + 700 * S, "into the treasury")
	var owed3 := 0
	for lid in w.peek("liability"):
		var l: Dictionary = w.peek("liability")[lid]
		if String(l["debtor"]) == "founder:3" and String(l["kind"]) == "GRANT":
			owed3 += int(l["amount"])
	check_eq(owed3, a3 - 700 * S, "only what neither reached is owed")
	check_eq(int(w.peek("grant")[p3]["repaid"]), 700 * S, "what came back refills the programme's sum")
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
