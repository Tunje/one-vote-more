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


func _homes(w: WorldState) -> void:
	# a landlord asking 100 for a home: the starting salary (2 x the rent, 200) is then above a worker's needs (the
	# rent and a household's food, 198.6), so people apply at once; these tests are about what follows a hire
	Company.set_price(w, Company.create(w, "LANDLORD", "SMALL", HW, "Homes", {"area": "landing"}), "@home", 100 * S)


func _farm(w: WorldState, staff_g: int, staff_s: int) -> Array:
	var id := Company.create(w, "FARM", "SMALL", HW, "F", {"area": "landing"})
	var pid := Company.add_plant(w, id, "SMALL")
	if staff_g > 0:
		Company.staff_change(w, id, pid, "G", "landing|I2|G", staff_g * S, 300 * S, 0)   # trained staff, in place from the start (no training, 9.2)
	if staff_s > 0:
		Company.staff_change(w, id, pid, "S", "landing|I3|S", staff_s * S, 450 * S, 0)
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
	Company.staff_change(w, b, pid, "G", "landing|I2|G", 4 * S, 300 * S, 0)
	Company.staff_change(w, b, pid, "S", "landing|I3|S", 2 * S, 450 * S, 0)
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
	Company.staff_change(w, b, "crew", "G", "landing|I2|G", 12 * S, 300 * S, 0)
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


func test_the_hiring_offer_climbs_five_percent_a_month_a_post_stays_open_and_falls_back_when_filled() -> void:
	# the user, 2026-11-18 (9.2, "How the hiring offer moves"): a new opening is offered the starting salary; it climbs
	# 5% for each month a post could not be filled; the rise is gone once filled; there is no rule for lowering
	var w := _w()
	var f := _crew(w, 9)   # 9 of 12 general posts filled; nobody out of work, no money for adverts: nobody is hired
	var offer := func() -> int: return Company.hiring_salary(w, f[0], "G", "landing")
	var start := Rules.starting_salary(w, "landing", "G")
	Rules.salary_rules(w, f[0])
	check_eq(offer.call(), start, "a new opening is offered the starting salary")
	Rules.staff_to_posts(w, f[0])   # its hiring leaves the three open
	w.month = 1
	Rules.salary_rules(w, f[0])
	check_eq(offer.call(), start * 1050 / 1000, "unfilled a whole month: 5%")
	check_eq(Company.payroll(w, f[0])[0]["pay"], 300 * S, "nobody's pay moved")
	Rules.staff_to_posts(w, f[0])
	w.month = 2
	Rules.salary_rules(w, f[0])
	check_eq(offer.call(), start * 1050 / 1000 * 1050 / 1000, "and 5% again the next month")
	Company.staff_change(w, f[0], f[1], "G", "landing|I2|G", 3 * S, offer.call())   # filled
	Rules.staff_to_posts(w, f[0])
	w.month = 3
	Rules.salary_rules(w, f[0])
	check_eq(offer.call(), start, "filled: the rise is gone")
	Company.staff_change(w, f[0], f[1], "G", "landing|I2|G", -S, 300 * S)   # a new opening
	w.month = 4
	Rules.salary_rules(w, f[0])
	check_eq(offer.call(), start, "a new opening starts from the starting salary: rises do not stack")
	Households.seed_test(w, "landing", "I2", "G", 30)
	Company.staff_change(w, f[0], f[1], "G", "landing|I2|G", S, 300 * S)
	w.month = 5
	Rules.salary_rules(w, f[0])
	check_eq(offer.call(), start, "30 out of work, no post open: there is no rule for lowering")
	check_eq(Logbook.rows(w, {"kind": "SALARY", "who": f[0]}).size(), 3, "two climbs and one fall back, each in the log")


## A small builder with its crew in the landing: every skilled and specialist post filled, `g` of its 12 general.
func _crew(w: WorldState, g: int) -> Array:
	var id := Company.create(w, "BUILDER", "SMALL", HW, "B", {"area": "landing"})
	Company.staff_change(w, id, "crew", "G", "landing|I2|G", g * S, 300 * S, 0)
	Company.staff_change(w, id, "crew", "S", "landing|I3|S", 6 * S, 450 * S, 0)
	Company.staff_change(w, id, "crew", "Sp", "landing|I4|Sp", 2 * S, 675 * S, 0)
	return [id, "crew"]


func test_the_familys_own_posts_are_never_open() -> void:
	var w := _w()
	var f := _crew(w, 11)
	var fam := Households.make_founder(w, Households.seed_test(w, "landing", "I2", "G", 10), "", true)
	Company.family_set(w, f[0], f[1], fam, {"G": 1})   # the family works the twelfth general post
	for m in 3:
		w.month = m
		Rules.salary_rules(w, f[0])
		Rules.staff_to_posts(w, f[0])
	check_eq(Company.hiring_salary(w, f[0], "G", "landing"), Rules.starting_salary(w, "landing", "G"), "no post open: the offer stays at the start")


func test_the_starting_salary_is_twice_the_rent_in_the_area_and_the_placed_get_two_and_a_half() -> void:
	# the user, 2026-11-18 (9.2): "Change the sallery from fod and rent to just rent at 2× we will have to find a better
	# formula for it later", then "3 5x housing try it", then after both trials "2", "Merge with 2"; and for those
	# placed at the landing: "lets set their sallery at 2.5 from start same for builders"
	var w := _w()
	var shelter := TypeTable.start_price_of("LANDLORD") / 2
	var g := shelter * 2000 / 1000
	check_eq(Rules.starting_salary(w, "landing", "G"), g, "no landlord yet: 2 times the landing's shelter")
	check_eq(Rules.starting_salary(w, "landing", "S"), g * 1500 / 1000, "a skilled post 1.5 times")
	check(absi(g - 194 * S) <= S, "194 at the landing (the rent doubled, 2026-11-18)")
	check_eq(Rules.placed_salary(w, "landing", "G"), shelter * 2500 / 1000, "the placed: 2.5 times the landing's shelter")
	check_eq(Rules.placed_salary(w, "landing", "S"), shelter * 2500 / 1000 * 1500 / 1000, "a skilled placed post 1.5 times")
	check(absi(Rules.placed_salary(w, "landing", "G") - 242 * S) <= S, "242 at the landing")
	var l1 := Company.create(w, "LANDLORD", "SMALL", HW, "L1", {"area": "landing"})
	var l2 := Company.create(w, "LANDLORD", "SMALL", HW, "L2", {"area": "landing"})
	Company.set_price(w, l1, "@home", 100 * S)
	Company.set_price(w, l2, "@home", 200 * S)
	check_eq(Rules.starting_salary(w, "landing", "G"), 300 * S, "2 times the average rent the landlords ask; no food in it")
	check_eq(Rules.placed_salary(w, "landing", "G"), 375 * S, "the placed: 2.5 times that average")
	check(Rules.starting_salary(w, "landing", "G") > Rules.needs_line(w, "landing"), "here above a worker's needs: people apply")
	check_eq(Company.hiring_salary(w, Company.create(w, "FARM", "SMALL", HW, "F", {"area": "landing"}), "G", "landing"),
		Rules.starting_salary(w, "landing", "G"), "what a new opening is offered")


func test_a_month_without_hiring_holds_the_offer() -> void:
	var w := _w()
	var f := _crew(w, 9)
	var start := Rules.starting_salary(w, "landing", "G")
	Rules.staff_to_posts(w, f[0])
	w.month = 1
	Rules.salary_rules(w, f[0])
	check_eq(Company.hiring_salary(w, f[0], "G", "landing"), start * 1050 / 1000, "climbed once")
	Company.book(w, f[0], "wages_due", 1000 * S)
	Company.book(w, f[0], "wages", 0)   # it could not pay: 19a, no hiring this month
	Rules.staff_to_posts(w, f[0])
	w.month = 2
	Rules.salary_rules(w, f[0])
	check_eq(Company.hiring_salary(w, f[0], "G", "landing"), start * 1050 / 1000, "after a month it did not hire: held, neither up nor back")


func test_staff_follow_the_posts_and_unpaid_staff_are_laid_off() -> void:
	var w := _w()
	_homes(w)
	Households.seed_test(w, "landing", "I2", "G", 20)
	Households.seed_test(w, "landing", "I3", "S", 5)
	var id := Company.create(w, "BUILDER", "SMALL", HW, "B", {"area": "landing"})
	Rules.staff_to_posts(w, id)
	check_eq(Company.staff_count(w, id) / S, 17, "a small builder's 12 + 6 + 2 posts: 12 general, the 5 skilled there are, no specialist (never a lower skill)")
	Company.set_level(w, id, "crew", 500)
	Rules.staff_to_posts(w, id)
	check_eq(Company.staff_count(w, id) / S, 17, "slack for a month: kept, a layoff costs more (9.2)")
	w.month = 24   # the slack has lasted two years: idle wages now outweigh the layoff pay, the advert and training
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


func test_founding_sees_plans_booked_with_a_builder_and_plans_with_a_grant_not_plans_only_made() -> void:
	var w := _w()
	var stores := Company.create(w, "SHOP", "LARGE", HW, "Stores", {"area": "landing"})
	Company.stock_add(w, stores, "FOOD", 100000 * S, 10 * S, "LANDING", "x")
	Company.offer(w, stores, "FOOD", TypeTable.start_price("FOOD"))
	var acct := "hh:test"
	w.ledger.open_account(acct)
	w.ledger.transfer(Ledger.EXTERNAL, acct, 100000000 * S, "TEST", 0)
	for m in 3:
		w.month = m
		Market.order(w, {"kind": "POOL", "id": "pool", "acct": acct, "area": "landing"}, "FOOD", 1000 * S, 100 * S)
		Market.clear(w)
	var work := Rules.work(w, "FARM", "landing")
	_farm(w, 0, 0)   # one small farm stands: 2 sixths
	# four plans of a small farm (Otto's plan rows, Ella's grant row; as their pieces write them)
	for row in [["plan:1", "MADE"], ["plan:2", "MADE"], ["plan:3", "SIGNED"], ["plan:4", "GIVEN_UP"]]:
		w.table("plan")[row[0]] = {"id": row[0], "type": "FARM", "size": "SMALL", "area": "landing", "status": row[1]}
	w.table("grant")["plan:2"] = {"plan": "plan:2", "status": "PAID"}
	w.table("grant")["plan:4"] = {"plan": "plan:4", "status": "OWED"}
	var f := Rules.founding(w, "FARM", "landing")
	check_eq(int(f["FAMILY"]["work_share"]), work * 1 / 7, "2 standing + 2 booked (plan 3) + 2 granted (plan 2) + its own 1; plan 1 only made, plan 4 given up")
	var row: Dictionary = Logbook.rows(w, {"kind": "RULE"})[-1]
	check_eq([int(row["why"]["standing"]), int(row["why"]["booked"]), int(row["why"]["granted"])], [2, 2, 2], "the founding row names the three")
	var own := Rules.founding(w, "FARM", "landing", false, "plan:2")
	check_eq(int(own["SMALL"]["work_share"]), work * 2 / 6, "plan 2 re-reading before it signs: 2 standing + 2 booked + its own 2, not counted twice")
	w.table("plan")["plan:2"]["status"] = "SIGNED"
	var g := Rules.founding(w, "FARM", "landing", false)
	check_eq(int(g["FAMILY"]["work_share"]), work * 1 / 7, "a granted plan that signs counts once, as booked")


func test_the_needs_line_reads_the_last_food_price_when_food_is_sold_out() -> void:
	var w := _w()
	check_eq(Rules.needs_food(w, "landing"), {"price": TypeTable.start_price("FOOD"), "from": "START"}, "never sold: the starting price")
	var stores := Company.create(w, "SHOP", "LARGE", HW, "Stores", {"area": "landing"})
	Company.stock_add(w, stores, "FOOD", 10 * S, 10 * S, "LANDING", "x")
	Company.offer(w, stores, "FOOD", 200 * S)
	check_eq(Rules.needs_food(w, "landing"), {"price": 200 * S, "from": "OFFER"}, "offered: the cheapest offer")
	var acct := "hh:test"
	w.ledger.open_account(acct)
	w.ledger.transfer(Ledger.EXTERNAL, acct, 100000 * S, "TEST", 0)
	Market.order(w, {"kind": "POOL", "id": "pool", "acct": acct, "area": "landing"}, "FOOD", 20 * S, 300 * S)
	Market.clear(w)
	check_eq(Rules.needs_food(w, "landing"), {"price": 200 * S, "from": "LAST_SOLD"}, "sold out: the last price it sold at, not the starting price")
	check_eq(Rules.needs_line(w, "landing"), TypeTable.start_price_of("LANDLORD") + 200 * S * 2500 / 1000, "and the line uses it")


func test_a_family_works_its_own_posts_unpaid_and_hiring_fills_the_rest() -> void:
	var w := _w()
	check_eq(Company.family_fill({"G": 6, "S": 2, "Sp": 0}, {"G": 1, "S": 0, "Sp": 1}), {"G": 1, "S": 1, "Sp": 0},
		"each tier from the adults of that skill or above: the specialist takes a skilled post")
	_homes(w)
	var f := _farm(w, 0, 0)   # a small farm, nobody hired
	var alone := Making.make_plant(w, f[0], f[1])
	check(Company.family_set(w, f[0], f[1], "founder:x", {"G": 1, "S": 1}), "the family in its posts")
	check_eq(Company.family_of(w, f[0]), "founder:x", "whose family it is")
	check_eq(Company.family_count(w, f[0]), 2 * S, "two of the family work")
	check(alone == 0 and Making.make_plant(w, f[0], f[1]) > 0, "the family's work counts in making")
	# a real household (Maja's founder with family), on a builder's crew (its posts stand where it does)
	var pool := Households.seed_test(w, "landing", "I2", "G", 40)
	Households.seed_test(w, "landing", "I3", "S", 5)
	var fam := Households.make_founder(w, pool, "", true)
	var adults: Dictionary = Households.family_adults(w, fam)
	var n_ad := int(adults["G"]) + int(adults["S"]) + int(adults["Sp"])
	check(n_ad >= 1, "the household has %d adults" % n_ad)
	var b := Company.create(w, "BUILDER", "SMALL", HW, "B", {"area": "landing"})
	Company.family_set(w, b, "crew", fam, {})
	Rules.staff_to_posts(w, b)
	check_eq(Company.family_count(w, b) / S, n_ad, "every adult of the family works a post")
	var fw: Dictionary = Households.family_working(w, fam)
	check_eq(int(fw["G"]) + int(fw["S"]) + int(fw["Sp"]), n_ad, "and the households' side has them employed")
	check_eq((Company.staff_count(w, b) + Company.family_count(w, b)) / S, 17, "hired only for the posts the family leaves (12 + 5 of 6 skilled there are)")
	check_eq(Company.wage_bill(w, b), Company.staff_count(w, b, "G") / S * Rules.starting_salary(w, "landing", "G")
		+ Company.staff_count(w, b, "S") / S * Rules.starting_salary(w, "landing", "S"), "the family is on no payroll")
	check(Households.check(w).is_empty(), "jobs = people still holds: %s" % str(Households.check(w)))
	Company.book(w, b, "wages_due", 1000 * S)
	Company.book(w, b, "wages", 0)
	Rules.staff_to_posts(w, b)   # 19a: it could pay none of its hired staff
	check_eq(Company.staff_count(w, b), 0, "19a lays off every hired worker it could not pay")
	check_eq(Company.family_count(w, b) / S, n_ad, "but never the family")


func test_the_family_takes_the_winnings_above_a_month_of_what_it_does_not_do() -> void:
	var w := _w()
	var f := _farm(w, 2, 0)
	var fam := Households.make_founder(w, Households.seed_test(w, "landing", "I2", "G", 10), "", true)
	Company.family_set(w, f[0], f[1], fam, {"G": 1})
	w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.acct(f[0]), 5000 * S, "TEST", 0)   # the founder's opening money
	check_eq(int(Rules.winnings(w, f[0])["amount"]), 0, "opening money is capital, not winnings: nothing earned yet")
	Company.book(w, f[0], "rev", 2000 * S)
	Company.book(w, f[0], "inputs", 400 * S)
	Company.book(w, f[0], "wages", 600 * S)
	Company.book(w, f[0], "upkeep", 100 * S)
	var wn := Rules.winnings(w, f[0])
	check_eq(int(wn["earned"]), 2000 * S - 400 * S - 600 * S - 100 * S, "the month's takings less what it paid")
	check_eq(int(wn["keep"]), 2 * 300 * S + 400 * S + 100 * S, "it keeps back the hired wages, inputs and upkeep")
	check_eq(int(wn["amount"]), int(wn["earned"]), "the family takes what the month earned")
	Rules.pay_winnings(w)
	check_eq(w.ledger.balance(CoreUtil.acct(f[0])), 5000 * S - int(wn["amount"]), "paid out; the capital stays")
	check_eq(int(Company.books_month(w, f[0])["winnings"]), int(wn["amount"]), "booked")
	var rows := Logbook.rows(w, {"kind": "WINNINGS"}).size()
	Rules.pay_winnings(w)
	check_eq(Logbook.rows(w, {"kind": "WINNINGS"}).size(), rows, "once a month")
	check_eq(int(Households.founder_income(w, fam)["winnings"]), int(wn["amount"]), "the household's income")


func test_a_loss_is_made_good_before_the_family_takes_winnings() -> void:
	var w := _w()
	var f := _farm(w, 0, 0)
	var fam := Households.make_founder(w, Households.seed_test(w, "landing", "I2", "G", 10), "", true)
	Company.family_set(w, f[0], f[1], fam, {"G": 1})
	w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.acct(f[0]), 5000 * S, "TEST", 0)
	Company.book(w, f[0], "upkeep", 300 * S)   # a bad month: nothing sold
	Rules.pay_winnings(w)
	var r: Dictionary = Logbook.rows(w, {"kind": "WINNINGS"})[-1]
	check_eq([r["what"], int(r["why"]["loss_carried_after"])], ["no winnings this month", 300], "it lost 300: carried")
	Company.close_month(w, f[0])
	w.month = 1
	Company.book(w, f[0], "rev", 200 * S)   # earns 200: pays the loss down to 100, nothing for the family
	Rules.pay_winnings(w)
	r = Logbook.rows(w, {"kind": "WINNINGS"})[-1]
	check_eq([int(r["change"]["winnings"][1]), int(r["why"]["pays_down"]), int(r["why"]["loss_carried_after"])], [0, 200, 100], "first the loss")
	Company.close_month(w, f[0])
	w.month = 2
	Company.book(w, f[0], "rev", 500 * S)   # earns 500: 100 makes the loss good, 400 is the family's
	Rules.pay_winnings(w)
	r = Logbook.rows(w, {"kind": "WINNINGS"})[-1]
	check_eq([int(r["change"]["winnings"][1]), int(r["why"]["loss_carried"]), int(r["why"]["loss_carried_after"])], [400, 100, 0], "then the family")


func test_a_new_hire_makes_half_rising_evenly_to_full_after_six_months() -> void:
	var w := _w()
	check_eq([Company.trained_pm(0), Company.trained_pm(3), Company.trained_pm(5), Company.trained_pm(6)], [500, 750, 916, 1000], "half, rising evenly, full after six")
	var id := Company.create(w, "FARM", "SMALL", HW, "F", {"area": "landing"})
	var pid := Company.add_plant(w, id, "SMALL")
	Company.staff_change(w, id, pid, "G", "landing|I2|G", 4 * S, 300 * S, 0)   # four trained
	Company.staff_change(w, id, pid, "G", "landing|I2|G", 2 * S, 300 * S)      # two hired now
	check_eq(Company.trained_count(w, id), 4 * S + 2 * S / 2, "the two new count as one")
	w.month = 3
	check_eq(Company.trained_count(w, id), 4 * S + 2 * S * 750 / 1000, "three months on")
	Company.staff_change(w, id, pid, "G", "landing|I2|G", -3 * S)   # no row named: the rows in order, the longest here first
	check_eq(Company.trained_count(w, id), S + 2 * S * 750 / 1000, "three of the trained row leave; the trainees keep their months")
	w.month = 6
	check_eq(Company.trained_count(w, id), 3 * S, "all trained after six months")


func test_a_company_keeps_slack_staff_until_idle_wages_outweigh_what_a_layoff_costs() -> void:
	var w := _w()
	_homes(w)
	Households.seed_test(w, "landing", "I2", "G", 40)
	var b := Company.create(w, "BUILDER", "SMALL", HW, "B", {"area": "landing"})
	w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.acct(b), 1000000 * S, "TEST", 0)
	Rules.staff_to_posts(w, b)
	var g0 := Company.staff_count(w, b, "G")
	check_eq(g0, 12 * S, "twelve general posts filled")
	Company.set_level(w, b, "crew", 500)   # half the posts
	var months := 0
	while Company.staff_count(w, b, "G") == g0 and months < 24:
		Rules.staff_to_posts(w, b)
		months += 1
		w.month += 1
	var wg := Rules.layoff_weighing(w, b, "crew", "G", 1)
	check(months > int(wg["layoff_months"]), "it kept them %d months: longer than the %d months of layoff pay" % [months, int(wg["layoff_months"])])
	check(Company.staff_count(w, b, "G") < g0, "then laid them off")
	check(not bool(wg["lay_off"]), "one month idle does not outweigh the cost")
	check_eq(Logbook.rows(w, {"kind": "RULE", "what": "keeps its slack staff: a layoff costs more than their wages while idle"}).size() >= 3, true, "each month it kept them is logged with what it weighed")


func test_hiring_pays_its_job_adverts_and_waits_if_it_cannot() -> void:
	var w := _w()
	_homes(w)
	var Media: GDScript = load("res://sim/media/media_ops.gd")
	var a: String = Media.call("found_outlet", w, {"kind": "COMPANY", "id": "org:1"}, {"quality": 100})["out_id"]
	Media.call("state", w)["circ"] = {a: {"landing": 300}}
	Households.seed_test(w, "landing", "I2", "G", 40)
	var poor := Company.create(w, "BUILDER", "SMALL", HW, "Poor", {"area": "landing"})
	Rules.staff_to_posts(w, poor)
	check_eq(Company.staff_count(w, poor, "G"), 0, "it cannot pay a single advert: nobody hired this month")
	var one := int(Media.call("job_advert_cost", w, "landing", Company.hiring_salary(w, poor, "G", "landing"), 1))
	w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.acct(poor), 3 * one, "TEST", 0)
	Rules.staff_to_posts(w, poor)
	check_eq(Company.staff_count(w, poor) / S, 3, "money for three adverts: it hires three, not none")
	var b := Company.create(w, "BUILDER", "SMALL", HW, "B", {"area": "landing"})
	w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.acct(b), 100000 * S, "TEST", 0)
	var before := w.ledger.balance(CoreUtil.acct(b))
	Rules.staff_to_posts(w, b)
	var hired := Company.staff_count(w, b) / S
	check(hired > 0, "it can: it hires")
	check(int(Company.books_month(w, b).get("adverts", 0)) > 0, "and pays the papers for them, booked as adverts")
	check_eq(before - w.ledger.balance(CoreUtil.acct(b)), int(Company.books_month(w, b)["adverts"]), "only the adverts left its account")


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


func test_a_farm_family_takes_its_food_from_its_own_farm_before_any_is_offered() -> void:
	# the user, 2026-11-18 (12.3 15e): "the farmers themselves I RULED EATS THEMSELVES FIRST, THEY ARE THREE THEY CAN
	# PRODUVE 30 ... THEY WOULD TAKE SIX OUT OF THIRTY SELL 24 AND THAT SHOULD BE ENOUGH TO HIRE ONE PERSON"
	var w := _w()
	var f := _farm(w, 0, 0)
	var fam := Households.make_founder(w, Households.seed_test(w, "landing", "I2", "G", 10), "", true)
	Company.family_set(w, f[0], f[1], fam, {"G": 3})
	Company.set_price(w, f[0], "FOOD", 40 * S)
	Company.stock_add(w, f[0], "FOOD", 30 * S, 20 * S, "OUTPUT", "harvest")
	check_eq(Making.family_take(w, f[0], "FOOD", 6 * S), 6 * S, "they take six out of thirty")
	check_eq(Company.stock_of(w, f[0], "FOOD"), {"qty": 24 * S, "value": 24 * 20 * S, "waiting": 0, "ship": 0}, "24 left, at its book value")
	var offered := 0
	for off in Market.offers(w, "FOOD", "landing"):
		if String(off["seller"]) == f[0]:
			offered += int(off["qty"])
	check_eq(offered, 24 * S, "and 24 offered for sale: the take is never offered, so rules 3 and 4 never see it")
	check_eq(int(Company.books_month(w, f[0]).get("took:FOOD", 0)), 6 * S, "booked as taken, not sold")
	check_eq(w.ledger.balance(CoreUtil.acct(f[0])), 0, "no money: it is their own farm")
	var row: Dictionary = Logbook.rows(w, {"kind": "TAKE", "who": f[0]})[-1]
	check_eq([String(row["why"]["family"]), int(row["why"]["want"]), int(row["change"]["FOOD"][1])], [fam, 6 * S, 24 * S], "one TAKE row")
	check_eq(Making.family_take(w, f[0], "FOOD", 30 * S), 24 * S, "never more than the farm holds")
	check_eq(Making.family_take(w, f[0], "FOOD", 6 * S), 0, "nothing held: nothing taken")
	var g := _farm(w, 2, 0)
	Company.stock_add(w, g[0], "FOOD", 30 * S, 20 * S, "OUTPUT", "harvest")
	check_eq(Making.family_take(w, g[0], "FOOD", 6 * S), 0, "a farm with no family: nobody takes")
