extends TestCase
## Month one's government side and the purse's monthly payments (sim/economy/landing.gd), in a whole new game.

const Landing := preload("res://sim/economy/landing.gd")
const Company := preload("res://sim/economy/company.gd")
const TypeTable := preload("res://sim/economy/type_table.gd")
const Households := preload("res://sim/population/households.gd")
const Rules := preload("res://sim/economy/rules.gd")
const S := CoreUtil.S


func _game() -> Simulation:
	return GameSim.make(1)


func _made(w: WorldState) -> Dictionary:
	return Landing.land(w, AreaStore.found_landing(w))


func test_every_founding_household_has_a_shelter() -> void:
	var w := _game().world
	var land := AreaStore.found_landing(w)
	var housing := String(_made(w)["housing"])
	check_eq(AreaStore.capacity(w, land), 400, "400 homes for the 400 households")
	check_eq(Company.plant_ids_of(w, housing).size(), 8, "eight shelter blocks of 50")
	check(Company.is_state(w, housing), "the housing office is the state's")
	check_eq(Company.price(w, housing, "@home"), Landing.SHELTER_RENT, "at the shelter rent")
	check_eq(Landing.SHELTER_RENT, 97 * S, "97, half of a new home's doubled rent (the user, 2026-11-18: \"double the rent\")")
	check_eq(Logbook.rows(w, {"what": "landing homes short"}).size(), 0, "nobody reports homes short")
	check_eq(Logbook.rows(w, {"what": "shelter block NOT laid"}).size(), 0, "every block found a site")


func test_the_landing_stock_is_in_the_stores_at_the_starting_prices() -> void:
	var w := _game().world
	var stores := String(_made(w)["stores"])
	for item in Landing.STOCK:
		check_eq(int(Company.stock_of(w, stores, item)["qty"]), int(Landing.STOCK[item]) * S, "%s landed" % item)
		check_eq(Company.price(w, stores, item), TypeTable.start_price(item), "%s at its starting price" % item)
		check(TypeTable.start_price(item) > 0, "%s has a starting price" % item)
	check_eq(Logbook.rows(w, {"what": "landing stock NOT taken in or offered"}).size(), 0, "nothing refused")
	check_eq(Logbook.rows(w, {"kind": "STOCK", "who": stores}).size(), Landing.STOCK.size(), "one stock row per good")


func test_the_subsidiaries_exist_and_only_the_working_ones_have_staff() -> void:
	var w := _game().world
	var m := _made(w)
	check_eq((m["unbuilt"] as Dictionary).size(), 6, "six with no building yet")
	for type in m["unbuilt"]:
		var cid := String(m["unbuilt"][type])
		check(Company.is_state(w, cid), "%s is the state's" % type)
		check(Company.plant_ids_of(w, cid).is_empty(), "%s has no plant" % type)
		check_eq(Company.staff_count(w, cid), 0, "%s has no staff" % type)
	check_eq(Company.staff_count(w, String(m["admin"])), 15 * S, "the administration's full posts")
	check_eq(Company.staff_count(w, String(m["housing"])), 16 * S, "two wardens a shelter block")
	check_eq(Company.staff_count(w, String(m["stores"])), 10 * S, "the stores' full posts")
	check_eq((m["builders"]["home_world"] as Array).size(), 5, "the five builders")
	check_eq(Logbook.rows(w, {"kind": "CREW"}).size(), 0, "no crew came up short")
	check(Households.check(w).is_empty(), "the household side's own check passes: %s" % str(Households.check(w)))


func test_landing_twice_makes_nothing_more() -> void:
	var w := _game().world
	var n := Company.ids(w).size()
	var total := -w.ledger.balance(Ledger.EXTERNAL)
	var again := _made(w)
	check_eq(Company.ids(w).size(), n, "no new company")
	check_eq(n, 5 + 1 + 6 + 1 + 1 + 1, "five builders, public works, six unbuilt, administration, housing, stores")
	check_eq(-w.ledger.balance(Ledger.EXTERNAL), total, "no new money")
	check_eq(String(again["stores"]), String(Landing.land(w, "elsewhere")["stores"]), "the same answer")


func test_the_builders_land_with_three_months_of_wages() -> void:
	var w := _game().world
	for cid in _made(w)["builders"]["home_world"]:
		check(Company.wage_bill(w, cid) > 0, "a crew on the payroll")
		check_eq(w.ledger.balance(CoreUtil.acct(cid)), 3 * Company.wage_bill(w, cid), "three months of its wage bill")


func test_the_purse_pays_staff_benefit_and_pensions_and_money_is_conserved() -> void:
	var sim := _game()
	var w := sim.world
	var tre := CoreUtil.TREASURY
	check_eq(w.ledger.balance(tre), Landing.TREASURY_START * S, "the treasury's opening money")
	var wage_bill := 0
	for cid in Landing.state_companies(w):
		wage_bill += Company.wage_bill(w, cid)
	check(wage_bill > 0, "the state has staff to pay")
	var jobless := 0
	var retired := 0
	var benefit_due := 0
	var pension_due := 0
	for pid in Households.pools(w):
		jobless += Households.persons(w, pid, "UNEMPLOYED")
		retired += Households.persons(w, pid, "RETIRED")
		# the area's starting salary (12.5, 41): 2 x the area's rent for a general post (9.2)
		var start := Rules.starting_salary(w, String(w.peek("pool")[pid]["area"]), "G")
		benefit_due += Households.persons(w, pid, "UNEMPLOYED") * (start * int(w.levers["ECON_UNEMPLOYMENT_BENEFIT_RATE"]) / 100)
		pension_due += Households.persons(w, pid, "RETIRED") * (start * int(w.levers["ECON_PENSION_RATE"]) / 100)
	var total := -w.ledger.balance(Ledger.EXTERNAL)
	var paid := Landing.purse_month(w)
	check_eq(int(paid["wages"]), wage_bill, "every state company is given its whole wage bill: it holds nothing itself")
	check(jobless > 0 and retired > 0, "people on support")
	check_eq(int(paid["benefit"]), benefit_due, "the benefit at its lever, of the area's starting salary")
	check_eq(int(paid["pension"]), pension_due, "the pension at its lever, of the area's starting salary")
	var area := String(w.peek("pool")[Households.pools(w)[0]]["area"])
	check_eq(int(Landing.support_rates(w, 100)[area]), 2 * Rules.area_rent(w, area), "100% of it is 2 x the area's rent, not the type table's 300")
	check(int(paid["benefit"]) > 0 and int(paid["pension"]) > 0, "both were paid")
	check_eq(w.ledger.balance(tre), Landing.TREASURY_START * S - wage_bill - int(paid["benefit"]) - int(paid["pension"]), "all of it from the treasury")
	check_eq(-w.ledger.balance(Ledger.EXTERNAL), total, "nothing appears or vanishes")
	check_eq(Logbook.rows(w, {"kind": "PURSE"}).size(), 1, "the month is in the log")
	check_eq(w.facts.query("ECON_PURSE_SHORT", 0).size(), 0, "a purse that pays in full reports nothing")
	check(w.ledger.has_account(CoreUtil.FINES), "the fines account exists for the law to pay into")
	w.levers["ECON_UNEMPLOYMENT_BENEFIT_RATE"] = 0
	var again := Landing.purse_month(w)
	check_eq(int(again["benefit"]), 0, "a benefit voted to nothing pays nothing")
	check_eq(int(again["wages"]), 0, "a state company that already holds its wages is given nothing more")


func test_a_state_company_pays_its_own_staff_with_what_the_purse_gave_it() -> void:
	var sim := _game()
	var w := sim.world
	var admin := String(_made(w)["admin"])
	var bill := Company.wage_bill(w, admin)
	sim.step()
	check_eq(w.ledger.balance(CoreUtil.acct(admin)), 0, "given exactly its wage bill and paid it all out")
	var pay: Array = Logbook.rows(w, {"kind": "PAY", "who": admin})
	check_eq(pay.size(), 1, "one wages row, the company's own")
	check_eq(int(pay[0]["change"]["paid"][1]), bill, "its whole bill")
	# a home-world builder pays its crew from its own capital
	var b := String(_made(w)["builders"]["home_world"][0])
	var bpay: Array = Logbook.rows(w, {"kind": "PAY", "who": b})
	check_eq(bpay.size(), 1, "a builder paid its crew once")
	check(int(bpay[0]["change"]["paid"][1]) > 0 and int(bpay[0]["change"]["short"][1]) == 0, "in full, from its own capital")


func test_rent_due_is_a_shelter_rent_per_household_owed_to_the_housing_office() -> void:
	var w := _game().world
	var housing := String(_made(w)["housing"])
	var all := 0
	for pid in Households.pools(w):
		var due := Landing.rent_due(w, pid)
		check_eq(due.size(), 1, "one landlord")
		check_eq(int(due[CoreUtil.acct(housing)]), 80 * Landing.SHELTER_RENT, "80 households of a band at the shelter rent")
		all += int(due[CoreUtil.acct(housing)])
	check_eq(all, 400 * Landing.SHELTER_RENT, "400 rents in all")
	check(Landing.rent_due(w, "pool:nobody").is_empty(), "an unknown pool owes nothing")


func test_the_stores_takings_go_to_the_treasury_as_a_sale_of_the_landing_stock() -> void:
	var w := _game().world
	var stores := String(_made(w)["stores"])
	w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.acct(stores), 500 * S, "TEST", w.month)
	var before := w.ledger.balance(CoreUtil.TREASURY)
	check_eq(Landing.stores_takings(w), 500 * S, "all of it")
	check_eq(w.ledger.balance(CoreUtil.TREASURY), before + 500 * S, "in the treasury")
	check_eq(String(w.ledger.journal[-1]["memo"]), "LANDING_STOCK_SALE", "named as the sale of an asset")
	check_eq(Landing.stores_takings(w), 0, "nothing twice")


func test_an_empty_treasury_pays_what_it_has_and_no_more() -> void:
	var w := _game().world
	var tre := CoreUtil.TREASURY
	w.ledger.transfer(tre, Ledger.EXTERNAL, w.ledger.balance(tre) - 1000 * S, "TEST", w.month)
	var paid := Landing.purse_month(w)
	check_eq(int(paid["wages"]) + int(paid["benefit"]) + int(paid["pension"]), 1000 * S, "exactly what it held")
	check_eq(w.ledger.balance(tre), 0, "never overdrawn")
	check_eq(w.ledger.balance(Landing.PAYING), 0, "nothing left on the way")
	# one bill: every line gets the same share, no line before another
	for line in ["wages", "benefit", "pension"]:
		var want := int(paid[line + "_due"]) * 1000 / int(paid["due"])
		check(absi(int(paid[line]) / S - want) <= 1, "%s got its share of the 1,000 (%d of %d)" % [line, int(paid[line]) / S, want])
	var got_some := 0
	for cid in Landing.state_companies(w):
		if w.ledger.balance(CoreUtil.acct(cid)) > 0:
			got_some += 1
	check_eq(got_some, 4, "all four state companies with staff were given something toward their wages (administration, housing, stores, public works): none left out by its id")
	check_eq(w.facts.query("ECON_PURSE_SHORT", 0).size(), 1, "and the public is told")
	check_eq(Logbook.rows(w, {"what": "the month's payments SHORT"}).size(), 1, "and the log says short")


func test_revenue_is_swept_into_the_treasury_and_seen_by_source() -> void:
	var w := _game().world
	w.ledger.open_account("gov:test_revenue")
	w.ledger.transfer(Ledger.EXTERNAL, "gov:test_revenue", 700 * S, "TEST", w.month)
	var before := w.ledger.balance(CoreUtil.TREASURY)
	check_eq(Landing.sweep(w), 700 * S, "swept")
	check_eq(w.ledger.balance("gov:test_revenue"), 0, "the source is empty")
	check_eq(w.ledger.balance(CoreUtil.TREASURY), before + 700 * S, "the treasury has it")
	var e: Dictionary = w.ledger.journal[-1]
	check_eq(String(e["memo"]), "SWEEP:gov:test_revenue", "the ledger names the source")
	check_eq(Logbook.rows(w, {"kind": "SWEEP"}).size(), 1, "and so does the log")
	check_eq(Landing.sweep(w), 0, "nothing to sweep twice")


func test_a_game_pays_every_month_and_saves_and_loads_the_same() -> void:
	var a := _game()
	for i in 6:
		a.step()
	check_eq(Logbook.rows(a.world, {"kind": "PURSE", "what_has": "the month's payments"}).size(), 6, "six months, six purse rows")
	var b := GameSim.for_load()
	b.load_dict(a.to_dict())
	a.step()
	b.step()
	check_eq(a.world.state_hash(), b.world.state_hash(), "a loaded game goes on the same")


func test_a_family_on_its_own_opened_farm_pays_no_rent() -> void:
	var sim := _game()
	var w := sim.world
	var housing := String(_made(w)["housing"])
	var on_farm := ""
	var planning := ""
	for m in 14:
		sim.step()
		for fid in w.peek("founder"):
			if Landing.lives_on_own_farm(w, fid):
				on_farm = fid
			elif not (w.peek("founder")[fid]["owns"] as Array).is_empty():
				planning = fid
		if on_farm != "" and planning != "":
			break
	check(on_farm != "", "a family farm has opened within fourteen months")
	check(Landing.rent_due(w, on_farm).is_empty(), "the farm is their home: no rent to a landlord")
	if planning != "":
		check_eq(int(Landing.rent_due(w, planning)[CoreUtil.acct(housing)]), Landing.SHELTER_RENT, "a family whose farm is still a plan pays its shelter's rent")

