extends TestCase
## The type table (planning/rebuild-type-table.md): 30 rows, the four sizes, the bills, and the starting prices that
## the one pricing rule gives, which must match the paper; the salary formula returns the salary the prices are built on.

const TypeTable := preload("res://sim/economy/type_table.gd")
const S := 1000


func test_thirty_rows_none_of_the_gone_ones() -> void:
	check_eq(TypeTable.types().size(), 30, "30 rows")
	for gone in ["HQOFFICE", "BIZSVC", "PUBJOBS", "WAREHOUSE", "FAMFARM", "FAMBAKERY", "TRUCKER", "DEPOT", "OFFICE", "HOUSING", "RETAIL", "COMFORT", "NEWSROOM", "POLICE_STATION"]:
		check(not TypeTable.has_type(gone), "%s is not a row" % gone)
	for t in TypeTable.types():
		var r := TypeTable.row(t)
		check((r["bill"] as Array).size() == 4, "%s has a bill" % t)
		check(String(r["setting"]) in ["TOWN", "COUNTRY"], "%s stands in town or country" % t)
		for i in TypeTable.line_count(t):
			var o := TypeTable.out_of(t, i)
			check(TypeTable.is_item(o) or o.begins_with("@"), "%s line %d sells an item or a non-item" % [t, i])
			for k in TypeTable.line(t, i)["in"]:
				check(TypeTable.is_item(String(k)), "%s takes in an item: %s" % [t, k])


func test_the_four_sizes() -> void:
	# the user, 2026-11-18 (9.2): one farm worker feeds ten people, "10 purple each": 24 posts, 240 FOOD
	check_eq(TypeTable.output_milli("FARM", "LARGE"), 240 * S, "a large farm makes the full row")
	check_eq(TypeTable.posts("FARM", "LARGE"), {"G": 18, "S": 5, "Sp": 1}, "with the same 24 posts")
	check_eq(TypeTable.output_milli("FARM", "FAMILY"), 240 * S * 94 / 600, "a family farm: a sixth, less 6%")
	check_eq(TypeTable.output_milli("BUILDER", "AVERAGE"), 39200, "an average builder: 2/3 of 60 BW, less 2%")
	check_eq(TypeTable.output_milli("BUILDER", "SMALL"), 19200, "a small builder: 1/3 of 60 BW, less 4%")
	check_eq(TypeTable.posts("BUILDER", "LARGE"), {"G": 36, "S": 18, "Sp": 6}, "a large builder's posts")
	check_eq(TypeTable.posts("BUILDER", "AVERAGE"), {"G": 24, "S": 12, "Sp": 4}, "an average builder's posts")
	check_eq(TypeTable.posts("BUILDER", "FAMILY"), {"G": 6, "S": 3, "Sp": 1}, "a family builder's posts")
	check_eq(TypeTable.posts("FARM", "FAMILY"), {"G": 3, "S": 1, "Sp": 0}, "a family farm: 4 people, by largest remainder")
	check_eq(TypeTable.inputs_milli("BAKERY", "SMALL")["FOOD"], 1300 * S / 3, "inputs scale with the share, no penalty")
	check_eq(TypeTable.sixths("AVERAGE"), 4, "an average company is four sixths")


func test_bills_and_the_fewest_months() -> void:
	check_eq(TypeTable.bill("FARM", "LARGE"), {"bw": 240 * S, "material": 240 * S, "component": 12 * S, "months": 4}, "a large farm")
	check_eq(TypeTable.bill("FARM", "FAMILY"), {"bw": 40 * S, "material": 40 * S, "component": 2 * S, "months": 3}, "a family farm: 3 months (Otto)")
	check_eq(int(TypeTable.bill("POWER", "SMALL")["months"]), 6, "a small power plant: ceil(8 × 8/6 / 2) = 6")
	check_eq(int(TypeTable.bill("BANK", "FAMILY")["months"]), 2, "never under 2 months")
	check_eq(TypeTable.upkeep_milli("FARM", "LARGE"), {"material": 600, "bw": 400}, "upkeep: 1/400 of the material a month, 2% of the BW a year")


func test_starting_prices_are_the_papers() -> void:
	# rebuild-type-table.md sections 2, 4 and 5 (to the credit; the code solves the same rule as the calculator)
	# FOOD, BREAD and CLOTHING since a farm worker feeds ten (the user, 2026-11-18, 9.2): were 60.7, 58.3, 19.3
	var want := {"FOOD": 39.4, "BREAD": 39.9, "MATERIAL": 37.1, "COMPONENT": 138.1, "MINERAL": 7.7, "TRUCK": 6425.6,
		"BW": 392.0, "CLOTHING": 17.1, "ENERGY": 0.189}
	for k in want:
		var got := float(TypeTable.start_price(k)) / S
		check(absf(got - float(want[k])) <= maxf(0.06, float(want[k]) * 0.002), "%s starts at %.3f, the paper says %.3f" % [k, got, want[k]])
	# the user, 2026-11-18 (9.2, "The rent is doubled"): "Screw lowering food, double the rent"
	check(absf(float(TypeTable.start_price_of("LANDLORD")) / S - 194.0) < 1.0, "a new home rents at 194, double the solve's 97")
	check(absf(float(TypeTable.start_price_of("CLINIC")) / S - 7.57) < 0.02, "a clinic place-month 7.57")
	check_eq(TypeTable.start_price_of("BUILDER"), TypeTable.start_price("BW"), "a builder posts the BW price")
	check_eq(TypeTable.start_price_of("BANK"), 5, "the bank's price is its rate, 5 per mille a month")


func test_a_price_is_its_making_price_plus_the_building_over_ten_years() -> void:
	var p := TypeTable.start_prices()
	var w := {"G": TypeTable.salary("G"), "S": TypeTable.salary("S"), "Sp": TypeTable.salary("Sp")}
	var b := TypeTable.bill("MINE", "LARGE")
	var bill_cost := int(b["bw"]) * int(p["BW"]) / S + int(b["material"]) * int(p["MATERIAL"]) / S + int(b["component"]) * int(p["COMPONENT"]) / S
	var capital := bill_cost * 1100 / 1000 / 120 * S / TypeTable.output_milli("MINE", "LARGE")
	var making := TypeTable.making_price("MINE", "LARGE", 0, p, w)
	check(absi(making + capital - int(p["MINERAL"])) <= 3, "mineral = making %d + building %d = %d" % [making, capital, int(p["MINERAL"])])
	check(making < int(p["MINERAL"]), "the making price is below the starting price")


func test_the_salary_formula_at_the_landing_prices() -> void:
	# plan 12.5, 37 (revised): 1.5 × (rent of a home + food of a household of 2.5); the shelter at half a new house.
	# It gave back the table's 300 until the user doubled the rent (2026-11-18, 9.2); the table still solves at 300.
	var shelter := TypeTable.start_price_of("LANDLORD") / 2
	var line := TypeTable.salary_line(shelter, TypeTable.start_price("FOOD"), 2500)
	check(absi(line - 293 * S) <= 2 * S, "the formula gives %d with the rent doubled and a farm worker feeding ten; the table's salary is %d" % [line, TypeTable.salary("G")])


func test_town_and_country() -> void:
	for t in ["BAKERY", "SHOP", "CAFE", "SERVICEHUB", "CLINIC", "SCHOOL", "CHILDCARE", "ELDERCARE", "POLICE", "ADMIN", "BANK", "NEWSPAPER", "OFFICEBLOCK", "LANDLORD", "TRUCKSHOP"]:
		check_eq(TypeTable.setting(t), "TOWN", t)
	for t in ["FARM", "MINE", "PROCESSING", "POWER", "HAULIER", "BUILDER", "PRISON", "TRANSIT", "SANITATION"]:
		check_eq(TypeTable.setting(t), "COUNTRY", t)


func test_farms_need_no_grid_and_the_grid_goods_cannot_be_stocked() -> void:
	check(TypeTable.line("FARM")["in"].is_empty(), "a farm takes nothing in at the start")
	check(bool(TypeTable.ITEMS["ENERGY"]["grid"]) and bool(TypeTable.ITEMS["WATER"]["grid"]), "power and water travel on the grid")
	check_eq(TypeTable.out_of("COMPONENTS", 1), "TRUCK", "a components works' second output is trucks")


func test_an_item_two_rows_make_starts_at_the_cheaper() -> void:
	var p := TypeTable.start_prices()
	var w := {"G": TypeTable.salary("G"), "S": TypeTable.salary("S"), "Sp": TypeTable.salary("Sp")}
	var cap_c := _capital("COMPONENTS", 1, p)
	var cap_t := _capital("TRUCKSHOP", 1, p)
	var by_c := TypeTable.making_price("COMPONENTS", "LARGE", 1, p, w) + cap_c
	var by_t := TypeTable.making_price("TRUCKSHOP", "LARGE", 1, p, w) + cap_t
	check(absi(TypeTable.start_price("TRUCK") - mini(by_c, by_t)) <= 5 * S, "a truck starts at the cheaper maker's price (%d; %d, %d)" % [TypeTable.start_price("TRUCK"), by_c, by_t])
	check(by_c < by_t, "the components works' plain truck is the cheaper")


func _capital(type: String, idx: int, p: Dictionary) -> int:
	var b := TypeTable.bill(type, "LARGE")
	var cost := int(b["bw"]) * int(p["BW"]) / S + int(b["material"]) * int(p["MATERIAL"]) / S + int(b["component"]) * int(p["COMPONENT"]) / S
	return cost * 1100 / 1000 / 120 * S / TypeTable.output_milli(type, "LARGE", idx)
