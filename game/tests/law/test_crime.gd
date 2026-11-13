extends TestCase
## P1a crime model (planning/design-p1-crime-police.md §1): Swedish-level rates at full employment, a slump and hunger
## raise them, police cuts lower clearance and leave districts unpatrolled, crime waves, opt-in switch.

const F := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const CR := preload("res://sim/law/crime.gd")


## 10,000 residents in one district: 6,000 in the labour force, `unemp_pm` of them out of work.
func _world(unemp_pm: int = 40, seed: int = 7) -> WorldState:
	var w := F.bare_world(seed)
	LawOps.init_world(w)
	w.month = 10
	w.meta["on"] = ["CRIME"]
	w.table("econ")["s"] = {"food_shortfall": 0}
	var lf := 6000
	var emp := lf - lf * unemp_pm / 1000
	_hh(w, "hb:1|MID", "d:1", "MID", lf, emp, 4000, 3000)
	w.table("district")["d:1"] = {"households": 4000000, "units": 4000000}
	return w


func _hh(w: WorldState, gid: String, d: String, band: String, lf: int, emp: int, other: int, wage_pp: int) -> void:
	w.table("hh")[gid] = {"id": gid, "district": d, "band": band, "lf": lf * 1000, "nonpart": other * 1000, "retired": 0,
		"children": 0, "owners": 0, "emp": {"SERVICES": emp * 1000}, "income": {"wages": emp * wage_pp}}


func _run(w: WorldState, months: int) -> void:
	for i in months:
		w.month += 1
		CR.monthly(w)


func test_off_by_default() -> void:
	var w := _world()
	w.meta.erase("on")
	_run(w, 6)
	check(CR.crime_rate(w).is_empty(), "nothing without the switch")


func test_reference_rates_are_swedish_level() -> void:
	var w := _world()
	_run(w, 12)
	var wl_sum := 0
	for i in 12:                  # a single month's workload is noisy (fraud cases are 40 hours each): average a year
		_run(w, 1)
		wl_sum += int(CR.stats(w)["d:1"]["workload_pm"])
	var r := CR.crime_rate(w, "d:1")
	for k in CR.KINDS:
		var base := CR.base_rate(k)
		check(absf(float(r[k]) - float(base)) <= 0.3 * float(base) + 6.0, "%s near the reported base (%d vs %d)" % [k, r[k], base])
	check_eq(CR.crime_rate(w)["THEFT"], r["THEFT"], "colony = the only district")
	var wl := wl_sum / 12
	check(wl > 500 and wl < 950, "reference police with slack for surges (%d‰ a month on average)" % wl)


func test_a_slump_raises_theft_and_violence() -> void:
	var a := _world(40)
	var b := _world(150)
	_run(a, 24)
	_run(b, 24)
	var ra := CR.crime_rate(a, "d:1")
	var rb := CR.crime_rate(b, "d:1")
	check(float(rb["THEFT"]) >= 1.4 * float(ra["THEFT"]), "theft up in a slump (%d → %d)" % [ra["THEFT"], rb["THEFT"]])
	check(float(rb["VIOLENCE"]) > float(ra["VIOLENCE"]), "violence up (%d → %d)" % [ra["VIOLENCE"], rb["VIOLENCE"]])


func test_hunger_driver() -> void:
	var dr := {"unemployed_pm": 40, "hunger_pm": 250, "homeless_pm": 0, "ineq_x1000": CR.INEQ_REF}
	check(absf(CR.driver_mult(dr, "THEFT") - 2.0) < 0.01, "250‰ food shortfall doubles theft")
	check_eq(CR.driver_mult(dr, "FRAUD"), 1.0, "fraud does not follow hunger")


func test_police_cuts_lower_clearance_and_leave_districts_unpatrolled() -> void:
	var a := _world()
	var b := _world()
	b.levers["LAW_POLICE_BUDGET"] = CR.DEFAULT_BUDGET
	_run(b, 3)
	b.levers["LAW_POLICE_BUDGET"] = CR.DEFAULT_BUDGET / 4
	_run(a, 36)
	_run(b, 33)
	var ca := int(CR.stats(a)["d:1"]["clearance_pm"]["VIOLENCE"])
	var cb := int(CR.stats(b)["d:1"]["clearance_pm"]["VIOLENCE"])
	check(cb < ca, "fewer crimes solved after the cut (%d‰ → %d‰)" % [ca, cb])
	var un := b.facts.query("LAW_DISTRICT_UNPATROLLED", 0, b.month)
	check(un.size() >= 1, "district left unpatrolled")
	if not un.is_empty():
		check(bool(un[0]["data"]["budget_cut"]), "after a budget cut")
		check_eq(String(un[0]["responsible"][0]["actor"]["kind"]), "GOVERNMENT", "the government's fault")
	check(float(CR.crime_rate(b, "d:1")["THEFT"]) > float(CR.crime_rate(a, "d:1")["THEFT"]), "less deterrence, more theft")


func test_crime_wave() -> void:
	var w := _world()
	_run(w, 30)
	check(w.facts.query("LAW_CRIME_WAVE", 0, w.month).is_empty(), "no wave in steady times")
	w.table("econ")["s"]["food_shortfall"] = 400
	_run(w, 4)
	var wv := w.facts.query("LAW_CRIME_WAVE", 0, w.month)
	check_eq(wv.size(), 1, "a famine brings a crime wave")
	_run(w, 6)
	check_eq(w.facts.query("LAW_CRIME_WAVE", 0, w.month).size(), 1, "at most one a year")


func test_a_growing_district_is_not_a_wave() -> void:
	var w := _world()
	_run(w, 30)
	_hh(w, "hb:1|MID", "d:1", "MID", 12000, 12000 - 480, 8000, 3000)    # the district doubles, same unemployment
	_run(w, 6)
	check(w.facts.query("LAW_CRIME_WAVE", 0, w.month).is_empty(), "more people, same rate: no wave")


## v8: lasting high crime is news once a year (a wave only measures a district against its own past).
func test_lasting_high_crime_stays_news() -> void:
	var w := _world()
	var row := {"pop": 10000, "hist": {"THEFT": [], "VIOLENCE": [], "FRAUD": []}}
	for i in 12:
		(row["hist"]["THEFT"] as Array).append(90)       # 1,080 reported a year per 10k
		(row["hist"]["VIOLENCE"] as Array).append(12)    # 144
	CR._high_crime(w, "d:1", row)
	check_eq(w.facts.query("LAW_HIGH_CRIME", 0, w.month).size(), 1, "index 1,512 vs base 600: news")
	w.month += 6
	CR._high_crime(w, "d:1", row)
	check_eq(w.facts.query("LAW_HIGH_CRIME", 0, w.month).size(), 1, "not again within the year")
	var calm := {"pop": 10000, "hist": {"THEFT": [], "VIOLENCE": [], "FRAUD": []}}
	for i in 12:
		(calm["hist"]["THEFT"] as Array).append(40)
		(calm["hist"]["VIOLENCE"] as Array).append(5)
	CR._high_crime(w, "d:2", calm)
	check_eq(w.facts.query("LAW_HIGH_CRIME", 0, w.month).size(), 1, "normal crime is not")
