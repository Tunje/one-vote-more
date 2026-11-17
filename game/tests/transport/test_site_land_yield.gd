extends TestCase
## Terra, rebuild step 3 (planning/rebuild-step3-joins.md): a farm's yield from the planet, month by month with the
## season (Site.yield_pm, read by Bob's making); a plan buying the land under its site through land law's one deed
## (Site.buy_land calls LandLaw.sell).

const Site := preload("res://sim/transport/site.gd")
const Company := preload("res://sim/economy/company.gd")
const LandLaw := preload("res://sim/law/land_law.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const OWNER := {"kind": "FAMILY", "holders": {"person:1": 1000}}


func _world(seed_v: int = 1) -> WorldState:
	var w := GameSim.make(seed_v, "BALANCED", {}, true).world
	LawOps.init_world(w)
	LandLaw.ensure_rules(w)   # the land law's rules (selling land by default), as the law provider installs them
	return w


func _farm(w: WorldState) -> String:
	var cid := Company.create(w, "FARM", "FAMILY", OWNER, "test farm")
	var pid := Company.add_plant(w, cid, "FAMILY")
	check_eq(Site.place(w, pid, Site.choose_country(w, "FARM", 1, 1)[0]), "", "a family farm placed")
	return pid


func test_a_farm_grows_with_the_season_and_averages_its_row() -> void:
	for seed_v in [1, 3]:
		var w := _world(seed_v)
		var pid := _farm(w)
		var cell := Planet.hex_of_tile(w, ColonyLayout.as_tile(String(Site.of(w, pid)["tile"])))
		var sum := 0
		var lo := 100000
		var hi := 0
		var season_sum := 0
		for m in 12:
			var pm := Site.yield_pm(w, pid, m)
			check_eq(pm, PlanetSeasons.farm_pct(w, cell, m) * PlanetEcology.yield_pct(w, cell) * 10 / 100,
				"seed %d month %d: season × land" % [seed_v, m])
			sum += pm
			season_sum += PlanetSeasons.season_pct(w, cell, m)
			lo = mini(lo, pm)
			hi = maxi(hi, pm)
		check(absi(season_sum - 1200) <= 12, "seed %d: the season shares average 100%% over a year (%d)" % [seed_v, season_sum])
		check(sum <= 12 * 1000 + 12, "seed %d: a year makes at most its row (%d ‰-months), less any drought" % [seed_v, sum])
		check(hi > lo, "seed %d: the yield follows the season (%d..%d)" % [seed_v, lo, hi])
		check_eq(Site.yield_pm(w, pid, 3), Site.yield_pm(w, pid, 3), "pure in the month")


func test_other_types_and_unplaced_plants_make_their_row() -> void:
	var w := _world()
	var cid := Company.create(w, "MINE", "LARGE", {"kind": "STATE", "holders": {"government": 1000}}, "test mine")
	var mine := Company.add_plant(w, cid, "LARGE")
	check_eq(Site.yield_pm(w, mine, 5), 1000, "a mine has no season")
	var fc := Company.create(w, "FARM", "FAMILY", OWNER, "farm with no place")
	check_eq(Site.yield_pm(w, Company.add_plant(w, fc, "FAMILY"), 5), 1000, "a farm with no place yet: its row")


func test_harmed_land_yields_less_and_the_log_says_so() -> void:
	var w := _world()
	var pid := _farm(w)
	var cell := Planet.hex_of_tile(w, ColonyLayout.as_tile(String(Site.of(w, pid)["tile"])))
	var before := Site.yield_pm(w, pid, 6)
	w.table("planet")["eco"] = {str(cell): [900000, 900]}
	var after := Site.yield_pm(w, pid, 6)
	check(after < before, "harmed land grows less (%d -> %d)" % [before, after])
	check(Logbook.rows(w, {"kind": "PLANET", "who": pid, "what": "low yield"}).is_empty(), "reading the yield writes nothing")
	w.month = 6
	Site.note_low_yields(w)
	if after < Site.YIELD_LOG_BELOW:
		check_eq(Logbook.rows(w, {"kind": "PLANET", "who": pid, "what": "low yield"}).size(), 1, "a low month is one log row, once")
	check(Site.hold(w, "plan:9", "FARM", 1, Site.choose_country(w, "FARM", 1, 1)[0]) == "", "a plan holds a farm's tile")
	check_eq(Site.yield_pm(w, "plan:9", 6), 1000, "a plan's site grows nothing")


func _plan_with_money(w: WorldState, plan_id: String, credits: int) -> String:
	check_eq(Site.hold(w, plan_id, "FARM", 1, Site.choose_country(w, "FARM", 1, 1)[0]), "", "%s holds a farm's tile" % plan_id)
	var acct := "test_acct:" + plan_id
	w.ledger.open_account(acct)
	w.ledger.transfer(Ledger.EXTERNAL, acct, credits * CoreUtil.S, "test money", w.month)
	return acct


func test_a_plan_buys_its_land_from_the_colony() -> void:
	var w := _world()
	var acct := _plan_with_money(w, "plan:1", 5000)
	var s := Site.of(w, "plan:1")
	var want := Site.land_price(w, s, Site.bill_credits("FARM", "FAMILY")) * CoreUtil.S
	check(want > 0, "a family farm's land has a price (%d mcr)" % want)
	var t := Site.land_terms(w, "plan:1")
	check(bool(t["allowed"]) and int(t["price"]) == want, "land law's terms at the plan's own price")
	check_eq(int(t["due"]), want, "under a sale, the price is due at signing")
	var tr0 := w.ledger.balance(CoreUtil.TREASURY)
	var a0 := w.ledger.balance(acct)
	var r := Site.buy_land(w, "plan:1", acct)
	check(bool(r["ok"]), "bought (%s)" % r["why"])
	check_eq(int(r["price"]), want, "at the plan's price")
	check_eq(int(r["due"]), want, "and the price was what it paid")
	check_eq(w.ledger.balance(acct), a0 - want, "the plan paid it")
	check_eq(w.ledger.balance(CoreUtil.TREASURY), tr0 + want, "the colony received it: nothing appears or vanishes")
	check(not Logbook.rows(w, {"kind": "SITE", "who": "plan:1", "what": "land bought"}).is_empty(), "a log row")
	check_eq(int(LandLaw.plots_of(w, String(s["tile"])).get("plan:1", {}).get("sixths", 0)), 1, "the title holds the plan's plot of one sixth")
	check_eq(int(LandLaw.plots_of(w, String(s["tile"])).get("plan:1", {}).get("sixths", 0)), Site.square_sixths(w, "t:" + String(s["tile"]), "FARM"),
		"land law's plots and the map's square agree")


func test_a_plan_short_of_money_buys_nothing() -> void:
	var w := _world()
	var acct := _plan_with_money(w, "plan:2", 1)
	var tr0 := w.ledger.balance(CoreUtil.TREASURY)
	var r := Site.buy_land(w, "plan:2", acct)
	check(not bool(r["ok"]) and String(r["why"]) != "", "refused, with why (%s)" % r["why"])
	check_eq(w.ledger.balance(acct), 1 * CoreUtil.S, "nothing taken")
	check_eq(w.ledger.balance(CoreUtil.TREASURY), tr0, "nothing paid in")
	check(not Logbook.rows(w, {"kind": "SITE", "who": "plan:2", "what": "land not bought"}).is_empty(), "a log row")
	check(not bool(Site.buy_land(w, "plan:none", acct)["ok"]), "a plan with no site buys nothing")


func test_under_a_lease_the_first_rent_is_due() -> void:
	var w := _world()
	w.levers["LAW_LAND_DISPOSAL"] = "LEASE"
	var acct := _plan_with_money(w, "plan:3", 5000)
	var t := Site.land_terms(w, "plan:3")
	check_eq(String(t["mode"]), "LEASE", "the government leases its land")
	check(int(t["lease_rent"]) > 0 and int(t["due"]) == int(t["lease_rent"]), "the first month's rent is due, not the price")
	var a0 := w.ledger.balance(acct)
	var r := Site.buy_land(w, "plan:3", acct)
	check(bool(r["ok"]), "leased (%s)" % r["why"])
	check_eq(int(r["due"]), int(t["lease_rent"]), "the plan paid the first rent")
	check_eq(w.ledger.balance(acct), a0 - int(r["due"]), "and only that left its account")
