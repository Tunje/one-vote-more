extends TestCase
## ST8 (30-year soak), determinism, save/load mid-task, and monthly reports (S-K).

const F := preload("res://tests/support/staff_fixture.gd")
const Ops := preload("res://sim/staff/staff_ops.gd")
const LawProvider := preload("res://sim/law/law_provider.gd")
const StaffProvider := preload("res://sim/staff/staff_provider.gd")
var SAVE_PATH := F.save_path("staff.sav")


## ST8: 360 months with autoplay: no invariant violations; civil service always 10 (vacancy <= 2 months).
func test_st8_thirty_year_soak() -> void:
	var s := F.sim(11, true)
	var max_vacancy := 0
	var errors: Array = []
	for m in 360:
		s.step()
		var errs := Ops.check_invariants(s.world)
		if not errs.is_empty() and errors.size() < 5:
			errors.append("month %d: %s" % [m, errs])
		for rid in s.world.table("recruitment"):
			var rec: Dictionary = s.world.table("recruitment")[rid]
			if rec["status"] == "OPEN":
				max_vacancy = maxi(max_vacancy, s.world.month - int(rec["opened_month"]))
	check(errors.is_empty(), "invariants: %s" % [errors])
	check(max_vacancy <= 2, "max vacancy %d months" % max_vacancy)
	# (hire facts are magnitude 5 and get compacted after 24 months, so count filled recruitments)
	var hires := s.world.table("recruitment").values().filter(func(r): return r["status"] == "FILLED").size()
	check(hires >= 3 and hires <= 20, "civil replacements over 30 years: %d" % hires)
	check(not s.world.meta.has("violations"), "kernel violations")


## S-K: every pooled official reports each month; routine reports older than 12 months are compressed.
func test_monthly_reports() -> void:
	var s := F.sim(5, true)
	s.step()
	var month0 := s.world.table("staff_report").values().filter(func(r): return r["month"] == 0)
	check_eq(month0.size(), 20, "20 reports in month 1")
	for _i in 20:
		s.step()
	var old := s.world.table("staff_report").values().filter(func(r):
		return r["month"] < s.world.month - 13 and (r["category"] == "ROUTINE" or r["category"] == "AVAILABLE"))
	check(old.is_empty(), "old routine reports compressed")
	check(not Ops.state(s.world)["report_counts"].is_empty(), "counts kept")


func test_deterministic() -> void:
	var a := F.sim(21, true)
	var b := F.sim(21, true)
	a.run(60)
	b.run(60)
	check_eq(a.world.state_hash(), b.world.state_hash(), "same seed same state")


func test_save_load_mid_task() -> void:
	var ref := F.sim(31, true)
	ref.run(2)   # slate tasks staffed and mid-progress
	var active := ref.world.table("task").values().filter(func(t): return t["status"] == "ACTIVE" and t["progress"] > 0)
	check(not active.is_empty(), "a finite task is mid-progress")
	check_eq(SaveIO.save(ref, SAVE_PATH), OK, "save")
	ref.run(24)
	var loaded := Simulation.new(0, [LawProvider.new(), StaffProvider.new()])
	check_eq(SaveIO.load_into(loaded, SAVE_PATH), OK, "load")
	loaded.run(24)
	check_eq(loaded.world.state_hash(), ref.world.state_hash(), "continued identically")
