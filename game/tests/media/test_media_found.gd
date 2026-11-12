extends TestCase
## MEDIA v1 AI founding (planning/spec-media-v1.md §2.1, §15): parties, the union federation and large companies
## found papers when the market has room; one paper per owner; papers die with their owners.

const LawOps := preload("res://sim/law/law_ops.gd")

const WREF := 1200000


func _line(d: Dictionary) -> Dictionary:
	var l := {}
	for ax in PolDefs.AXES:
		l[ax] = int(d.get(ax, 0))
	return l


func _world(voters: int = 2000) -> WorldState:
	var w := WorldState.new(7)
	LawOps.init_world(w)
	w.month = 30
	w.values["ECON_W_REF"] = WREF
	var sal := {}
	for c in PolDefs.CONCERNS:
		sal[c] = 100
	w.table("cell")["c1"] = {"key": "c1", "district": "district:1", "band": "MID", "pop": voters, "occ": "SERVICES",
		"ideology": _line({}), "salience": sal}
	Media.ensure_founding(w)
	return w


func _party(w: WorldState, pid: String, support: int, cash_wref: float, integrity: int = 80) -> void:
	w.table("party")[pid] = {"id": pid, "name": "Labour", "status": "ACTIVE", "support": support, "seats": 20,
		"positions": _line({"LABOR": 50000}), "leader": {"name": "X", "integrity": integrity}}
	var acc := "party:" + pid
	if not w.ledger.has_account(acc):
		w.ledger.open_account(acc)
	w.ledger.transfer(Ledger.EXTERNAL, acc, int(cash_wref * WREF), "seed", w.month)


func _all(v: int) -> Dictionary:
	var d := {}
	for ax in PolDefs.AXES:
		d[ax] = v
	return d


func _months(w: WorldState, n: int) -> void:
	for i in n:
		w.month += 1
		Media._found_ai(w)


func test_party_founds_a_paper_when_rich_and_popular() -> void:
	var w := _world()
	_party(w, "party:1", 20000, 10.0, 80)
	_party(w, "party:2", 20000, 2.0)      # too poor
	_party(w, "party:3", 3000, 50.0)      # too small
	w.meta["media_found_scale"] = 100.0
	_months(w, 3)
	check_eq(Media.owned_by(w, {"kind": "PARTY", "id": "party:1"}).size(), 1, "the rich, popular party founds one")
	check(Media.owned_by(w, {"kind": "PARTY", "id": "party:2"}).is_empty(), "not without funds")
	check(Media.owned_by(w, {"kind": "PARTY", "id": "party:3"}).is_empty(), "not below 8% in the polls")
	var o := Media.outlet(w, Media.owned_by(w, {"kind": "PARTY", "id": "party:1"})[0])
	check_eq(int(o["line"]["LABOR"]), 50000, "the party's line")
	check(absf(float(o["ethics"]) - 0.8) < 0.001, "ethics follows the leader's integrity")
	check_eq(w.ledger.balance("media:" + String(o["id"])), 3 * WREF, "endowed from the party account")
	check_eq(w.ledger.balance("party:party:1"), 7 * WREF, "paid by the party")
	check(not w.facts.query("MEDIA_OUTLET_FOUNDED").filter(func(f): return f["data"]["outlet"] == o["id"]).is_empty(), "a public fact")


func test_one_paper_per_owner_and_market_room() -> void:
	var w := _world(1000)     # room for 1 + 1000/500 = 3 papers: the Gazette + 2
	for i in 4:
		_party(w, "party:%d" % (i + 1), 20000, 10.0)
	w.meta["media_found_scale"] = 100.0
	_months(w, 12)
	check_eq(Media.outlets(w).size(), 3, "the market caps entry")
	check_eq(Media.market_room(w), 0, "no room left")
	for i in 4:
		check(Media.owned_by(w, {"kind": "PARTY", "id": "party:%d" % (i + 1)}).size() <= 1, "at most one per owner")


func test_at_most_one_new_paper_a_month() -> void:
	var w := _world()
	for i in 3:
		_party(w, "party:%d" % (i + 1), 20000, 10.0)
	w.meta["media_found_scale"] = 100.0
	_months(w, 1)
	check_eq(Media.outlets(w).size(), 2, "one new paper this month")


func test_no_private_press_in_the_first_year_or_when_banned() -> void:
	var w := _world()
	_party(w, "party:1", 20000, 10.0)
	w.meta["media_found_scale"] = 100.0
	w.month = 2
	Media._found_ai(w)
	check_eq(Media.outlets(w).size(), 1, "first year: Gazette only")
	w.month = 30
	w.levers["LAW_PARTY_PRESS"] = false
	_months(w, 3)
	check_eq(Media.outlets(w).size(), 1, "party press banned")


func test_union_federation_founds_the_worker() -> void:
	var w := _world()
	w.table("econ")["s"] = {"union": {"density": {"MINING": 45000, "PUBLIC_SECTOR": 48000, "SERVICES": 12000}}}
	w.meta["media_found_scale"] = 100.0
	_months(w, 2)
	var ids := Media.owned_by(w, {"kind": "UNION", "id": "union:fed"})
	check_eq(ids.size(), 1, "the federation founds a paper")
	var o := Media.outlet(w, ids[0])
	check(int(o["line"]["LABOR"]) == 40000 and int(o["line"]["REDISTRIBUTION"]) == 30000, "line pulled toward labour")
	var w2 := _world()
	w2.table("econ")["s"] = {"union": {"density": {"MINING": 45000, "SERVICES": 12000}}}
	w2.meta["media_found_scale"] = 100.0
	_months(w2, 3)
	check(Media.owned_by(w2, {"kind": "UNION", "id": "union:fed"}).is_empty(), "one strong occupation is not enough")


func _company(w: WorldState, oid: String, cash_wref: float, staff: int, type: String = "PRIVATE") -> void:
	w.table("org")[oid] = {"id": oid, "name": "Basalt Processing Ltd", "type": type, "status": "ACTIVE", "is_contractor": true,
		"crew": {"CREW": {"G": staff}}}
	w.ledger.open_account("co:" + oid)
	w.ledger.transfer(Ledger.EXTERNAL, "co:" + oid, int(cash_wref * WREF), "seed", w.month)


func test_bad_press_pushes_a_company_to_found_a_paper() -> void:
	var w := _world()
	_company(w, "org:1", 300.0, 80000)
	_company(w, "org:2", 300.0, 80000)
	_company(w, "org:3", 300.0, 80000, "PUBLIC_ENTERPRISE")
	_company(w, "org:4", 300.0, 10000)
	for i in 2:
		w.add_fact({"type": "COMP_WORKPLACE_ACCIDENT", "owner": "t", "subjects": [{"kind": "COMPANY", "id": "org:2"}],
			"responsible": [{"actor": {"kind": "COMPANY", "id": "org:2"}, "share": 1.0}], "impact": {"SAFETY": -3},
			"magnitude": 50, "visibility": "PUBLIC"})
	var by := {}
	for c in Media.founding_candidates(w):
		by[String(c["owner"]["id"])] = c
	check(by.has("org:1") and by.has("org:2"), "large private companies are candidates")
	check(not by.has("org:3"), "public enterprises do not found papers")
	check(not by.has("org:4"), "small firms do not")
	check(float(by["org:2"]["p"]) > 5.0 * float(by["org:1"]["p"]), "bad press makes it far likelier (%s vs %s)" % [by["org:2"]["p"], by["org:1"]["p"]])
	check_eq(String(by["org:2"]["opts"]["name"]), "The Basalt Courier", "named after the firm")
	check_eq(Media.bad_press_12m(w, "org:2"), 2, "public bad-press query (Bob's firm AI)")
	check_eq(Media.bad_press_12m(w, "org:1"), 0, "no bad press")
	w.table("org").erase("org:1")
	w.meta["media_found_scale"] = 1000.0
	_months(w, 1)
	var ids := Media.owned_by(w, {"kind": "COMPANY", "id": "org:2"})
	check_eq(ids.size(), 1, "the firm founds its paper")
	check_eq(String(w.peek("org")["org:2"].get("media_out", "")), String(ids[0]), "the org records its paper (M4 asset)")
	check_eq(w.ledger.balance("co:org:2"), 280 * WREF, "20 W_ref endowment from the firm")


func test_licensing_refuses_the_opposition() -> void:
	var w := _world()
	_party(w, "party:1", 20000, 10.0)
	w.table("party")["party:2"] = {"id": "party:2", "name": "Gov", "status": "ACTIVE", "support": 0, "seats": 80,
		"positions": _line(_all(-60000))}
	w.table("pol")["state"] = {"government": {"members": ["party:2"]}}
	w.levers["LAW_PRESS_LICENSING"] = "LICENCE"
	check(not Media.licensed(w, {"kind": "PARTY", "id": "party:1"}), "an opposition party gets no licence")
	check(Media.licensed(w, {"kind": "PARTY", "id": "party:2"}), "the government's own party does")


func test_paper_dies_with_its_owner() -> void:
	var w := _world()
	_party(w, "party:1", 20000, 10.0)
	w.meta["media_found_scale"] = 100.0
	_months(w, 2)
	var id: String = Media.owned_by(w, {"kind": "PARTY", "id": "party:1"})[0]
	w.table("party")["party:1"]["status"] = "DISSOLVED"
	Media._close_orphans(w)
	check_eq(String(Media.outlet(w, id)["status"]), "CLOSED", "closed when the party dissolves")
	check_eq(Media.outlets(w).size(), 1, "the Gazette remains")
