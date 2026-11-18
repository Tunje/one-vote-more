extends TestCase
## 61c (the user, 2026-11-18: "Yes on zoning laws"): the government can stop founding by zoning the colony's own unsold
## country land in one act (Anni's: one record, INDUSTRIAL refuses farms). Anni's; for review.

const Land := preload("res://sim/law/land_law.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const Site := preload("res://sim/transport/site.gd")

const S := 1000


func _world() -> WorldState:
	var w := WorldState.new(23)
	Terrain.generate(w)
	LawOps.init_world(w)
	Land.ensure_rules(w)
	Land.land_value_fn = Callable()
	for d in preload("res://sim/law/law_data.gd").LEVERS:
		if String(d["id"]) in ["LAW_LAND_DISPOSAL", "LAW_LAND_PRICE_FLOOR_PCT"]:
			w.levers[d["id"]] = d["default"]
	w.ledger.open_account(CoreUtil.TREASURY)
	return w


func _key(w: WorldState, dx: int) -> String:
	var l := Terrain.landing(w)
	var t := Terrain.nearest_free(w, clampi(l.x + dx, 0, Terrain.W - 1), l.y, Terrain.BUILDABLE_HOUSING, 8)
	return "%d,%d" % [t.x, t.y]


func _buy(w: WorldState, key: String, plan: String, type: String) -> Dictionary:
	if not w.ledger.has_account("acct:" + plan):
		w.ledger.open_account("acct:" + plan)
	w.ledger.transfer(Ledger.EXTERNAL, "acct:" + plan, 100 * S, "TEST", w.month)
	return Land.sell(w, [key], plan, "acct:" + plan, type, 1, 50 * S)


func test_one_act_zones_the_colonys_own_land_and_lifting_clears_it() -> void:
	var w := _world()
	var free := _key(w, 3)
	var part := _key(w, 6)
	check(_buy(w, part, "plan:f0", "FARM")["ok"], "a family farm holds a sixth of a tile before the zoning")
	var titles := w.peek("land_title").size()
	check_eq(Land.colony_zone(w), "", "no colony zone at landing")
	check(Land.zone_colony(w, "INDUSTRIAL")["ok"], "the government zones the colony's land")
	check_eq(Land.colony_zone(w), "INDUSTRIAL", "one record")
	check_eq(w.peek("land_title").size(), titles, "not a title row per tile")
	check_eq(Logbook.rows(w, {"kind": "LAND", "what": "colony land zoned"}).size(), 1, "one row")
	for key in [free, part]:
		var r := Land.terms(w, [key], "plan:new", "FARM", 1, 50 * S)
		check(not r["allowed"] and String(r["reason"]).contains("industrial"), "no new farm on %s (%s)" % [key, r])
		check(not Site.zone_allows(w, key, "FARM"), "and the site choice does not offer it")
	check(Land.terms(w, [free], "plan:mine", "MINE", 6, 300 * S)["allowed"], "a mine may still buy: only farms are stopped")
	check_eq(Land.right_of(w, "plan:f0", part), "OWNER", "the farm already there keeps its plot")
	check(Land.lift_colony_zone(w)["ok"], "lifted")
	check_eq(Land.colony_zone(w), "", "the record is gone")
	check(Land.terms(w, [free], "plan:new", "FARM", 1, 50 * S)["allowed"], "farms may buy again")
	check_eq(Logbook.rows(w, {"kind": "LAND", "what": "colony zone lifted"}).size(), 1, "one row")
	check(not Land.lift_colony_zone(w)["ok"], "nothing to lift")


func test_a_tiles_own_zone_and_town_cells_are_not_in_it() -> void:
	var w := _world()
	var a := _key(w, 3)
	check(Land.zone(w, [a], "FARM")["ok"], "the government zones one tile for farms")
	check(Land.zone_colony(w, "INDUSTRIAL")["ok"], "then the colony's land against them")
	check_eq(Land.zone_of(w, a), "FARM", "the tile's own zone holds")
	var cell := Land.key_of_cell(TownGrid.centre_cell(Terrain.landing(w)))
	check_eq(Land.zone_of(w, cell), "UNZONED", "a town cell is not in the colony zone")
	check(not Land.zone_colony(w, "UNZONED")["ok"] and not Land.zone_colony(w, "NOPE")["ok"], "only a real zone")


func test_a_caretaker_may_not_zone_or_lift() -> void:
	var w := _world()
	check(Land.zone_colony(w, "INDUSTRIAL")["ok"], "zoned")
	w.table("pol")["state"] = {"caretaker": true}
	check(not Land.lift_colony_zone(w)["ok"], "a caretaker may not lift")
	check_eq(Land.colony_zone(w), "INDUSTRIAL", "it stands")
	w.table("pol")["state"] = {"caretaker": false}
	check(Land.lift_colony_zone(w)["ok"], "lifted")
	w.table("pol")["state"] = {"caretaker": true}
	check(not Land.zone_colony(w, "INDUSTRIAL")["ok"], "nor zone")


func test_a_plan_made_while_the_land_was_open_keeps_its_site() -> void:
	# Wilma, 61c: "Zoning stops new plans only: a plan made while the land was open keeps its right to buy the site it holds"
	var w := _world()
	var key := _key(w, 3)
	var own := _key(w, 6)
	w.month = 5
	w.table("plan")["plan:old"] = {"id": "plan:old", "made": 4}
	w.table("plan")["plan:new"] = {"id": "plan:new", "made": 5}
	check(Land.zone_colony(w, "INDUSTRIAL")["ok"], "zoned in month 5")
	check(Land.terms(w, [key], "plan:old", "FARM", 1, 50 * S)["allowed"], "a plan made in month 4 may still buy")
	check(not Land.terms(w, [key], "plan:new", "FARM", 1, 50 * S)["allowed"], "a plan made after the zoning may not")
	check(not Land.terms(w, [key], "someone", "FARM", 1, 50 * S)["allowed"], "nor a buyer that is no plan")
	check(not Site.zone_allows(w, key, "FARM"), "and no new site is offered on it")
	check(_buy(w, key, "plan:old", "FARM")["ok"], "the old plan buys its sixth")
	check(Land.zone(w, [own], "RESERVE")["ok"], "a tile zoned on its own")
	check(not Land.terms(w, [own], "plan:old", "FARM", 1, 50 * S)["allowed"], "binds the old plan too")
	check(Land.lift_colony_zone(w)["ok"], "lifted")
	w.month = 9
	check(Land.zone_colony(w, "INDUSTRIAL")["ok"], "zoned again in month 9")
	w.table("plan")["plan:mid"] = {"id": "plan:mid", "made": 7}
	check(Land.terms(w, [_key(w, 9)], "plan:mid", "FARM", 1, 50 * S)["allowed"], "a plan made while it was lifted keeps its site")
