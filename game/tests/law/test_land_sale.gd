extends TestCase
## Rebuild step 3 (Anni): a plan buys its land in one deed (LandLaw.sell), town cells pass whole, a country tile keeps
## the plots sold off it in sixths, a plan's land and licences pass to its company at the opening, and the law's plainest
## demands of a new company (LawCompany.may_sign, register, may_open). Money exact to the milli-credit; nothing appears
## or vanishes.

const Land := preload("res://sim/law/land_law.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const LawCompany := preload("res://sim/law/law_company.gd")
const Company := preload("res://sim/economy/company.gd")

const S := 1000
const PLAN := "plan:1"
const PLAN_ACCT := "plan:plan:1"


func _world() -> WorldState:
	var w := WorldState.new(23)
	Terrain.generate(w)
	LawOps.init_world(w)
	Land.ensure_rules(w)
	Land.land_value_fn = Callable()
	for d in preload("res://sim/law/law_data.gd").LEVERS:
		if String(d["id"]) in ["LAW_LAND_DISPOSAL", "LAW_LAND_PRICE_FLOOR_PCT", "LAW_LICENCE_REGIME_HAZARD", "LAW_LICENCE_REGIME_EXTRACTION"]:
			w.levers[d["id"]] = d["default"]
	w.ledger.open_account(CoreUtil.TREASURY)
	return w


func _tile(w: WorldState, dx: int = 3) -> Vector2i:
	var l := Terrain.landing(w)
	return Terrain.nearest_free(w, clampi(l.x + dx, 0, Terrain.W - 1), l.y, Terrain.BUILDABLE_HOUSING, 8)


func _payer(w: WorldState, acct: String, credits: int) -> void:
	if not w.ledger.has_account(acct):
		w.ledger.open_account(acct)
	w.ledger.transfer(Ledger.EXTERNAL, acct, credits * S, "TEST", w.month)


func _cells(t: Vector2i, n: int) -> Array:
	var c := TownGrid.centre_cell(t)
	var out: Array = []
	for i in n:
		out.append(Land.key_of_cell(c + Vector2i(i, 0)))
	return out


func test_the_colony_sells_by_default() -> void:
	var w := _world()
	check_eq(String(w.levers["LAW_LAND_DISPOSAL"]), "SELL", "a plan buys its land (12.1, 3)")
	var t := Land.terms(w, _cells(_tile(w), 2), PLAN, "SHOP", 1, 500 * S)
	check(t["allowed"] and t["mode"] == "SELL" and int(t["price"]) == 500 * S and int(t["lease_rent"]) == 0, "terms: a sale at the price (%s)" % [t])
	check_eq(int(t["floor"]), 450 * S, "the floor is on that same figure (90%)")


func test_a_town_sale_is_one_deed() -> void:
	var w := _world()
	var keys := _cells(_tile(w), 3)
	_payer(w, PLAN_ACCT, 1000)
	var r := Land.sell(w, keys, PLAN, PLAN_ACCT, "SHOP", 1, 600 * S)
	check(r["ok"], "sold (%s)" % [r])
	check_eq(w.ledger.balance(PLAN_ACCT), 400 * S, "the payer paid the price, no more")
	check_eq(w.ledger.balance(CoreUtil.TREASURY), 600 * S, "the treasury got it all")
	var j: Dictionary = w.ledger.journal[w.ledger.journal.size() - 1]
	check_eq(String(j["memo"]), "LAND_SALE", "memo LAND_SALE (capital in the budget figures)")
	for k in keys:
		check_eq(String(Land.title(w, k)["owner"]), PLAN, "%s is the plan's" % k)
	check(Land.holds(w, PLAN, keys), "the plan holds its site")
	check_eq(Logbook.rows(w, {"what": "land bought", "who": PLAN}).size(), 3, "one LAND row per cell")
	var again := Land.sell(w, keys, "plan:2", PLAN_ACCT, "SHOP", 1, 600 * S)
	check(not again["ok"] and String(again["reason"]).contains("not the colony's"), "sold land is not sold twice (%s)" % [again])


func test_a_payer_short_of_the_price_buys_nothing() -> void:
	var w := _world()
	var keys := _cells(_tile(w), 2)
	_payer(w, PLAN_ACCT, 100)
	var r := Land.sell(w, keys, PLAN, PLAN_ACCT, "SHOP", 1, 600 * S)
	check(not r["ok"] and String(r["reason"]).contains("cannot pay"), "refused (%s)" % [r])
	check_eq(w.ledger.balance(PLAN_ACCT), 100 * S, "nothing taken")
	check_eq(w.ledger.balance(CoreUtil.TREASURY), 0, "nothing paid in")
	check_eq(String(Land.title(w, keys[0])["owner"]), "gov", "the land stays the colony's")
	check_eq(Logbook.rows(w, {"what": "land sale refused"}).size(), 1, "the refusal is logged")


func test_the_zone_decides() -> void:
	var w := _world()
	var t := _tile(w)
	check(Land.zone(w, [t], "RESERVE")["ok"], "the tile is a reserve")
	var r := Land.terms(w, [t], PLAN, "FARM", 1, 100 * S)
	check(not r["allowed"] and String(r["reason"]).contains("reserve"), "no farm in a reserve (%s)" % [r])
	check_eq(Land.use_of("FARM"), "FARM", "a farm's use")
	check_eq(Land.use_of("LANDLORD"), "HOUSING", "a landlord's use")
	check_eq(Land.use_of("SHOP"), "SERVICE", "a town type is a service")
	check_eq(Land.use_of("MINE"), "MINE", "a mine's use")


func test_a_country_tile_keeps_its_plots_in_sixths() -> void:
	var w := _world()
	var t := _tile(w)
	var key := "%d,%d" % [t.x, t.y]
	for i in 6:
		var plan := "plan:f%d" % i
		_payer(w, "acct:" + plan, 100)
		check(Land.sell(w, [key], plan, "acct:" + plan, "FARM", 1, 50 * S)["ok"], "family farm %d gets its sixth" % i)
	var full := Land.terms(w, [key], "plan:f6", "FARM", 1, 50 * S)
	check(not full["allowed"] and String(full["reason"]).contains("no room"), "a seventh family farm has no room (%s)" % [full])
	_payer(w, "acct:mine", 1000)
	check(Land.terms(w, [key], "plan:mine", "MINE", 6, 300 * S)["allowed"], "another type has its own full size on the tile")
	var plots := Land.plots_of(w, key)
	check_eq(plots.size(), 6, "six plots")
	check_eq(int(plots["plan:f0"]["sixths"]), 1, "each a sixth")
	check_eq(Land.right_of(w, "plan:f0", key), "OWNER", "a plot's holder may build")
	check_eq(String(Land.title(w, key)["owner"]), "gov", "the rest of the tile stays the colony's")
	check_eq(w.ledger.balance(CoreUtil.TREASURY), 300 * S, "six sixths paid, exactly")


func test_a_lease_pays_rent_each_month() -> void:
	var w := _world()
	w.levers["LAW_LAND_DISPOSAL"] = "LEASE"
	var keys := _cells(_tile(w), 1)
	_payer(w, PLAN_ACCT, 20)
	var r := Land.sell(w, keys, PLAN, PLAN_ACCT, "SHOP", 1, 1000 * S)
	var rent := int(round(1000.0 * S * Land.LEASE_YIELD_PER_MONTH))
	check(r["ok"] and r["mode"] == "LEASE" and int(r["lease_rent"]) == rent, "leased (%s)" % [r])
	check_eq(w.ledger.balance(CoreUtil.TREASURY), rent, "the first month's rent at once")
	check_eq(Land.right_of(w, PLAN, keys[0]), "LESSEE", "the plan leases the cell")
	Land.tick(w)
	check_eq(w.ledger.balance(CoreUtil.TREASURY), rent, "not twice in the month it began")
	w.month += 1
	Land.tick(w)
	check_eq(w.ledger.balance(CoreUtil.TREASURY), 2 * rent, "a month's rent the next month")
	w.ledger.transfer(PLAN_ACCT, Ledger.EXTERNAL, w.ledger.balance(PLAN_ACCT), "TEST", w.month)
	w.month += 1
	Land.tick(w)
	check_eq(int(w.peek("land_title")[keys[0]]["rent_owed"]), rent, "what it cannot pay it owes")
	var debt := 0
	for l in w.peek("liability").values():
		if String(l["debtor"]) == PLAN and String(l["kind"]) == "LAND_RENT":
			debt += int(l["amount"])
	check_eq(debt, rent, "as a debt to the government, the one record (12.8, 50b)")
	check_eq(Logbook.rows(w, {"what": "rent owed", "who": PLAN}).size(), 1, "and that is logged")


func test_the_plans_land_and_licences_pass_to_its_company() -> void:
	var w := _world()
	var t := _tile(w)
	var key := "%d,%d" % [t.x, t.y]
	var cells := _cells(_tile(w, 6), 2)
	_payer(w, PLAN_ACCT, 1000)
	check(Land.sell(w, [key], PLAN, PLAN_ACCT, "MINE", 6, 200 * S)["ok"], "a plot")
	check(Land.sell(w, cells, PLAN, PLAN_ACCT, "SHOP", 1, 100 * S)["ok"], "and cells")
	var lid := LawOps.grant_licence(w, PLAN, LawCompany.LICENCE_KIND, "EXTRACTION", 120)
	var cid := Company.create(w, "MINE", "LARGE", {"kind": "PRIVATE", "holders": {"person:1": 1000}}, "Redrock")
	check_eq(Land.pass_holder(w, PLAN, cid, "OPENED"), 3, "three keys passed")
	check(Land.holds(w, cid, [key]) and Land.holds(w, cid, cells), "the company holds them")
	check(not Land.holds(w, PLAN, cells), "the plan no longer does")
	check_eq(String(Land.plots_of(w, key)[cid]["acct"]), CoreUtil.acct(cid), "the plot's account is the company's")
	LawCompany.register(w, cid, PLAN)
	check_eq(String(w.table("licence")[lid]["holder_id"]), cid, "the plan's licence is the company's")
	check_eq(String(w.peek("company_register")[cid]["plan"]), PLAN, "the law's record of the company")
	check(LawCompany.records_of(w, cid)["titles"].size() >= 3, "its titles are among its law records")


func test_what_the_law_requires_of_a_new_company() -> void:
	var w := _world()
	var t := _tile(w)
	var site := {"where": "COUNTRY", "tile": "%d,%d" % [t.x, t.y], "cells": []}
	var farm := LawCompany.may_sign(w, PLAN, "FARM", site)
	check(farm["ok"] and (farm["needs"] as Array).is_empty(), "a farm needs only its land (%s)" % [farm])
	var mine := LawCompany.may_sign(w, "plan:2", "MINE", site)
	check(mine["ok"] and "EXTRACTION" in mine["needs"] and "HAZARD" in mine["needs"], "a mine needs its licences (%s)" % [mine])
	var apps := func(holder: String) -> int:
		return w.peek("permit_application").values().filter(func(a): return String(a["holder_id"]) == holder).size()
	check_eq(apps.call("plan:2"), 2, "both applied for")
	LawCompany.may_sign(w, "plan:2", "MINE", site)
	check_eq(apps.call("plan:2"), 2, "not twice")
	w.levers["LAW_LICENCE_REGIME_HAZARD"] = "NONE"
	w.levers["LAW_LICENCE_REGIME_EXTRACTION"] = "NONE"
	check((LawCompany.licences_required(w, "MINE") as Array).is_empty(), "with no regime, nothing is required")
	w.levers["LAW_LICENCE_REGIME_HAZARD"] = "REQUIRED"
	w.levers["LAW_LICENCE_REGIME_EXTRACTION"] = "REQUIRED"
	check(Land.zone(w, [t], "RESIDENTIAL")["ok"], "rezoned")
	check(not LawCompany.may_sign(w, "plan:3", "FARM", site)["ok"], "no farm where the zone forbids it")


func test_a_plant_without_its_licence_is_closed_until_granted() -> void:
	var w := _world()
	var cid := Company.create(w, "MINE", "LARGE", {"kind": "PRIVATE", "holders": {"person:1": 1000}}, "Redrock")
	var pid := Company.add_plant(w, cid, "LARGE")
	var r := LawCompany.may_open(w, cid, pid)
	check(not r["ok"] and (r["reasons"] as Array).size() == 2, "no licences: may not run (%s)" % [r])
	Company.close_plant(w, pid, "LAW")
	LawCompany.reopen_licensed(w)
	check(bool(Company.plant(w, pid)["closed"]), "still closed without its licences")
	LawOps.grant_licence(w, cid, LawCompany.LICENCE_KIND, "HAZARD", 60)
	LawOps.grant_licence(w, cid, LawCompany.LICENCE_KIND, "EXTRACTION", 120)
	LawCompany.reopen_licensed(w)
	check(not bool(Company.plant(w, pid)["closed"]), "reopened once licensed")
	check(not w.peek("law_closed").has(pid), "off the law's list")
	check_eq(Logbook.rows(w, {"what": "may run", "who": cid}).size(), 1, "logged")
	var farm := Company.create(w, "FARM", "FAMILY", {"kind": "FAMILY", "holders": {"person:2": 1000}}, "Green")
	check(LawCompany.may_open(w, farm, Company.add_plant(w, farm, "FAMILY"))["ok"], "a farm opens with no licence")


func test_public_owe_and_programme_end() -> void:
	var w := _world()
	w.lever_defs["ECON_FAMILY_FARM_GRANT"] = {"id": "ECON_FAMILY_FARM_GRANT", "owner": "econ"}
	w.levers["ECON_FAMILY_FARM_GRANT"] = 50
	var eid := LawOps.end_programme(w, "ECON_FAMILY_FARM_GRANT", "its time ran out")
	check_eq(int(w.levers["ECON_FAMILY_FARM_GRANT"]), 0, "the lever is 0 at once")
	check_eq(String(w.peek("enactment")[eid]["status"]), "EFFECTIVE", "by an enactment in force")
	check_eq(int(LawOps.state(w)["legal_values"]["ECON_FAMILY_FARM_GRANT"]), 0, "and its lawful value is 0")
	check_eq(Logbook.rows(w, {"what": "programme ended"}).size(), 1, "logged")
	var J := preload("res://sim/law/justice_ops.gd")
	J.init_courts(w)
	J.owe(w, "founder:1", "gov", CoreUtil.TREASURY, 5000 * S, "GRANT")
	var owed := 0
	for l in w.peek("liability").values():
		if String(l["debtor"]) == "founder:1":
			owed += int(l["amount"])
	check_eq(owed, 5000 * S, "a founder's debt is recorded in full")
	w.month += 30
	J._petitions(w)
	check_eq(Logbook.rows(w, {"what": "petition"}).size(), 0, "a person's debt is not a company's: no winding-up petition")


func test_a_new_game_has_the_land_rules_from_the_start() -> void:
	var w := GameSim.make(3).world
	var t := Land.terms(w, ["c:1,1"], PLAN, "SHOP", 1, 100 * S)
	check(String(t["reason"]) != "land policy does not allow this", "no month needs to pass before land can be sold")
	check(LawOps.validate(w, LawOps.GOVERNMENT, "SELL_LAND", {"price_ok": true})["result"] == "AUTHORIZED", "the SELL_LAND rule is in force at landing")


func test_land_passes_to_a_founder_with_the_founders_account() -> void:
	var w := _world()
	w.levers["LAW_LAND_DISPOSAL"] = "LEASE"
	var keys := _cells(_tile(w), 3)
	_payer(w, PLAN_ACCT, 100)
	check(Land.sell(w, keys, PLAN, PLAN_ACCT, "SHOP", 1, 1001 * S)["ok"], "leased")
	check_eq(String(Land.title(w, keys[0])["lessee_kind"]), "PLAN", "a plan holds it, not a company")
	check_eq(Land.pass_holder(w, PLAN, "founder:7", "GIVEN_UP"), 3, "a given-up plan's land to its founder (60b)")
	check_eq(String(Land.title(w, keys[0])["lessee_acct"]), "founder:7", "rent from the founder's own account")
	check_eq(String(Land.title(w, keys[0])["lessee_kind"]), "PERSON", "a person holds it")
	check_eq(Land.acct_of("company:3"), CoreUtil.acct("company:3"), "a company's account")


func test_the_titles_add_up_to_what_was_paid() -> void:
	var w := _world()
	var keys := _cells(_tile(w), 3)
	_payer(w, PLAN_ACCT, 2000)
	check(Land.sell(w, keys, PLAN, PLAN_ACCT, "SHOP", 1, 1000 * S + 2)["ok"], "sold at a price three does not divide")
	var total := 0
	for k in keys:
		total += int(w.peek("land_title")[k]["price_paid"])
	check_eq(total, 1000 * S + 2, "the titles' prices add up to the price taken")
