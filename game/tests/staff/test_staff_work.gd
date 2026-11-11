extends TestCase
## Staff work model: formula constants (spec-staff §2), ST1, ST2, ST4, ST6.

const F := preload("res://tests/support/staff_fixture.gd")
const Ops := preload("res://sim/staff/staff_ops.gd")
const W := preload("res://sim/staff/work_model.gd")
const RG := preload("res://sim/staff/roster_gen.gd")
const D := preload("res://sim/staff/staff_data.gd")


func test_formula_constants() -> void:
	check(is_equal_approx(W.speed_mult(50), 1.0), "V(50)=1")
	check(is_equal_approx(W.speed_mult(100), 1.4), "V(100)=1.4")
	check(is_equal_approx(W.suit_mult(50, []), 1.0), "K(50)=1")
	check(is_equal_approx(W.suit_mult(0, []), 0.4), "K floor")
	check(is_equal_approx(W.suit_mult(100, []), 1.6), "K(100)=1.6")
	check(is_equal_approx(W.suit_mult(0, ["ADAPTABLE"]), 0.85), "Adaptable floor")
	check(is_equal_approx(W.talent_t(["SKILLED_MEDIATOR", "CAUTIOUS_PLANNER", "INDUSTRIAL_EXPERT"], ["NEGOTIATION", "INDUSTRY"]), 1.35), "T product")
	check(W.talent_t(["SKILLED_MEDIATOR", "INDUSTRIAL_EXPERT", "FIELD_SUPERVISOR"], ["NEGOTIATION", "INDUSTRY", "SUPERVISION"]) <= 1.5, "T cap")
	# coordinated: n*(0.5 mean + 0.5 min)*C
	check(is_equal_approx(W.team_coordinated([10.0, 20.0], [], false), 2.0 * (7.5 + 5.0)), "coordinated 2")
	check(is_equal_approx(W.team_coordinated([10.0, 10.0, 10.0], [4.0], true), 3.0 * 10.0 * 1.05 + 4.0), "coordinated 3 + organizer + optional")
	check(is_equal_approx(W.defect_probability(40), 0.2), "defect p at Q40")
	check(is_equal_approx(W.poll_moe_pp(70), 2.9), "poll MoE at Q70")


## ST4: Sainte-Laguë 49/28/19 -> 5/3/2; a tiny partner still gets 1; single party gets 10.
func test_st4_seat_allocation() -> void:
	var a := Ops.allocate_seats({"A": 49, "B": 28, "C": 19}, ["A", "B", "C"])
	check_eq(a, {"A": 5, "B": 3, "C": 2}, "49/28/19")
	var b := Ops.allocate_seats({"A": 70, "B": 3}, ["A", "B"])
	check_eq(b, {"A": 9, "B": 1}, "min 1")
	check_eq(Ops.allocate_seats({"A": 80}, ["A"]), {"A": 10}, "single party")


## ST2: 3-clause bill, typical 2-person team + 1 optional, completes in 3 +/- 1 months.
func test_st2_bill_three_months() -> void:
	var w := F.bare_world(3)
	var drafter := F.add(w, "CIVIL", {"LAW": 76, "ADMIN": 55}, 42, 100)
	var lead := F.add(w, "POLITICAL", {"ECON": 68, "POLI": 35}, 67, 100)
	var coord := F.add(w, "POLITICAL", {"POLI": 65}, 67, 100)
	var r := Ops.create_task(w, "STAFF_T_DRAFT_BILL", {"clauses": 3, "domain": "ECON"}, Ops.GOV)
	check(r["ok"], "create")
	check_eq(Ops.task(w, r["id"])["work_required"], 90000, "90 WU")
	check(Ops.assign(w, r["id"], 0, drafter)["ok"], "assign drafter")
	check(Ops.assign(w, r["id"], 1, lead)["ok"], "assign lead")
	check(Ops.assign(w, r["id"], 2, coord)["ok"], "assign coordinator")
	var months := 0
	while Ops.task(w, r["id"])["status"] == "ACTIVE" and months < 12:
		F.work_month(w)
		months += 1
	check(months >= 2 and months <= 4, "3-clause bill took %d months" % months)
	var t := Ops.task(w, r["id"])
	check(t["outputs"].has("draft_quality"), "draft_quality output")
	check_eq(t["outputs"]["defects"].size(), 3, "defect per clause")
	check_eq(Ops.person(w, drafter)["assignment_id"], "", "staff released")


## ST6: Rush finishes faster than Careful with a higher defect rate (seeded statistics).
func test_st6_rush_vs_careful() -> void:
	var res := {}
	for mode in ["RUSH", "CAREFUL"]:
		var months := 0
		var defects := 0
		for seed_value in 60:
			var w := F.bare_world(100 + seed_value)
			var d := F.add(w, "CIVIL", {"LAW": 62, "ADMIN": 50}, 45, 70)
			var l := F.add(w, "POLITICAL", {"ECON": 60, "POLI": 40}, 65, 60)
			var r := Ops.create_task(w, "STAFF_T_DRAFT_BILL", {"clauses": 3, "domain": "ECON"}, Ops.GOV)
			Ops.assign(w, r["id"], 0, d)
			Ops.assign(w, r["id"], 1, l)
			Ops.set_mode(w, r["id"], mode)
			var m := 0
			while Ops.task(w, r["id"])["status"] == "ACTIVE" and m < 24:
				F.work_month(w)
				m += 1
			months += m
			defects += Ops.task(w, r["id"])["outputs"]["defects"].count(true)
		res[mode] = {"months": months, "defects": defects}
	check(res["RUSH"]["months"] < res["CAREFUL"]["months"], "rush faster: %s" % [res])
	check(res["RUSH"]["defects"] > res["CAREFUL"]["defects"], "rush more defects: %s" % [res])


## ST1: 1,000 seeded rosters; the founding slate is staffable in 100%, with <= 1% needing fallback.
func test_st1_roster_staffability() -> void:
	var fallbacks := 0
	var failures := 0
	for seed_value in 1000:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7919 * (seed_value + 1)
		var r := RG.generate_founding(rng, 0)
		if r["fallback"]:
			fallbacks += 1
		var people: Array = r["civil"] + r["candidates"].slice(0, D.POLITICAL_SEATS)
		if not RG.slate_staffable(people, D.FOUNDING_SLATE):
			failures += 1
	check_eq(failures, 0, "unstaffable rosters")
	check(fallbacks <= 10, "fallbacks %d > 1%%" % fallbacks)


func test_bench_minimums() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 50:
		var bench := RG.generate_bench(rng, 6, 0)
		RG.enforce_bench_minimums(bench)
		for skill in D.BENCH_REQUIRED:
			var best := 0
			for p in bench:
				best = maxi(best, int(p["skills"][skill]))
			check(best >= 50, "bench lacks %s" % skill)
