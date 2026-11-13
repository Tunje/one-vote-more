extends TestCase
## Repeat offenders: a prior conviction for the same kind of offence within 5 years doubles the fine; a SERIOUS
## repeat suspends licences, a SEVERE repeat suspends them twice as long.

const F := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const JO := preload("res://sim/law/justice_ops.gd")


func _world() -> WorldState:
	var w := F.bare_world()
	LawOps.init_world(w)
	w.month = 100
	w.table("org")["org:1"] = {"id": "org:1", "pl_last": {"rev": 0}}
	w.table("licence")["lic:1"] = {"id": "lic:1", "holder_id": "org:1", "status": "ACTIVE"}
	for id in ["v:1", "v:2", "v:3"]:
		w.table("violation_track")[id] = {"company": "org:1", "kind": "SAFETY_CORNERS"}
	w.table("violation_track")["v:x"] = {"company": "org:1", "kind": "DUMPING"}
	return w


func test_second_conviction_of_same_kind_is_doubled() -> void:
	var w := _world()
	var first := JO._fine(w, "org:1", "SERIOUS", "v:1")
	check_eq(String(w.peek("licence")["lic:1"]["status"]), "ACTIVE", "a first SERIOUS conviction suspends nothing")
	w.month += 12
	check(JO.repeat_offender(w, "org:1", "v:2"), "same kind within 5 years")
	check(not JO.repeat_offender(w, "org:1", "v:x"), "another kind is not a repeat")
	var second := JO._fine(w, "org:1", "SERIOUS", "v:2")
	check_eq(second, 2 * first, "doubled")
	check_eq(String(w.peek("licence")["lic:1"]["status"]), "SUSPENDED", "a SERIOUS repeat suspends licences")
	check_eq(int(w.peek("licence")["lic:1"]["suspended_until"]), w.month + JO.SUSPEND_MONTHS, "for the normal term")


func test_old_convictions_lapse_and_severe_repeats_suspend_longer() -> void:
	var w := _world()
	JO._fine(w, "org:1", "SEVERE", "v:1")
	w.month += JO.REPEAT_WINDOW + 1
	check(not JO.repeat_offender(w, "org:1", "v:2"), "older than 5 years: lapsed")
	JO._fine(w, "org:1", "SEVERE", "v:2")
	w.table("licence")["lic:1"]["status"] = "ACTIVE"
	w.month += 6
	JO._fine(w, "org:1", "SEVERE", "v:3")
	check_eq(int(w.peek("licence")["lic:1"]["suspended_until"]), w.month + 2 * JO.SUSPEND_MONTHS, "SEVERE repeat: twice as long")
