extends TestCase
## T5 transport law (planning/spec-transport-v1.md T5): levers and their readings.

const F := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const TL := preload("res://sim/law/transport_law.gd")


func _world() -> WorldState:
	var w := F.bare_world()
	LawOps.init_world(w)
	w.values["ECON_W_REF"] = 1200000
	return w


func test_levers_registered() -> void:
	var w := _world()
	for id in ["LAW_FARE_CAP", "LAW_TRANSPORT_SAFETY", "LAW_TOUR_LICENSING", "LAW_ROAD_TOLL", "LAW_TRANSPORT_OPERATION"]:
		check(w.lever_defs.has(id) and String(w.lever_defs[id]["type"]) == "NUMBER" and bool(w.lever_defs[id]["legislative"]),
			id + " is a draftable NUMBER")


func test_defaults_are_neutral() -> void:
	var w := _world()
	check_eq(TL.capped_fare(w, 1000, 900), {"fare": 900, "subsidy": 100}, "cost-recovery cap: the wanted fare stands")
	check_eq(TL.road_toll(w), 0, "free roads")
	check_eq(TL.operation(w), "PUBLIC", "the CTA runs the routes")


func test_fare_cap_and_franchise() -> void:
	var w := _world()
	w.levers["LAW_FARE_CAP"] = 0
	check_eq(TL.capped_fare(w, 1000, 900), {"fare": 0, "subsidy": 1000}, "free transit: the treasury pays it all")
	w.levers["LAW_FARE_CAP"] = 50
	check_eq(int(TL.capped_fare(w, 1000, 900)["fare"]), 500, "half the cost")
	w.levers["LAW_TRANSPORT_OPERATION"] = 2
	check(not TL.fare_cap_binds(w, false) and TL.fare_cap_binds(w, true), "open market: the cap binds only the CTA")
	w.levers["LAW_TRANSPORT_OPERATION"] = 1
	check(TL.fare_cap_binds(w, false), "franchisees keep the CTA's fares")


func test_safety_tolls_and_tours() -> void:
	var w := _world()
	w.levers["LAW_TRANSPORT_SAFETY"] = 100
	check(TL.accident_factor(w) < 0.5 and TL.safety_cost_factor(w) > 1.1, "strict inspection: fewer accidents, dearer")
	w.levers["LAW_TOUR_LICENSING"] = 100
	check(TL.tour_approval_p(w) < 0.3, "few tour licences")
	w.levers["LAW_ROAD_TOLL"] = 5
	check_eq(TL.road_toll(w), 6000, "5 milli-W_ref per trip")
