extends TestCase
## E171 law side (planning/design-charter-quota-law.md): quota goods in quota_due, the home world's designation,
## the delivery record (real burden), the port-full rule (excused once, then the government's breach), and the debt
## epoch on recognition / autonomy.

const F := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const CO := preload("res://sim/law/charter_ops.gd")


func _world(on: bool = true) -> WorldState:
	var w := F.bare_world()
	LawOps.init_world(w)
	CO.ensure_m12(w)
	w.month = 40
	if on:
		w.meta["on"] = ["E171"]
	return w


func _report(sr: String, due: int, delivered: int) -> Dictionary:
	return {"goods": {"MINERAL": {"due": due, "delivered": delivered, "owed": due - delivered, "short_reason": sr}},
		"paid": 3500, "market_value": 10000}


func test_quota_goods_default_and_designation() -> void:
	var w := _world()
	var q := CO.quota_due(w)
	check(bool(q["due"]) and q["goods"] == ["COMPONENT", "MATERIAL", "MINERAL"], "the building goods by default (%s)" % [q])
	check(bool(CO.home_world_designate(w, "FINE_FOOD", true)["ok"]), "the home world adds a good")
	check(bool(CO.home_world_designate(w, "COMPONENT", false)["ok"]), "and drops one")
	check_eq(CO.quota_due(w)["goods"], ["FINE_FOOD", "MATERIAL", "MINERAL"], "the charter's list")
	check_eq(w.facts.query("LAW_CHARTER_QUOTA_GOOD", 0, w.month).size(), 2, "public")
	CO.recognise_independence(w)
	check(CO.quota_due(w)["goods"].is_empty() and not bool(CO.home_world_designate(w, "MINERAL", true)["ok"]), "none after independence")


func test_delivery_record_and_burden() -> void:
	var w := _world()
	var fid := CO.record_delivery(w, _report("", 100, 100))
	check(fid != "", "a delivery fact")
	var d: Dictionary = w.facts.get_fact(fid)["data"]
	check_eq(int(d["burden"]), 6500, "market value minus the charter payment")
	check_eq(int(CO.sov(w)["last_quota"]["burden"]), 6500, "kept for the home world")
	var off := _world(false)
	check_eq(CO.record_delivery(off, _report("", 100, 100)), "", "nothing while E171 is off")


func test_full_port_is_excused_once_then_the_governments_breach() -> void:
	var w := _world()
	CO.record_delivery(w, _report("HOLD_FULL", 100, 60))
	check(not CO.evasion_proven(w), "a full hold is the home world's own ship")
	CO.record_delivery(w, _report("PORT_FULL", 100, 70))
	check(not CO.evasion_proven(w), "a full port is excused the first time")
	w.month += 24
	CO.record_delivery(w, _report("PORT_FULL", 100, 70))
	var ev := w.facts.query("HOME_EVASION_FOUND", 0, w.month)
	check(ev.size() == 1 and String(ev[0]["data"]["cause"]) == "NO_STORAGE", "then the colony failed to store it")
	check_eq(String(ev[0]["responsible"][0]["actor"]["kind"]), "GOVERNMENT", "the party to the charter answers")
	check(CO.evasion_proven(w) and bool(CO.home_sanction(w, "FINE")["lawful"]), "a home fine is now lawful")


func test_refusal_suspends_and_epochs_cancel_debt() -> void:
	var w := _world()
	CO.refuse_quota(w)
	var q := CO.quota_due(w)
	check(not bool(q["due"]) and String(q["reason"]) == "REFUSAL", "suspended while refusing")
	var fid := CO.record_delivery(w, _report("REFUSAL", 100, 0))
	check(bool(w.facts.get_fact(fid)["data"]["refusal"]), "the empty ship is on record")
	var e0 := int(q["epoch"])
	CO.restore_charter(w, {"LAW_CHARTER_QUOTA_SHARE": 60}, false)
	check_eq(int(CO.quota_due(w)["epoch"]), e0, "a restored charter keeps the debt")
	CO.grant_autonomy(w, {"LAW_CHARTER_QUOTA_SHARE": 20})
	check_eq(int(CO.quota_due(w)["epoch"]), e0 + 1, "autonomy cancels it")
	CO.recognise_independence(w)
	check_eq(int(CO.quota_due(w)["epoch"]), e0 + 2, "so does recognition")
