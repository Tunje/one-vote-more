extends TestCase
## v4 review P0 (all 21 matured confidence-and-supply deals failed): deals are only struck on levers parliament can
## table, they reach the drafting agenda with priority, and the cabinet backs them. v5 had no minority governments,
## so this is a targeted test.


func _world() -> WorldState:
	var sim: Simulation = EconSim.make(2, "BALANCED", {}, true)
	sim.run(60)
	return sim.world


func test_deals_only_on_tableable_levers() -> void:
	var w := _world()
	check(not Coalition.feasible(w, "LAW_EVICTION_NOTICE_MONTHS", 1), "law-owned, non-legislative lever is not a valid price")
	var cur := int(w.levers.get("ECON_BENEFIT_DURATION", 12))
	check_eq(Coalition.feasible(w, "ECON_BENEFIT_DURATION", 1), cur < 60, "a LAW-level NUMBER lever is a valid price")


func test_deal_reaches_the_agenda_and_is_drafted() -> void:
	var w := _world()
	var st: Dictionary = w.table("pol")["state"]
	var g: Dictionary = st.get("government", {})
	check(not g.is_empty(), "a government exists")
	var partner := ""
	for pid in w.table("party"):
		if not (pid in g["members"]) and w.table("party")[pid]["status"] == "ACTIVE":
			partner = pid
			break
	check(partner != "", "an outside party exists")
	g["support"] = [partner]
	g["deals"] = [{"party": partner, "lever": "ECON_BENEFIT_DURATION", "dir": 1}]
	var agenda: Array = PoliticsProvider._agenda(g)
	var has := false
	for a in agenda:
		if a.get("deal", false) and a["lever"] == "ECON_BENEFIT_DURATION":
			has = true
	check(has, "the owed price is on the government's agenda")
	var cs := [{}, {}]
	for c in PolDefs.CONCERNS:
		cs[0][c] = 50000
		cs[1][c] = 111
	var clauses: Array = Legislature.propose(w, g["center"], cs[0], cs[1], agenda, "PARLIAMENT")
	var drafted := false
	for c in clauses:
		if c["lever"] == "ECON_BENEFIT_DURATION" and int(c["to"]) > int(c["from"]):
			drafted = true
	check(drafted, "the deal is drafted in the agreed direction (got %s)" % str(clauses.map(func(c): return c["lever"])))


func test_withdrawn_partner_drops_from_agenda() -> void:
	var g := {"agreement": [], "support": ["party:9"], "withdrawn": ["party:9"], "deals": [{"party": "party:9", "lever": "ECON_BENEFIT_DURATION", "dir": 1}]}
	check(PoliticsProvider._agenda(g).is_empty(), "a withdrawn partner's price is no longer owed")
