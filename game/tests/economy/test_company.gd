extends TestCase
## The company record (plan section 3): made with its account and starting prices and a Logbook row; plants in their
## own table; staff written once through staff_change and read back per tier, plant and pool; no old table touched.

const Company := preload("res://sim/economy/company.gd")
const TypeTable := preload("res://sim/economy/type_table.gd")
const S := 1000
const HW := {"kind": "HOME_WORLD", "holders": {"home_world": 1000}}


func _w() -> WorldState:
	return WorldState.new(1)


func test_a_company_is_made_with_its_account_prices_and_a_row() -> void:
	var w := _w()
	var id := Company.create(w, "BUILDER", "LARGE", HW, "Meridian Builders", {"origin": "HOME_WORLD_LANDING", "origin_n": 2})
	check(id.begins_with("company:"), "an id like company:N (%s)" % id)
	check(w.ledger.has_account(CoreUtil.acct(id)), "its account is open")
	check_eq(w.ledger.balance(CoreUtil.acct(id)), 0, "with nothing in it: money is a payment")
	var r := Company.record(w, id)
	check_eq(String(r["type"]), "BUILDER", "type")
	check_eq(String(r["size"]), "LARGE", "size")
	check_eq(String(r["origin"]), "HOME_WORLD_LANDING", "origin")
	check_eq(int(r["origin_n"]), 2, "origin number")
	check_eq((r["plants"] as Array).size(), 0, "a home-world builder has no plant")
	check_eq(Company.price(w, id, "BW"), TypeTable.start_price("BW"), "it posts the starting BW price")
	check_eq(Logbook.rows(w, {"kind": "OPEN", "who": id}).size(), 1, "one OPEN row")
	check_eq(Company.owner_kind(w, id), "HOME_WORLD", "owner kind")
	check(not Company.is_state(w, id), "not the state's")


func test_a_two_line_type_has_a_price_for_each_line() -> void:
	var w := _w()
	var id := Company.create(w, "COMPONENTS", "SMALL", {"kind": "PRIVATE", "holders": {"person:4": 600, "person:9": 400}}, "Parts")
	check_eq(Company.price(w, id, "COMPONENT"), TypeTable.start_price("COMPONENT"), "first output's price")
	check_eq(Company.price(w, id, "TRUCK"), TypeTable.start_price("TRUCK"), "second output's price")
	var svc := Company.create(w, "CLINIC", "AVERAGE", {"kind": "STATE", "holders": {"gov": 1000}}, "Landing Clinic")
	check_eq(Company.price(w, svc, "@person"), TypeTable.start_price_of("CLINIC"), "a service's price per client-month")
	check(Company.is_state(w, svc), "a state company")
	var bank := Company.create(w, "BANK", "LARGE", HW, "Colony Bank")
	check_eq(Company.price(w, bank, "RATE"), 5, "the bank posts its rate")


func test_bad_input_makes_nothing() -> void:
	var w := _w()
	check_eq(Company.create(w, "OFFICE", "LARGE", HW, "x"), "", "no such type")
	check_eq(Company.create(w, "FARM", "HUGE", HW, "x"), "", "no such size")
	check_eq(Company.create(w, "FARM", "FAMILY", {"kind": "FAMILY", "holders": {"person:1": 900}}, "x"), "", "shares must add up to 1000")
	check_eq(Company.create(w, "FARM", "FAMILY", {"kind": "GUILD", "holders": {"person:1": 1000}}, "x"), "", "no such owner kind")
	check(Company.ids(w).is_empty(), "nothing was made")
	check(Logbook.rows(w).is_empty(), "and nothing logged")


func test_plants_live_in_their_own_table() -> void:
	var w := _w()
	var id := Company.create(w, "FARM", "FAMILY", {"kind": "FAMILY", "holders": {"person:1": 1000}}, "Hill Farm")
	var pid := Company.add_plant(w, id, "FAMILY", "plan:3")
	check(pid.begins_with("plant:"), "a plant id")
	var p := Company.plant(w, pid)
	check_eq(String(p["company"]), id, "its company")
	check_eq(int(p["sixths"]), 1, "a family plant is one sixth")
	check_eq(int(p["condition"]), 100, "new: condition 100")
	check_eq(bool(p["closed"]), false, "open")
	check_eq(Company.plant_ids(w), [pid], "all plants")
	check_eq(Company.plant_ids_of(w, id), [pid], "its plants")
	check_eq(Logbook.rows(w, {"kind": "PLANT", "ref": "plan:3"}).size(), 1, "the row carries the plan's id")
	check(not w.table("plant")[pid].has("homes") and not w.table("plant")[pid].has("tile"), "no place and no homes on the plant (Terra's)")


func test_staff_are_written_once_and_read_every_way() -> void:
	var w := _w()
	var id := Company.create(w, "BUILDER", "SMALL", HW, "B")
	check(Company.staff_change(w, id, "crew", "G", "landing|I2|G", 10 * S), "hire ten")
	check(Company.staff_change(w, id, "crew", "S", "landing|I3|S", 4 * S), "and four skilled")
	check(Company.staff_change(w, id, "crew", "G", "landing|I3|S", 1 * S), "a skilled person in a general post")
	check_eq(Company.staff_count(w, id), 15 * S, "fifteen in all")
	check_eq(Company.staff_count(w, id, "G"), 11 * S, "eleven in general posts")
	check_eq(Company.staff_of_pool(w, "landing", "I3"), {id: 5 * S}, "the I3 pool has five there")
	check(not Company.staff_change(w, id, "crew", "G", "landing|I2|G", -11 * S), "cannot lay off more than are there")
	check_eq(Company.staff_count(w, id, "G"), 11 * S, "and nothing changed")
	check(Company.staff_change(w, id, "crew", "S", "landing|I3|S", -4 * S), "all four skilled go")
	check(not Company.staff_entries(w, id)["crew"].has("S"), "an empty tier is dropped")
	check(not Company.staff_change(w, id, "plant:99", "G", "landing|I2|G", S), "not at a plant it does not have")
	check(not Company.staff_change(w, id, "crew", "X", "landing|I2|G", S), "not in a tier that does not exist")


func test_occupation() -> void:
	var w := _w()
	var farm := Company.create(w, "FARM", "SMALL", {"kind": "COOP", "holders": {"person:1": 500, "person:2": 500}}, "Co-op Farm")
	var clinic := Company.create(w, "CLINIC", "SMALL", {"kind": "STATE", "holders": {"gov": 1000}}, "Clinic")
	check_eq(Company.occupation(w, farm, "G"), "AGRICULTURE", "the row's occupation")
	check_eq(Company.occupation(w, farm, "Sp"), "PROFESSIONAL", "a specialist post")
	check_eq(Company.occupation(w, clinic, "S"), "PUBLIC_SECTOR", "a state company")


func test_prices_change_only_with_a_row() -> void:
	var w := _w()
	var id := Company.create(w, "FARM", "FAMILY", {"kind": "FAMILY", "holders": {"person:1": 1000}}, "F")
	var p0 := Company.price(w, id, "FOOD")
	check(Company.set_price(w, id, "FOOD", p0 + 500, {"test": 1}), "set")
	var rows := Logbook.rows(w, {"kind": "PRICE", "who": id})
	check_eq(rows.size(), 1, "one PRICE row")
	check_eq(rows[0]["change"]["FOOD"], [p0, p0 + 500], "from and to")
	check(not Company.set_price(w, id, "MINERAL", 1), "not a thing it sells")


func test_stock_goes_in_with_its_cost_and_a_row() -> void:
	var w := _w()
	var id := Company.create(w, "SHOP", "LARGE", {"kind": "STATE", "holders": {"gov": 1000}}, "Colony Stores")
	check(Company.stock_add(w, id, "FOOD", 12000 * S, 60663, "LANDING", "landing stock"), "food in")
	check(Company.stock_add(w, id, "FOOD", 1000 * S, 50000, "IMPORT", "more"), "more food in")
	var f := Company.stock_of(w, id, "FOOD")
	check_eq(int(f["qty"]), 13000 * S, "13,000 FOOD")
	check_eq(int(f["value"]), 12000 * 60663 + 1000 * 50000, "its book value")
	check_eq(Company.stock_of(w, id, "MINERAL"), {"qty": 0, "value": 0, "waiting": 0}, "none of what it does not hold")
	check(not Company.stock_add(w, id, "ENERGY", S, 1, "LANDING", "x"), "power cannot be stocked")
	check(not Company.stock_add(w, id, "BW", S, 1, "LANDING", "x"), "building work is not an item")
	check(not Company.stock_add(w, id, "FOOD", -S, 1, "LANDING", "x"), "no negative quantity")
	check(not Company.stock_add(w, id, "FOOD", S, 1, "company:9", "x"), "not from another company: that is stock_move")
	check(not Company.stock_add(w, "company:404", "FOOD", S, 1, "LANDING", "x"), "not into an unknown company")
	check(Company.stock_add(w, id, "MATERIAL", 10 * S, 0, "LANDING", "free"), "a cost of 0 is allowed")
	check_eq(Logbook.rows(w, {"kind": "STOCK", "who": id}).size(), 3, "one row per delivery")
	check_eq(Logbook.rows(w, {"kind": "STOCK", "who": id, "party": "LANDING"}).size(), 2, "each says where it came from")
	check(Company.offer(w, id, "FOOD", TypeTable.start_price("FOOD"), {"why": "landing stock"}), "a shop opens a price for food")
	check_eq(Company.price(w, id, "FOOD"), TypeTable.start_price("FOOD"), "at the starting price")
	check(not Company.offer(w, id, "FOOD", 1), "not twice: set_price moves it")
	var farm := Company.create(w, "FARM", "SMALL", HW, "F")
	check(not Company.offer(w, farm, "MATERIAL", 1), "only a shop sells what it buys in")


func test_goods_move_between_companies_never_appear() -> void:
	var w := _w()
	var farm := Company.create(w, "FARM", "SMALL", HW, "F")
	var shop := Company.create(w, "SHOP", "SMALL", HW, "S")
	check((Company.record(w, shop)["price"] as Dictionary).is_empty(), "a shop has no price at creation: it opens one per item")
	Company.stock_add(w, farm, "FOOD", 100 * S, 30000, "OUTPUT", "harvest")
	check(Company.stock_move(w, farm, shop, "FOOD", 40 * S, 60000, "sale"), "moved")
	check_eq(int(Company.stock_of(w, farm, "FOOD")["qty"]) + int(Company.stock_of(w, shop, "FOOD")["qty"]), 100 * S, "nothing appeared or vanished")
	check_eq(int(Company.stock_of(w, farm, "FOOD")["value"]), 60 * 30000, "the seller keeps the rest at its cost")
	check_eq(int(Company.stock_of(w, shop, "FOOD")["value"]), 40 * 60000, "the buyer holds it at what it paid")
	check(not Company.stock_move(w, farm, shop, "FOOD", 61 * S, 1, "too much"), "not more than the seller holds")
	check_eq(Company.stock_take(w, shop, "FOOD", 10 * S, "SPOILED", "rot"), 10 * 60000, "spoiled at its average cost")
	check_eq(Company.stock_take(w, shop, "FOOD", 31 * S, "SOLD", "x"), -1, "not more than it holds")
	check_eq(Company.stock_take(w, shop, "FOOD", S, "STOLEN", "x"), -1, "not for an unknown reason")
	var rows := Logbook.rows(w, {"kind": "STOCK"}).size()
	check(not Company.stock_move(w, farm, shop, "FOOD", 0, 1, "nothing"), "a quantity of 0 is refused")
	check(not Company.stock_add(w, farm, "FOOD", 0, 1, "OUTPUT", "nothing"), "nothing added")
	check(not Company.stock_move(w, shop, farm, "MINERAL", S, 1, "never held"), "not what the seller never held")
	check_eq(Logbook.rows(w, {"kind": "STOCK"}).size(), rows, "and no rows of nothing")


func test_crew_is_for_builders_and_companies_without_a_plant() -> void:
	var w := _w()
	var farm := Company.create(w, "FARM", "SMALL", HW, "F")
	check(Company.staff_change(w, farm, "crew", "G", "a|I1|G", S), "a company with no plant yet keeps its staff as crew")
	Company.staff_change(w, farm, "crew", "G", "a|I1|G", -S)
	var pid := Company.add_plant(w, farm, "SMALL")
	check(not Company.staff_change(w, farm, "crew", "G", "a|I1|G", S), "a farm with a plant cannot park staff under crew")
	check(Company.staff_change(w, farm, pid, "G", "a|I1|G", S), "it hires at its plant")
	var b := Company.create(w, "BUILDER", "SMALL", HW, "B")
	Company.add_plant(w, b, "SMALL")
	check(Company.staff_change(w, b, "crew", "G", "a|I1|G", S), "a builder with a yard still keeps its crews as crew")
	check(not Company.staff_change(w, b, "plant:999", "G", "a|I1|G", S), "not at a plant it does not own")
	check_eq(Company.create(w, "FARM", "FAMILY", {"kind": "PRIVATE", "holders": {"person:1": 500, "person:2": 499}}, "x"), "", "999 per mille is refused")


func test_no_old_table_is_created() -> void:
	var w := _w()
	var id := Company.create(w, "SHOP", "SMALL", HW, "S")
	Company.add_plant(w, id, "SMALL")
	Company.staff_of_pool(w, "landing", "I1")
	Company.record(w, "company:404")
	for old in ["org", "facility", "project", "hh"]:
		check(not w.entities.has(old), "no table %s" % old)
	check(Company.record(w, "company:404").is_empty(), "an unknown id reads as {}")
