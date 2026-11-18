extends TestCase
## The government stops farm founding by its land (the user, 2026-11-18, rebuild-company 12.9 61c: "stopping land being
## allowed to be built on"; "Yes on zoning laws"). GovBuilder.farm_land zones the colony's unsold land INDUSTRIAL
## (Anni's LandLaw.zone_colony) when it wants no more farms (Wilma's reading: Grants.wanted FARM = 0), and lifts only its
## own zoning when it wants farms again. On zoned land no site is offered and no founder drawn. Zoning stops new plans
## only (Wilma's reading, 61c): a plan made while the land was open keeps its right to buy its held site and signs.
## In real new games.

const LandLaw := preload("res://sim/law/land_law.gd")
const Grants := preload("res://sim/economy/grants.gd")
const Building := preload("res://sim/economy/building.gd")
const Month := preload("res://sim/economy/month.gd")


func _founders(w: WorldState) -> int:
	return w.peek("founder").size()


func test_on_zoned_land_no_farm_is_planned_and_no_founder_drawn() -> void:
	var sim := GameSim.make(1)
	var w: WorldState = sim.world
	check(bool(LandLaw.zone_colony(w, "INDUSTRIAL")["ok"]), "the land is zoned before the colony's first month")
	sim.run(1)
	check_eq(w.peek("plan").size(), 0, "no farm plan is made")
	check_eq(_founders(w), 0, "and no founder is drawn")
	check_eq(LandLaw.colony_zone(w), "INDUSTRIAL", "the government does not lift a zoning it did not set")
	check(bool(LandLaw.lift_colony_zone(w)["ok"]), "lifted")
	sim.run(1)
	check(w.peek("plan").size() > 0, "lifted, founding goes on (%d plans)" % w.peek("plan").size())


func test_the_government_zones_when_it_wants_no_more_farms_and_lifts_its_own() -> void:
	var sim := GameSim.make(1)
	var w: WorldState = sim.world
	sim.run(2)
	var rows := Logbook.rows(w, {"kind": "GRANT", "what": "land zoned against farms"})
	check_eq(rows.size(), 1, "zoned once")
	if rows.size() != 1:
		return
	check_eq(int(rows[0]["m"]), 1, "in month 2, the first month it decides after month one's plans")
	check_eq(int(rows[0]["why"]["wanted"]), 0, "when it wants no more farms (Grants.wanted)")
	check_eq(int(Grants.wanted(w, "FARM")["wanted"]), 0, "it still wants none")
	check_eq(LandLaw.colony_zone(w), "INDUSTRIAL", "the colony's land is zoned INDUSTRIAL")
	var plans := w.peek("plan").size()
	sim.run(1)
	check_eq(w.peek("plan").size(), plans, "no farm plan made while the land is zoned")
	# it wants farms again (every plan and farm counted out): it lifts its own zoning
	for pid in w.table("plan"):
		w.table("plan")[pid]["status"] = "GIVEN_UP"
	for pid in Month.Company.plant_ids(w):
		w.table(Month.Company.PLANT_TABLE)[pid]["closed"] = true
	check(int(Grants.wanted(w, "FARM")["wanted"]) > 0, "it wants farms")
	GovBuilder.farm_land(w)
	check_eq(LandLaw.colony_zone(w), "", "it lifts its own zoning")
	check_eq(Logbook.rows(w, {"kind": "GRANT", "what": "farm land opened again"}).size(), 1, "and says so")
	# a zoning set by someone else is not the government's to lift
	LandLaw.zone_colony(w, "RESERVE")
	GovBuilder.farm_land(w)
	check_eq(LandLaw.colony_zone(w), "RESERVE", "a zone it did not set stays")


func test_a_plan_made_on_open_land_keeps_its_site_when_the_land_is_zoned() -> void:
	# Wilma, 2026-11-18 (61c): zoning stops new plans only; a plan made while the land was open keeps its right to buy
	# the site it holds, and signs (Otto: may_sign must pass it too, or it waits for the law forever)
	var sim := GameSim.make(1)
	var w: WorldState = sim.world
	# a month with the market cleared and no farm planned (the land zoned), so rule 7 reads real work and sees no farm
	LandLaw.zone_colony(w, "INDUSTRIAL")
	sim.run(1)
	LandLaw.lift_colony_zone(w)
	var area := String(AreaStore.areas(w)[0]["id"])
	var sites: Array = Month.Site.choose_country(w, "FARM", 1, 1)
	check(not sites.is_empty(), "a free farm site on open land")
	if sites.is_empty():
		return
	var founder := Month.Households.make_founder(w, String(Month.Households.pools(w)[0]), "", true)
	var made := Building.make_plan(w, founder, "FARM", "FAMILY", area, sites[0])
	Month.Households.own(w, founder, made)
	check(made != "" and String(w.peek("plan")[made]["status"]) == "MADE", "made on open land, not signed")
	if made == "":
		return
	# a founder who can pay what the plan needs (Building.founder_needs), as founding draws one
	var needs := Building.founder_needs(w, "FARM", "FAMILY", area)
	w.ledger.transfer(Ledger.EXTERNAL, made, maxi(0, needs - w.ledger.balance(made)), "TEST", w.month)
	w.month += 1   # the zoning comes in a later month than the plan
	check(bool(LandLaw.zone_colony(w, "INDUSTRIAL")["ok"]), "then the land is zoned")
	check(Month.Site.choose_country(w, "FARM", 1, 1).is_empty(), "no new farm site is offered")
	var total := w.ledger.total()
	Building.sign_round(w)
	check(String(w.peek("plan")[made]["status"]) != "GIVEN_UP", "not given up for the zoning")
	check(Logbook.rows(w, {"kind": "PLAN", "what": "waits: the law", "who": made}).is_empty(), "the law does not hold it back")
	check(Logbook.rows(w, {"kind": "PLAN", "what": "waits: the land", "who": made}).is_empty(), "its held site is sold to it")
	check_eq(String(w.peek("plan")[made]["status"]), "SIGNED", "it signs with a builder")
	check_eq(w.ledger.total(), total, "nothing appears or vanishes")
