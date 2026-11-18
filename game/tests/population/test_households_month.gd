extends TestCase
## Rebuild step 3 (Maja): the households' month: buying food in the ruled order, eating and hunger by why, rent,
## applying only to jobs that meet their needs, quitting for better pay, the negotiation, founders counted one by one,
## life (births, deaths, growing up, retiring, band moves), settlers and leavers on a ship. Short exact tests.

const Households := preload("res://sim/population/households.gd")
const Demography := preload("res://sim/population/demography.gd")
const Company := preload("res://sim/economy/company.gd")
const Market := preload("res://sim/economy/market.gd")
const S := 1000


func _world() -> WorldState:
	var w := WorldState.new(5)
	Terrain.generate(w)
	AreaStore.change_listeners = []
	AreaStore.district_resolver = Callable()
	return w


## A seller of FOOD in the area holding `qty` units, at its starting price.
func _seller(w: WorldState, area: String, qty: int) -> String:
	var cid := Company.create(w, "FARM", "SMALL", {"kind": "STATE", "holders": {"gov": 1000}}, "test farm", {"area": area})
	if qty > 0:
		Company.stock_add(w, cid, "FOOD", qty * S, 0, "LANDING", "test")
	return cid


## A pool of n unemployed general workers with `money` credits.
func _pool(w: WorldState, area: String, band: String, n: int, money: int) -> String:
	var pid := Households.seed_test(w, area, band, "G", n)
	if money > 0:
		w.ledger.transfer(Ledger.EXTERNAL, Households.account(pid), money * S, "TEST", w.month)
	return pid


func _buy_month(w: WorldState) -> Dictionary:
	Households.post_orders(w)
	Market.clear(w)
	return Households.after_market(w)


func test_food_is_bought_eaten_and_nothing_appears_or_vanishes() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	var pid := _pool(w, land, "I2", 10, 10000)
	var cid := _seller(w, land, 100)
	var price := Company.price(w, cid, "FOOD")
	var money0 := Households.savings(w, pid) + w.ledger.balance(CoreUtil.acct(cid))
	var tot := _buy_month(w)
	var m := Households.month_of(w, pid)
	check_eq(int(m["food_need"]), 10 * S, "ten people need ten units")
	check_eq(int(m["food_bought"]), 10 * S, "they bought ten")
	check_eq(int(m["store_bought"]), 10 * S, "and ten more for the store: double")
	check_eq(int(m["hunger"]), 0, "nobody hungry")
	check_eq(int(tot["hunger"]), 0, "the colony fed")
	check_eq(int(Company.stock_of(w, cid, "FOOD")["qty"]), 80 * S, "the seller holds 100 units less 20: goods come from somewhere")
	check_eq(w.ledger.balance(CoreUtil.acct(cid)), 20 * price, "the seller was paid twenty units at its price")
	check_eq(Households.savings(w, pid) + w.ledger.balance(CoreUtil.acct(cid)), money0, "money only changed hands")
	check_eq(Households.fed_pm(w, pid), 1000, "fed in full")
	check_eq(Logbook.rows(w, {"kind": "BUDGET", "who": pid}).size(), 1, "the budget is a log row")


func test_hunger_is_counted_from_need_and_split_by_why() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	var poor := _pool(w, land, "I1", 10, 0)       # no money at all
	var short := _pool(w, land, "I2", 10, 100)    # some money, less than the price of ten units
	var cid := _seller(w, land, 100)
	var price := Company.price(w, cid, "FOOD")
	check(100 * S < 10 * price, "the test needs 100 credits to be under ten units' price")
	_buy_month(w)
	check_eq(int(Households.month_of(w, poor)["hunger_money"]), 10 * S, "no money behind the order: unmet for lack of money")
	var ms := Households.month_of(w, short)
	check(int(ms["food_bought"]) > 0 and int(ms["food_bought"]) < 10 * S, "with some money it buys what its budget reaches (%d)" % int(ms["food_bought"]))
	check_eq(int(ms["hunger_price"]), 10 * S - int(ms["food_bought"]), "the rest it could not pay for is a refusal of the price (23a)")
	check_eq(Households.fed_pm(w, poor), 0, "nothing eaten")
	var w2 := _world()
	var land2 := AreaStore.found_landing(w2)
	var p2 := _pool(w2, land2, "I3", 10, 100000)
	_buy_month(w2)
	check_eq(int(Households.month_of(w2, p2)["hunger_scarce"]), 10 * S, "money but nobody selling: none to be had")


func test_a_famine_after_three_hungry_months() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	_pool(w, land, "I1", 10, 0)
	for i in 3:
		_buy_month(w)
		w.month += 1
	check(Households.famine_now(w), "three months with more than a quarter uneaten is a famine")
	check_eq(w.facts.query("ECON_FAMINE", 0).size(), 1, "one fact when it begins")
	check_eq(w.facts.query("ECON_FOOD_UNAFFORDABLE", 0).size(), 1, "and food unaffordable, once")


func test_food_spoils_in_store_and_the_store_is_kept_for_emergencies() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	var pid := _pool(w, land, "I3", 2, 10000)
	var st: Dictionary = w.table("pool")[pid]
	st["stock"] = {"FOOD": 1000 * S}
	_seller(w, land, 50)
	_buy_month(w)
	var m := Households.month_of(w, pid)
	check_eq(int(m["food_bought"]), 2 * S, "it buys its month's food though it holds plenty (15f: the store is for emergencies)")
	check_eq(int(m["store_eaten"]), 0, "nothing eaten from the store")
	check_eq(int(m["store_bought"]), 0, "more than six months held: nothing bought for it")
	check_eq(int(st["stock"]["FOOD"]), (1000 * S) - (1000 * S) * 10 / 1000, "1% of the store spoiled")


func test_rent_after_food_and_what_is_left_unpaid_is_owed() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	var pid := _pool(w, land, "I2", 5, 0)
	w.ledger.open_account("test:landlord")
	var rent := func(id: String) -> Dictionary: return {"test:landlord": 100 * S} if id == pid else {}
	w.ledger.transfer(Ledger.EXTERNAL, Households.account(pid), 60 * S, "TEST", w.month)
	check_eq(Households.pay_rent(w, rent), 60 * S, "pays what it holds")
	check_eq(int(Households.month_of(w, pid)["rent_paid"]), 60 * S, "booked")
	w.month += 1
	w.ledger.transfer(Ledger.EXTERNAL, Households.account(pid), 500 * S, "TEST", w.month)
	check_eq(Households.pay_rent(w, rent), 140 * S, "next month: the 40 owed and the month's 100")
	check_eq(w.ledger.balance("test:landlord"), 200 * S, "the landlord has two months' rent")


func test_nobody_applies_to_a_post_below_their_needs() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	_pool(w, land, "I2", 10, 1000)
	var cid := _seller(w, land, 100)
	var needs := Households.needs_per_worker(w, land)
	check(needs > 0, "food has a price, so needs are above nothing (%d)" % needs)
	check_eq(Households.applicants(w, land, "G", needs - 1), 0, "below the needs: no applicants")
	check_eq(Households.applicants(w, land, "G", needs), 10, "at the needs: all of them")
	var b := Company.create(w, "BUILDER", "SMALL", {"kind": "HOME_WORLD", "holders": {"hw": 1000}}, "b", {"area": land})
	check_eq(Households.hire(w, b, "crew", "G", land, 3, {}, needs - 1), 0, "a hire below the needs finds nobody")
	check_eq(Logbook.rows(w, {"kind": "HIRE", "what": "no applicants: the pay is below their needs"}).size(), 1, "said in the log")
	check_eq(Households.hire(w, b, "crew", "G", land, 3, {}, needs), 3, "at the needs they come")


func test_a_founder_is_drawn_counted_one_by_one_and_goes_back() -> void:
	var sim := GameSim.make(3)
	var w := sim.world
	var land := AreaStore.found_landing(w)
	var need := 20000 * S
	var grants := {}
	for pid in Households.pools(w):
		grants[pid] = 10000 * S
	var pick := Households.pick_founder(w, land, need, grants)
	check(pick != "", "some household can pay 20,000 with a 10,000 grant")
	check(Households.household_share(w, pick) + 10000 * S >= need, "the pool drawn can pay")
	var again := Households.pick_founder(GameSim.make(3).world, land, need, grants)
	check_eq(again, pick, "the draw repeats with the seed")
	var share := Households.household_share(w, pick)
	var before := PopStore.total(w)
	var id := Households.make_founder(w, pick, "plan:test")
	check(id.begins_with("founder:"), "a person of their own")
	var r := Households.person(w, id)
	check_eq(String(r["pool"]), pick, "the record carries the pool (one grant per household)")
	check_eq(w.ledger.balance(id), share, "they take one household's share of the savings")
	check_eq(PopStore.total(w), before, "nobody appears or vanishes")
	check_eq(int(Households.counts(w, pick)["owners"]) / S, 1, "counted as an owner in PopStore")
	check(Households.check(w).is_empty(), "jobs = people")
	check(not Households.release_founder(w, id), "not back while they own something")
	Households.disown(w, id, "plan:test")
	var bal := Households.savings(w, pick)
	check(Households.release_founder(w, id), "back into the pool once they own nothing")
	check_eq(Households.savings(w, pick), bal + share, "their money with them")
	check_eq(int(Households.counts(w, pick)["owners"]), 0, "no owner left")
	check(PopStore.reconcile(w).is_empty(), "the population reconciles")


func test_nobody_founds_when_no_household_can_pay() -> void:
	var sim := GameSim.make(3)
	var w := sim.world
	check_eq(Households.pick_founder(w, AreaStore.found_landing(w), 10000000 * S, {}), "", "ten million is beyond everyone")
	check_eq(Logbook.rows(w, {"kind": "FOUNDER", "what": "nobody can pay"}).size(), 1, "said in the log")


func test_two_years_of_life_keep_the_population_whole() -> void:
	var sim := GameSim.make(3)
	var w := sim.world
	var land := AreaStore.found_landing(w)
	var start := PopStore.total(w)
	for i in 24:
		Demography.monthly(w)
		w.month += 1
	var v := w.values
	check_eq(PopStore.total(w), start + int(v.get("pop_births", 0)) - int(v.get("pop_deaths", 0)) + int(v.get("pop_arrivals", 0)) - int(v.get("pop_departures", 0)),
		"the total is the start plus births less deaths")
	check(int(v.get("pop_births", 0)) > 0, "children were born (%d)" % int(v.get("pop_births", 0)))
	check(int(v.get("pop_deaths", 0)) > 0, "people died (%d)" % int(v.get("pop_deaths", 0)))
	var h := Demography.histogram(w, land)
	var hs := 0
	for x in h:
		hs += int(x)
	check(absi(hs - AreaStore.residents(w, land)) <= 2, "the age histogram follows the people (%d vs %d)" % [hs, AreaStore.residents(w, land)])
	check(PopStore.reconcile(w).is_empty(), "the population reconciles")
	check(Households.check(w).is_empty(), "jobs = people after deaths and retirements: %s" % str(Households.check(w)))


func test_hunger_raises_deaths() -> void:
	var fed := GameSim.make(4).world
	var hungry := GameSim.make(4).world
	for pid in Households.pools(hungry):
		var m := {"m": hungry.month, "food_need": 1000, "food_eaten": 0}
		hungry.table("pool")[pid]["month"] = m
	for i in 6:
		Demography.monthly(fed)
		for pid in Households.pools(hungry):
			hungry.table("pool")[pid]["month"] = {"m": hungry.month, "food_need": 1000, "food_eaten": 0}
		Demography.monthly(hungry)
		fed.month += 1
		hungry.month += 1
	check(int(hungry.values.get("pop_deaths", 0)) > int(fed.values.get("pop_deaths", 0)),
		"a hungry colony loses more people (%d vs %d)" % [int(hungry.values.get("pop_deaths", 0)), int(fed.values.get("pop_deaths", 0))])
	check(int(hungry.values.get("pop_births", 0)) < int(fed.values.get("pop_births", 0)) or int(fed.values.get("pop_births", 0)) == 0,
		"and has fewer children")


func test_band_moves_take_their_jobs_and_savings_and_keep_everything_whole() -> void:
	var sim := GameSim.make(3)
	var w := sim.world
	var land := AreaStore.found_landing(w)
	for i in 3:
		Households.pay_support(w, "benefit", Ledger.EXTERNAL, {land: 50 * S})
		Demography.monthly(w)
		w.month += 1
	var money0 := 0
	for pid in Households.pools(w):
		money0 += Households.savings(w, pid)
	var people0 := PopStore.total(w)
	var jobs0 := 0
	for cid in Company.ids(w):
		jobs0 += Company.staff_count(w, cid)
	var moved := Demography.band_moves(w)
	check(moved > 0, "with wages against a small benefit, groups change band (%d persons)" % moved)
	var money1 := 0
	for pid in Households.pools(w):
		money1 += Households.savings(w, pid)
	var jobs1 := 0
	for cid in Company.ids(w):
		jobs1 += Company.staff_count(w, cid)
	check_eq(money1, money0, "savings only move between pools")
	check_eq(PopStore.total(w), people0, "nobody appears or vanishes")
	check_eq(jobs1, jobs0, "every post is still filled: the jobs went with the people")
	check(PopStore.reconcile(w).is_empty(), "the population reconciles")
	check(Households.check(w).is_empty(), "jobs = people: %s" % str(Households.check(w)))
	check(not Logbook.rows(w, {"kind": "BAND"}).is_empty(), "each move is a log row")


func test_settlers_land_and_young_jobless_leave() -> void:
	var sim := GameSim.make(3)
	var w := sim.world
	var land := AreaStore.found_landing(w)
	var before := PopStore.total(w)
	check_eq(Households.land_settlers(w, land, 100), 100, "a hundred landed")
	check_eq(PopStore.total(w), before + 100, "counted as arrivals")
	check_eq(w.facts.query("ECON_MIGRANTS_ARRIVED", 0).size(), 1, "a fact")
	var gone := Households.departures(w, land)
	check(gone >= 0, "some may leave (%d)" % gone)
	check(PopStore.reconcile(w).is_empty(), "the population reconciles")
	check(Households.check(w).is_empty(), "jobs = people")


func test_a_worker_quits_for_a_better_paid_post() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	_pool(w, land, "I2", 6, 1000)
	var needs := Households.needs_per_worker(w, land)
	var a := Company.create(w, "BUILDER", "SMALL", {"kind": "HOME_WORLD", "holders": {"hw": 1000}}, "low", {"area": land})
	var p0 := needs - needs % 1000 + 1000   # a whole credit above their needs, so 10% of it is exact
	check_eq(Households.hire(w, a, "crew", "G", land, 6, {}, p0), 6, "hired just above their needs")
	var b := Company.create(w, "BUILDER", "SMALL", {"kind": "HOME_WORLD", "holders": {"hw": 1000}}, "high", {"area": land})
	Company.set_hiring_salary(w, b, "G", land, p0 * 11 / 10)   # exactly the bar: 10%
	var open := 0
	for v in Company.vacancies(w, land):
		if String(v["cid"]) == b and String(v["tier"]) == "G":
			open = int(v["open"])
	check(open > 0, "the better payer has open general posts (%d)" % open)
	var moved := Households.labour_month(w)
	check_eq(moved, mini(6, open), "they move for the better pay")
	check_eq(Company.staff_count(w, b, "G") / S, mini(6, open), "now at the better payer")
	check(Households.check(w).is_empty(), "jobs = people")
	check(not Logbook.rows(w, {"kind": "JOB", "what": "QUIT_FOR_PAY"}).is_empty(), "each move is a log row")


func test_press_income_is_shared_by_the_employed() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	var p1 := _pool(w, land, "I2", 4, 0)
	var p2 := _pool(w, land, "I3", 4, 0)
	w.ledger.open_account("media:test")
	w.ledger.transfer(Ledger.EXTERNAL, "media:test", 90 * S, "TEST", w.month)
	check_eq(Households.pay_income(w, "media:test", 100 * S, land, "press"), 90 * S, "never more than the account holds")
	check_eq(Households.savings(w, p1) + Households.savings(w, p2), 90 * S, "all of it reached the pools")
	check_eq(int(Households.income(w, p1).get("press", 0)), 45 * S, "shared evenly (by persons, as nobody works)")


func test_life_survives_a_save_and_the_game_continues_the_same() -> void:
	var a := GameSim.make(6)
	for _m in 14:   # past a January: ageing, the band moves and the yearly raise have run
		a.step()
	var path := "user://test_households_month.sav"
	check_eq(SaveIO.save(a, path), OK, "saved")
	var c := GameSim.for_load()
	check_eq(SaveIO.load_into(c, path), OK, "loaded")
	for _m in 2:
		a.step()
		c.step()
	check_eq(c.world.state_hash(), a.world.state_hash(), "save/load/continue stays identical")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_one_grant_per_household_survives_a_founder_going_back() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	var pid := _pool(w, land, "I2", 10, 1000)   # 4 households; one household's share of 1,000 is 250
	var share := Households.household_share(w, pid)
	var need := share + 5000 * S                 # only with a grant can a household of this pool found
	var grants := {pid: 10000 * S}
	check_eq(Households.pick_founder(w, land, need, grants), pid, "with the grant it can found")
	var f1 := Households.make_founder(w, pid, "plan:a")
	check(not bool(Households.person(w, f1)["had_grant"]), "it had no grant before")
	Households.mark_granted(w, f1)
	check(bool(Households.person(w, f1)["had_grant"]), "marked when the grant is paid")
	Households.disown(w, f1, "plan:a")
	Households.release_founder(w, f1)
	check_eq(int(w.peek("pool")[pid]["granted"]), 1, "it went back as a household that has had its grant")
	var hh := int(Households.counts(w, pid)["households"]) / S
	w.table("pool")[pid]["granted"] = hh          # every household of the pool has had its grant now
	check_eq(Households.pick_founder(w, land, need, grants), "", "none of them can take a second one")
	w.table("pool")[pid]["granted"] = hh - 1
	check_eq(Households.pick_founder(w, land, need, grants), pid, "one household without a grant: it can")
	var f2 := Households.make_founder(w, pid, "plan:b")
	check(not bool(Households.person(w, f2)["had_grant"]), "and it is the one drawn")
	check_eq(int(w.peek("pool")[pid]["granted"]), hh - 1, "the granted count is unchanged by an ungranted founder leaving")


func test_a_small_colony_still_loses_some_of_its_young_jobless() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	_pool(w, land, "I2", 5, 0)   # 5 unemployed, about 2 of them young
	var gone := 0
	for i in 40:
		gone += Households.departures(w, land)
		w.month += 1
	check(gone > 0, "over many ships some leave, with fewer than ten young jobless (%d)" % gone)


func test_ages_follow_people_when_areas_split() -> void:
	var w := _world()
	AreaStore.change_listeners = [func(world, moves): Demography.on_area_moves(world, moves)]
	var l := Terrain.landing(w)
	var a := AreaStore.place_housing(w, l, 300, "GOV")
	var t2 := l + Vector2i(1, 0)
	var rows: Array = w.table("map")["grid"]["rows"]
	rows[t2.y] = String(rows[t2.y]).substr(0, t2.x) + "." + String(rows[t2.y]).substr(t2.x + 1)
	AreaStore.place_housing(w, t2, 300, "GOV")
	Households.seed_test(w, a, "I2", "G", 400)
	var h0 := 0
	for x in Demography.histogram(w, a):
		h0 += int(x)
	var b := AreaStore.split(w, a, [t2], "SETTLEMENT", "TEST")
	var ha := 0
	var hb := 0
	for x in Demography.histogram(w, a):
		ha += int(x)
	for x in Demography.histogram(w, b):
		hb += int(x)
	check_eq(ha + hb, h0, "no age lost or doubled")
	check_eq(hb, AreaStore.residents(w, b), "the new area's ages are its people's")
	check_eq(ha, AreaStore.residents(w, a), "and the old area keeps the rest")


func test_a_pool_with_half_the_money_for_its_food_buys_half_its_food() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	var cid := _seller(w, land, 100)
	var price := Company.price(w, cid, "FOOD")
	var pid := Households.seed_test(w, land, "I2", "G", 10)
	w.ledger.transfer(Ledger.EXTERNAL, Households.account(pid), 5 * price, "TEST", w.month)   # half of ten units
	_buy_month(w)
	var m := Households.month_of(w, pid)
	check_eq(int(m["food_bought"]), 5 * S, "half the money buys half the food, not none")
	check_eq(int(m["hunger_price"]), 5 * S, "the rest is a refusal of the price: the seller hears it (23a)")
	check_eq(Households.savings(w, pid), 0, "its money went on food")


func test_money_for_food_only_goes_on_food_and_the_rent_is_owed() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	var cid := _seller(w, land, 100)
	var price := Company.price(w, cid, "FOOD")
	var pid := Households.seed_test(w, land, "I2", "G", 10)
	w.ledger.transfer(Ledger.EXTERNAL, Households.account(pid), 10 * price, "TEST", w.month)   # exactly the food
	w.ledger.open_account("test:landlord")
	_buy_month(w)
	var rent := func(id: String) -> Dictionary: return {"test:landlord": 100 * S} if id == pid else {}
	Households.pay_rent(w, rent)
	var m := Households.month_of(w, pid)
	check_eq(int(m["food_bought"]), 10 * S, "food first: all of it")
	check_eq(int(m["rent_paid"]), 0, "nothing left for the rent")
	check_eq(int(w.peek("pool")[pid]["rent_owed"]["test:landlord"]), 100 * S, "so it is owed")



## Two builders in the Landing: `a` employs 6 general workers at p0 since month `m0`; `b` offers `offer`. Returns
## [world, a, b, open posts at b].
func _bar_world(offer_pm: int, years: int) -> Array:
	var w := _world()
	var land := AreaStore.found_landing(w)
	_pool(w, land, "I2", 6, 1000)
	var needs := Households.needs_per_worker(w, land)
	var p0 := needs - needs % 1000 + 1000
	var a := Company.create(w, "BUILDER", "SMALL", {"kind": "HOME_WORLD", "holders": {"hw": 1000}}, "low", {"area": land})
	Households.hire(w, a, "crew", "G", land, 6, {}, p0)
	w.month += 12 * years
	var b := Company.create(w, "BUILDER", "SMALL", {"kind": "HOME_WORLD", "holders": {"hw": 1000}}, "high", {"area": land})
	Company.set_hiring_salary(w, b, "G", land, p0 * (1000 + offer_pm) / 1000)
	var open := 0
	for v in Company.vacancies(w, land):
		if String(v["cid"]) == b and String(v["tier"]) == "G":
			open = int(v["open"])
	return [w, a, b, open, p0]


func test_a_raise_below_ten_percent_moves_nobody_and_says_why() -> void:
	var r := _bar_world(99, 0)   # 9.9%
	var w: WorldState = r[0]
	check(int(r[3]) > 0, "the better payer has open posts")
	check_eq(Households.labour_month(w), 0, "9.9% more is below the 10% bar: nobody moves")
	var rows := Logbook.rows(w, {"kind": "STAY"})
	check_eq(rows.size(), 1, "one STAY row for the company")
	var e: Dictionary = (rows[0]["why"]["entries"] as Dictionary).values()[0]
	check_eq(int(e["bar_pm"]), 100, "the bar: 10%")
	check_eq(int(e["old_pay"]), int(r[4]), "the old pay")
	check_eq(int(e["new_pay"]), int(r[4]) * 1099 / 1000, "the pay offered")
	check_eq(int(rows[0]["change"]["stayed"][1]), 6, "all six stayed")


func test_ten_percent_moves_a_new_worker() -> void:
	var r := _bar_world(100, 0)
	var w: WorldState = r[0]
	check_eq(Households.labour_month(w), mini(6, int(r[3])), "10% more reaches the bar")
	var row: Dictionary = Logbook.rows(w, {"kind": "JOB", "what": "QUIT_FOR_PAY"})[0]
	check_eq(int(row["why"]["bar_pm"]), 100, "the bar is on the JOB row")
	check_eq(int(row["why"]["old_pay"]), int(r[4]), "with the old pay")
	check_eq(int(row["why"]["new_pay"]), int(r[4]) * 11 / 10, "and the new pay")
	check(Households.check(w).is_empty(), "jobs = people")


func test_three_years_at_the_workplace_raise_the_bar_to_thirteen_percent() -> void:
	var r := _bar_world(129, 3)
	check_eq(Households.labour_month(r[0]), 0, "12.9% is below 13% after three full years")
	var e: Dictionary = (Logbook.rows(r[0], {"kind": "STAY"})[0]["why"]["entries"] as Dictionary).values()[0]
	check_eq(int(e["bar_pm"]), 130, "the bar: 10% + 3 x 1%")
	check_eq(int(e["years"]), 3, "three years")
	var r2 := _bar_world(130, 3)
	check(Households.labour_month(r2[0]) > 0, "13% moves them")


func test_the_bar_stops_at_fifteen_percent() -> void:
	var r := _bar_world(150, 9)
	check(Households.labour_month(r[0]) > 0, "after nine years 15% is enough: up to 15%")
	var r2 := _bar_world(149, 9)
	check_eq(Households.labour_month(r2[0]), 0, "14.9% is not")


func test_years_go_with_a_band_move_and_start_again_after_a_job_move() -> void:
	var r := _bar_world(100, 2)
	var w: WorldState = r[0]
	var a: String = r[1]
	var land := String(AreaStore.areas(w)[0]["id"])
	Households.move_jobs_band(w, land, "I2", "I3", "G")
	var e: Dictionary = Company.payroll(w, a)[0]
	check_eq(String(e["labour_key"]), Households.labour_key(land, "I3", "G"), "the jobs moved band")
	check_eq(Households.years_at(w, e), 2, "and kept their two years at the workplace")
	Households.move_jobs_band(w, land, "I3", "I2", "G")   # back, to where the people are (only the jobs moved here)
	Households.labour_month(w)   # 12% bar not reached by 10%: they stay
	check_eq(Company.staff_count(w, a) / S, 6, "two years: 10% is not enough")
	var b: String = r[2]
	Company.set_hiring_salary(w, b, "G", land, int(r[4]) * 12 / 10)
	var moved := Households.labour_month(w)
	check(moved > 0, "20% is")
	for x in Company.payroll(w, b):
		check_eq(int(x["since"]), w.month, "at the new company the years start again")


func test_joining_an_entry_keeps_each_hires_own_years() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	_pool(w, land, "I2", 8, 1000)
	var needs := Households.needs_per_worker(w, land)
	var a := Company.create(w, "BUILDER", "SMALL", {"kind": "HOME_WORLD", "holders": {"hw": 1000}}, "low", {"area": land})
	Households.hire(w, a, "crew", "G", land, 4, {}, needs + 10 * S)
	w.month += 24
	Households.hire(w, a, "crew", "G", land, 4, {}, needs + 10 * S)
	var rows: Array = Company.payroll(w, a)
	check_eq(rows.map(func(e): return int(e["n"]) / S), [4, 4], "two hires, two rows (the user: merge only if all fields match)")
	check_eq(rows.map(func(e): return Households.years_at(w, e)), [2, 0], "each keeps its own years: no averaging")



## A builder employing 4 general workers of pool I2 at their needs + 100 credits, its account holding `money_months`
## months of one worker's pay. Returns [w, cid, pid, land, pay].
func _layoff_world(money_months: int) -> Array:
	var w := _world()
	var land := AreaStore.found_landing(w)
	var pid := _pool(w, land, "I2", 4, 0)
	var pay := Households.needs_per_worker(w, land) + 100 * S
	var money := money_months * pay
	var cid := Company.create(w, "BUILDER", "SMALL", {"kind": "HOME_WORLD", "holders": {"hw": 1000}}, "b", {"area": land})
	Households.hire(w, cid, "crew", "G", land, 4, {}, pay)
	var have := w.ledger.balance(CoreUtil.acct(cid))
	if have > 0:
		w.ledger.transfer(CoreUtil.acct(cid), Ledger.EXTERNAL, have, "TEST", w.month)
	if money > 0:
		w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.acct(cid), money, "TEST", w.month)
	return [w, cid, pid, land, pay]


func test_a_laid_off_worker_is_paid_three_months_of_their_own_pay() -> void:
	var r := _layoff_world(1000)
	var pay: int = r[4]
	var w: WorldState = r[0]
	check_eq(Households.layoff(w, r[1], "crew", "G", 2, {"reason": "LEVEL"}), 2, "two laid off")
	check_eq(int(Households.income(w, r[2]).get("layoff_pay", 0)), 2 * 3 * pay, "2 persons x 3 months x their pay, into their pool")
	var row: Dictionary = Logbook.rows(w, {"kind": "LAYOFF"})[0]
	check_eq(int(row["change"]["layoff_pay_owed"][1]), 2 * 3 * pay, "the row says what was owed")
	check_eq(int(row["change"]["layoff_pay_paid"][1]), 2 * 3 * pay, "and what was paid")
	check_eq(int(row["change"]["layoff_pay_debt"][1]), 0, "nothing left owed")
	check_eq(PopStore.count(w, {"hb": String(r[3]), "status": "UNEMPLOYED"}), 2, "they are jobless, so they draw the benefit too")


func test_what_the_company_cannot_pay_is_owed_through_the_law() -> void:
	var r := _layoff_world(2)   # two months of one worker's pay, of the six owed
	var pay: int = r[4]
	var w: WorldState = r[0]
	Households.layoff(w, r[1], "crew", "G", 2, {"reason": "UNPAID"})
	check_eq(int(Households.income(w, r[2]).get("layoff_pay", 0)), 2 * pay, "paid as far as the account reaches")
	check_eq(w.ledger.balance(CoreUtil.acct(r[1])), 0, "all of it")
	var debt := 0
	for lid in w.peek("liability"):
		var l: Dictionary = w.peek("liability")[lid]
		if String(l["kind"]) == "LAYOFF_PAY" and String(l["debtor"]) == String(r[1]):
			check_eq(String(l["creditor"]), String(r[2]), "owed to the pool")
			check_eq(String(l["creditor_acct"]), Households.account(String(r[2])), "into the pool's account")
			debt += int(l["amount"])
	check_eq(debt, 6 * pay - 2 * pay, "the rest is a debt")
	check_eq(int(Logbook.rows(w, {"kind": "LAYOFF"})[0]["change"]["layoff_pay_debt"][1]), 4 * pay, "on the row too")


func test_quitting_death_and_leaving_owe_nothing() -> void:
	var r := _layoff_world(1000)
	var w: WorldState = r[0]
	var land: String = r[3]
	Households.end_jobs(w, land, "I2", 1, "QUIT")
	Households.end_jobs(w, land, "I2", 1, "DEATH")
	Households.end_jobs(w, land, "I2", 1, "RETIRE")
	Households.end_jobs(w, land, "I2", 1, "DEPART")
	check_eq(int(Households.income(w, r[2]).get("layoff_pay", 0)), 0, "no layoff pay")
	check_eq(w.ledger.balance(CoreUtil.acct(r[1])), 1000 * int(r[4]), "the company paid nothing")



func _owners(w: WorldState, land: String) -> int:
	return PopStore.count(w, {"hb": land, "occ": "BUSINESS_OWNER"})


func test_a_family_founder_takes_the_whole_household() -> void:
	var sim := GameSim.make(3)
	var w := sim.world
	var land := AreaStore.area_of(w, Terrain.landing(w))
	var pid := Households.pool_id(land, "I3")
	var total := PopStore.total(w)
	var hh0 := int(Households.counts(w, pid)["households"]) / S
	var fids: Array = []
	for i in 4:
		fids.append(Households.make_founder(w, pid, "", true))
	var size := 0
	for fid in fids:
		size += Households.family_size(w, fid)
	# households are counts of 2.5 persons: whole persons with the fractions carried, so four households hold about ten
	check(size >= 9 and size <= 11, "four households, not four adults (%d persons)" % size)
	check_eq(_owners(w, land), size, "every member of the four households is an owner's, in PopStore")
	check_eq(PopStore.total(w), total, "nobody appears or vanishes")
	check(absi(int(Households.counts(w, pid)["households"]) / S - (hh0 - 4)) <= 1, "the pool has about four households fewer")
	check(Households.check(w).is_empty(), "jobs = people")
	var b: Dictionary = Households.buyers(w).filter(func(x): return String(x["id"]) == String(fids[0]))[0]
	check_eq(int(b["persons"]), Households.family_size(w, fids[0]), "the founder buys food for the household")
	var one := Households.make_founder(w, pid, "")
	check_eq(Households.family_size(w, one), 1, "a founder of a larger company still leaves alone")


func test_the_family_works_its_posts_on_no_payroll_and_comes_back_whole() -> void:
	var sim := GameSim.make(3)
	var w := sim.world
	var land := AreaStore.area_of(w, Terrain.landing(w))
	var pid := Households.pool_id(land, "I3")
	var total := PopStore.total(w)
	var emp0 := PopStore.count(w, {"hb": land, "status": "EMPLOYED"})
	var fid := Households.make_founder(w, pid, "plan:x", true)
	var ad := Households.family_adults(w, fid)
	var sk := "G" if int(ad["G"]) > 0 else ("S" if int(ad["S"]) > 0 else "Sp")
	Households.family_work(w, fid, {sk: 99})
	check_eq(int(Households.family_working(w, fid)[sk]), int(ad[sk]), "never more than the family has")
	check_eq(PopStore.count(w, {"hb": land, "status": "EMPLOYED", "occ": "BUSINESS_OWNER"}), int(ad[sk]), "employed in the counts")
	check(PopStore.count(w, {"hb": land, "status": "EMPLOYED"}) >= emp0 - 2 + int(ad[sk]), "they add to the employed")
	check(Households.check(w).is_empty(), "on no payroll: jobs = people still holds")
	Households.disown(w, fid, "plan:x")
	check(Households.release_founder(w, fid), "the farm ended: back into the pool")
	check_eq(_owners(w, land), 0, "the whole household came back")
	check_eq(PopStore.total(w), total, "nobody appears or vanishes")


func test_winnings_are_the_familys_income() -> void:
	var sim := GameSim.make(3)
	var w := sim.world
	var land := AreaStore.area_of(w, Terrain.landing(w))
	var fid := Households.make_founder(w, Households.pool_id(land, "I3"), "", true)
	w.ledger.open_account("test:farm")
	w.ledger.transfer(Ledger.EXTERNAL, "test:farm", 50 * S, "TEST", w.month)
	var before := w.ledger.balance(fid)
	check_eq(Households.pay_winnings(w, fid, "test:farm", 80 * S), 50 * S, "never more than the farm holds")
	check_eq(w.ledger.balance(fid) - before, 50 * S, "into the founder's account")
	check_eq(int(Households.founder_income(w, fid)["winnings"]), 50 * S, "booked as winnings")


func test_a_death_in_the_family_is_taken_off_its_record() -> void:
	var sim := GameSim.make(3)
	var w := sim.world
	var land := AreaStore.area_of(w, Terrain.landing(w))
	var pid := Households.pool_id(land, "I3")
	var fid := ""
	for i in 20:   # a household with a child and a second adult
		var f := Households.make_founder(w, pid, "", true)
		var fam: Dictionary = w.peek("founder")[f]["family"]
		if int(fam["children"]) > 0 and (fam["adults"] as Array).size() > 1:
			fid = f
			break
	check(fid != "", "a household with a child and two adults")
	var n0 := Households.family_size(w, fid)
	var kid: String = PopStore.select(w, {"hb": land, "inc": "I3", "status": "CHILD", "occ": "BUSINESS_OWNER"})[0]
	PopStore.death(w, kid, 1)
	var sk := String(w.peek("founder")[fid]["family"]["adults"][1]["skill"])
	var ad: String = PopStore.select(w, {"hb": land, "inc": "I3", "status": "NOT_IN_LF", "occ": "BUSINESS_OWNER"}).filter(
		func(k): return int(w.peek("pop")[k]["skill"].get(sk, 0)) > 0)[0]
	PopStore.death(w, ad, 1, {"skill": sk})
	Households.reconcile_families(w)
	var size := 0
	for f in w.peek("founder"):
		size += Households.family_size(w, f)
	check_eq(size, _owners(w, land), "the records hold exactly the owners' people")
	check(Households.family_size(w, fid) <= n0, "the household shrank or another of the same band did")



func test_layoff_pay_collected_later_is_booked_as_layoff_pay() -> void:
	var r := _layoff_world(0)
	var w: WorldState = r[0]
	Households.debt_received(w, String(r[2]), "LAYOFF_PAY", 7 * S)
	check_eq(int(Households.income(w, r[2]).get("layoff_pay", 0)), 7 * S, "booked in the month it arrives")
	Households.debt_received(w, String(r[2]), "GRANT", 5 * S)
	Households.debt_received(w, "founder:9", "LAYOFF_PAY", 5 * S)
	check_eq(int(Households.income(w, r[2]).get("layoff_pay", 0)), 7 * S, "other kinds and creditors are not layoff pay")


func test_a_founder_who_owes_goes_back_carrying_the_debt() -> void:
	var sim := GameSim.make(3)
	var w := sim.world
	var land := AreaStore.area_of(w, Terrain.landing(w))
	var fid := Households.make_founder(w, Households.pool_id(land, "I3"), "", true)
	load("res://sim/law/justice_ops.gd").owe(w, fid, "gov", CoreUtil.TREASURY, 10 * S, "GRANT")
	check_eq(Households.release_idle_founders(w), 1, "owning nothing, back with the household at the month's retry")
	check(Households.person(w, fid).is_empty(), "a founder no more")
	check_eq(int(w.peek("founder_carried")[fid]["owed"]), 10 * S, "the debt keeps its name in a stub")
	for lid in w.peek("liability"):
		var l: Dictionary = w.peek("liability")[lid]
		check_eq(String(l["status"]), "OPEN", "still owed, for the court")
		check(bool(l["carried"]), "and carried")



## Ship food from the Stores at `ship_price` and a farm's food at `farm_price`, ten units each, in the Landing.
func _two_sellers(w: WorldState, land: String, ship_price: int, farm_price: int) -> void:
	var stores := Company.create(w, "SHOP", "SMALL", {"kind": "HOME_WORLD", "holders": {"hw": 1000}}, "stores", {"area": land})
	Company.stock_add(w, stores, "FOOD", 10 * S, 0, "LANDING", "landed")
	Company.offer(w, stores, "FOOD", ship_price)
	var farm := Company.create(w, "FARM", "SMALL", {"kind": "HOME_WORLD", "holders": {"hw": 1000}}, "farm", {"area": land})
	Company.stock_add(w, farm, "FOOD", 10 * S, 0, "OUTPUT", "grown")
	Company.set_price(w, farm, "FOOD", farm_price)


func test_with_money_for_all_its_food_a_pool_buys_colony_food_up_to_a_quarter_dearer() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	_two_sellers(w, land, 60 * S, 70 * S)
	var pid := Households.seed_test(w, land, "I2", "G", 10)
	w.ledger.transfer(Ledger.EXTERNAL, Households.account(pid), 700 * S - Households.savings(w, pid), "TEST", w.month)
	_buy_month(w)
	check_eq(int(Households.month_of(w, pid)["food_bought"]), 10 * S, "all ten units")
	check_eq(Households.savings(w, pid), 0, "at 70 each: the colony's food, though ship food was 60")


func test_with_money_for_part_of_its_food_a_pool_buys_the_cheaper_ship_food_and_eats_more() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	_two_sellers(w, land, 60 * S, 70 * S)
	var pid := Households.seed_test(w, land, "I2", "G", 10)
	w.ledger.transfer(Ledger.EXTERNAL, Households.account(pid), 600 * S - Households.savings(w, pid), "TEST", w.month)
	_buy_month(w)
	check_eq(int(Households.month_of(w, pid)["food_bought"]), 10 * S, "ten units of ship food at 60, not eight of the farm's at 70")
	check_eq(int(Households.month_of(w, pid)["hunger"]), 0, "nobody hungry beside unsold ship food")



func _family_people(w: WorldState) -> int:
	var n := 0
	for f in w.peek("founder"):
		n += Households.family_size(w, f)
	return n


func test_families_keep_their_records_through_a_split_and_a_merge() -> void:
	var w := _world()
	AreaStore.change_listeners = [func(world, moves): Demography.on_area_moves(world, moves)]
	var l := Terrain.landing(w)
	var a := AreaStore.place_housing(w, l, 300, "GOV")
	var t2 := l + Vector2i(1, 0)
	var rows: Array = w.table("map")["grid"]["rows"]
	rows[t2.y] = String(rows[t2.y]).substr(0, t2.x) + "." + String(rows[t2.y]).substr(t2.x + 1)
	AreaStore.place_housing(w, t2, 300, "GOV")
	var pid := Households.seed_test(w, a, "I2", "G", 400)
	var f1 := Households.make_founder(w, pid, "", true)
	var f2 := Households.make_founder(w, pid, "", true)
	var owners := _family_people(w)
	check(owners >= 3, "two households (%d persons)" % owners)
	var total := PopStore.total(w)
	var b := AreaStore.split(w, a, [t2], "SETTLEMENT", "TEST")
	check_eq(PopStore.count(w, {"hb": a, "occ": "BUSINESS_OWNER"}), owners, "a split leaves the owners' households where their records are")
	check_eq(PopStore.count(w, {"hb": b, "occ": "BUSINESS_OWNER"}), 0, "none moved without their record")
	Households.reconcile_families(w)
	check_eq(_family_people(w), owners, "nobody taken off a record as if dead")
	AreaStore.merge(w, b, a)   # a merges into b: everyone moves, owners too
	check_eq(String(Households.person(w, f1)["area"]), b, "the records follow their people")
	check_eq(String(Households.person(w, f2)["pool"]), Households.pool_id(b, "I2"), "into the pool of the same band there")
	Households.reconcile_families(w)
	check_eq(_family_people(w), owners, "nobody dropped after the merge")
	check_eq(PopStore.count(w, {"hb": b, "occ": "BUSINESS_OWNER"}), owners, "and every owner has a record")
	check_eq(PopStore.total(w), total, "nobody appears or vanishes")


func test_a_death_at_work_on_the_family_farm_takes_one_off_the_posts() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	var pid := Households.seed_test(w, land, "I2", "G", 40)
	var fid := ""
	for i in 10:
		var f := Households.make_founder(w, pid, "", true)
		if int(Households.family_adults(w, f)["G"]) >= 2:
			fid = f
			break
	check(fid != "", "a household with two adults")
	Households.family_work(w, fid, {"G": 2})
	var k: String = PopStore.select(w, {"hb": land, "inc": "I2", "status": "EMPLOYED", "occ": "BUSINESS_OWNER"})[0]
	PopStore.death(w, k, 1)
	Households.reconcile_families(w)
	var working := 0
	for f in w.peek("founder"):
		working += int(Households.family_working(w, f)["G"])
	check_eq(working, PopStore.count(w, {"hb": land, "status": "EMPLOYED", "occ": "BUSINESS_OWNER"}), "the records' workers are the employed owners' people")
	check_eq(int(Households.family_working(w, fid)["G"]), 1, "one fewer at work")



func test_an_adult_outside_the_labour_force_can_found_beside_a_founder() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	var pid := Households.ensure_pool(w, land, "I2")
	PopStore.seed_leaf(w, {"hb": land, "inc": "I2", "occ": "NONE", "status": "NOT_IN_LF", "arch": Households.ARCH, "eff": "e0"}, 2, {"age": {"A": 2}, "skill": {"G": 2}})
	check(Households.make_founder(w, pid, "") != "", "the first founds")
	check(Households.make_founder(w, pid, "") != "", "the second is still free: a founder beside them is not counted against them")
	check_eq(Households.make_founder(w, pid, ""), "", "nobody left")



func test_the_landings_hires_start_trained_and_say_so() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	_pool(w, land, "I2", 6, 1000)
	var pay := Households.needs_per_worker(w, land) + 10 * S
	var a := Company.create(w, "BUILDER", "SMALL", {"kind": "HOME_WORLD", "holders": {"hw": 1000}}, "a", {"area": land})
	check_eq(Households.hire(w, a, "crew", "G", land, 3, {}, pay, true), 3, "hired")
	check(bool(Logbook.rows(w, {"kind": "HIRE"})[0]["why"]["trained"]), "the row says trained")
	check_eq(int(Company.payroll(w, a)[0]["since"]), w.month, "here since this month")
	check_eq(Households.hire(w, a, "crew", "G", land, 3, {}, pay), 3, "a later hire")
	check(not bool(Logbook.rows(w, {"kind": "HIRE"})[1]["why"]["trained"]), "trains")



## The store (15f). A pool of ten with `money` credits exactly, and a farm with `qty` units at `price` credits.
func _store_world(w: WorldState, land: String, money: int, qty: int, price: int) -> String:
	if qty > 0:
		var farm := _seller(w, land, qty)
		Company.set_price(w, farm, "FOOD", price * S)
	var pid := Households.seed_test(w, land, "I2", "G", 10)
	w.ledger.transfer(Ledger.EXTERNAL, Households.account(pid), money * S - Households.savings(w, pid), "TEST", w.month)
	return pid


func test_a_pool_with_money_buys_double_until_its_store_holds_six_months() -> void:
	# 15f, the user (2026-11-18): "THEY BUY DOUBLE UNTIL THEY FILL SIX MONTHS THAT WAS TOO EVEN IF OUT" (to even it out)
	var w := _world()
	var land := AreaStore.found_landing(w)
	var pid := _store_world(w, land, 100000, 500, 50)
	var m := {}
	for i in 6:
		_buy_month(w)
		m = Households.month_of(w, pid)
		check_eq([int(m["food_bought"]), int(m["store_bought"])], [10 * S, 10 * S], "month %d: double, never more" % (i + 1))
		var sid := String(m["orders"]["FOOD_STORE"])
		check_eq(int(Logbook.rows(w, {"kind": "ORDER", "ref": sid})[0]["why"]["qty"]), 10 * S, "the store order asks one month's food")
		check_eq(int(m["store_eaten"]), 0, "and eats its month's food, not the store")
		w.month += 1
	check(int(m["store_pm"]) >= 5700 and int(m["store_pm"]) < 6000, "six months stored, less what spoiled: %d" % int(m["store_pm"]))
	_buy_month(w)
	m = Households.month_of(w, pid)
	check(int(m["store_bought"]) > 0 and int(m["store_bought"]) < 10 * S, "the seventh month tops up what spoiled: %d" % int(m["store_bought"]))
	check_eq(int(m["store_pm"]), 5940, "six months held, less this month's 1% spoiled")
	w.month += 1
	_buy_month(w)
	check_eq(int(Households.month_of(w, pid)["store_bought"]), 600, "then only what spoiled: it stops at six months")
	check_eq(Logbook.rows(w, {"kind": "STORE", "who": pid}).size(), 8, "one STORE row a month")


func test_a_pool_with_money_for_its_food_only_holds_no_store() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	var pid := _store_world(w, land, 500, 500, 50)
	_buy_month(w)
	var m := Households.month_of(w, pid)
	check_eq(int(m["food_bought"]), 10 * S, "its food")
	check(not (m["orders"] as Dictionary).has("FOOD_STORE"), "no store order: nothing left for it")
	check_eq(int(w.table("pool")[pid]["stock"].get("FOOD", 0)), 0, "nothing held")


func test_a_store_is_eaten_when_nothing_can_be_bought_and_hunger_comes_when_it_is_gone() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	var pid := _store_world(w, land, 100000, 0, 0)
	w.table("pool")[pid]["stock"] = {"FOOD": 20 * S}
	_buy_month(w)
	var m := Households.month_of(w, pid)
	check_eq(int(m["store_eaten"]), 10 * S, "a month eaten from the store")
	check_eq(int(m["hunger"]), 0, "nobody hungry")
	check_eq(int(w.table("pool")[pid]["stock"]["FOOD"]), 9900, "ten left, less 1% spoiled")
	w.month += 1
	_buy_month(w)
	m = Households.month_of(w, pid)
	check_eq(int(m["store_eaten"]), 9900, "the rest of the store")
	check_eq(int(m["hunger"]), 100, "hungry only for what spoiled away")
	w.month += 1
	_buy_month(w)
	check_eq(int(Households.month_of(w, pid)["hunger"]), 10 * S, "the store gone: hungry")


func test_a_drawn_down_store_is_refilled_at_once_even_when_food_is_dear() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	var pid := _store_world(w, land, 100000, 500, 500)   # ten times the price above
	w.table("pool")[pid]["stock"] = {"FOOD": 30 * S}
	_buy_month(w)
	check_eq(int(Households.month_of(w, pid)["store_bought"]), 10 * S, "double again at once at 500 a unit: it does not wait")


func test_the_store_comes_from_what_the_months_food_and_the_rent_leave() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	var pid := _store_world(w, land, 500 + 100 + 150, 500, 50)
	w.ledger.open_account("test:landlord")
	var rent := func(id: String) -> Dictionary: return {"test:landlord": 100 * S} if id == pid else {}
	Households.post_orders(w, rent)
	Market.clear(w)
	Households.after_market(w)
	var m := Households.month_of(w, pid)
	check_eq(int(m["food_bought"]), 10 * S, "the month's food first")
	check_eq(int(m["store_bought"]), 3 * S, "then three units from the 150 left after the rent")
	check_eq(Households.savings(w, pid), 100 * S, "the rent's money is still there")
	var sid := String(m["orders"]["FOOD_STORE"])
	check_eq(int(Logbook.rows(w, {"kind": "ORDER", "ref": sid})[0]["why"]["qty"]), 3 * S,
		"the store order asks only for what its money buys (Bob's review: no orders nobody can pay for)")


func test_the_months_food_of_every_household_comes_before_anyones_store() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	var rich := _store_world(w, land, 100000, 25, 50)
	var poor := Households.seed_test(w, land, "I1", "G", 10)
	w.ledger.transfer(Ledger.EXTERNAL, Households.account(poor), 500 * S - Households.savings(w, poor), "TEST", w.month)
	_buy_month(w)
	check_eq(int(Households.month_of(w, poor)["hunger"]), 0, "the poor household eats its month")
	check_eq(int(Households.month_of(w, rich)["food_bought"]), 10 * S, "so does the rich one")
	check_eq(int(Households.month_of(w, rich)["store_bought"]), 5 * S, "and stores only what was left")


func test_a_founder_takes_a_households_share_of_the_store() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	var pid := Households.seed_test(w, land, "I2", "G", 10)
	w.table("pool")[pid]["stock"] = {"FOOD": 100 * S}
	var fid := Households.make_founder(w, pid, "")
	check_eq(int(Households.person(w, fid)["stock"]["FOOD"]), 10 * S, "one person of ten: a tenth of the store")
	check_eq(int(w.table("pool")[pid]["stock"]["FOOD"]), 90 * S, "the rest stays: nothing appears or vanishes")



func _area_food(w: WorldState) -> int:
	var n := 0
	for pid in Households.pools(w):
		n += int(w.peek("pool")[pid].get("stock", {}).get("FOOD", 0))
	return n


func _area_money(w: WorldState) -> int:
	var n := 0
	for pid in Households.pools(w):
		n += Households.savings(w, pid)
	return n


func test_savings_and_the_store_follow_people_through_a_split_and_a_merge() -> void:
	var w := _world()
	AreaStore.change_listeners = [func(world, moves): Demography.on_area_moves(world, moves)]
	var l := Terrain.landing(w)
	var a := AreaStore.place_housing(w, l, 300, "GOV")
	var t2 := l + Vector2i(1, 0)
	var rows: Array = w.table("map")["grid"]["rows"]
	rows[t2.y] = String(rows[t2.y]).substr(0, t2.x) + "." + String(rows[t2.y]).substr(t2.x + 1)
	AreaStore.place_housing(w, t2, 300, "GOV")
	var pid := Households.seed_test(w, a, "I2", "G", 400)
	w.table("pool")[pid]["stock"] = {"FOOD": 4000 * S}
	w.ledger.transfer(Ledger.EXTERNAL, Households.account(pid), 40000 * S, "TEST", w.month)
	var money := _area_money(w)
	var b := AreaStore.split(w, a, [t2], "SETTLEMENT", "TEST")
	var pb := Households.pool_id(b, "I2")
	var nb := Households.persons(w, pb)
	check(nb > 0, "people moved to the new area")
	check_eq(int(w.peek("pool")[pb]["stock"]["FOOD"]), 4000 * S * nb / 400, "their part of the store went with them")
	check_eq(_area_food(w), 4000 * S, "no food appears or vanishes")
	check_eq(_area_money(w), money, "no money appears or vanishes")
	check(Households.savings(w, pb) > 0, "and their part of the savings")
	AreaStore.merge(w, b, a)   # a merges into b: everyone moves
	check_eq(int(w.peek("pool")[pid].get("stock", {}).get("FOOD", 0)), 0, "the merged-away pool holds no food")
	check_eq(Households.savings(w, pid), 0, "and no money")
	check_eq(int(w.peek("pool")[pb]["stock"]["FOOD"]), 4000 * S, "all of it is where the people are")
	check_eq(_area_money(w), money, "still no money appears or vanishes")
	check(Logbook.rows(w, {"kind": "AREA"}).size() >= 2, "AREA rows")


## A founder's household of three (two adults, one child) whose own FAMILY farm holds `food` units; the founder has
## `money` credits.
func _farm_family(w: WorldState, land: String, food: int, money: int) -> Array:
	var pid := _pool(w, land, "I2", 10, 0)
	var fid := Households.make_founder(w, pid, "", true)
	w.table("founder")[fid]["family"]["adults"] = [{"skill": "G", "was": "UNEMPLOYED"}, {"skill": "G", "was": "UNEMPLOYED"}]
	w.table("founder")[fid]["family"]["children"] = 1
	var acct := String(w.peek("founder")[fid]["account"])
	var bal := w.ledger.balance(acct)
	if bal > 0:
		w.ledger.transfer(acct, Ledger.EXTERNAL, bal, "TEST", w.month)
	if money > 0:
		w.ledger.transfer(Ledger.EXTERNAL, acct, money * S, "TEST", w.month)
	var cid := Company.create(w, "FARM", "FAMILY", {"kind": "PRIVATE", "holders": {fid: 1000}}, "family farm", {"area": land})
	var plant := Company.add_plant(w, cid, "FAMILY")
	Company.family_set(w, cid, plant, fid, {})
	if food > 0:
		Company.stock_add(w, cid, "FOOD", food * S, 0, "OUTPUT", "made")
	return [fid, cid]


func test_a_farm_family_of_three_takes_six_of_thirty_and_the_farm_offers_twenty_four() -> void:
	# 15e, the user: "THEY ARE THREE THEY CAN PRODUVE 30 ... THEY WOULD TAKE SIX OUT OF THIRTY SELL 24"
	var w := _world()
	var land := AreaStore.found_landing(w)
	var r := _farm_family(w, land, 30, 0)
	var fid := String(r[0])
	var cid := String(r[1])
	check_eq(Households.family_size(w, fid), 3, "they are three")
	Households.post_orders(w)
	check_eq(int(Company.stock_of(w, cid, "FOOD")["qty"]), 24 * S, "they took six: their month and the store's double")
	var offered := 0
	for off in Market.offers(w, "FOOD", land):
		offered += int(off["qty"])
	check_eq(offered, 24 * S, "the farm offers 24")
	var m: Dictionary = w.peek("founder")[fid]["month"]
	check_eq([int(m["farm_eat"]), int(m["farm_store"])], [3 * S, 3 * S], "three to eat, three to store")
	check(not (m["orders"] as Dictionary).has("FOOD"), "nothing left to buy for the month")
	Market.clear(w)
	Households.after_market(w)
	m = w.peek("founder")[fid]["month"]
	check_eq(int(m["hunger"]), 0, "with no money at all, nobody hungry: the farm made food")
	check_eq(int(m["store_eaten"]), 0, "they ate their own month's food, not the store")
	check_eq(int(w.peek("founder")[fid]["stock"]["FOOD"]), 3 * S - 3 * S * 10 / 1000, "three stored, less 1% spoiled")
	check_eq(w.ledger.balance(String(w.peek("founder")[fid]["account"])), 0, "no money changed hands")
	check_eq(Logbook.rows(w, {"kind": "TAKE", "who": cid}).size(), 1, "one TAKE row (Bob's)")


func test_a_farm_family_with_six_months_stored_takes_only_its_month() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	var r := _farm_family(w, land, 30, 0)
	var fid := String(r[0])
	w.table("founder")[fid]["stock"] = {"FOOD": 18 * S}
	Households.post_orders(w)
	check_eq(int(Company.stock_of(w, String(r[1]), "FOOD")["qty"]), 27 * S, "six months held: only the month's three")


func test_a_farm_family_buys_what_its_farm_could_not_give() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	var r := _farm_family(w, land, 1, 10000)
	var fid := String(r[0])
	_seller(w, land, 100)
	_buy_month(w)
	var m: Dictionary = w.peek("founder")[fid]["month"]
	check_eq(int(m.get("farm_eat", 0)), 1 * S, "the one unit the farm had")
	check_eq(int(m["food_bought"]), 2 * S, "the rest of the month bought")
	check_eq(int(m["store_bought"]), 3 * S, "and the store's double bought: one month's more")
	check_eq(int(m["hunger"]), 0, "fed")
	check_eq(int(Company.stock_of(w, String(r[1]), "FOOD")["qty"]), 0, "the farm offered nothing: its family ate it")


## A pool of ten general workers, all employed by a state builder's crew at 300 a month, and a plan still MADE.
func _employed_pool(w: WorldState, land: String) -> Array:
	var pid := _pool(w, land, "I2", 10, 10000)
	var cid := Company.create(w, "BUILDER", "SMALL", {"kind": "STATE", "holders": {"gov": 1000}}, "test builder", {"area": land})
	check_eq(Households.hire(w, cid, "crew", "G", land, 10, {}, 300 * S), 10, "all ten in posts")
	w.table("plan")["plan:t1"] = {"id": "plan:t1", "status": "MADE"}
	return [pid, cid]


func _rows(w: WorldState, cid: String) -> Array:
	return Company.payroll(w, cid).map(func(e): return [int(e["n"]), int(e["pay"]), int(e["since"]), int(e["train"])])


func _all_money(w: WorldState) -> int:
	var n := 0
	for pid in Households.pools(w):
		n += Households.savings(w, pid)
	for fid in w.peek("founder"):
		n += w.ledger.balance(String(w.peek("founder")[fid]["account"]))
	return n


func test_a_founder_whose_plan_is_given_up_has_not_lost_their_job() -> void:
	# Wilma, 2026-11-18: "a person whose plan is given up the same month, or never signed, has not lost their job"
	var w := _world()
	var land := AreaStore.found_landing(w)
	var r := _employed_pool(w, land)
	var pid := String(r[0])
	var cid := String(r[1])
	w.month += 3
	var rows0 := _rows(w, cid)
	var money0 := _all_money(w)
	var hh0 := int(Households.homes(w, land)["households"])
	var fid := Households.make_founder(w, pid, "plan:t1")
	check(fid != "", "an employed adult founds")
	check_eq(int(Households.homes(w, land)["households"]), hh0, "still one of the pool's households, not a second one (Terra)")
	check_eq(Households.rent_set_aside(w, fid, func(_id): return {"x": 100 * S}), 0, "no rent of its own: the pool pays for them")
	check_eq(_rows(w, cid), rows0, "at making nobody's post moved: same people, pay, month and training")
	check_eq(Households.in_post(w, fid), 1, "the founder is still in their post")
	check(Households.check(w).is_empty(), "jobs = people")
	check(w.ledger.balance(fid) > 0, "the plan's money is the founder's: a household's share of the savings")
	check_eq(_all_money(w), money0, "the money moved, none made or lost")
	var b: Dictionary = Households.buyers(w).filter(func(x): return String(x["id"]) == fid)[0]
	check_eq(int(b["persons"]), 0, "they eat with their pool while in post: nobody eats twice")
	check_eq(Households.make_founder(w, pid, "plan:t2").length() > 0 and int(w.peek("pool")[pid]["in_post"]["G"]) == 2, true,
		"a second founder draws another person, not the same one")
	Households.disown(w, fid, "plan:t1")   # the plan given up
	check(Households.release_founder(w, fid), "the founder goes back")
	check_eq(_rows(w, cid), rows0, "given up: still in the job, same pay, month served and training")
	check(Households.check(w).is_empty(), "jobs = people")
	check_eq(int(w.peek("pool")[pid]["in_post"].get("G", 0)), 1, "only the second founder still promised")
	check_eq(_all_money(w), money0, "what was left came back: nothing counted twice or lost")
	check_eq(PopStore.count(w, {"hb": land, "inc": "I2", "status": "EMPLOYED"}), 10, "all ten still employed")


func test_a_founder_whose_plan_signs_gives_up_the_post() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	var r := _employed_pool(w, land)
	var pid := String(r[0])
	var cid := String(r[1])
	var fid := Households.make_founder(w, pid, "plan:t1")
	Households.release_idle_founders(w)
	check_eq(Households.in_post(w, fid), 1, "still MADE: still in post")
	w.table("plan")["plan:t1"]["status"] = "SIGNED"
	Households.release_idle_founders(w)
	check_eq(Households.in_post(w, fid), 0, "signed: the post is given up")
	check_eq(Company.staff_count(w, cid) / S, 9, "one post fewer")
	check_eq(PopStore.count(w, {"hb": land, "inc": "I2", "status": "NOT_IN_LF", "occ": "BUSINESS_OWNER"}), 1, "the founder is an owner now")
	check(Households.check(w).is_empty(), "jobs = people")
	check(not w.peek("pool")[pid].has("in_post") or (w.peek("pool")[pid]["in_post"] as Dictionary).is_empty(), "nobody promised any more")
	var b: Dictionary = Households.buyers(w).filter(func(x): return String(x["id"]) == fid)[0]
	check_eq(int(b["persons"]), 1, "and eats from their own account")
	check_eq(Logbook.rows(w, {"kind": "FOUNDER", "what": "the plan signed: gave up their posts"}).size(), 1, "one row")


func test_a_family_founders_employed_adults_keep_their_posts_until_the_plan_signs() -> void:
	var w := _world()
	var land := AreaStore.found_landing(w)
	var r := _employed_pool(w, land)
	var pid := String(r[0])
	var cid := String(r[1])
	var rows0 := _rows(w, cid)
	var fid := Households.make_founder(w, pid, "plan:t1", true)
	var k := Households.in_post(w, fid)
	check(k >= 1, "the founder and any other adult of the household stay in post (%d)" % k)
	check_eq(_rows(w, cid), rows0, "no post moved at making")
	check_eq(int(Households.family_adults(w, fid)["G"]), 0, "none of them free to work the farm yet")
	check(Households.check(w).is_empty(), "jobs = people")
	w.table("plan")["plan:t1"]["status"] = "SIGNED"
	Households.release_idle_founders(w)
	check_eq(Households.in_post(w, fid), 0, "signed: all of them give up their posts")
	check_eq(Company.staff_count(w, cid) / S, 10 - k, "%d posts fewer" % k)
	check_eq(int(Households.family_adults(w, fid)["G"]), k, "and are the farm's family now")
	check(Households.check(w).is_empty(), "jobs = people")


func test_a_given_up_plan_still_owned_never_takes_up_the_post() -> void:
	# Terra's review: only SIGNED or OPEN counts as signed
	var w := _world()
	var land := AreaStore.found_landing(w)
	var r := _employed_pool(w, land)
	var fid := Households.make_founder(w, String(r[0]), "plan:t1")
	w.table("plan")["plan:t1"]["status"] = "GIVEN_UP"
	Households.take_up_posts(w)
	check_eq(Households.in_post(w, fid), 1, "a dead plan ends nobody's job")
	check_eq(Company.staff_count(w, String(r[1])) / S, 10, "all ten posts held")
