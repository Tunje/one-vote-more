extends TestCase
## A45 W6 waste law (planning/spec-waste-v1.md W6): levers, readers neutral at the defaults, the standard drives
## environmental inspections and dumping fines, burial law by direction.

const F := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const JO := preload("res://sim/law/justice_ops.gd")
const WL := preload("res://sim/law/waste_law.gd")

const LEVERS := ["LAW_WASTE_STANDARD", "LAW_RECYCLING_TARGET", "LAW_LANDFILL_TAX", "LAW_SEWAGE_STANDARD",
	"LAW_BURIAL_RULES", "LAW_SANITATION_FEE"]


func _world() -> WorldState:
	var w := F.bare_world()
	LawOps.init_world(w)
	return w


func test_levers_are_draftable_and_neutral_by_default() -> void:
	var w := _world()
	for id in LEVERS:
		check(w.lever_defs.has(id) and String(w.lever_defs[id]["type"]) == "NUMBER" and bool(w.lever_defs[id]["legislative"]),
			id + " is a draftable NUMBER")
	check_eq(WL.inspection_factor(w), 1.0, "inspections as before")
	check_eq(WL.disposal_cost_factor(w), 1.0, "disposal cost as before")
	check_eq(WL.disposal_pollution_factor(w), 1.0, "pollution as before")
	check_eq(WL.sewage_cost_factor(w), 1.0, "treatment cost as before")
	check(WL.recycling_target_pm(w) == 0 and WL.landfill_tax_per_tonne(w) == 0 and WL.sanitation_fee_pm(w) == 0, "no target, tax or fee")
	check_eq(WL.cremation_share_pm(w, 300), 300, "families choose")


func test_a_strict_standard_costs_more_and_pollutes_less() -> void:
	var w := _world()
	w.levers["LAW_WASTE_STANDARD"] = 100
	check(WL.disposal_cost_factor(w) > 1.5 and WL.disposal_pollution_factor(w) < 0.5, "strict: dear and clean")
	w.levers["LAW_WASTE_STANDARD"] = 0
	check(WL.disposal_cost_factor(w) < 1.0 and WL.disposal_pollution_factor(w) > 1.4, "lax: cheap and dirty")
	w.levers["LAW_LANDFILL_TAX"] = 10
	check_eq(WL.landfill_tax_per_tonne(w), 10 * int(w.values.get("ECON_W_REF", 1200000)) / 1000, "10 milli-W_ref a tonne")


func test_the_standard_drives_env_inspections() -> void:
	var w := _world()
	var base := float(JO.detect_ctx(w)["ENV"])
	w.levers["LAW_WASTE_STANDARD"] = 90
	check(float(JO.detect_ctx(w)["ENV"]) > 1.9 * base, "a strict law: twice the inspections")
	w.levers["LAW_WASTE_STANDARD"] = 0
	check_eq(float(JO.detect_ctx(w)["ENV"]), 0.5 * base, "no standard: half")


func test_dumping_fines_follow_the_standard() -> void:
	var w := _world()
	w.table("org")["org:1"] = {"id": "org:1", "pl_last": {"rev": 0}}
	w.table("violation_track")["v:d"] = {"kind": "DUMPING"}
	w.table("violation_track")["v:s"] = {"kind": "SAFETY_CORNERS"}
	var dump0 := JO._fine(w, "org:1", "SERIOUS", "v:d")
	var safe0 := JO._fine(w, "org:1", "SERIOUS", "v:s")
	check_eq(dump0, safe0, "the default: dumping fined like any serious violation")
	w.levers["LAW_WASTE_STANDARD"] = 90
	check_eq(JO._fine(w, "org:1", "SERIOUS", "v:d"), int(round(float(dump0) * WL.dumping_fine_factor(w))), "strict: dearer")
	check_eq(JO._fine(w, "org:1", "SERIOUS", "v:s"), safe0, "other violations unchanged")


func test_burial_law_by_direction() -> void:
	var w := _world()
	w.levers["LAW_BURIAL_RULES"] = -100
	check_eq(WL.cremation_share_pm(w, 200), 1000, "cremation required")
	w.levers["LAW_BURIAL_RULES"] = 60
	check_eq(WL.cremation_share_pm(w, 700), 400, "burial for at least 60%: cremation capped at 40%")
	check_eq(int(WL.burial(w)["strictness"]), 60, "strictness for the offended side")
	check(float(w.lever_defs["LAW_BURIAL_RULES"]["ideology"]["INSTITUTIONS"]) < 0.0, "the order pole leans to burial")
