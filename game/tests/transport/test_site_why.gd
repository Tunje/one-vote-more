extends TestCase
## Terra, 2026-11-18. When no site is found, why (Site.why_no_site): the user, 61c, "stopping land being allowed to be
## built on" stops founding; when the government's zoning is the cause, the founding row says "the land is zoned
## against farms", not "no free site" (Ella's request).

const Site := preload("res://sim/transport/site.gd")
const LandLaw := preload("res://sim/law/land_law.gd")
const LawOps := preload("res://sim/law/law_ops.gd")


func _world() -> WorldState:
	var w := GameSim.make(1, "BALANCED", {}, true).world
	LawOps.init_world(w)
	LandLaw.ensure_rules(w)
	return w


## Every tile a farm could stand on: its terrain, not a settlement's or a town's.
func _farm_tiles(w: WorldState) -> Array:
	var out: Array = []
	var codes: Array = Site.COUNTRY_TERRAIN.get("FARM", ColonyLayout.BUILD_TERRAIN)
	for y in Terrain.H:
		for x in Terrain.W:
			if Terrain.at(w, x, y) in codes:
				out.append(Terrain.key(x, y))
	return out


func test_land_zoned_against_farms_says_so() -> void:
	var w := _world()
	var area := String(AreaStore.found_landing(w))
	check(not Site.choose_country(w, "FARM", 1, 1).is_empty(), "before: a farm finds a site")
	var r: Dictionary = LandLaw.zone(w, _farm_tiles(w), "RESIDENTIAL")
	check(bool(r["ok"]), "the government zones the country against farms (%s)" % r["reason"])
	check(Site.choose_country(w, "FARM", 1, 1).is_empty(), "after: no farm site")
	var why := Site.why_no_site(w, area, "FARM", 1)
	check_eq(String(why["cause"]), "ZONED", "the cause is the zoning")
	check_eq(String(why["why"]), "the land is zoned against farms", "and the words say so")
	check(int(why["counts"]["zoned"]) > 0 and int(why["counts"]["zoned"]) <= int(why["counts"]["candidates"]),
		"counted: %s" % str(why["counts"]))


func test_without_zoning_the_cause_is_not_zoning() -> void:
	var w := _world()
	var area := String(AreaStore.found_landing(w))
	var why := Site.why_no_site(w, area, "FARM", 1)
	check_eq(int(why["counts"]["zoned"]), 0, "nothing zoned against farms")
	check(String(why["cause"]) != "ZONED", "so the cause is never zoning (%s)" % why["cause"])
	var rows0 := Logbook.rows(w).size()
	Site.why_no_site(w, area, "FARM", 1)
	check_eq(Logbook.rows(w).size(), rows0, "pure: reading it writes nothing")


func test_the_founding_row_says_the_land_is_zoned_against_farms() -> void:
	var sim := GameSim.make(1)
	var w := sim.world
	var area := String(AreaStore.found_landing(w))
	load("res://sim/economy/landing.gd").land(w, area)
	check(bool(LandLaw.zone(w, _farm_tiles(w), "RESIDENTIAL")["ok"]), "the country zoned against farms")
	sim.step()   # the month: orders give rule 7 its work, and founding finds no site
	check(w.peek("plan").is_empty(), "no farm plan is made")
	var rows := Logbook.rows(w, {"kind": "PLAN", "what": "no plan: the land is zoned against farms"})
	check(not rows.is_empty(), "the founding row says why")
	if not rows.is_empty():
		check_eq(String(rows[0]["why"]["cause"]), "ZONED", "with the cause")
