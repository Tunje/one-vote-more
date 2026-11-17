extends TestCase
## Terra, rebuild step 2 (sim/transport/site.gd; rebuild-company.md 3, 5, 9.8, 12.1 points 3–6): where a plant stands,
## recorded once on the map; a plan holds its site and hands it to its plant; one full size per type in a square; the
## zone decides what may stand; the land price is 10% of the bill × the value of the place; every deed is in the log.

const Site := preload("res://sim/transport/site.gd")
const Company := preload("res://sim/economy/company.gd")
const LandLaw := preload("res://sim/law/land_law.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const OWNER := {"kind": "STATE", "holders": {"government": 1000}}


func _world(seed_v: int = 1) -> WorldState:
	return GameSim.make(seed_v, "BALANCED", {}, true).world


func _plant(w: WorldState, type: String, size: String) -> String:
	var cid := Company.create(w, type, size, OWNER, "test %s" % type.to_lower())
	return Company.add_plant(w, cid, size)


func _landing(w: WorldState) -> String:
	return String(ColonyLayout.settlements(w)[0]["id"])


func test_a_farm_stands_on_its_best_country_tile() -> void:
	var w := _world()
	var pid := _plant(w, "FARM", "FAMILY")
	var opts := Site.choose_country(w, "FARM", 1, 5)
	check(opts.size() == 5, "five places offered")
	var best: Dictionary = opts[0]
	var t := ColonyLayout.as_tile(String(best["tile"]))
	check(Terrain.at(w, t.x, t.y) in ["f", "n", "."], "a farm on farmland (%s)" % Terrain.at(w, t.x, t.y))
	check(Vector2(t).distance_to(Vector2(Terrain.landing(w))) <= 3.0, "next to the colony (farmland lies at the landing)")
	check(float(opts[0]["score"]) >= float(opts[4]["score"]), "best first")
	check_eq(var_to_str(Site.choose_country(w, "FARM", 1, 5)), var_to_str(opts), "choosing is pure")
	check_eq(Site.place(w, pid, best), "", "placed")
	var s := Site.of(w, pid)
	check_eq(String(s["where"]), "COUNTRY", "a country plant")
	check_eq(String(s["tile"]), String(best["tile"]), "on its tile")
	check_eq(ColonyLayout.facility_tiles(w)[pid], t, "the map knows where it stands")
	check_eq(String(ColonyLayout.plants(w)[pid]["type"]), "FARM", "and what it is")
	check(Company.plant(w, pid).get("tile", null) == null, "the company record keeps no place")
	check(not Logbook.rows(w, {"kind": "SITE", "who": pid, "what": "placed"}).is_empty(), "the log has it")
	check(Site.place(w, pid, best) != "", "a plant stands in one place")
	check(Site.place(w, _plant(w, "SHOP", "SMALL"), best) != "", "a shop does not stand in the country")


func test_one_full_size_per_type_in_a_square() -> void:
	var w := _world()
	var best: Dictionary = Site.choose_country(w, "FARM", 1, 1)[0]
	for i in 6:
		check_eq(Site.place(w, _plant(w, "FARM", "FAMILY"), best), "", "family farm %d on the tile" % (i + 1))
	check_eq(Site.square_sixths(w, "t:" + String(best["tile"]), "FARM"), 6, "six sixths: the square is full of farms")
	check(Site.place(w, _plant(w, "FARM", "FAMILY"), best) != "", "a seventh family farm does not fit")
	for o in Site.choose_country(w, "FARM", 1, 20):
		check(String(o["tile"]) != String(best["tile"]), "the full square is not offered")
	var mine_opts := Site.choose_country(w, "PROCESSING", 6, 50)
	var shares := false
	for o in mine_opts:
		shares = shares or String(o["tile"]) == String(best["tile"])
	check(shares, "another type may still stand in that square")


## The landing shelters: 8 plants of the housing office, a block of 50 homes each (Bob's LANDLORD row, Otto's count).
func _shelters(w: WorldState) -> Array:
	# month one's government side lays them (sim/economy/landing.gd), through choose_town and place
	var out: Array = []
	for cid in Company.ids(w):
		if String(Company.record(w, cid)["origin"]) == "HOUSING_OFFICE":
			out = Company.plant_ids_of(w, cid)
	check_eq(out.size(), 8, "eight shelter blocks laid in month one")
	return out


func test_the_landing_shelters_are_homes_on_the_grid() -> void:
	var w := _world()
	var town := _landing(w)
	var big := _plant(w, "LANDLORD", "LARGE")
	check(Site.place(w, big, Site.choose_town(w, town, "LANDLORD", 6, 1)[0], 400) != "", "a large landlord holds 50 homes, not 400")
	check(Site.place(w, _plant(w, "SHOP", "SMALL"), Site.choose_town(w, town, "SHOP", 2, 1)[0], 10) != "", "a shop has no homes")
	var ps := _shelters(w)
	var homes := 0
	for pid in ps:
		var s := Site.of(w, pid)
		check_eq(String(s["where"]), "TOWN", "a town plant")
		check_eq(TownGrid.homes_of(w, pid), 50, "50 homes, recorded once, in the cells")
		check_eq((s["cells"] as Array).size(), 7, "8 houses to a cell: 7 cells")
		homes += TownGrid.homes_of(w, pid)
	check_eq(homes, 400, "400 homes for 1,000 settlers")
	var squares := {}
	for pid in ps:
		squares[Site.square_of(Site.of(w, pid))] = true
	check_eq(squares.size(), 8, "one full-size landlord to a street block")
	check(TownGrid.has_grid(w, town), "the Landing got its grid with its first homes")
	check(not w.facts.query("TOWN_GRID_LAID", 0, 1 << 30).is_empty(), "news")
	check(not Logbook.rows(w, {"kind": "TOWN", "who": town, "what": "grid laid"}).is_empty(), "and a log row")
	var bh := 0
	for b in TownGrid.blocks(w, town):
		check_eq(AreaStore.area_of_block(w, b), town, "block %s is the Landing's" % b)
		bh += TownGrid.block_homes(w, b)
	check_eq(bh, 400, "every home is in a block of the Landing")
	check_eq(String(ColonyLayout.plants(w)[ps[0]]["area"]), town, "a shelter stands in the Landing")


func test_a_plan_holds_its_site_and_hands_it_to_its_plant() -> void:
	var w := _world()
	var town := _landing(w)
	var site: Dictionary = Site.choose_town(w, town, "SHOP", 2, 1)[0]
	check_eq(Site.hold(w, "plan:7", "SHOP", 2, site), "", "the plan holds the cell")
	check_eq(String(Site.what(w, "plan:7")["type"]), "SHOP", "a held site knows what is coming")
	check(bool(ColonyLayout.plants(w)["plan:7"]["plan"]), "the map shows it as being built")
	for o in Site.choose_town(w, town, "SHOP", 2, 20):
		check(String(o["cells"][0]) != String(site["cells"][0]), "a held cell is not offered again")
	var pid := _plant(w, "SHOP", "SMALL")
	check_eq(Site.open(w, "plan:7", pid), "", "opened")
	check(Site.of(w, "plan:7").is_empty(), "the plan holds nothing now")
	check_eq(Site.of(w, pid)["cells"], site["cells"], "the plant stands where its plan was")
	check(not Logbook.rows(w, {"kind": "SITE", "who": pid, "ref": "plan:7"}).is_empty(), "the log joins plan and plant")
	var blk := TownGrid.block_of(site["cells"][0])
	var alone := TownGrid.block_homes(w, blk) == 0 and TownGrid.blocks(w, town).size() == 1
	Site.release(w, pid, "test")
	check(Site.of(w, pid).is_empty(), "released")
	if alone:
		check_eq(AreaStore.area_of_block(w, blk), "", "a block with nothing left in it is free again")
	# a held country site, given up
	var mines := Site.choose_country(w, "MINE", 6, 1)
	check(not mines.is_empty(), "a mine finds its ore")
	var fsite: Dictionary = mines[0]
	var mt := ColonyLayout.as_tile(String(fsite["tile"]))
	check(Terrain.at(w, mt.x, mt.y) in ["o", "x"], "on the ore itself (%s)" % Terrain.at(w, mt.x, mt.y))
	check_eq(Site.hold(w, "plan:8", "MINE", 6, fsite), "", "a mine's plan holds its tile")
	Site.release(w, "plan:8", "given up")
	check(Site.of(w, "plan:8").is_empty() and Site.what(w, "plan:8").is_empty(), "given up: nothing left")
	# a month frees places nobody owns
	Site.hold(w, "plan:9", "MINE", 6, fsite)
	w.table("site")["hold"].erase("plan:9")
	Site.step_month(w)
	check(Site.of(w, "plan:9").is_empty(), "a place without a plant or a plan is freed")


func _zone(w: WorldState, key: String, zone: String) -> void:
	LawOps.init_world(w)
	LandLaw.ensure_rules(w)
	var r: Dictionary = LandLaw.zone(w, [key], zone)
	check(bool(r["ok"]), "zoned %s %s (%s)" % [key, zone, r.get("reason", "")])


func test_the_zone_decides_what_may_stand() -> void:
	var w := _world()
	var best: Dictionary = Site.choose_country(w, "FARM", 1, 1)[0]
	_zone(w, String(best["tile"]), "RESERVE")
	for o in Site.choose_country(w, "FARM", 1, 30):
		check(String(o["tile"]) != String(best["tile"]), "a reserve is not offered")
	check(Site.place(w, _plant(w, "FARM", "FAMILY"), best) != "", "nor can a farm be put there")
	_zone(w, String(best["tile"]), "FARM")
	check_eq(Site.place(w, _plant(w, "FARM", "FAMILY"), best), "", "farmland takes a farm")
	check(Site.place(w, _plant(w, "PROCESSING", "LARGE"), best) != "", "but no works")
	# a town cell has its own zone (Anni: "c:fx,fy")
	var town := _landing(w)
	var cell: String = Site.choose_town(w, town, "SHOP", 2, 1)[0]["cells"][0]
	_zone(w, Site.cell_key(cell), "RESIDENTIAL")
	check(Site.zone_allows(w, Site.cell_key(cell), "LANDLORD") and Site.zone_allows(w, Site.cell_key(cell), "SHOP"),
		"a residential cell takes homes and shops")
	_zone(w, Site.cell_key(cell), "FARM")
	for o in Site.choose_town(w, town, "SHOP", 2, 40):
		check(String(o["cells"][0]) != cell, "a cell zoned for farming is not offered to a shop")


func test_homes_on_a_cell() -> void:
	var w := _world()
	var town := _landing(w)
	var pid := _plant(w, "LANDLORD", "LARGE")
	check_eq(Site.place(w, pid, Site.choose_town(w, town, "LANDLORD", 6, 1)[0], 50), "", "50 homes")
	var n := 0
	for ck in TownGrid.cells_of(w, pid):
		n += TownGrid.homes_on_cell(w, ck)
		check(TownGrid.homes_on_cell(w, ColonyLayout.as_tile(ck)) == TownGrid.homes_on_cell(w, ck), "a cell as Vector2i or text")
	check_eq(n, 50, "the cells' homes add up to the plant's")
	check_eq(TownGrid.homes_on_cell(w, "0,0"), 0, "an empty cell has none")


func test_the_land_price() -> void:
	var w := _world()
	var site: Dictionary = Site.choose_country(w, "FARM", 1, 1)[0]
	var bill := Site.bill_credits("FARM", "FAMILY")
	check(bill > 0, "a family farm has a bill (%d)" % bill)
	var v := Site.value_pm(w, site)
	check_eq(Site.land_price(w, site, bill), roundi(float(bill) * 0.1 * float(v) / 1000.0), "10% of the bill × the value of the place")
	var t := ColonyLayout.as_tile(String(site["tile"]))
	check(LandLaw.land_value(w, t) > 0, "land law prices land with the map's price")
	check_eq(LandLaw.land_value(w, t), Site.land_value_milli(w, t), "through its hook")
	var cell := TownGrid.centre_cell(Terrain.landing(w))
	var cell_v := Site.land_value_milli(w, "c:%d,%d" % [cell.x, cell.y])
	check(cell_v > 0, "a town cell has a land value (%d)" % cell_v)


func test_a_neighbourhood_split_off_stays_in_its_town() -> void:
	var w := _world()
	var town := _landing(w)
	var pid: String = _shelters(w)[0]
	var bs := TownGrid.blocks(w, town)
	check(bs.size() >= 2, "the shelters span blocks (%d)" % bs.size())
	var hood := AreaStore.split_blocks(w, town, [bs[bs.size() - 1]], "TEST")
	check_eq(AreaStore.town_of(w, hood), town, "the neighbourhood belongs to the town")
	check_eq(TownGrid.town_of(w, pid), town, "one town, one grid")
	# a shop in the neighbourhood's block: the town may build there, and the plant is the neighbourhood's
	var shop := _plant(w, "SHOP", "SMALL")
	var in_hood := {}
	for o in Site.choose_town(w, town, "SHOP", 2, 200):
		if AreaStore.area_of_block(w, String(o["block"])) == hood:
			in_hood = o
			break
	check(not in_hood.is_empty(), "the town still offers cells in its new neighbourhood")
	check_eq(Site.place(w, shop, in_hood), "", "a shop laid there")
	check_eq(String(ColonyLayout.plants(w)[shop]["area"]), hood, "the shop stands in the neighbourhood")
	check_eq(String(ColonyLayout.plants(w)[pid]["area"]), AreaStore.area_of_block(w, TownGrid.block_of(TownGrid.cells_of(w, pid)[0])),
		"every plant is the area of its first block")
