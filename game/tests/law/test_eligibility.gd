extends TestCase
## M10 electoral eligibility levers and the per-leaf eligible-voter count.

const F := preload("res://tests/support/staff_fixture.gd")
const LQ := preload("res://sim/law/law_query.gd")
const SQ := preload("res://sim/staff/staff_query.gd")


func test_eligible_voters() -> void:
	var s := F.sim(5, true)
	var w := s.world
	var leaf := {"n": 1000, "age": {"C": 180, "Y": 240, "A": 300, "M": 160, "O": 120}, "recent": 100}
	check_eq(LQ.eligibility(w)["voting_age"], 18, "default 18")
	check_eq(LQ.eligible_voters(w, leaf), 820, "defaults: all adults, newcomers included")
	w.levers["LAW_VOTING_AGE"] = "16"
	check_eq(LQ.eligible_voters(w, leaf), 840, "16: plus 2/18 of children")
	w.levers["LAW_VOTING_AGE"] = "21"
	check_eq(LQ.eligible_voters(w, leaf), 760, "21: minus 3/12 of young adults")
	w.levers["LAW_VOTING_AGE"] = "18"
	w.levers["LAW_RESIDENCY_FOR_VOTE"] = 12
	check_eq(LQ.eligible_voters(w, leaf), 779, "12 months: half the newcomers (10% of 820 / 2 = 41) barred")
	w.levers["LAW_NONCITIZEN_VOTE"] = false
	check_eq(LQ.eligible_voters(w, leaf), 738, "no non-citizen vote: all newcomers barred")
	check(LQ.eligibility(w)["text"].find("newcomers") >= 0, "rule text")
	check_eq(LQ.eligible_voters(w, {"n": 0}), 0, "empty leaf")


func test_named_headcount() -> void:
	var s := F.sim(5, true)
	s.run(2)
	var h := SQ.named_headcount(s.world)
	check(h["public"] == h["political"] + h["civil"] + h["judges"], "public = officials + civil servants + judges: %s" % [h])
	check(h["civil"] > 0, "founding civil servants counted")
