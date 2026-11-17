extends TestCase
## Mass layoffs as politics reads them (EconPublish.layoffs; the rule recorded in planning/pic-economy.md): 15 persons
## or more and 20% or more of the workforce in one month, one fact per company per six months, carrying the severance
## owed and paid since the user's ruling on keeping workers (9.2).

const EconPublish := preload("res://sim/economy/econ_publish.gd")
const S := CoreUtil.S


func _data(n: int, staff: int, owed: int = 0, paid: int = 0) -> Dictionary:
	return {"company": "company:1", "area": "landing", "n": n, "staff": staff, "owed": owed, "paid": paid, "months_pay": 3}


func test_a_mass_layoff_is_public_with_what_was_owed_and_paid() -> void:
	var w := WorldState.new(1)
	var fid := EconPublish.layoffs(w, _data(20, 50, 9000 * S, 6000 * S))
	check(fid != "", "20 of 50 is a mass layoff")
	var f: Array = w.facts.query("ECON_LAYOFFS_MASS")
	check_eq(f.size(), 1, "one public fact")
	if f.size() == 1:
		var d: Dictionary = f[0]["data"]
		check_eq(int(d["persons"]), 20, "how many")
		check_eq(int(d["share_pct"]), 40, "what share of the staff")
		check_eq(int(d["owed"]), 9000 * S, "the severance owed")
		check_eq(int(d["paid"]), 6000 * S, "what was paid")
		check_eq(int(d["unpaid"]), 3000 * S, "and what is still unpaid")
		check_eq(int(d["months_pay"]), 3, "months of pay the law sets")
		check_eq(int(f[0]["magnitude"]), 50, "30 + half the share")
	check_eq(Logbook.rows(w, {"kind": "LAYOFF", "what": "mass layoffs"}).size(), 1, "logged")


func test_small_layoffs_are_not_mass() -> void:
	var w := WorldState.new(1)
	check_eq(EconPublish.layoffs(w, _data(14, 20)), "", "fewer than 15 persons")
	check_eq(EconPublish.layoffs(w, _data(15, 100)), "", "less than 20% of the staff")
	check_eq(w.facts.query("ECON_LAYOFFS_MASS").size(), 0, "no fact")
	var w2 := WorldState.new(1)
	check(EconPublish.layoffs(w2, _data(15, 75)) != "", "15 persons and exactly 20% is mass")


func test_one_fact_per_company_per_six_months() -> void:
	var w := WorldState.new(1)
	check(EconPublish.layoffs(w, _data(20, 50)) != "", "the first")
	w.month += 3
	check_eq(EconPublish.layoffs(w, _data(20, 50)), "", "not again within six months")
	check_eq(Logbook.rows(w, {"kind": "LAYOFF", "what": "mass layoffs, no new fact within six months"}).size(), 1, "held back, logged")
	w.month += 3
	check(EconPublish.layoffs(w, _data(20, 50)) != "", "again after six")
	check_eq(w.facts.query("ECON_LAYOFFS_MASS").size(), 2, "two facts")
