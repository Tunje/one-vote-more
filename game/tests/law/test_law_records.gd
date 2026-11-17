extends TestCase
## Rebuild step 2 (Anni): the law's records keyed by company id, read through LawCompany; land titles per tile and per
## town cell; a Logbook row for every decision and deed of the law.

const LawCompany := preload("res://sim/law/law_company.gd")
const Land := preload("res://sim/law/land_law.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const J := preload("res://sim/law/justice_ops.gd")
const F := preload("res://tests/support/staff_fixture.gd")

const S := 1000


func _world() -> WorldState:
	var w := WorldState.new(23)
	Terrain.generate(w)
	LawOps.init_world(w)
	Land.ensure_rules(w)
	Land.land_value_fn = Callable()
	Land.on_land_taken_fn = Callable()
	for lid in ["LAW_LAND_DISPOSAL", "LAW_LAND_PRICE_FLOOR_PCT", "LAW_EVICTION_NOTICE_MONTHS"]:
		for d in preload("res://sim/law/law_data.gd").LEVERS:
			if d["id"] == lid:
				w.levers[lid] = d["default"]
	return w


func _free(w: WorldState, dx: int = 3) -> Vector2i:
	var l := Terrain.landing(w)
	return Terrain.nearest_free(w, clampi(l.x + dx, 0, Terrain.W - 1), l.y, Terrain.BUILDABLE_HOUSING, 8)


func _rows(w: WorldState, what: String, who: String = "") -> Array:
	var f := {"what": what}
	if who != "":
		f["who"] = who
	return Logbook.rows(w, f)


func test_the_law_reads_a_company_through_one_place() -> void:
	var w := F.bare_world()
	F.company(w, "company:1", "PRIVATE", {"name": "Redrock Mining", "chief": {"name": "A. Chief"}})
	F.company(w, "company:2", "STATE")
	check(LawCompany.exists(w, "company:1") and LawCompany.trading(w, "company:1"), "a company that exists trades")
	check(not LawCompany.exists(w, "company:9"), "no record, no company")
	check_eq(LawCompany.name_of(w, "company:1"), "Redrock Mining", "its name")
	check_eq(LawCompany.chief_name(w, "company:1"), "A. Chief", "its chief")
	check_eq(LawCompany.account("company:1"), "co:company:1", "its account is CoreUtil.acct")
	check(LawCompany.is_state(w, "company:2") and not LawCompany.is_state(w, "company:1"), "the state's company is the state's")
	check_eq(LawCompany.holders(w, "company:1"), {"person:1": 1000}, "the owners by share")
	w.table("company")["company:1"]["status"] = "ENDED"
	check(LawCompany.exists(w, "company:1") and not LawCompany.trading(w, "company:1"), "an ended company no longer trades")


func test_the_law_keeps_its_own_records_by_company_id() -> void:
	var w := F.bare_world()
	LawOps.init_world(w)
	J.init_courts(w)
	F.company(w, "company:1", "PRIVATE", {"pl_last": {"rev": 100 * 1200 * S}})
	w.ledger.open_account("co:company:1")
	w.ledger.open_account("gov:fines_revenue")
	var lic := LawOps.grant_licence(w, "company:1", "licence", "HAZARD", 60)
	var app := LawOps.apply_licence(w, "company:1", "licence", "EXTRACTION", "", true, 120)
	var vid := LawOps.record_violation(w, {"kind": "COMPANY", "id": "company:1"}, "OPERATE_FACILITY", {"hazard_class": "HIGH"})
	var fine := J._fine(w, "company:1", "SERIOUS", vid)
	var r := LawCompany.records_of(w, "company:1")
	check_eq(r["licences"], [lic], "its licence")
	check_eq(r["applications"], [app], "its application")
	check_eq(r["violations"], [vid], "its violation")
	check(fine > 0 and r["liabilities"].size() >= 1, "the fine it could not pay is owed (%d)" % fine)
	check(LawCompany.records_of(w, "company:2")["licences"].is_empty(), "another company's records are its own")
	check(w.table("licence")[lic]["status"] == "ACTIVE", "the law's record is the law's, not a field of the company")
	check(not (w.table("company")["company:1"] as Dictionary).has("licences"), "no copy in the company record")


func test_every_decision_and_deed_writes_a_logbook_row() -> void:
	var w := F.bare_world()
	LawOps.init_world(w)
	J.init_courts(w)
	F.company(w, "company:1", "PRIVATE", {"pl_last": {"rev": 100 * 1200 * S}})
	w.ledger.open_account("co:company:1")
	w.ledger.open_account("gov:fines_revenue")
	LawOps.grant_licence(w, "company:1", "licence", "HAZARD", 60)
	LawOps.apply_licence(w, "company:1", "licence", "EXTRACTION", "", true, 120)
	LawOps.process_permits(w)
	var vid := LawOps.record_violation(w, {"kind": "COMPANY", "id": "company:1"}, "OPERATE_FACILITY", {"hazard_class": "HIGH"})
	J._fine(w, "company:1", "SERIOUS", vid)
	for what in ["licence granted", "licence applied", "permit decided", "violation", "fine", "owed"]:
		check(_rows(w, what, "company:1").size() >= 1, "a row for: " + what)
	var fine_row: Dictionary = _rows(w, "fine", "company:1")[0]
	check(fine_row["why"].has("annual_rev") and fine_row["why"].has("owed"), "the row says what it read and what it set")
	F.company(w, "company:2", "STATE")
	check(not J._liquidate(w, "company:2", "TEST"), "a state company is never wound up by the court")
	check(not J._liquidate(w, "company:1", "TEST"), "no endings before step 5: the doorway refuses")
	check_eq(_rows(w, "wind up refused", "company:1").size(), 1, "and the refusal is logged")


func test_a_town_cell_has_its_tiles_title_until_it_has_its_own() -> void:
	var w := _world()
	var t := _free(w)
	var cell := TownGrid.centre_cell(t)
	var ck := Land.key_of_cell(cell)
	check(ck.begins_with("c:") and Land.tile_of_key(ck) == t, "a cell key lies in its tile (%s)" % ck)
	check_eq(Land.title(w, ck)["owner"], "gov", "the colony's at landing")
	check(Land.zone(w, [t], "INDUSTRIAL")["ok"], "the tile is zoned")
	check_eq(Land.zone_of(w, ck), "INDUSTRIAL", "a cell with no row of its own has its tile's zone")
	check(Land.zone(w, [ck], "RESIDENTIAL")["ok"], "a cell is zoned on its own")
	check_eq(Land.zone_of(w, ck), "RESIDENTIAL", "the cell's own zone")
	check_eq(Land.zone_of(w, t), "INDUSTRIAL", "the tile keeps its own")
	var next := Land.key_of_cell(cell + Vector2i(1, 0))
	check_eq(Land.zone_of(w, next), "INDUSTRIAL", "a neighbouring cell still has the tile's")
	var off := Land.land_offer(w, ck, {"kind": "COMPANY", "id": "company:1"}, "HOUSING")
	check(off["allowed"] and off["mode"] == "LEASE", "a cell is leased like a tile (%s)" % [off])
	check(Land.grant_land(w, ck, {"kind": "COMPANY", "id": "company:1"}, "LEASE", int(off["lease_rent"]), 240)["ok"], "lease granted")
	check_eq(Land.right_of(w, {"kind": "COMPANY", "id": "company:1"}, ck), "LESSEE", "the company leases the cell")
	check_eq(Land.right_of(w, {"kind": "COMPANY", "id": "company:1"}, t), "", "and not the tile around it")
	var place := Land.title_of_place(w, [ck, next])
	check(place.size() == 2 and String(place[ck]["lessee"]) == "company:1" and String(place[next]["lessee"]) == "", "the titles of a place")
	check(LawCompany.records_of(w, "company:1")["titles"].has(ck), "the lease is among the company's law records")


func test_land_value_reads_the_hook_by_key() -> void:
	var w := _world()
	var seen: Array = []
	Land.land_value_fn = func(_w: WorldState, key: String) -> int:
		seen.append(key)
		return 5000
	var t := _free(w)
	var ck := Land.key_of_cell(TownGrid.centre_cell(t))
	check_eq(Land.land_value(w, ck), 5000, "a cell's value from the hook")
	Land.land_value(w, t)
	check(seen.has(ck) and seen.has("%d,%d" % [t.x, t.y]), "the hook gets the key, cell or tile (%s)" % [seen])
	Land.land_value_fn = Callable()


func test_land_deeds_and_the_landing_are_logged() -> void:
	var w := _world()
	check_eq(_rows(w, "the colony holds all land").size(), 1, "one row at landing")
	Land.ensure_rules(w)
	check_eq(_rows(w, "the colony holds all land").size(), 1, "not again")
	var t := _free(w)
	Land.zone(w, [t], "FARM")
	var off := Land.land_offer(w, t, {"kind": "COMPANY", "id": "company:1"}, "FARM")
	Land.grant_land(w, t, {"kind": "COMPANY", "id": "company:1"}, "LEASE", int(off["lease_rent"]), 24)
	Land.report_arrears(w, t, int(w.levers.get("LAW_EVICTION_NOTICE_MONTHS", 3)) + 5)
	check_eq(_rows(w, "zoned").size(), 1, "zoning logged")
	check_eq(_rows(w, "land leased", "company:1").size(), 1, "the lease logged")
	check_eq(_rows(w, "lease ended", "company:1").size(), 1, "the end of the lease logged")


## Ella's review: a cell with a row of its own (here its zone) still follows its tile's owner and lease; only a deed on
## the cell itself makes the cell's owner its own.
func test_a_cell_follows_its_tile_until_it_is_dealt_with_on_its_own() -> void:
	var w := _world()
	var t := _free(w)
	var cell := TownGrid.centre_cell(t)
	var zoned := Land.key_of_cell(cell)
	var sold := Land.key_of_cell(cell + Vector2i(1, 0))
	check(Land.zone(w, [zoned], "RESIDENTIAL")["ok"], "one cell zoned on its own")
	var co := {"kind": "COMPANY", "id": "company:1"}
	var hh := {"kind": "HOUSEHOLD", "id": "hh:p3"}
	w.levers["LAW_LAND_DISPOSAL"] = "SELL"
	var v := Land.land_value(w, sold)
	check(Land.grant_land(w, sold, hh, "SELL", v)["ok"], "another cell sold on its own")
	var tv := Land.land_value(w, t)
	check(Land.grant_land(w, t, co, "SELL", tv)["ok"], "then the tile is sold")
	check_eq(String(Land.title(w, zoned)["owner"]), "company:1", "the zoned cell went with its tile")
	check_eq(Land.zone_of(w, zoned), "RESIDENTIAL", "and kept its own zone")
	check_eq(String(Land.title(w, sold)["owner"]), "hh:p3", "the cell sold on its own stays its buyer's")
	check_eq(String(Land.title(w, Land.key_of_cell(cell + Vector2i(2, 0)))["owner"]), "company:1", "an untouched cell is the tile's")


func test_a_company_has_the_district_of_its_area() -> void:
	var w := F.bare_world()
	F.company(w, "company:1", "PRIVATE", {"area": ""})
	check_eq(LawCompany.district_of(w, "company:1"), "", "no area yet, no district")
	w.table("area")["area:1"] = {"id": "area:1", "district": "d:2", "status": "ACTIVE"}
	w.table("company")["company:1"]["area"] = "area:1"
	check_eq(LawCompany.district_of(w, "company:1"), "d:2", "its area's district")
