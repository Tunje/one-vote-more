extends TestCase
## Rebuild step 2 (Maja): the founding settlers, the household pools, hiring and layoffs, jobs = people
## (planning/rebuild-households.md P1, P3–P7, P12, P14; rebuild-company.md 9.2, 12.2 point 10, 12.5 point 35).

const Households := preload("res://sim/population/households.gd")
const Company := preload("res://sim/economy/company.gd")
const S := 1000


## A company of Bob's record (owner kind, one holder), with one plant unless it is a crew company.
func _co(w: WorldState, type: String, kind: String) -> String:
	return Company.create(w, type, "SMALL", {"kind": kind, "holders": {"holder:1": 1000}}, type.to_lower(),
		{"area": AreaStore.found_landing(w)})


func _world() -> WorldState:
	var w := WorldState.new(7)
	Terrain.generate(w)
	AreaStore.change_listeners = []
	AreaStore.district_resolver = Callable()
	return w


func test_a_new_game_lands_the_founding_settlers_in_the_landing() -> void:
	var sim := GameSim.make(3)
	var w := sim.world
	var land := AreaStore.found_landing(w)
	check_eq(PopStore.total(w), 1000, "1,000 settlers")
	check_eq(AreaStore.residents(w, land), 1000, "all in the Landing")
	check_eq(Households.pools(w).size(), 5, "one pool per income band")
	var all := {"persons": 0, "lf": 0, "children": 0, "retired": 0, "households": 0, "employed": 0}
	for pid in Households.pools(w):
		var c := Households.counts(w, pid)
		for f in all:
			all[f] = int(all[f]) + int(c[f])
	check_eq(int(all["persons"]) / S, 1000, "the pools' counts are read from the people")
	check_eq(int(all["households"]) / S, 400, "400 households of 2.5")
	check_eq(int(all["lf"]) / S, 675, "675 in the labour force (90% of 750)")
	check_eq(int(all["children"]) / S, 220, "220 children")
	check_eq(int(all["retired"]) / S, 30, "30 retired")
	check_eq(int(all["employed"]) / S, 261, "month one's companies have hired: 220 builder and public works crew, 41 for the state")
	var g := 0
	var sk := 0
	var sp := 0
	for band in Households.BANDS:
		g += PopStore.count(w, {"hb": land, "inc": band, "status": "UNEMPLOYED"}, "skill:G")
		sk += PopStore.count(w, {"hb": land, "inc": band, "status": "UNEMPLOYED"}, "skill:S")
		sp += PopStore.count(w, {"hb": land, "inc": band, "status": "UNEMPLOYED"}, "skill:Sp")
	check_eq([g, sk, sp], [246, 125, 43], "who is still looking for work after month one's hires, by skill")
	check_eq(g + sk + sp + int(all["employed"]) / S, 675, "employed and jobless together are the labour force")
	check_eq(Logbook.rows(w, {"kind": "CREW"}).size(), 0, "there was enough of each skill: no crew came up short")
	check(PopStore.reconcile(w).is_empty(), "the population reconciles")
	check(not w.peek("hh").size(), "the old household table is not created")


func test_the_settlers_bring_their_savings_by_band() -> void:
	var sim := GameSim.make(3)
	var w := sim.world
	var land := AreaStore.found_landing(w)
	var want := {"I1": 144000, "I2": 288000, "I3": 576000, "I4": 1152000, "I5": 2880000}
	for band in want:
		check_eq(w.ledger.balance(Households.account(Households.pool_id(land, band))), int(want[band]) * S,
			"%s: 80 households × %d" % [band, Households.SAVINGS_PER_HOUSEHOLD[band]])
	var rows := Logbook.rows(w, {"kind": "ARRIVE"})
	check_eq(rows.size(), 5, "one log row per pool for the landing")


func test_hire_takes_the_posts_skill_first_then_higher_never_lower() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	Households.seed_test(w, land, "I2", "G", 3)
	Households.seed_test(w, land, "I3", "S", 5)
	Households.seed_test(w, land, "I4", "Sp", 2)
	var c1 := _co(w, "BUILDER", "HOME_WORLD")
	check_eq(Households.hire(w, c1, "crew", "S", land, 6), 6, "six skilled posts filled")
	var st := Company.staff_entries(w, c1)
	check_eq(int(st["crew"]["S"][Households.labour_key(land, "I3", "S")]["n"]), 5 * S, "the five skilled first")
	check_eq(int(st["crew"]["S"][Households.labour_key(land, "I4", "Sp")]["n"]), 1 * S, "then one specialist")
	check_eq(int(st["crew"]["S"][Households.labour_key(land, "I3", "S")]["hires"][0]["pay"]), Company.hiring_salary(w, c1, "S", land),
		"hired at the company's hiring salary")
	check_eq(Households.hire(w, c1, "crew", "Sp", land, 5), 1, "a specialist post takes no one less skilled")
	check_eq(PopStore.count(w, {"hb": land, "status": "UNEMPLOYED"}), 3, "only the general workers are left")
	check_eq(PopStore.count(w, {"hb": land, "status": "EMPLOYED", "occ": "CONSTRUCTION"}), 6, "hired into the builder's occupation")
	check_eq(PopStore.count(w, {"hb": land, "status": "EMPLOYED", "occ": "PROFESSIONAL"}), 1, "a specialist post counts as professional")
	check(Households.check(w).is_empty(), "jobs = people: %s" % str(Households.check(w)))
	check_eq(Logbook.rows(w, {"kind": "HIRE"}).size(), 2, "each hire is a log row")


func test_layoff_returns_people_to_the_unemployed_and_the_check_holds() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	Households.seed_test(w, land, "I2", "G", 10)
	var c1 := _co(w, "FARM", "FAMILY")
	var p1 := Company.add_plant(w, c1, "SMALL")
	var c2 := _co(w, "BUILDER", "STATE")
	Households.hire(w, c1, p1, "G", land, 6, {}, 300 * S)
	Households.hire(w, c2, "crew", "G", land, 4)
	check_eq(PopStore.count(w, {"hb": land, "status": "EMPLOYED", "occ": "PUBLIC_SECTOR"}), 4, "a state company's staff are public sector")
	check(Households.check(w).is_empty(), "jobs = people after two hires")
	check_eq(Households.layoff(w, c1, p1, "G", 4, {"reason": "LAYOFF"}), 4, "four laid off")
	check_eq(PopStore.count(w, {"hb": land, "status": "UNEMPLOYED", "occ": "AGRICULTURE"}), 4, "they keep their occupation")
	check_eq(Company.staff_count(w, c1, "G", p1), 2 * S, "two stay on the farm")
	check(Households.check(w).is_empty(), "jobs = people after the layoff")
	check_eq(Households.layoff(w, c1, p1, "G", 9), 2, "a layoff takes no more than are there")
	check(Households.check(w).is_empty(), "jobs = people when the posts are empty")


func test_the_check_finds_a_job_without_a_person() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	Households.seed_test(w, land, "I2", "G", 2)
	var c1 := _co(w, "FARM", "FAMILY")
	var p1 := Company.add_plant(w, c1, "SMALL")
	Households.hire(w, c1, p1, "G", land, 2, {}, 300 * S)
	Company.staff_change(w, c1, p1, "G", Households.labour_key(land, "I2", "G"), S, 300 * S)   # a post written with no person
	check_eq(Households.check(w).size(), 1, "the check names it")


func test_counts_and_the_settlers_repeat_exactly() -> void:
	var a := GameSim.make(9).world
	var b := GameSim.make(9).world
	check_eq(a.peek("pop").hash(), b.peek("pop").hash(), "same seed, same settlers")
	check_eq(a.peek("pool").hash(), b.peek("pool").hash(), "same pools")


func test_wages_go_to_the_pools_of_the_people_employed() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	Households.seed_test(w, land, "I2", "G", 4)
	Households.seed_test(w, land, "I3", "S", 2)
	var c1 := _co(w, "BUILDER", "HOME_WORLD")
	Households.hire(w, c1, "crew", "G", land, 4, {}, 300 * S)
	Households.hire(w, c1, "crew", "S", land, 2, {}, 450 * S)
	var acct := CoreUtil.acct(c1)
	w.ledger.transfer(Ledger.EXTERNAL, acct, 10000 * S, "TEST", w.month)
	check_eq(Households.pay_wages(w, c1, acct), (4 * 300 + 2 * 450) * S, "the whole bill paid, each at their own pay")
	check_eq(w.ledger.balance(Households.account(Households.pool_id(land, "I2"))), 1200 * S, "four general wages to I2")
	check_eq(w.ledger.balance(Households.account(Households.pool_id(land, "I3"))), 900 * S, "two skilled wages to I3")
	check_eq(int(Households.income(w, Households.pool_id(land, "I3"))["wages"]), 900 * S, "booked as the pool's wages this month")
	check_eq(Logbook.rows(w, {"kind": "PAY", "who": c1}).size(), 1, "one log row per company")


func test_a_company_short_of_money_pays_everyone_the_same_share() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	Households.seed_test(w, land, "I2", "G", 2)
	Households.seed_test(w, land, "I3", "G", 2)
	var c1 := _co(w, "BUILDER", "HOME_WORLD")
	Households.hire(w, c1, "crew", "G", land, 4, {}, 300 * S)
	var acct := CoreUtil.acct(c1)
	w.ledger.transfer(Ledger.EXTERNAL, acct, 600 * S, "TEST", w.month)
	check_eq(Households.pay_wages(w, c1, acct), 600 * S, "it pays what it holds")
	check_eq(w.ledger.balance(acct), 0, "never overdrawn")
	check_eq(w.ledger.balance(Households.account(Households.pool_id(land, "I2"))), 300 * S, "half the bill to each pool")
	check_eq(int(Logbook.rows(w, {"kind": "PAY"})[0]["change"]["short"][1]), 600 * S, "the shortfall is in the log row")


func test_benefit_and_pension_by_status() -> void:
	var sim := GameSim.make(3)
	var w := sim.world
	var land := AreaStore.found_landing(w)
	w.ledger.open_account("test:treasury")
	w.ledger.transfer(Ledger.EXTERNAL, "test:treasury", 1000000 * S, "TEST", w.month)
	var ben := Households.pay_support(w, "benefit", "test:treasury", {land: 120 * S})
	check_eq(ben, 414 * 120 * S, "the 414 settlers still jobless after month one's hires get the benefit")
	var pen := Households.pay_support(w, "pension", "test:treasury", {land: 100 * S})
	check_eq(pen, 30 * 100 * S, "the 30 retired get the pension")
	var pid := Households.pool_id(land, "I1")
	check_eq(int(Households.income(w, pid).get("benefit", 0)), Households.persons(w, pid, "UNEMPLOYED") * 120 * S, "booked per pool")
	check_eq(Logbook.rows(w, {"kind": "PAY", "what": "pension"}).size(), 1, "one log row for the pensions")


func test_the_first_month_says_when_the_landing_has_too_few_homes() -> void:
	var sim := GameSim.make(3)
	var w := sim.world
	var land := AreaStore.found_landing(w)
	var short := AreaStore.capacity(w, land) < 400
	sim.run(1)
	check_eq(Logbook.rows(w, {"kind": "HOMES"}).size(), 1 if short else 0, "a row exactly when the shelters are short")
	check_eq(w.facts.query("POP_HOMES_SHORT", 0).size(), 1 if short else 0, "and an official fact")
	sim.run(1)
	check_eq(Logbook.rows(w, {"kind": "HOMES"}).size(), 1 if short else 0, "only in the first month")


func test_a_salary_is_set_at_hire_and_rises_only_by_the_yearly_raise() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	Households.seed_test(w, land, "I2", "G", 4)
	var c1 := _co(w, "BUILDER", "HOME_WORLD")
	Households.hire(w, c1, "crew", "G", land, 2, {}, 300 * S)
	Company.set_hiring_salary(w, c1, "G", land, 400 * S)
	var acct := CoreUtil.acct(c1)
	w.ledger.transfer(Ledger.EXTERNAL, acct, 100000 * S, "TEST", w.month)
	check_eq(Households.pay_wages(w, c1, acct), 600 * S, "a new hiring salary does not change what the two already earn")
	Company.yearly_raise(w, c1, 0, 20)
	check_eq(Households.pay_wages(w, c1, acct), 612 * S, "the yearly raise (2% minimum) lifts them")
	Households.hire(w, c1, "crew", "G", land, 2)
	check_eq(Company.wage_bill(w, c1), 1412 * S, "two new hires at the new 400 blend in by head count: 2 x 306 + 2 x 400")
	check(Households.check(w).is_empty(), "jobs = people")


func test_a_hire_is_paid_the_hiring_salary_of_the_area_the_plant_stands_in() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	Households.seed_test(w, land, "I2", "G", 4)
	var c1 := _co(w, "BUILDER", "HOME_WORLD")
	Company.set_hiring_salary(w, c1, "G", land, 333 * S)
	check_eq(Households.plant_area(w, c1, "crew"), land, "a crew works from the company's home area")
	check_eq(Households.hire(w, c1, "crew", "G", land, 2), 2, "hired")
	check_eq(Company.wage_bill(w, c1), 666 * S, "at the hiring salary of the plant's area")
	check_eq(int(Logbook.rows(w, {"kind": "HIRE", "who": c1})[0]["why"]["pay"]), 333 * S, "the pay is in the log row")
	var c2 := _co(w, "FARM", "FAMILY")
	var p2 := Company.add_plant(w, c2, "SMALL")
	check_eq(Households.hire(w, c2, p2, "G", land, 2), 0, "a plant that stands nowhere hires nobody without a pay")
	check_eq(PopStore.count(w, {"hb": land, "status": "UNEMPLOYED"}), 2, "and nobody was moved")
	check(Households.check(w).is_empty(), "jobs = people")


func test_within_a_skill_hires_are_shared_over_the_bands_in_proportion() -> void:
	var sim := GameSim.make(3)
	var w := sim.world
	var land := AreaStore.found_landing(w)
	var c1 := _co(w, "BUILDER", "HOME_WORLD")
	var g0 := {}
	for band in Households.BANDS:
		g0[band] = PopStore.count(w, {"hb": land, "inc": band, "status": "UNEMPLOYED"}, "skill:G")
	var before := {}
	for band in Households.BANDS:
		before[band] = PopStore.count(w, {"hb": land, "inc": band, "status": "EMPLOYED"})
	Households.hire(w, c1, "crew", "G", land, 100, {}, 300 * S)
	var total_g := 0
	for band in g0:
		total_g += int(g0[band])
	for band in Households.BANDS:
		var got := PopStore.count(w, {"hb": land, "inc": band, "status": "EMPLOYED"}) - int(before[band])
		var share := 100.0 * float(g0[band]) / float(total_g)
		check(absf(float(got) - share) < 1.0, "%s: %d hired against its share %.1f" % [band, got, share])
	check(Households.check(w).is_empty(), "jobs = people")


## Four general workers of band I2 hired at 400, then ten at 300 shared over I2 (six left) and I3 (ten): four and six.
func _two_pays(w: WorldState) -> Array:
	var land := AreaStore.found_landing(w)
	Households.seed_test(w, land, "I2", "G", 10)
	var c1 := _co(w, "BUILDER", "STATE")
	check_eq(Households.hire(w, c1, "crew", "G", land, 4, {}, 400 * S), 4, "four at 400")
	Households.seed_test(w, land, "I3", "G", 10)
	check_eq(Households.hire(w, c1, "crew", "G", land, 10, {}, 300 * S), 10, "ten at 300")
	return [land, c1]


func _rows(w: WorldState, cid: String, lk: String) -> Array:
	return Company.payroll(w, cid).filter(func(e): return String(e["labour_key"]) == lk).map(func(e): return [int(e["n"]) / S, int(e["pay"]) / S])


func test_joiners_at_a_lower_pay_cut_nobody() -> void:
	var w := _world()
	var r := _two_pays(w)
	check_eq(_rows(w, r[1], Households.labour_key(r[0], "I2", "G")), [[4, 400], [4, 300]], "the four hired at 400 still earn 400")
	check_eq(Company.wage_bill(w, r[1]), (4 * 400 + 10 * 300) * S, "each paid their own")


func test_a_band_move_keeps_each_groups_own_pay() -> void:
	var w := _world()
	var r := _two_pays(w)
	var bill := Company.wage_bill(w, r[1])
	Households.move_jobs_band(w, r[0], "I2", "I3", "G")
	check_eq(_rows(w, r[1], Households.labour_key(r[0], "I3", "G")), [[4, 400], [10, 300]],
		"the four at 400 keep 400 in their new band; the 300s join the 300s already there")
	check_eq(Company.wage_bill(w, r[1]), bill, "nobody's pay moved")


func test_a_layoff_owes_each_group_its_own_pay() -> void:
	var w := _world()
	var r := _two_pays(w)
	var months := int(load("res://sim/law/work_law.gd").layoff_pay_months(w))
	# largest groups first: I3 at 300 (six), then of the two fours in I2 the higher pay first
	check_eq(Households.layoff(w, r[1], "crew", "G", 10), 10, "ten laid off")
	var row: Dictionary = Logbook.rows(w, {"kind": "LAYOFF", "who": r[1]})[-1]
	check_eq(int(row["change"]["layoff_pay_owed"][1]), months * (6 * 300 + 4 * 400) * S, "each owed months of their own pay")
	check_eq(_rows(w, r[1], Households.labour_key(r[0], "I2", "G")), [[4, 300]], "the four at 300 stay, at 300")
	check(Households.check(w).is_empty(), "jobs = people: %s" % str(Households.check(w)))


func test_a_band_move_carries_its_training() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	Households.seed_test(w, land, "I2", "G", 4)
	var c1 := _co(w, "BUILDER", "STATE")
	check_eq(Households.hire(w, c1, "crew", "G", land, 4, {}, 400 * S), 4, "four new hires, in training")
	w.month = 2
	var before := Company.trained_count(w, c1)
	Households.move_jobs_band(w, land, "I2", "I3", "G")
	check_eq(Company.trained_count(w, c1), before, "still two months into training: nothing learned by moving")
	var e: Dictionary = Company.payroll(w, c1)[0]
	check_eq([String(e["labour_key"]), int(e["since"]), int(e.get("train", -9))], [Households.labour_key(land, "I3", "G"), 0, 0],
		"the row moved whole: its month and its training")


func test_unpaid_wages_are_owed_and_paid_when_the_company_has_money() -> void:
	# the user, 9.2 "Unpaid wages": "Record it make them pay after our if they refused take it to court"
	var w := _world()
	var land := AreaStore.found_landing(w)
	Households.seed_test(w, land, "I2", "G", 2)
	Households.seed_test(w, land, "I3", "G", 2)
	var c1 := _co(w, "BUILDER", "HOME_WORLD")
	Households.hire(w, c1, "crew", "G", land, 4, {}, 300 * S)
	var acct := CoreUtil.acct(c1)
	w.ledger.transfer(Ledger.EXTERNAL, acct, 600 * S, "TEST", w.month)
	Households.pay_wages(w, c1, acct)
	var owed := 0
	for li in w.peek("liability").values():
		if String(li["debtor"]) == c1 and String(li["kind"]) == "UNPAID_WAGES":
			owed += int(li["amount"])
	check_eq(owed, 600 * S, "what it could not pay is owed to the workers' pools")
	var rows: Array = w.peek("liability").values().filter(func(li): return String(li["debtor"]) == c1)
	check_eq(rows.map(func(li): return [int(li["due_month"]), bool(li["plan"])]), [[w.month + 1, false], [w.month + 1, false]],
		"one row per pool, whole, due next month: no instalments for pay already earned (Anni)")
	check_eq(int(Logbook.rows(w, {"kind": "PAY"})[-1]["change"]["owed"][1]), 600 * S, "and in the PAY row")
	var i2 := Households.pool_id(land, "I2")
	var before := w.ledger.balance(Households.account(i2))
	w.ledger.transfer(Ledger.EXTERNAL, acct, 1000 * S, "TEST", w.month)
	var late := 0
	for m in 2:
		w.month += 1
		load("res://sim/law/justice_ops.gd").collect_debts(w)
		late += int(Households.income(w, i2).get("wages", 0))
	check_eq(w.ledger.balance(Households.account(i2)) - before, 300 * S, "paid afterwards: the I2 pool gets its half")
	check_eq(late, 300 * S, "booked as wages in the months it came")
	check_eq(w.ledger.balance(acct), 400 * S, "from the company's account")
