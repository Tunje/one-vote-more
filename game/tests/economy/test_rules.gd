extends TestCase
## Making and the rules of step 3 (plan section 6, 12.3 points 14, 15, 15a, 15b, 18, 19a): a plant makes from its
## staff, level, condition, season and inputs; the making price over normal full output; the price moves by
## k·s/(1+s) both ways, rule 9 deciding a tie; the hold-back; output by g·s/(1+s); the hiring salary; staff to posts;
## rule 7's work and rule 8's answer. To the last unit and credit.

const Company := preload("res://sim/economy/company.gd")
const TypeTable := preload("res://sim/economy/type_table.gd")
const Market := preload("res://sim/economy/market.gd")
const Making := preload("res://sim/economy/making.gd")
const Rules := preload("res://sim/economy/rules.gd")
const Households := preload("res://sim/population/households.gd")
const HomeBuilders := preload("res://sim/economy/home_builders.gd")
const Building := preload("res://sim/economy/building.gd")
const S := 1000
const HW := {"kind": "HOME_WORLD", "holders": {"home_world": 1000}}


func _w() -> WorldState:
	return WorldState.new(1)


func _farm(w: WorldState, staff_g: int, staff_s: int) -> Array:
	var id := Company.create(w, "FARM", "SMALL", HW, "F", {"area": "landing"})
	var pid := Company.add_plant(w, id, "SMALL")
	if staff_g > 0:
		Company.staff_change(w, id, pid, "G", "landing|I2|G", staff_g * S, 300 * S)
	if staff_s > 0:
		Company.staff_change(w, id, pid, "S", "landing|I3|S", staff_s * S, 450 * S)
	return [id, pid]


func test_a_plant_makes_from_its_staff_and_level() -> void:
	var w := _w()
	var f := _farm(w, 6, 2)   # a small farm's full posts: 6 general, 2 skilled
	var full := TypeTable.output_milli("FARM", "SMALL")
	check_eq(Making.make_plant(w, f[0], f[1]), full, "fully staffed, level full, no season off the map: the full row")
	check_eq(int(Company.stock_of(w, f[0], "FOOD")["qty"]), full, "into its stock as OUTPUT")
	var g := _farm(w, 3, 1)
	check_eq(Making.make_plant(w, g[0], g[1]), full / 2, "half staffed: half")
	Company.set_level(w, g[0], g[1], 500)
	check_eq(Making.make_plant(w, g[0], g[1]), full / 2, "at half level the same four people are a full crew for it")
	Company.close_plant(w, g[1], "LAW")
	check_eq(Making.make_plant(w, g[0], g[1]), 0, "a closed plant makes nothing")
	check_eq(Logbook.rows(w, {"kind": "MAKE", "who": f[0]})[0]["why"]["staffed_pm"], 1000, "the row says what it read")


func test_inputs_limit_what_is_made_and_are_used_up() -> void:
	var w := _w()
	var b := Company.create(w, "BAKERY", "SMALL", HW, "B", {"area": "landing"})
	var pid := Company.add_plant(w, b, "SMALL")
	Company.staff_change(w, b, pid, "G", "landing|I2|G", 4 * S, 300 * S)
	Company.staff_change(w, b, pid, "S", "landing|I3|S", 2 * S, 450 * S)
	var need := int(TypeTable.inputs_milli("BAKERY", "SMALL")["FOOD"])
	Company.stock_add(w, b, "FOOD", need / 4, 60 * S, "LANDING", "test")
	var made := Making.make_plant(w, b, pid)
	check_eq(made, TypeTable.output_milli("BAKERY", "SMALL") * (need / 4) / need, "a quarter of the flour: a quarter of the bread (to the milli-unit)")
	check_eq(int(Company.stock_of(w, b, "FOOD")["qty"]), 0, "the flour is used up")
	check_eq(int(Company.books_month(w, b)["inputs"]), need / 4 * 60, "its value booked as inputs")


func test_the_making_price_is_over_normal_full_output() -> void:
	var w := _w()
	var f := _farm(w, 6, 2)
	Company.book(w, f[0], "wages_due", 2700 * S)
	check_eq(Making.making_price(w, f[0]), 2700 * S * S / TypeTable.output_milli("FARM", "SMALL"), "wages over full output, whatever it sold")


func test_price_rules_move_by_k_s_over_one_plus_s_both_ways() -> void:
	var w := _w()
	var f := _farm(w, 6, 2)
	Company.set_price(w, f[0], "FOOD", 60 * S)
	var up := Rules.price_rule(w, f[0], "FOOD", {"offered": 10 * S, "sold": 10 * S, "unmet_above": 20 * S, "refused": 0}, 0)
	check_eq(up, 60 * S * (1000 + 200 * 20 / 30) / 1000, "sold out with 20 wanted beyond 10 sold: up by 0.2 × 2/3")
	Company.set_price(w, f[0], "FOOD", 60 * S)
	var down := Rules.price_rule(w, f[0], "FOOD", {"offered": 40 * S, "sold": 10 * S, "unmet_above": 0, "refused": 0}, 0)
	check_eq(down, 60 * S * (1000 - 200 * 30 / 40) / 1000, "30 unsold of 40: down by 0.2 × 3/4")
	Company.set_price(w, f[0], "FOOD", 60 * S)
	check_eq(Rules.price_rule(w, f[0], "FOOD", {"offered": 10 * S, "sold": 0, "unmet_above": 0, "refused": 0}, 0), 48 * S, "sold nothing: the full k")
	Company.set_price(w, f[0], "FOOD", 60 * S)
	check_eq(Rules.price_rule(w, f[0], "FOOD", {}, 0), 60 * S, "no signal, no move")
	var both := {"offered": 20 * S, "sold": 10 * S, "unmet_above": 10 * S, "refused": 0}
	check(Rules.price_rule(w, f[0], "FOOD", both, 70 * S) > 60 * S, "both signals below the making price: climbing first (rule 9)")
	Company.set_price(w, f[0], "FOOD", 60 * S)
	check(Rules.price_rule(w, f[0], "FOOD", both, 50 * S) < 60 * S, "above it: lowering first")


func test_the_hold_back_covers_the_months_expenses_and_holds_the_rest() -> void:
	var w := _w()
	var f := _farm(w, 6, 2)   # wage bill 6 × 300 + 2 × 450 = 2,700
	Company.stock_add(w, f[0], "FOOD", 100 * S, 30 * S, "OUTPUT", "test")
	Company.set_price(w, f[0], "FOOD", 60 * S)
	check(Rules.hold_back(w, f[0], "FOOD", 80 * S), "below its making price it holds back")
	check_eq(Company.hold_of(w, f[0], "FOOD"), 100 * S - 45 * S, "it offers the 45 that cover its 2,700 and holds 55")
	check(not Rules.hold_back(w, f[0], "FOOD", 50 * S), "above its making price it holds nothing")
	check_eq(Company.hold_of(w, f[0], "FOOD"), 0, "released")


func test_output_moves_by_g_s_over_one_plus_s_and_never_above_full() -> void:
	var w := _w()
	var f := _farm(w, 6, 2)
	Company.set_level(w, f[0], f[1], 800)
	Rules.output_rule(w, f[0], {"offered": 10 * S, "sold": 10 * S, "unmet_above": 10 * S, "refused": 0}, false)
	check_eq(Company.level_of(w, f[0], f[1]), 800 * (1000 + 125) / 1000, "up by 0.25 × 1/2")
	Rules.output_rule(w, f[0], {"offered": 10 * S, "sold": 10 * S, "unmet_above": 100 * S, "refused": 0}, false)
	check_eq(Company.level_of(w, f[0], f[1]), 1000, "never above full")
	Rules.output_rule(w, f[0], {"offered": 10 * S, "sold": 10 * S, "unmet_above": 100 * S, "refused": 0}, false)
	Rules.output_rule(w, f[0], {"offered": 40 * S, "sold": 10 * S, "unmet_above": 0, "refused": 0}, false)
	check_eq(Company.level_of(w, f[0], f[1]), 1000 * (1000 - 250 * 30 / 40) / 1000, "down by 0.25 × 3/4")
	var lv := Company.level_of(w, f[0], f[1])
	Rules.output_rule(w, f[0], {"offered": 10 * S, "sold": 10 * S, "unmet_above": 10 * S, "refused": 0}, true)
	check_eq(Company.level_of(w, f[0], f[1]), lv, "rule 3 does not act while it holds stock back (12.3, 18)")


func test_a_level_walked_down_to_nothing_climbs_back_when_asked() -> void:
	var w := _w()
	var f := _farm(w, 6, 2)
	Company.set_level(w, f[0], f[1], 0)
	Rules.output_rule(w, f[0], {"offered": 0, "sold": 0, "unmet_above": 30 * S, "refused": 0}, false)
	check(Company.level_of(w, f[0], f[1]) > 0, "from 0 it rises by at least one post's share (now %d)" % Company.level_of(w, f[0], f[1]))


func test_builders_run_the_same_rules_on_their_crew_and_their_making_price() -> void:
	var w := _w()
	var b := Company.create(w, "BUILDER", "SMALL", HW, "B", {"area": "landing"})
	Company.staff_change(w, b, "crew", "G", "landing|I2|G", 12 * S, 300 * S)
	Company.book(w, b, "wages_due", 3600 * S)
	check_eq(Making.making_price(w, b), 3600 * S * S / TypeTable.output_milli("BUILDER", "SMALL"), "a builder's making price over its crew's full output")
	Rules.output_rule(w, b, {"offered": 20 * S, "sold": 10 * S, "unmet_above": 0, "refused": 0}, false)
	check(Company.level_of(w, b, "crew") < 1000, "empty crews: its crew level falls (rule 4)")
	check(Rules.building_signal(w, b).is_empty(), "no signal until the building side is in the tree")


func test_the_public_works_department_keeps_its_crew_and_price_while_idle() -> void:
	var w := _w()
	var pw := Company.create(w, "BUILDER", "SMALL", {"kind": "STATE", "holders": {"state": 1000}}, "Public works",
		{"area": "landing", "origin": HomeBuilders.ORIGIN_PUBLIC, "crew_posts": true})
	Company.set_price(w, pw, "BW", 400 * S)
	var lv := Company.level_of(w, pw, "crew")
	w.table(Building.OPENED)["first_quote_m"] = 0   # past the start: the builders' market is open, so a signal exists
	for m in 4:
		w.month = m
		w.table(Building.MONTH)[pw] = {"m": m, "cap": 20 * S, "done": 0, "waiting_material": 0, "short_crew": 0,
			"refused_price_bw": 0}   # idle: crews ready, no work (what Building records for it)
		Rules.company_month(w, pw)
	check_eq(Company.level_of(w, pw, "crew"), lv, "no rule 4 on a crew that waits for the government")
	check_eq(Company.price(w, pw, "BW"), 400 * S, "no price rule: it does not sell on a market")


func test_the_hiring_salary_rises_while_posts_stay_open_and_falls_while_more_apply() -> void:
	var w := _w()
	var f := _farm(w, 3, 2)   # 3 of 6 general posts filled; nobody out of work
	Rules.salary_rules(w, f[0])
	check_eq(Company.hiring_salary(w, f[0], "G", "landing"), 300 * S * (1000 + 200 * 3 / 6) / 1000, "3 open of 6: up")
	check_eq(Company.payroll(w, f[0])[0]["pay"], 300 * S, "nobody's pay moved")
	var g := _farm(w, 6, 2)
	Households.seed_test(w, "landing", "I2", "G", 30)
	check(Rules.needs_line(w, "landing") <= 300 * S, "the starting salary meets a household's needs (%d)" % Rules.needs_line(w, "landing"))
	Rules.salary_rules(w, g[0])
	var low := 300 * S * (1000 - 200 * 30 / 36) / 1000
	check_eq(Company.hiring_salary(w, g[0], "G", "landing"), low, "30 out of work for 6 posts, none open: down")
	for i in 20:
		Rules.salary_rules(w, g[0])
	check(Company.hiring_salary(w, g[0], "G", "landing") >= Rules.needs_line(w, "landing") * 800 / 1000,
		"below the needs line nobody applies, so it stops falling there (%d against %d)" % [Company.hiring_salary(w, g[0], "G", "landing"), Rules.needs_line(w, "landing")])


func test_staff_follow_the_posts_and_unpaid_staff_are_laid_off() -> void:
	var w := _w()
	Households.seed_test(w, "landing", "I2", "G", 20)
	Households.seed_test(w, "landing", "I3", "S", 5)
	var id := Company.create(w, "BUILDER", "SMALL", HW, "B", {"area": "landing"})
	Rules.staff_to_posts(w, id)
	check_eq(Company.staff_count(w, id) / S, 17, "a small builder's 12 + 6 + 2 posts: 12 general, the 5 skilled there are, no specialist (never a lower skill)")
	Company.set_level(w, id, "crew", 500)
	Rules.staff_to_posts(w, id)
	check_eq(Company.staff_count(w, id) / S, 9, "at half level its posts are 6 + 3 + 1: it lays off to 6 + 3")
	Company.book(w, id, "wages_due", 1000 * S)
	Company.book(w, id, "wages", 500 * S)
	Rules.staff_to_posts(w, id)
	check(Company.staff_count(w, id) / S <= 5, "it could pay half: it lays off at least half (19a)")


func test_rule_7_reads_the_work_and_rule_8_says_when_it_is_covered() -> void:
	var w := _w()
	var stores := Company.create(w, "SHOP", "LARGE", {"kind": "STATE", "holders": {"gov": 1000}}, "Stores", {"area": "landing", "price_fixed": true})
	Company.stock_add(w, stores, "FOOD", 100000 * S, TypeTable.start_price("FOOD"), "LANDING", "landing")
	Company.offer(w, stores, "FOOD", TypeTable.start_price("FOOD"))
	var acct := "hh:test"
	w.ledger.open_account(acct)
	w.ledger.transfer(Ledger.EXTERNAL, acct, 100000000 * S, "TEST", 0)
	for m in 3:
		w.month = m
		Market.order(w, {"kind": "POOL", "id": "pool", "acct": acct, "area": "landing"}, "FOOD", 1000 * S, 100 * S)
		Market.clear(w)
	var work := Rules.work(w, "FARM", "landing")
	check_eq(work, 1000 * TypeTable.start_price("FOOD"), "1,000 FOOD a month at today's price")
	var f := Rules.founding(w, "FARM", "landing")
	check(bool(f["FAMILY"]["covers"]), "a family farm's running cost is covered by a sixth of it")
	check_eq(int(f["LARGE"]["work_share"]), work, "with no farm yet, a large one would have all the work")
	_farm(w, 0, 0)
	_farm(w, 0, 0)
	_farm(w, 0, 0)   # three small farms: 6 sixths already serve it
	var g := Rules.founding(w, "FARM", "landing")
	check_eq(int(g["FAMILY"]["work_share"]), work / 7, "a newcomer's share counts every plant, by size, its own included")
	check_eq(Rules.work(w, "CLINIC", "landing"), 0, "services have no work signal before step 4")


func test_stocking_up_tops_up_to_two_months_and_no_more() -> void:
	var w := _w()
	var stores := Company.create(w, "SHOP", "LARGE", HW, "Stores", {"area": "landing"})
	Company.stock_add(w, stores, "MATERIAL", 100000 * S, 1 * S, "LANDING", "x")
	Company.offer(w, stores, "MATERIAL", 1 * S)   # far under what it is worth to a furniture works
	var fw := Company.create(w, "FURNITURE", "SMALL", HW, "Fw", {"area": "landing"})
	Company.add_plant(w, fw, "SMALL")
	Company.set_price(w, fw, "FURNISHINGS", 1000 * S)
	w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.acct(fw), 10000000 * S, "TEST", 0)
	var need := int(TypeTable.inputs_milli("FURNITURE", "SMALL")["MATERIAL"])
	for m in 4:
		w.month = m
		Making.post_orders(w)
		Market.clear(w)
	check_eq(int(Company.stock_of(w, fw, "MATERIAL")["qty"]), 2 * need, "it holds two months' need, not a month more every month")


func test_the_month_closes_the_books() -> void:
	var w := _w()
	var f := _farm(w, 6, 2)
	Company.book(w, f[0], "rev", 5 * S)
	Rules.month(w)
	check_eq(Company.months_on_books(w, f[0]), 1, "closed into the ring")
	check(Company.books_month(w, f[0]).is_empty(), "a new month opened")
