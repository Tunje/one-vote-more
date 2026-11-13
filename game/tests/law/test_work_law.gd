extends TestCase
## Workload law step 1 (user ruling on lean staffing and stress): levers and readers, neutral until Bob reports.

const F := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const WK := preload("res://sim/law/work_law.gd")
const JO := preload("res://sim/law/justice_ops.gd")


func _world() -> WorldState:
	var w := F.bare_world()
	LawOps.init_world(w)
	return w


func test_levers_and_frontier_defaults() -> void:
	var w := _world()
	for id in ["LAW_MAX_WORKING_HOURS", "LAW_STAFFING_RATIOS", "LAW_WORK_INSPECTORATE_BUDGET"]:
		check(w.lever_defs.has(id) and String(w.lever_defs[id]["type"]) == "NUMBER" and bool(w.lever_defs[id]["legislative"]), id + " is draftable")
	check_eq(WK.max_hours(w), 60, "a frontier colony works long hours")
	check_eq(WK.ratio_mode(w), "NONE", "no ratios at the founding")
	check_eq(WK.required_staff(w, "HEALTH", 1500), 0, "no ratio law: nothing required")
	check(int(w.lever_defs["LAW_MAX_WORKING_HOURS"]["concerns"]["JOBS"]) > 0, "longer hours: the market side's jobs argument")
	check(int(w.lever_defs["LAW_WORK_INSPECTORATE_BUDGET"]["concerns"]["GOVERNANCE"]) < 0, "the authority costs budget")


func test_five_doctors_for_1500_people() -> void:
	var w := _world()
	w.levers["LAW_STAFFING_RATIOS"] = 1
	var g := WK.staffing_check(w, "HEALTH", 1500, 5)
	check(g["required"] == 5 and g["short"] == 0 and not g["unlawful"], "1:300: five doctors meet the ratio exactly (%s)" % [g])
	var c := WK.staffing_check(w, "CHILDCARE", 100, 8)
	check(c["short"] == 5 and not c["unlawful"], "guidance: short but lawful (%s)" % [c])
	w.levers["LAW_STAFFING_RATIOS"] = 2
	check(WK.staffing_check(w, "CHILDCARE", 100, 8)["unlawful"], "binding: unlawful")
	w.levers["LAW_MAX_WORKING_HOURS"] = 45
	check_eq(WK.overtime(w, 52), 7, "seven hours over a 45-hour week")
	check(WK.stress_accident(1400) and not WK.stress_accident(1100), "stress accidents from 130% workload")


func test_lean_running_is_conduct_the_authority_inspects() -> void:
	var w := _world()
	LawOps.ensure_m11_rules(w)
	LawOps.ensure_work_rules(w)
	var ow := LawOps.record_greed(w, "org:1", {"kind": "OVERWORK", "facility": "fac:1", "saving": 1000})
	check(bool(w.peek("violation_track")[ow]["unlawful"]), "hours over the maximum: unlawful")
	check_eq(String(w.peek("violation_track")[ow]["channel"]), "WORK", "the work-environment authority's case")
	var us := LawOps.record_greed(w, "org:2", {"kind": "UNDERSTAFFING", "facility": "fac:2", "saving": 1000})
	check(not bool(w.peek("violation_track")[us]["unlawful"]), "no binding ratios: understaffing is lawful (harmful)")
	w.levers["LAW_STAFFING_RATIOS"] = 2
	var us2 := LawOps.record_greed(w, "org:3", {"kind": "UNDERSTAFFING", "facility": "fac:3", "saving": 1000})
	check(bool(w.peek("violation_track")[us2]["unlawful"]), "binding ratios: unlawful")
	var base := float(JO.detect_ctx(w)["WORK"])
	w.levers["LAW_WORK_INSPECTORATE_BUDGET"] = 9000
	check_eq(float(JO.detect_ctx(w)["WORK"]), 3.0 * base, "a bigger authority makes more inspections")
