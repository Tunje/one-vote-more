extends TestCase
## The company record (plan section 3): made with its account and starting prices and a Logbook row; plants in their
## own table; staff written once through staff_change and read back per tier, plant and pool; no old table touched.

const Company := preload("res://sim/economy/company.gd")
const TypeTable := preload("res://sim/economy/type_table.gd")
const Rules := preload("res://sim/economy/rules.gd")
const S := 1000
const Households := preload("res://sim/population/households.gd")
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
	check(Company.staff_change(w, id, "crew", "G", "landing|I2|G", 10 * S, 300 * S), "hire ten")
	check(Company.staff_change(w, id, "crew", "S", "landing|I3|S", 4 * S, 300 * S), "and four skilled")
	check(Company.staff_change(w, id, "crew", "G", "landing|I3|S", 1 * S, 300 * S), "a skilled person in a general post")
	check_eq(Company.staff_count(w, id), 15 * S, "fifteen in all")
	check_eq(Company.staff_count(w, id, "G"), 11 * S, "eleven in general posts")
	check_eq(Company.staff_of_pool(w, "landing", "I3"), {id: 5 * S}, "the I3 pool has five there")
	check(not Company.staff_change(w, id, "crew", "G", "landing|I2|G", -11 * S), "cannot lay off more than are there")
	check_eq(Company.staff_count(w, id, "G"), 11 * S, "and nothing changed")
	check(Company.staff_change(w, id, "crew", "S", "landing|I3|S", -4 * S), "all four skilled go")
	check(not Company.staff_entries(w, id)["crew"].has("S"), "an empty tier is dropped")
	check(not Company.staff_change(w, id, "plant:99", "G", "landing|I2|G", S, 300 * S), "not at a plant it does not have")
	check(not Company.staff_change(w, id, "crew", "X", "landing|I2|G", S, 300 * S), "not in a tier that does not exist")


func test_a_salary_is_set_at_hire_and_rises_only_by_the_yearly_raise() -> void:
	var w := _w()
	var id := Company.create(w, "BUILDER", "SMALL", HW, "B")
	var g0 := Rules.starting_salary(w, "landing", "G")   # the user's formula in the area (9.2)
	check_eq(Company.hiring_salary(w, id, "G", "landing"), g0, "it offers the starting salary until it sets its own")
	check(Company.staff_change(w, id, "crew", "G", "landing|I2|G", 10 * S, Company.hiring_salary(w, id, "G", "landing")), "ten hired at the hiring salary")
	check(Company.set_hiring_salary(w, id, "G", "landing", 400 * S, {"rule": "R1"}), "the price rules raise the hiring salary")
	check_eq(Company.payroll(w, id)[0]["pay"], g0, "those already hired keep what they were hired at")
	check(Company.staff_change(w, id, "crew", "G", "landing|I2|G", 10 * S, Company.hiring_salary(w, id, "G", "landing")), "ten more, at the new hiring salary")
	check_eq(Company.payroll(w, id).map(func(e): return int(e["pay"])), [400 * S, g0], "a pay group each: nobody's pay is blended")
	check(Company.staff_change(w, id, "crew", "G", "landing|I2|G", -5 * S), "five leave (no group named: highest pay first)")
	check_eq(Company.payroll(w, id).map(func(e): return [int(e["n"]), int(e["pay"])]), [[5 * S, 400 * S], [10 * S, g0]], "leaving does not change the pay")
	check(Company.staff_change(w, id, "crew", "S", "elsewhere|I3|S", 2 * S, 500 * S), "two hired at a given salary")
	check_eq(Company.wage_bill(w, id), 5 * 400 * S + 10 * g0 + 2 * 500 * S, "the wage bill is Σ n × pay")
	check(Company.yearly_raise(w, id, 0, 20), "a yearly raise of nothing given: the government's 2% minimum applies")
	check_eq(Company.payroll(w, id)[2]["pay"], 500 * S * 1020 / 1000, "everyone's pay rose by 2%")
	check_eq(Company.payroll(w, id)[1]["pay"], g0 * 1020 / 1000, "every group's")
	check(Company.yearly_raise(w, id, 50, 20), "a company may give more than the minimum")
	check_eq(Company.payroll(w, id)[2]["pay"], 500 * S * 1020 / 1000 * 1050 / 1000, "5% more")
	check_eq(Logbook.rows(w, {"kind": "RAISE", "who": id}).size(), 2, "each raise is in the log")
	check_eq(Logbook.rows(w, {"kind": "SALARY", "who": id}).size(), 1, "the hiring salary change is in the log")
	check_eq(Company.hiring_salary(w, id, "G", "landing"), 400 * S, "the yearly raise does not move the hiring salary")


func test_each_hire_row_knows_since_when_its_people_have_been_at_the_workplace() -> void:
	# the user: a staff row keeps everything about a hire; "You can merge if all rows match"
	var w := _w()
	var id := Company.create(w, "BUILDER", "SMALL", HW, "B")
	w.month = 12
	Company.staff_change(w, id, "crew", "G", "landing|I2|G", 10 * S, 300 * S)
	check_eq(Company.payroll(w, id)[0]["since"], 12, "a new hire is here since this month")
	w.month = 36
	Company.staff_change(w, id, "crew", "G", "landing|I2|G", 30 * S, 300 * S)
	check_eq(Company.payroll(w, id).map(func(e): return [int(e["n"]) / S, int(e["since"])]), [[10, 12], [30, 36]],
		"the same pay in another month is another row: nobody's years are blended")
	Company.staff_change(w, id, "crew", "G", "landing|I2|G", -20 * S)   # no row named: the rows in order
	check_eq(Company.payroll(w, id).map(func(e): return [int(e["n"]) / S, int(e["since"])]), [[20, 36]], "leavers change no one's month")
	Company.staff_change(w, id, "crew", "G", "landing|I3|G", 5 * S, 320 * S, 6)
	check_eq(Company.payroll(w, id)[1]["since"], 6, "a move within the workplace keeps its own month")
	Company.yearly_raise(w, id, 0, 20)
	check_eq([Company.payroll(w, id)[0]["since"], Company.payroll(w, id)[1]["since"]], [36, 6], "a raise changes pay only")
	Company.staff_change(w, id, "crew", "G", "landing|I3|G", -5 * S)
	Company.staff_change(w, id, "crew", "G", "landing|I3|G", 2 * S, 300 * S)
	check_eq(Company.payroll(w, id)[1]["since"], 36, "an emptied entry starts again at the newcomers' month")


func test_the_hiring_area_is_the_plants_and_a_hire_must_name_its_pay() -> void:
	var w := _w()
	var id := Company.create(w, "FARM", "SMALL", HW, "F", {"area": "area:A"})
	var pid := Company.add_plant(w, id, "SMALL")
	Company.set_hiring_salary(w, id, "G", "area:A", 350 * S)
	Company.set_hiring_salary(w, id, "G", "area:B", 250 * S)
	# a worker living in B, hired at the plant in A, is paid A's hiring salary: the hirer reads it for the plant's area
	check(Company.staff_change(w, id, pid, "G", "area:B|I2|G", 3 * S, Company.hiring_salary(w, id, "G", "area:A")), "hired")
	check_eq(Company.payroll(w, id)[0]["pay"], 350 * S, "at the plant's area's salary, not the home area's")
	check(not Company.staff_change(w, id, pid, "G", "area:B|I2|G", S), "a hire without a pay is refused")
	check(Company.staff_change(w, id, pid, "G", "area:B|I2|G", -3 * S), "all leave (no pay needed)")
	check(Company.staff_change(w, id, pid, "G", "area:B|I2|G", 2 * S, 300 * S), "rehired into the emptied entry")
	check_eq(Company.payroll(w, id)[0]["pay"], 300 * S, "an emptied entry starts again at the new hire's pay")
	check(Company.staff_change(w, id, pid, "S", "area:A|I3|S", S, 0), "a pay of 0 is allowed (an unpaid post)")
	check_eq(Company.wage_bill(w, id), 2 * 300 * S, "and adds nothing to the wage bill")
	var empty := Company.create(w, "SHOP", "SMALL", HW, "S")
	check(Company.yearly_raise(w, empty, 0, 20), "a raise with nobody on staff")
	var r := Logbook.rows(w, {"kind": "RAISE", "who": empty})
	check_eq(r.size(), 1, "still a row: the decision was made")
	check_eq(r[0]["change"]["wage_bill"], [0, 0], "from 0 to 0")


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
	check_eq(Company.stock_of(w, id, "MINERAL"), {"qty": 0, "value": 0, "waiting": 0, "ship": 0}, "none of what it does not hold")
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


func test_ship_goods_are_counted_in_a_stock_and_leave_in_proportion() -> void:
	var w := _w()
	var a := Company.create(w, "SHOP", "LARGE", HW, "A", {"area": "landing"})
	var b := Company.create(w, "BAKERY", "SMALL", HW, "B", {"area": "landing"})
	Company.stock_add(w, a, "FOOD", 30 * S, 10 * S, "LANDING", "landed")
	Company.stock_add(w, a, "FOOD", 10 * S, 10 * S, "OUTPUT", "made")
	check_eq(int(Company.stock_of(w, a, "FOOD")["ship"]), 30 * S, "landing is ship, output is not")
	Company.stock_take(w, a, "FOOD", 20 * S, "SOLD", "x")
	check_eq(int(Company.stock_of(w, a, "FOOD")["ship"]), 15 * S, "half sold, half the ship goods gone: the share stays 3 in 4")
	Company.stock_move(w, a, b, "FOOD", 8 * S, 10 * S, "x")
	check_eq([int(Company.stock_of(w, a, "FOOD")["ship"]), int(Company.stock_of(w, b, "FOOD")["ship"])], [9 * S, 6 * S], "moved goods carry their share")
	Company.stock_add(w, b, "FOOD", 2 * S, 10 * S, "IMPORT", "x")
	check_eq(int(Company.stock_of(w, b, "FOOD")["ship"]), 8 * S, "imports are ship goods")


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
	check(Company.staff_change(w, farm, "crew", "G", "a|I1|G", S, 300 * S), "a company with no plant yet keeps its staff as crew")
	Company.staff_change(w, farm, "crew", "G", "a|I1|G", -S)
	var pid := Company.add_plant(w, farm, "SMALL")
	check(not Company.staff_change(w, farm, "crew", "G", "a|I1|G", S, 300 * S), "a farm with a plant cannot park staff under crew")
	check(Company.staff_change(w, farm, pid, "G", "a|I1|G", S, 300 * S), "it hires at its plant")
	var b := Company.create(w, "BUILDER", "SMALL", HW, "B")
	Company.add_plant(w, b, "SMALL")
	check(Company.staff_change(w, b, "crew", "G", "a|I1|G", S, 300 * S), "a builder with a yard still keeps its crews as crew")
	check(not Company.staff_change(w, b, "plant:999", "G", "a|I1|G", S, 300 * S), "not at a plant it does not own")
	check_eq(Company.create(w, "FARM", "FAMILY", {"kind": "PRIVATE", "holders": {"person:1": 500, "person:2": 499}}, "x"), "", "999 per mille is refused")


func test_posts_follow_size_and_output_level_and_open_posts_are_vacancies() -> void:
	var w := _w()
	var farm := Company.create(w, "FARM", "SMALL", HW, "F", {"area": "landing"})
	var pid := Company.add_plant(w, farm, "SMALL")
	check_eq(Company.posts_wanted(w, farm, pid), {"G": 6, "S": 2, "Sp": 0}, "a small farm at full: 8 posts")
	check_eq(Company.posts_wanted(w, farm, "crew"), {"G": 0, "S": 0, "Sp": 0}, "a farm has no crew posts")
	check(Company.set_level(w, farm, pid, 500, {"rule": "R4"}), "half output")
	check_eq(Company.posts_wanted(w, farm, pid), {"G": 3, "S": 1, "Sp": 0}, "half the posts")
	check(not Company.set_level(w, farm, pid, 1200), "not above full: that is rule 5")
	Company.staff_change(w, farm, pid, "G", "landing|I2|G", 2 * S, 300 * S)
	var v := Company.vacancies(w, "landing")
	check_eq(v.size(), 2, "open posts: one general, one skilled")
	check_eq([v[0]["tier"], v[0]["open"], v[1]["tier"], v[1]["open"]], ["S", 1, "G", 1], "highest tier first")
	check_eq(int(v[0]["pay"]), Rules.starting_salary(w, "landing", "S"), "at the hiring salary")
	check(Company.vacancies(w, "elsewhere").is_empty(), "none in another area")
	var admin := Company.create(w, "ADMIN", "LARGE", {"kind": "STATE", "holders": {"gov": 1000}}, "A", {"area": "landing", "crew_posts": true})
	check_eq(Company.posts_wanted(w, admin, "crew"), {"G": 4, "S": 8, "Sp": 3}, "a company created with crew posts")
	check(not Company.close_plant(w, pid, "LAW"), "a farm is never shut (the user: \"FARMS DON'T SHUT\")")
	check(not bool(Company.plant(w, pid)["closed"]), "it stays open")
	check_eq(Logbook.rows(w, {"kind": "CLOSE_REFUSED", "ref": pid}).size(), 1, "a CLOSE row says it was asked and refused")
	var mine := Company.create(w, "MINE", "LARGE", HW, "M", {"area": "landing"})
	var mp := Company.add_plant(w, mine, "LARGE")
	check(Company.close_plant(w, mp, "LAW"), "another type: closed by the law")
	check_eq(Company.posts_wanted(w, mine, mp), {"G": 0, "S": 0, "Sp": 0}, "a closed plant wants nobody")
	check(not Company.close_plant(w, mp, "LAW"), "not twice")
	check(Company.reopen_plant(w, mp, "LICENSED"), "reopened")
	check_eq(Logbook.rows(w, {"kind": "CLOSE", "ref": mp}).size(), 1, "a CLOSE row")


func test_average_pay_negotiation_and_the_reference_wage() -> void:
	var w := _w()
	var id := Company.create(w, "BUILDER", "SMALL", HW, "B", {"area": "landing"})
	Company.staff_change(w, id, "crew", "G", "landing|I1|G", 10 * S, 300 * S)
	Company.staff_change(w, id, "crew", "G", "landing|I2|G", 10 * S, 200 * S)
	check_eq(Company.avg_pay(w, id, "G"), 250 * S, "the line of the general and skilled workers")
	check(not Company.negotiate(w, id, "crew", "G", "landing|I2|G", 260 * S), "never above the average")
	check(not Company.negotiate(w, id, "crew", "G", "landing|I2|G", 190 * S), "never lower")
	check(Company.negotiate(w, id, "crew", "G", "landing|I2|G", 240 * S, {"chief_mgmt": 50}), "closer to the average")
	check_eq(Company.payroll(w, id)[1]["pay"], 240 * S, "the underpaid entry rose")
	check_eq(Company.payroll(w, id)[0]["pay"], 300 * S, "the others did not move")
	check_eq(Company.reference_wage(w, "landing"), 270 * S, "the reference wage: head-weighted over all staff")
	check_eq(Company.reference_wage(w), 270 * S, "colony-wide the same here")
	check_eq(Company.chief(w, id), {"mgmt": 50, "risk": 50}, "a chief, 50 and 50 by default")
	check_eq(Company.raise_choice(w, id), 0, "it gives only the minimum unless it chooses more")
	check(Company.set_raise_choice(w, id, 30), "it may choose more")
	check_eq(Company.raise_choice(w, id), 30, "3%")


func test_books_close_into_twelve_months_and_revenue_is_read_from_them() -> void:
	var w := _w()
	var id := Company.create(w, "FARM", "SMALL", HW, "F")
	for m in 15:
		w.month = m
		Company.book(w, id, "rev", 1000 * S)
		Company.close_month(w, id)
	check_eq(Company.months_on_books(w, id), 12, "twelve months kept")
	check_eq(Company.revenue_12(w, id), 12000 * S, "the last twelve months' revenue")
	check(Company.books_month(w, id).is_empty(), "a new month opens empty")


func test_price_fixed_and_hold_back() -> void:
	var w := _w()
	var stores := Company.create(w, "SHOP", "LARGE", {"kind": "STATE", "holders": {"gov": 1000}}, "Stores", {"price_fixed": true})
	check(Company.is_price_fixed(w, stores), "the Stores' prices are fixed")
	var farm := Company.create(w, "FARM", "SMALL", HW, "F")
	check(not Company.is_price_fixed(w, farm), "an ordinary company's are not")
	check(Company.set_hold(w, farm, "FOOD", 5 * S, {"rule": "hold"}), "hold back 5")
	check_eq(Company.hold_of(w, farm, "FOOD"), 5 * S, "held")
	Company.set_hold(w, farm, "FOOD", 0)
	check_eq(Company.hold_of(w, farm, "FOOD"), 0, "released")
	check_eq(Logbook.rows(w, {"kind": "HOLD", "who": farm}).size(), 2, "each change a row")


func test_a_company_pays_its_own_wages() -> void:
	var w := _w()
	var pool := Households.seed_test(w, "landing", "I2", "G", 10)
	var id := Company.create(w, "BUILDER", "SMALL", HW, "B", {"area": "landing"})
	check_eq(Households.hire(w, id, "crew", "G", "landing", 4, {}, 300 * S), 4, "four hired")
	w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.acct(id), 1000 * S, "TEST", w.month)
	var m0 := w.ledger.total()
	var paid := Company.pay_wages(w, id)
	check_eq(paid, 1000 * S, "short of money it pays what it has (1,000 of 1,200)")
	check_eq(Company.books_month(w, id)["wages_due"], 1200 * S, "what was due is booked")
	check_eq(Company.books_month(w, id)["wages"], 1000 * S, "and what was paid")
	check_eq(w.ledger.balance(Households.account(pool)), 1000 * S, "the pool got it")
	check_eq(w.ledger.total(), m0, "no money appeared or vanished")


func test_no_old_table_is_created() -> void:
	var w := _w()
	var id := Company.create(w, "SHOP", "SMALL", HW, "S")
	Company.add_plant(w, id, "SMALL")
	Company.staff_of_pool(w, "landing", "I1")
	Company.record(w, "company:404")
	for old in ["org", "facility", "project", "hh"]:
		check(not w.entities.has(old), "no table %s" % old)
	check(Company.record(w, "company:404").is_empty(), "an unknown id reads as {}")


func test_an_entrys_existing_pay_does_not_move_when_someone_joins_at_a_different_pay() -> void:
	# Wilma's bug against 9.2 ("A worker's salary is set when they are hired. It is theirs from then on"): one blended
	# pay per staff entry cut the people already there whenever joiners came in at a lower pay.
	var w := _w()
	var id := Company.create(w, "BUILDER", "SMALL", HW, "B")
	var lk := "landing|I2|G"
	var rows := func() -> Array: return Company.payroll(w, id).map(func(e): return [int(e["n"]) / S, int(e["pay"]) / S])
	check(Company.staff_change(w, id, "crew", "G", lk, 10 * S, 300 * S, w.month), "ten at 300, trained")
	check(Company.staff_change(w, id, "crew", "G", lk, 10 * S, 200 * S), "ten new hires at 200")
	check_eq(rows.call(), [[10, 300], [10, 200]], "the ten at 300 still earn 300; the joiners are a group of their own")
	check_eq(Company.wage_bill(w, id), 10 * 300 * S + 10 * 200 * S, "each paid their own")
	check_eq(Company.trained_count(w, id), 10 * S + 10 * S * Company.trained_pm(0) / 1000, "only the new group is in training")
	check(not Company.staff_change(w, id, "crew", "G", lk, -11 * S, 200 * S), "the group at 200 holds only ten")
	check_eq(rows.call(), [[10, 300], [10, 200]], "and nothing changed")
	check(Company.staff_change(w, id, "crew", "G", lk, -4 * S, 200 * S), "four leave the group at 200")
	check(Company.staff_change(w, id, "crew", "G", lk, 5 * S, 300 * S, w.month), "five more at 300, trained, this month")
	check_eq(rows.call(), [[15, 300], [6, 200]], "every field matches: one row; no pay moved")
	check(Company.staff_change(w, id, "crew", "G", lk, 4 * S, 250 * S), "four at 250")
	check_eq(Company.avg_pay(w, id, "G"), (15 * 300 + 6 * 200 + 4 * 250) * S / 25, "the average over the rows")
	var at200 := String(Company.payroll(w, id)[-1]["row"])
	check(not Company.negotiate(w, id, "crew", "G", lk, 280 * S, {}, at200), "never above the average")
	check(Company.negotiate(w, id, "crew", "G", lk, 250 * S, {}, at200), "the row at 200 negotiates up to 250")
	check_eq(rows.call(), [[15, 300], [10, 250]], "it now matches the 250s in every field: one row; the others did not move")
	check(Company.yearly_raise(w, id, 0, 20), "the yearly raise")
	check_eq(rows.call(), [[15, 306], [10, 255]], "every row rose 2%")
	check(Company.staff_change(w, id, "crew", "G", lk, -25 * S), "all leave")
	check(not Company.staff_entries(w, id).has("crew"), "the emptied entry goes")


func test_rows_that_come_to_match_when_training_ends_are_one_row_to_every_reader() -> void:
	# Otto's review: two rows that match only once training is over, with nothing written in between
	var w := _w()
	var id := Company.create(w, "BUILDER", "SMALL", HW, "B")
	w.month = 10
	Company.staff_change(w, id, "crew", "G", "landing|I2|G", 5 * S, 300 * S, 10)   # came trained
	Company.staff_change(w, id, "crew", "G", "landing|I2|G", 3 * S, 300 * S)       # new, in training
	check_eq(Company.payroll(w, id).size(), 2, "two rows while three are in training")
	w.month = 20
	var p: Array = Company.payroll(w, id)
	check_eq(p.map(func(e): return [int(e["n"]) / S, String(e["row"])]), [[8, "300000|10|-1"]], "training over: every field matches, one row")
	check(Company.staff_move(w, id, "crew", "G", "landing|I2|G", "landing|I3|G", String(p[0]["row"]), 8 * S), "the whole row moves")
	check_eq(Company.payroll(w, id).map(func(e): return [String(e["labour_key"]), int(e["n"]) / S]), [["landing|I3|G", 8]], "all eight")
	Company.staff_change(w, id, "crew", "G", "landing|I3|G", 2 * S, 400 * S, 20)   # the average is now (2 × 400 + 9 × 300) / 11, about 318
	w.month = 30
	Company.staff_change(w, id, "crew", "G", "landing|I3|G", 1 * S, 300 * S, 10)   # a row matching the eight
	var low := String(Company.payroll(w, id)[-1]["row"])
	check(Company.negotiate(w, id, "crew", "G", "landing|I3|G", 310 * S, {}, low), "the row at 300 negotiates")
	check_eq(Company.payroll(w, id).map(func(e): return [int(e["n"]) / S, int(e["pay"]) / S]), [[2, 400], [9, 310]], "all nine of the row rose")



func test_specialists_are_averaged_apart_and_general_and_skilled_share_one_line() -> void:
	# the user (9.2): "avrage ask salleries in the company and underpayed is based on that line"; and "Specialists spoilt
	# have been counted seperatly"; Wilma's reading: general and skilled together, specialists apart
	var w := _w()
	var id := Company.create(w, "BUILDER", "SMALL", HW, "B", {"area": "landing"})
	Company.staff_change(w, id, "crew", "G", "landing|I2|G", 10 * S, 300 * S)
	Company.staff_change(w, id, "crew", "S", "landing|I3|S", 10 * S, 450 * S)
	Company.staff_change(w, id, "crew", "Sp", "landing|I4|Sp", 2 * S, 1000 * S)
	check_eq(Company.avg_pay(w, id, "G"), 375 * S, "a general worker's line: general and skilled together")
	check_eq(Company.avg_pay(w, id, "S"), 375 * S, "the same line for a skilled worker")
	check_eq(Company.avg_pay(w, id, "Sp"), 1000 * S, "the specialists' own line")
	Company.staff_change(w, id, "crew", "Sp", "landing|I4|Sp", 2 * S, 3000 * S)
	check_eq(Company.avg_pay(w, id, "G"), 375 * S, "a specialist's pay does not move the others' line")
	check(Company.negotiate(w, id, "crew", "G", "landing|I2|G", 375 * S), "a general worker may negotiate up to the shared line")
	check(not Company.negotiate(w, id, "crew", "S", "landing|I3|S", 400 * S), "a skilled worker above it is not underpaid")
