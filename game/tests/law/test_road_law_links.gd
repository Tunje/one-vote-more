extends TestCase
## Private roads, law side step 2 (planning/design-law-private-roads.md §4–§6) on Terra's links: the neglect ladder,
## step-in billing, revocation, takeover and reversion.

const RL := preload("res://sim/law/road_law.gd")
const Staff := preload("res://sim/staff/staff_ops.gd")


func _game() -> Simulation:
	var sim := EconSim.make(1, "BALANCED", {}, true)
	(sim.world.meta["on"] as Array).append_array([FreightRoads.FLAG, PrivateRoads.FLAG])
	for _m in 3:
		sim.step()
	return sim


func _firm(w: WorldState) -> String:
	for oid in CoreUtil.sorted_keys(w.peek("org")):
		if String(oid) != "gov" and String(w.peek("org")[oid].get("type", "")) == "PRIVATE":
			return String(oid)
	return ""


func _build(w: WorldState, owner: String, licence: String = "lic:1") -> String:
	var ds: Array = []
	for s in ColonyLayout.settlements(w):
		if not String(s["district"]) in ds:
			ds.append(String(s["district"]))
	var a := Commuting.district_node(w, ds[0])
	var b := Commuting.district_node(w, ds[1])
	return Transport.complete_road(w, {"id": "proj:t", "link": {"a": int(a["tile"]), "b": int(b["tile"]), "kind": "ROAD"},
		"owner": owner, "district": ds[0], "licence": licence})


func _econ(w: WorldState, v: int) -> void:
	var pm := Staff.pm_party(w)
	if w.table("party").has(pm):
		w.table("party")[pm]["positions"]["ECON_ROLE"] = v


func _wear(w: WorldState, lid: String, cond: int) -> void:
	w.table("transport")["links"][lid]["cond"] = cond


func _months(w: WorldState, n: int) -> void:
	for _i in n:
		w.month += 1
		RL.links_monthly(w)


func test_notice_then_a_market_government_leaves_it() -> void:
	var w := _game().world
	var firm := _firm(w)
	var lid := _build(w, firm)
	check(lid != "" and not Transport.private_link(w, lid).is_empty(), "a licensed private road")
	_econ(w, -80000)
	_wear(w, lid, 300)
	_months(w, RL.NOTICE_AFTER - 1)
	check(w.facts.query("LAW_ROAD_NEGLECT_NOTICE").is_empty(), "no notice yet")
	_months(w, 1)
	var n: Array = w.facts.query("LAW_ROAD_NEGLECT_NOTICE")
	check(n.size() == 1 and String(n[0]["data"]["link"]) == lid and not (n[0]["affected"]["districts"] as Array).is_empty(), "a public notice where the road runs")
	_months(w, RL.CURE_MONTHS)
	var u: Array = w.facts.query("LAW_PRIVATE_ROAD_UNENFORCED")
	check_eq(u.size(), 1, "the market government leaves it")
	check(u.size() == 1 and float(u[0]["responsible"][0]["share"]) == 0.8 and float(u[0]["responsible"][1]["share"]) == 0.2, "owner 0.8, government 0.2")
	var g := String(w.peek("road_watch")[lid]["greed"])
	check(g != "" and bool(w.peek("violation_track")[g]["unlawful"]) and String(w.peek("violation_track")[g]["kind"]) == "ROAD_NEGLECT", "neglect is a violation")
	_months(w, RL.CURE_MONTHS)
	check_eq(w.facts.query("LAW_PRIVATE_ROAD_UNENFORCED").size(), 2, "felt again every six months")
	_wear(w, lid, 800)
	_months(w, 1)
	check(int(w.peek("road_watch")[lid]["notice"]) < 0 and not bool(w.peek("violation_track")[g]["active"]), "repaired: the case closes")


func test_step_in_is_billed_to_the_owner() -> void:
	var w := _game().world
	var firm := _firm(w)
	var lid := _build(w, firm)
	_econ(w, 30000)
	_wear(w, lid, 300)
	_months(w, RL.NOTICE_AFTER + RL.CURE_MONTHS)
	var stepped := w.facts.query("LAW_ROAD_STEP_IN").size() == 1
	var left := w.facts.query("LAW_PRIVATE_ROAD_UNENFORCED").size() == 1
	check(stepped or left, "a centrist-to-state government steps in (or can't pay for it this year)")
	w.table("road_watch")[lid]["step_in"] = w.month
	Transport.add_public_money(w, lid, 50000)
	_months(w, 1)
	check_eq(RL.step_in_debt(w, lid), 50000, "the repair is owed by the owner")


func test_repeat_neglect_costs_the_licence_and_then_the_road() -> void:
	var w := _game().world
	var firm := _firm(w)
	var lid := _build(w, firm)
	_econ(w, 10000)
	_wear(w, lid, 300)
	_months(w, 1)
	w.table("road_watch")[lid]["notices"] = [w.month - 5]
	_months(w, RL.NOTICE_AFTER - 1 + RL.CURE_MONTHS)
	var r: Array = w.facts.query("LAW_ROAD_LICENCE_REVOKED")
	check_eq(r.size(), 1, "a second notice in two years: revoked")
	var v := RL.value(w, lid)
	check(v > 0, "the road has a value")
	_months(w, RL.REVOKED_SALE_MONTHS)
	check(Transport.private_link(w, lid).is_empty(), "unsold in a year: the state has it")
	var t: Array = w.facts.query("LAW_ROAD_TAKEN_OVER")
	check(t.size() == 1 and String(t[0]["data"]["mode"]) == "REVOKED" and String(t[0]["data"]["decided_by"]) == "CABINET", "taken over by the Cabinet")


func test_takeover_price_and_the_unlawful_expropriation() -> void:
	var w := _game().world
	var firm := _firm(w)
	var a := _build(w, firm)
	var v := RL.value(w, a)
	var pl := Transport.private_link(w, a)
	check_eq(v, int(pl["build_cost"]) * int(pl["cond"]) / 1000, "value: build cost × condition (state land under it)")
	Transport.add_public_money(w, a, v / 4)
	check_eq(RL.value(w, a), v - v / 4, "less the public money in it")
	var low := RL.take_over(w, a, "COMPULSORY", RL.value(w, a) / 2)
	check(bool(low["ok"]) and bool(low["unlawful"]) and bool(low["needs_cabinet"]), "half the value without consent: unlawful, and the Cabinet's")
	check(Transport.private_link(w, a).is_empty(), "the road is public")
	var b := _build(w, firm, "")
	var fair := RL.take_over(w, b, "COMPULSORY")
	check(bool(fair["ok"]) and not bool(fair["unlawful"]), "at value: lawful")
	check_eq(w.facts.query("LAW_ROAD_TAKEN_OVER").size(), 2, "both public")


func test_a_failed_owners_road_reverts() -> void:
	var w := _game().world
	var firm := _firm(w)
	var lid := _build(w, firm)
	_months(w, 1)
	w.table("org")[firm]["status"] = "LIQUIDATION"
	_months(w, RL.ESTATE_MONTHS)
	check(not Transport.private_link(w, lid).is_empty(), "the estate may still sell it")
	_months(w, 1)
	check(Transport.private_link(w, lid).is_empty(), "unsold: it reverts to the state")
	check_eq(w.facts.query("LAW_ROAD_REVERTED").size(), 1, "in public")


func test_flag_off_writes_nothing() -> void:
	var sim := EconSim.make(1, "BALANCED", {}, true)
	sim.step()
	RL.monthly(sim.world)
	check(sim.world.peek("road_watch").is_empty() and sim.world.peek("road_licence").is_empty(), "no road law without the flag")
	check(not LawOps_has_road_rules(sim.world), "no road rules")


func LawOps_has_road_rules(w: WorldState) -> bool:
	for r in w.peek("legal_rule").values():
		if String(r.get("source", "")) == "ROAD_LAW":
			return true
	return false
