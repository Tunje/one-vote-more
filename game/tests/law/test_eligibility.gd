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


## Over PopStore leaves (S1 API).
func test_eligible_total_over_leaves() -> void:
	var s := F.sim(5, true)
	var w := s.world
	var k1 := PopStore.seed_leaf(w, {"hb": "hb:d:1", "inc": "I2", "occ": "MINING", "status": "EMPLOYED", "arch": "LABOR", "eff": "e0"},
		300, {"age": {"Y": 120, "A": 180}})
	PopStore.seed_leaf(w, {"hb": "hb:d:1", "inc": "I2", "occ": "NONE", "status": "CHILD", "arch": "LABOR", "eff": "e0"},
		180, {"age": {"C": 180}})
	PopStore.seed_leaf(w, {"hb": "hb:d:2", "inc": "I3", "occ": "SERVICES", "status": "RETIRED", "arch": "STABILITY", "eff": "e0"},
		100, {"age": {"O": 100}})
	check_eq(LQ.eligible_total(w), 400, "adults only, never n (580)")
	check_eq(LQ.eligible_total(w, {"hb": "hb:d:1"}), 300, "per housing block")
	w.levers["LAW_VOTING_AGE"] = "16"
	check_eq(LQ.eligible_total(w), 420, "16: 2/18 of the 180 children")
	check_eq(LQ.eligible_voters(w, w.peek("pop")[k1]), 300, "single leaf")


## J22: a change that took effect less than 6 months before an election does not govern it.
func test_six_month_lead() -> void:
	var s := F.sim(5, true)
	var w := s.world
	w.levers["LAW_VOTING_AGE"] = "16"
	w.table("enactment")["enactment:x"] = {"id": "enactment:x", "lever": "LAW_VOTING_AGE", "value": "16", "status": "EFFECTIVE",
		"effective_month": 10, "prev_value": "18"}
	check_eq(LQ.eligibility(w)["voting_age"], 16, "in force now")
	check_eq(LQ.eligibility(w, 15)["voting_age"], 18, "election 5 months later: old law")
	check_eq(LQ.eligibility(w, 16)["voting_age"], 16, "6 months later: new law")
