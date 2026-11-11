extends TestCase
## M12 home world and charter politics (planning/spec-colony-v1.md §6–§8).

const EconSim := preload("res://sim/economy/econ_sim.gd")
const LQ := preload("res://sim/law/law_query.gd")
const CO := preload("res://sim/law/charter_ops.gd")


func _sim() -> Simulation:
	var sim: Simulation = EconSim.make(4, "BALANCED", {}, true)
	sim.run(60)
	return sim


func _st(w: WorldState) -> Dictionary:
	return w.table("pol")["state"]


func test_sovereignty_axis_and_burden_concern_exist() -> void:
	var w := _sim().world
	check(PolDefs.AXES.has("SOVEREIGNTY"), "axis")
	check(PolDefs.CONCERNS.has("COLONIAL_BURDEN"), "concern")
	for p in PartyLife.active(w):
		check(p["positions"].has("SOVEREIGNTY"), "%s has a sovereignty position" % p["name"])
	check(HomeWorld.burden(w) > 0, "the charter is a burden while a colony (%d)" % HomeWorld.burden(w))
	check(w.indicators.values.has("POL_COLONIAL_BURDEN"), "burden indicator published")


func test_ships_come_every_18_to_30_months() -> void:
	var sim := _sim()
	var w := sim.world
	var months: Array = []
	for _i in 120:
		sim.step()
		for f in w.facts.query("HOME_SHIP_CALLED", w.month - 1, w.month - 1) + w.facts.query("ECON_SHIP_ARRIVED", w.month - 1, w.month - 1):
			months.append(w.month - 1)
	check(months.size() >= 3 and months.size() <= 7, "about one ship every two years over 10 years (%d)" % months.size())
	for i in range(1, months.size()):
		var gap: int = months[i] - months[i - 1]
		check(gap >= 18 and gap <= 30, "gap %d months" % gap)


func test_petition_is_answered_on_the_next_ship() -> void:
	var w := _sim().world
	var st := _st(w)
	var h := HomeWorld.state(w)
	var pid := CO.petition_home(w, {"LAW_CHARTER_QUOTA_SHARE": 30})
	h["next_ship"] = w.month
	h["own_clock"] = true
	HomeWorld.monthly(w, st)
	var pt: Dictionary = LQ.sovereignty(w)["petitions"].get(pid, {})
	check(String(pt.get("status", "SENT")) != "SENT", "answered (%s)" % pt.get("status", "?"))


func test_independence_path_referendum_and_home_response() -> void:
	var w := _sim().world
	var st := _st(w)
	var h := HomeWorld.state(w)
	# an independence-minded colony and parliament
	for c in PolVoters.all(w):
		c["ideology"]["SOVEREIGNTY"] = 60 * 1000
	for p in PartyLife.active(w):
		p["positions"]["SOVEREIGNTY"] = 70 * 1000
	st["government"]["center"]["SOVEREIGNTY"] = 70 * 1000
	h["rejected_petitions"] = 2
	h["last_petition"] = w.month
	for c in PolVoters.all(w):
		c["sat"]["COLONIAL_BURDEN"] = 60000  # not petitioning now
	HomeWorld.monthly(w, st)
	check(int(h["referendum_month"]) > w.month, "parliament voted for independence; referendum scheduled")
	w.month = int(h["referendum_month"])
	HomeWorld.monthly(w, st)
	check_eq(String(LQ.sovereignty(w)["status"]), "INDEPENDENCE_DECLARED", "referendum carried")
	check_eq(w.facts.query("POL_INDEPENDENCE_REFERENDUM").size(), 1, "referendum fact")
	# the next ship brings the home world's answer
	h["next_ship"] = w.month + 1
	h["own_clock"] = true  # 88's real ships switch the clock off; simulate an arrival here
	w.month += 1
	HomeWorld.monthly(w, st)
	var status := String(LQ.sovereignty(w)["status"])
	check(status in ["INDEPENDENT", "AUTONOMY", "INDEPENDENCE_DECLARED"], "home world responded (%s, expedition %d)" % [status, h["expedition_month"]])
	if status == "INDEPENDENCE_DECLARED":
		check(int(h["expedition_month"]) > w.month, "an expedition is on its way")


func test_needy_home_world_raises_its_demands() -> void:
	var w := _sim().world
	var st := _st(w)
	var h := HomeWorld.state(w)
	var before := int(LQ.sovereignty(w)["quota_share"]) * 1000 - int(LQ.sovereignty(w)["price_pct"])
	h["need"] = 100
	var raised := 0
	for _i in 6:
		h["next_ship"] = w.month
		h["own_clock"] = true
		h["need"] = 100
		HomeWorld.monthly(w, st)
		w.month += 1
	raised = w.facts.query("HOME_DEMAND_RAISED").size()
	check(raised >= 1, "a desperate home world tightens the charter (%d)" % raised)
	var after := int(LQ.sovereignty(w)["quota_share"]) * 1000 - int(LQ.sovereignty(w)["price_pct"])
	check(after > before, "quota up or price down")
