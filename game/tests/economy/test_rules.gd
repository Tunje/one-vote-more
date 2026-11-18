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
	# k is the user's 5% (section 3, 2026-11-18: "TWENTY PERCENT WHAT HAPPENS TO THE FUCKING 5% CAP"; rule 9: "if your
	# going to cap it at 5% THEN DO THE SAME FOR BOTH")
	var w := _w()
	var f := _farm(w, 6, 2)
	Company.set_price(w, f[0], "FOOD", 60 * S)
	var up := Rules.price_rule(w, f[0], "FOOD", {"offered": 10 * S, "sold": 10 * S, "unmet_above": 20 * S, "refused": 0}, 0)
	check_eq(up, 60 * S * (1000 + 50 * 20 / 30) / 1000, "sold out with 20 wanted beyond 10 sold: up by 5% × 2/3")
	Company.set_price(w, f[0], "FOOD", 60 * S)
	var down := Rules.price_rule(w, f[0], "FOOD", {"offered": 40 * S, "sold": 10 * S, "unmet_above": 0, "refused": 0}, 0)
	check_eq(down, 60 * S * (1000 - 50 * 30 / 40) / 1000, "30 unsold of 40: down by 5% × 3/4")
	Company.set_price(w, f[0], "FOOD", 60 * S)
	check_eq(Rules.price_rule(w, f[0], "FOOD", {"offered": 10 * S, "sold": 0, "unmet_above": 0, "refused": 0}, 0), 57 * S, "sold nothing: the full 5% down")
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
	# g is the user's 5% (section 3, 2026-11-18: "25?! 5!!! CHANGE IT!!! STOP HEDGING")
	Company.set_level(w, f[0], f[1], 800)
	Rules.output_rule(w, f[0], {"offered": 10 * S, "sold": 10 * S, "unmet_above": 10 * S, "refused": 0}, false)
	check_eq(Company.level_of(w, f[0], f[1]), 840, "sold out: up by the whole 5% (rule 3, the user: \"if you sell out all your producing produce MORE\")")
	Company.set_level(w, f[0], f[1], 990)
	Rules.output_rule(w, f[0], {"offered": 10 * S, "sold": 10 * S, "unmet_above": 100 * S, "refused": 0}, false)
	check_eq(Company.level_of(w, f[0], f[1]), 1000, "never above full")
	Rules.output_rule(w, f[0], {"offered": 10 * S, "sold": 10 * S, "unmet_above": 100 * S, "refused": 0}, false)
	_three_months(w, f[0], {"offered": 40 * S, "sold": 10 * S, "unmet_above": 0, "refused": 0})
	check_eq(Company.level_of(w, f[0], f[1]), 950, "three months 3/4 unsold: down by the whole 5%")
	var lv := Company.level_of(w, f[0], f[1])
	Rules.output_rule(w, f[0], {"offered": 10 * S, "sold": 10 * S, "unmet_above": 10 * S, "refused": 0}, true)
	check_eq(Company.level_of(w, f[0], f[1]), lv, "rule 3 does not act while it holds stock back (12.3, 18)")


func test_a_level_walked_down_to_nothing_climbs_back_when_asked() -> void:
	var w := _w()
	var f := _farm(w, 6, 2)
	Company.set_level(w, f[0], f[1], 0)
	Rules.output_rule(w, f[0], {"offered": 0, "sold": 0, "unmet_above": 30 * S, "refused": 0}, false)
	check_eq(Company.level_of(w, f[0], f[1]), 1, "from 0 it rises by one per mille, the smallest step there is: it never sticks at 0")


func test_builders_run_the_same_rules_on_their_crew_and_their_making_price() -> void:
	var w := _w()
	var b := Company.create(w, "BUILDER", "SMALL", HW, "B", {"area": "landing"})
	Company.staff_change(w, b, "crew", "G", "landing|I2|G", 12 * S, 300 * S, 0)
	Company.book(w, b, "wages_due", 3600 * S)
	check_eq(Making.making_price(w, b), 3600 * S * S / TypeTable.output_milli("BUILDER", "SMALL"), "a builder's making price over its crew's full output")
	_three_months(w, b, {"offered": 30 * S, "sold": 10 * S, "unmet_above": 0, "refused": 0})
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


func test_each_opening_climbs_five_percent_a_month_on_its_own_count_and_a_new_one_starts_at_the_start() -> void:
	# the user, 2026-11-18 (9.2): "increases should not stack for seperate offers, infact they should fall back to the
	# original rule for settin on hire, then it should only climb max 5% if it cost not hire for one month"; "5% each
	# month, it goes i never said i wanted the rule for lowering". Built per opening (the audit of 2026-11-18).
	var w := _w()
	var f := _crew(w, 9)   # 9 of 12 general posts filled; nobody out of work, no money for adverts: nobody is hired
	var offers := func() -> Array: return Company.opening_offers(w, f[0], "crew", "G")
	var start := Rules.starting_salary(w, "landing", "G")
	var up1 := start * 1050 / 1000
	var up2 := up1 * 1050 / 1000
	Rules.salary_rules(w, f[0])
	check_eq(offers.call(), [start, start, start], "three new openings, each at the starting salary")
	Rules.staff_to_posts(w, f[0])   # its hiring leaves the three open
	w.month = 1
	Rules.salary_rules(w, f[0])
	check_eq(offers.call(), [up1, up1, up1], "each unfilled a whole month: 5% on its own count")
	check_eq(Company.payroll(w, f[0])[0]["pay"], 300 * S, "nobody's pay moved")
	Rules.staff_to_posts(w, f[0])
	w.month = 2
	Rules.salary_rules(w, f[0])
	check_eq(offers.call(), [up2, up2, up2], "and 5% again the next month")
	# one of them is filled at its offer: it is gone, with its climb
	Company.staff_change(w, f[0], f[1], "G", "landing|I2|G", S, up2)
	Company.fill_openings(w, f[0], "crew|G", 2, 1)
	# and one more post opens beside the two climbed ones
	Company.staff_change(w, f[0], f[1], "G", "landing|I2|G", -S, 300 * S)
	check_eq(offers.call(), [up2, up2, start], "the new opening beside them is offered the starting salary: rises do not stack")
	Rules.staff_to_posts(w, f[0])
	w.month = 3
	Rules.salary_rules(w, f[0])
	check_eq(offers.call(), [up2 * 1050 / 1000, up2 * 1050 / 1000, up1], "each climbs on its own count")
	Company.staff_change(w, f[0], f[1], "G", "landing|I2|G", 3 * S, start)   # all filled
	Rules.staff_to_posts(w, f[0])
	w.month = 4
	Rules.salary_rules(w, f[0])
	check_eq(offers.call(), [], "none open: no offer left standing")
	Company.staff_change(w, f[0], f[1], "G", "landing|I2|G", -S, 300 * S)
	w.month = 5
	Rules.salary_rules(w, f[0])
	check_eq(offers.call(), [start], "a later opening starts from the starting salary again")
	Households.seed_test(w, "landing", "I2", "G", 30)
	Company.staff_change(w, f[0], f[1], "G", "landing|I2|G", S, 300 * S)
	w.month = 6
	Rules.salary_rules(w, f[0])
	check_eq(offers.call(), [], "30 out of work, no post open: there is no rule for lowering")
	check_eq(Logbook.rows(w, {"kind": "SALARY", "who": f[0], "what": "openings climbed"}).size(), 3, "each month's climb in the log")


func test_the_dearest_opening_is_filled_first_and_the_newest_closes_first() -> void:
	# Maja's readings (a) and (b), with Wilma's yes (9.2)
	var w := _w()
	var f := _crew(w, 10)   # two open
	Rules.salary_rules(w, f[0])
	Rules.staff_to_posts(w, f[0])
	w.month = 1
	Rules.salary_rules(w, f[0])   # both climbed once
	Company.staff_change(w, f[0], f[1], "G", "landing|I2|G", -S, 300 * S)   # a third opens
	Rules.staff_to_posts(w, f[0])
	check_eq(Company.openings(w, f[0], "crew|G"), [1, 1, 0], "two climbed, one new")
	Company.staff_change(w, f[0], f[1], "G", "landing|I2|G", S, 300 * S)   # one fewer open
	Rules.staff_to_posts(w, f[0])
	check_eq(Company.openings(w, f[0], "crew|G"), [1, 1], "the newest closed first")


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
	check_eq(Company.opening_offers(w, f[0], "crew", "G"), [], "no post open: no opening")


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
	Rules.salary_rules(w, f[0])
	Rules.staff_to_posts(w, f[0])
	w.month = 1
	Rules.salary_rules(w, f[0])
	check_eq(Company.opening_offers(w, f[0], "crew", "G")[0], start * 1050 / 1000, "climbed once")
	Company.book(w, f[0], "wages_due", 1000 * S)
	Company.book(w, f[0], "wages", 0)   # it could not pay: 19a, no hiring this month
	Rules.staff_to_posts(w, f[0])
	w.month = 2
	Rules.salary_rules(w, f[0])
	check_eq(Company.opening_offers(w, f[0], "crew", "G")[0], start * 1050 / 1000, "after a month it did not hire: held (Maja's reading (c))")


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
	for m in Rules.WORK_MONTHS:   # a full year of orders
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
	for m in Rules.WORK_MONTHS:   # a full year of orders
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


func test_the_family_takes_half_of_what_the_month_earned_while_the_buffer_is_building() -> void:
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
	check(5000 * S < 6 * Rules.running_cost(w, "FARM", "SMALL", "landing"), "the account is below six months of running cost")
	check_eq(int(wn["keep_pm"]), 500, "so the farm keeps 50% (the user: \"50% until it had 6 months worth built up\")")
	check_eq(int(wn["amount"]), int(wn["earned"]) - int(wn["earned"]) * 500 / 1000, "the family takes the other half")
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
	Company.book(w, f[0], "rev", 500 * S)   # earns 500: 100 makes the loss good; of the 400 left the farm keeps half (buffer)
	Rules.pay_winnings(w)
	r = Logbook.rows(w, {"kind": "WINNINGS"})[-1]
	check_eq([int(r["change"]["winnings"][1]), int(r["why"]["loss_carried"]), int(r["why"]["loss_carried_after"])], [200, 100, 0], "then the family, after the buffer's half")


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
	# money for the specialist and skilled posts' adverts (opened first) and three general ones (9.2, the user,
	# 2026-11-18: an advert is paid when the post opens)
	var ad1 := func(t: String) -> int: return int(Media.call("job_advert_cost", w, "landing", Company.hiring_salary(w, poor, t, "landing"), 1))
	var posts := TypeTable.posts("BUILDER", "SMALL")
	w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.acct(poor), int(posts["Sp"]) * ad1.call("Sp") + int(posts["S"]) * ad1.call("S")
		+ 3 * ad1.call("G"), "TEST", 0)
	Rules.staff_to_posts(w, poor)
	check_eq(Company.staff_count(w, poor, "G") / S, 3, "money for three general adverts: it hires three, not none")
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


func test_a_family_farm_that_sells_pays_its_family_winnings_in_the_real_month_order() -> void:
	# 15e, the user: "The owners of a family farm should take winnings no sallery, wich comes after and saves the issue".
	# A whole game month (Wilma's fault: the rules close the month's books before JUSTICE pays the winnings, so they
	# read an empty month and no family was ever paid).
	var sim := GameSim.make(1)
	var w := sim.world
	var land := AreaStore.found_landing(w)
	var pid := Households.pool_id(land, "I2")
	var fam := Households.make_founder(w, pid, "", true)
	var cid := Company.create(w, "FARM", "FAMILY", HW, "Family Farm", {"area": land})
	Company.family_set(w, cid, "crew", fam, {})
	Company.set_price(w, cid, "FOOD", 1 * S)   # the cheapest food at the landing: it sells
	Company.stock_add(w, cid, "FOOD", 500 * S, 1 * S, "OUTPUT", "harvest")
	sim.step()
	var m := w.month - 1
	var rev := 0
	for r in Logbook.rows(w, {"kind": "SALE", "who": cid, "from": m, "to": m}):
		rev += int(r["change"]["paid"][1])
	check(rev > 0, "the farm sold food this month: %d" % rev)
	var rows: Array = Logbook.rows(w, {"kind": "WINNINGS", "who": cid, "from": m, "to": m})
	check_eq(rows.size(), 1, "one WINNINGS row")
	check_eq(int(rows[-1]["why"]["earned"]), rev / S, "what it earned is the month just lived: its sales, no wages, no inputs")
	check_eq(int(rows[-1]["change"]["winnings"][1]), rev / S - rev / S * 500 / 1000, "half to the family: the farm keeps 50% while it builds its buffer (15e)")
	var paid: Array = Logbook.rows(w, {"kind": "PAY", "who": CoreUtil.acct(cid), "from": m, "to": m}).filter(func(r): return String(r["what"]) == "winnings")
	var half := rev - rev * 500 / 1000
	check_eq(int(paid[-1]["change"]["paid"][1]) if not paid.is_empty() else 0, half, "paid into the family's account")
	check_eq(w.ledger.balance(CoreUtil.acct(cid)), rev - half, "the other half stays in the farm: its buffer")
	check_eq(int(Company.books_closed(w, cid, m).get("winnings", 0)), half, "booked in the month it was earned")
	check_eq(int(Company.books_month(w, cid).get("winnings", 0)), 0, "not in the month to come")


func _family_farm(w: WorldState, work: Dictionary) -> Array:
	var id := Company.create(w, "FARM", "FAMILY", HW, "FF", {"area": "landing"})
	var pid := Company.add_plant(w, id, "FAMILY")
	var fam := Households.make_founder(w, Households.seed_test(w, "landing", "I2", "G", 10), "", true)
	Company.family_set(w, id, pid, fam, work)
	return [id, pid]


func test_a_family_farm_makes_in_proportion_to_its_level_however_low() -> void:
	# Wilma's fault, the user: "NO ROUNDING ERRORS ARE NOT THINGS YOU BRING TO ME YOU FIX THEM": the posts wanted at a
	# level were rounded down, so under level 250 a family farm wanted no posts and made nothing with its family on it
	var w := _w()
	var f := _family_farm(w, {"G": 1, "S": 1})   # two of the family on its four posts
	var full := TypeTable.output_milli("FARM", "FAMILY")
	for lv in [100, 234, 250, 313]:
		Company.set_level(w, f[0], f[1], lv)
		check_eq(Making.make_plant(w, f[0], f[1]), full * lv / 1000, "level %d: the family makes the level's share" % lv)


func test_one_of_the_family_does_a_quarter_of_a_family_farms_work_company_16() -> void:
	# the traced case, seed 1, company:16: its family works the S post alone. Month 33 at level 313 it made 11.5 (one
	# person counted as the whole 1.25 posts' work); month 35 at level 234 it made nothing (0.94 posts rounded to none)
	var w := _w()
	var f := _family_farm(w, {"S": 1})
	var full := TypeTable.output_milli("FARM", "FAMILY")   # 37.6
	Company.set_level(w, f[0], f[1], 234)
	check_eq(Making.make_plant(w, f[0], f[1]), full * 234 / 1000, "level 234: one person covers the 0.94 posts' work: 8.8")
	Company.set_level(w, f[0], f[1], 313)
	check_eq(Making.make_plant(w, f[0], f[1]), full * 313 / 1000 * (1000 * S / (4 * S * 313 / 1000)) / 1000,
		"level 313: one person of the 1.25 posts' work makes a quarter of the farm's full: 9.4")
	check_eq(Company.posts_wanted(w, f[0], f[1]), {"G": 2, "S": 0, "Sp": 0}, "1.25 posts' work needs two persons")
	Company.set_level(w, f[0], f[1], 234)
	check_eq(Company.posts_wanted(w, f[0], f[1]), {"G": 1, "S": 0, "Sp": 0}, "0.94 posts' work needs one: rounded up, never to none")


func test_the_posts_wanted_are_the_persons_the_levels_work_needs() -> void:
	var w := _w()
	var f := _farm(w, 0, 0)   # a small farm: 6 general, 2 skilled
	for c in [[0, {"G": 0, "S": 0, "Sp": 0}], [100, {"G": 1, "S": 0, "Sp": 0}], [500, {"G": 3, "S": 1, "Sp": 0}], [560, {"G": 4, "S": 1, "Sp": 0}], [1000, {"G": 6, "S": 2, "Sp": 0}]]:
		Company.set_level(w, f[0], f[1], int(c[0]))
		check_eq(Company.posts_wanted(w, f[0], f[1]), c[1], "level %d" % int(c[0]))
	Company.set_level(w, f[0], f[1], 100)
	check_eq(Company.vacancies(w, "landing").filter(func(v): return String(v["cid"]) == f[0]).size(), 1, "at level 100 one post is open to apply for, not none")


func test_a_price_never_moves_more_than_five_percent_in_a_month_up_or_down() -> void:
	var w := _w()
	var f := _farm(w, 6, 2)
	Company.set_price(w, f[0], "FOOD", 100 * S)
	check_eq(Rules.price_rule(w, f[0], "FOOD", {"offered": 1000 * S, "sold": 0, "unmet_above": 0, "refused": 0}, 0), 95 * S, "nothing sold of a mountain: 5% down")
	Company.set_price(w, f[0], "FOOD", 100 * S)
	check_eq(Rules.price_rule(w, f[0], "FOOD", {"offered": 0, "sold": 0, "unmet_above": 1000 * S, "refused": 0}, 0), 105 * S, "everything wanted, nothing to sell: 5% up")
	Company.set_price(w, f[0], "FOOD", 100 * S)
	check(Rules.price_rule(w, f[0], "FOOD", {"offered": 1001 * S, "sold": 1 * S, "unmet_above": 0, "refused": 0}, 0) >= 95 * S, "a huge glut: never past 5%")
	var b := Company.create(w, "BUILDER", "SMALL", HW, "B", {"area": "landing"})
	Company.set_price(w, b, "BW", 400 * S)
	check_eq(Rules.price_rule(w, b, "BW", {"offered": 10 * S, "sold": 0, "unmet_above": 0, "refused": 0}, 0), 380 * S, "a builder's BW price the same: 5%")


func test_an_output_level_never_moves_more_than_five_percent_in_a_month_up_or_down() -> void:
	var w := _w()
	var f := _farm(w, 6, 2)
	Company.set_level(w, f[0], f[1], 600)
	Rules.output_rule(w, f[0], {"offered": 0, "sold": 0, "unmet_above": 1000 * S, "refused": 0}, false)
	check_eq(Company.level_of(w, f[0], f[1]), 630, "everything wanted, nothing to sell: 5% up")
	Company.set_level(w, f[0], f[1], 600)
	_three_months(w, f[0], {"offered": 1000 * S, "sold": 0, "unmet_above": 0, "refused": 0})
	check_eq(Company.level_of(w, f[0], f[1]), 570, "nothing sold of a mountain: 5% down")
	var b := Company.create(w, "BUILDER", "SMALL", HW, "B", {"area": "landing"})
	Company.set_level(w, b, "crew", 600)
	_three_months(w, b, {"offered": 1000 * S, "sold": 0, "unmet_above": 0, "refused": 0})
	check_eq(Company.level_of(w, b, "crew"), 570, "a builder's crew the same: 5%")


func _large_farm(w: WorldState) -> String:
	var id := Company.create(w, "FARM", "LARGE", HW, "L", {"area": "landing"})
	Company.add_plant(w, id, "LARGE")
	return id


func test_rule_8_no_plan_while_the_plants_seen_can_make_the_work_in_food() -> void:
	# rule 8, the user: do not start one when "the same signal says the work is covered": the FOOD ordered a month
	# against the full output a month of every plant a founder sees (standing, booked, granted); quantity, not money
	var w := _w()
	var stores := Company.create(w, "SHOP", "LARGE", HW, "Stores", {"area": "landing"})
	Company.stock_add(w, stores, "FOOD", 100000 * S, 10 * S, "LANDING", "x")
	Company.offer(w, stores, "FOOD", TypeTable.start_price("FOOD"))
	var acct := "hh:test"
	w.ledger.open_account(acct)
	w.ledger.transfer(Ledger.EXTERNAL, acct, 100000000 * S, "TEST", 0)
	for m in Rules.WORK_MONTHS:   # a full year of orders
		w.month = m
		Market.order(w, {"kind": "POOL", "id": "pool", "acct": acct, "area": "landing"}, "FOOD", 1000 * S, 100 * S)
		Market.clear(w)
	check_eq(Rules.work_qty(w, "FARM", "landing"), 1000 * S, "the work: 1,000 FOOD a month")
	for i in 4:
		_large_farm(w)   # 4 x 240 = 960 a month: not covered
	var f := Rules.founding(w, "FARM", "landing")
	check(bool(f["FAMILY"]["covers"]), "960 of 1,000 made: not covered, rule 7 sizes as before")
	var row: Dictionary = Logbook.rows(w, {"kind": "RULE"})[-1]
	check_eq([int(row["why"]["work_qty"]), int(row["why"]["capacity"]), bool(row["why"]["covered"])], [1000 * S, 960 * S, false], "the row says what it compared")
	w.table("plan")["plan:1"] = {"id": "plan:1", "type": "FARM", "size": "SMALL", "area": "landing", "status": "SIGNED"}
	var g := Rules.founding(w, "FARM", "landing")
	for size in TypeTable.SIZES:
		check(not bool(g[size]["covers"]), "960 standing + a booked small farm's 76.8: covered, no plan of any size (%s)" % size)
	w.month = Rules.WORK_MONTHS
	for i in 3:
		Market.order(w, {"kind": "POOL", "id": "pool", "acct": acct, "area": "landing"}, "FOOD", 1000 * S, 1000 * S)
	Market.clear(w)
	w.table("plan")["plan:1"]["status"] = "GIVEN_UP"
	Company.set_price(w, stores, "FOOD", 200 * TypeTable.start_price("FOOD") / 100)
	var before := int(Rules.work(w, "FARM", "landing"))
	check(bool(Rules.founding(w, "FARM", "landing")["FAMILY"]["covers"]), "the price doubled and the work is 1,167 a month over the last twelve: still in food, not covered")
	check(before > 0, "money work is still there for rule 7's sizing: %d" % before)


func test_rule_8_in_a_new_game_no_farm_is_planned_while_the_farms_standing_cover_the_work() -> void:
	var sim := GameSim.make(1)
	var w := sim.world
	var land := AreaStore.found_landing(w)
	for i in 5:
		var id := Company.create(w, "FARM", "LARGE", HW, "Farm %d" % i, {"area": land})
		var pid := Company.add_plant(w, id, "LARGE")
		# each fully staffed (trained, in place), so it makes its 240 this month: what it brings to the market is what
		# rule 8 counts, 5 x 240 = 1,200 against month 0's work of (2,000 + 11 x 1,000) / 12
		for tier in ["G", "S", "Sp"]:
			var n := int(TypeTable.posts("FARM", "LARGE")[tier])
			if n > 0:
				Company.staff_change(w, id, pid, tier, "%s|I2|%s" % [land, tier], n * S, 300 * S, 0)
	var plans := w.table("plan").size()
	sim.step()
	check_eq(w.table("plan").size(), plans, "no farm plan made: the work is covered")
	var rows: Array = Logbook.rows(w, {"kind": "RULE", "who": "FARM", "from": w.month - 1, "to": w.month - 1})
	check(not rows.is_empty() and bool(rows[-1]["why"]["covered"]), "rule 8 said covered: %s" % (str(rows[-1]["why"]) if not rows.is_empty() else "no row"))
	var sim2 := GameSim.make(1)
	sim2.step()
	check(sim2.world.table("plan").size() > 0, "the same game without those farms plans farms (%d)" % sim2.world.table("plan").size())


func test_a_family_on_the_skilled_post_is_not_doubled_by_a_stranger_on_a_general_one() -> void:
	# Otto's review of the rounding fix (15e: hire for what the family leaves): the family counts against the persons
	# the level's work needs whatever post it stands on
	var w := _w()
	_homes(w)
	Households.seed_test(w, "landing", "I2", "G", 10)
	var f := _family_farm(w, {"S": 1})
	w.table(Households.PERSON_TABLE)[Company.family_of(w, f[0])]["family"]["adults"] = [{"skill": "S"}]   # company:16: one skilled adult
	w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.acct(f[0]), 100000 * S, "TEST", 0)
	var mine := func() -> Array: return Company.vacancies(w, "landing").filter(func(v): return String(v["cid"]) == f[0]).map(func(v): return [String(v["tier"]), int(v["open"])])
	Company.set_level(w, f[0], f[1], 234)
	check_eq(Company.hire_wanted(w, f[0], f[1]), {"G": 0, "S": 0, "Sp": 0}, "0.94 posts' work: the family member does it all")
	check_eq(mine.call(), [], "no post open")
	var asked := func() -> Array: return Logbook.rows(w, {"kind": "HIRE", "who": f[0]}).map(func(r): return int(r["why"].get("wanted", 0)))
	Rules.staff_to_posts(w, f[0])
	check_eq(asked.call(), [], "no stranger asked for")
	Company.set_level(w, f[0], f[1], 313)
	check_eq(Company.hire_wanted(w, f[0], f[1]), {"G": 1, "S": 0, "Sp": 0}, "1.25 posts' work: two persons, one of them the family")
	check_eq(mine.call(), [["G", 1]], "one general post open")
	Rules.staff_to_posts(w, f[0])
	check_eq(asked.call(), [1], "staff_to_posts asks for one stranger (a test plant stands on no site, so the hire itself is refused there)")
	Company.set_level(w, f[0], f[1], 1000)
	check_eq(Company.hire_wanted(w, f[0], f[1]), {"G": 3, "S": 0, "Sp": 0}, "full: the three general posts the family leaves")


func test_the_work_in_the_first_year_counts_the_months_before_the_colony_at_its_eating_need() -> void:
	# 15a: "averaged per month over the last twelve months"; the months before the colony count at the need the
	# government counts for its grant (61b, Bob's reading with Wilma's yes): the first months' store filling (2,000 a
	# month against an eating need of 1,000) is not read as a year of it, and founding does not wait for a year
	var w := _w()
	var stores := Company.create(w, "SHOP", "LARGE", HW, "Stores", {"area": "landing"})
	Company.stock_add(w, stores, "FOOD", 100000 * S, 10 * S, "LANDING", "x")
	Company.offer(w, stores, "FOOD", TypeTable.start_price("FOOD"))
	var acct := "hh:test"
	w.ledger.open_account(acct)
	w.ledger.transfer(Ledger.EXTERNAL, acct, 100000000 * S, "TEST", 0)
	Households.seed_test(w, "landing", "I2", "G", 1000)
	var need := 0
	for b in Households.buyers(w):
		if String(b["area"]) == "landing":
			need += int(b["persons"]) * int(Households.NEED_PER_PERSON["FOOD"])
	check(need > 0, "the landing's eating need: %d" % need)
	Market.order(w, {"kind": "POOL", "id": "pool", "acct": acct, "area": "landing"}, "FOOD", 2000 * S, 100 * S)
	Market.clear(w)
	check_eq(Rules.work_qty(w, "FARM", "landing"), (2000 * S + 11 * need) / 12, "month 0: the 2,000 ordered and eleven months at the eating need")
	for m in range(1, 12):
		w.month = m
		Market.order(w, {"kind": "POOL", "id": "pool", "acct": acct, "area": "landing"}, "FOOD", (2000 if m < 6 else 1000) * S, 100 * S)
		Market.clear(w)
	check_eq(Rules.work_qty(w, "FARM", "landing"), (6 * 2000 + 6 * 1000) * S / 12, "a full year: only the months lived, 1,500 a month")
	check_eq(Rules.work_qty(w, "CLINIC", "landing"), 0, "a type that sells no item: none")

func test_an_output_step_never_rounds_to_nothing_up_or_past_five_percent_down() -> void:
	# Terra's review: per mille levels truncated, so a large builder's crew (60 posts: one post's share 16 per mille,
	# 16 x 5% = 0) at 19 or less never climbed, and a small level kept by flooring lost more than 5%
	var w := _w()
	var b := Company.create(w, "BUILDER", "LARGE", HW, "B", {"area": "landing"})
	Company.set_level(w, b, "crew", 10)
	Rules.output_rule(w, b, {"offered": 0, "sold": 0, "unmet_above": 1000 * S, "refused": 0}, false)
	check(Company.level_of(w, b, "crew") > 10, "a large crew at 10 per mille climbs (now %d)" % Company.level_of(w, b, "crew"))
	Company.set_level(w, b, "crew", 19)
	_three_months(w, b, {"offered": 1000 * S, "sold": 0, "unmet_above": 0, "refused": 0})
	check_eq(Company.level_of(w, b, "crew"), 19, "19 per mille: 5% of it is under one per mille, so it keeps 19 (never more than 5% off)")
	Company.set_level(w, b, "crew", 100)
	Rules.output_rule(w, b, {"offered": 1000 * S, "sold": 0, "unmet_above": 0, "refused": 0}, false)   # its run goes on: a fourth month
	check_eq(Company.level_of(w, b, "crew"), 95, "100: 5% off, 95")


func test_a_job_advert_is_paid_once_when_the_post_opens_not_every_month_it_stays_open() -> void:
	# 9.2, the user, 2026-11-18, verbatim: "On posts when you many an open post you pay the first time not every
	# consecutive month after"; Wilma's reading: paid in the month the post opens, whether or not anyone is hired then
	var w := _w()
	_homes(w)
	var Media: GDScript = load("res://sim/media/media_ops.gd")
	var a: String = Media.call("found_outlet", w, {"kind": "COMPANY", "id": "org:1"}, {"quality": 100})["out_id"]
	Media.call("state", w)["circ"] = {a: {"landing": 300}}
	var b := Company.create(w, "BUILDER", "SMALL", HW, "B", {"area": "landing"})
	var acct := CoreUtil.acct(b)
	var posts := TypeTable.posts("BUILDER", "SMALL")
	var one := {}
	var cost := 0
	for t in ["G", "S", "Sp"]:
		one[t] = int(Media.call("job_advert_cost", w, "landing", Company.hiring_salary(w, b, t, "landing"), 1))
		cost += int(one[t]) * int(posts[t])
	check(int(one["G"]) > 0, "a paper in the area: adverts cost something")
	w.ledger.transfer(Ledger.EXTERNAL, acct, cost, "TEST", 0)
	var papers0 := w.ledger.balance(String(Media.call("outlet", w, a)["account"]))
	Rules.staff_to_posts(w, b)   # nobody out of work: nobody hired
	check_eq(Company.staff_count(w, b), 0, "nobody to hire this month")
	check_eq(int(Company.books_month(w, b).get("adverts", 0)), cost, "every post opened: its advert paid this month, though nobody was hired")
	check_eq(w.ledger.balance(String(Media.call("outlet", w, a)["account"])) - papers0, cost, "paid to the paper")
	check_eq(w.ledger.balance(acct), 0, "nothing left for adverts")
	w.month = 1
	Company.close_month(w, b)
	Households.seed_test(w, "landing", "I2", "G", 4)
	Rules.staff_to_posts(w, b)
	check_eq(Company.staff_count(w, b, "G") / S, 4, "the same posts still open next month: it hires with no advert money")
	check_eq(int(Company.books_month(w, b).get("adverts", 0)), 0, "and pays nothing more for them")
	check_eq(Logbook.rows(w, {"kind": "HIRE", "what": "fewer posts advertised: it cannot pay all the job adverts"}).size(), 0,
		"nothing is asked of its money for a post already paid for")
	w.month = 2
	Company.close_month(w, b)
	Rules.staff_to_posts(w, b)
	check_eq(int(Company.books_month(w, b).get("adverts", 0)), 0, "the month after: nothing more")
	Households.layoff(w, b, "crew", "G", 1, {"reason": "TEST"})
	w.month = 3
	Company.close_month(w, b)
	w.ledger.transfer(Ledger.EXTERNAL, acct, 100000 * S, "TEST", 3)
	Rules.staff_to_posts(w, b)
	check_eq(int(Company.books_month(w, b).get("adverts", 0)), int(one["G"]), "a filled post open again: paid again, once")
	w.month = 4
	Company.close_month(w, b)
	Rules.staff_to_posts(w, b)
	check_eq(int(Company.books_month(w, b).get("adverts", 0)), 0, "and not the month after")


func test_rule_8_reads_what_the_plants_seen_actually_deliver_not_their_full_output() -> void:
	# rule 8, the user: "the same signal says the work is covered": the work is covered when what the plants seen deliver
	# meets what is ordered (Wilma's trace: 41 farms "at full output" 1,541 a month while they sold about 750)
	var w := _w()
	var stores := Company.create(w, "SHOP", "LARGE", HW, "Stores", {"area": "landing"})
	Company.stock_add(w, stores, "FOOD", 100000 * S, 10 * S, "LANDING", "x")
	Company.offer(w, stores, "FOOD", TypeTable.start_price("FOOD"))
	var acct := "hh:test"
	w.ledger.open_account(acct)
	w.ledger.transfer(Ledger.EXTERNAL, acct, 100000000 * S, "TEST", 0)
	var farms: Array = []
	for i in 5:
		farms.append(_large_farm(w))   # 5 x 240 = 1,200 a month at full output
	for m in Rules.WORK_MONTHS:
		w.month = m
		Market.order(w, {"kind": "POOL", "id": "pool", "acct": acct, "area": "landing"}, "FOOD", 1000 * S, 100 * S)
		Market.clear(w)
		for f in farms:
			Company.book(w, f, "made:FOOD", 120 * S)   # each really makes 120 a month, its family takes 20, it sells 30
			Company.book(w, f, "took:FOOD", 20 * S)
			Company.book(w, f, "sold:FOOD", 30 * S)
			Company.close_month(w, f)
	var f := Rules.founding(w, "FARM", "landing")
	var row: Dictionary = Logbook.rows(w, {"kind": "RULE"})[-1]
	check_eq(int(row["why"]["capacity"]), 500 * S, "what the five brought to the market a month, 5 x (120 - 20), not their 1,200 at full output nor the 150 they sold")
	check(not bool(row["why"]["covered"]), "500 of 1,000 delivered: not covered")
	check_eq(int(f["FAMILY"]["work_share"]), Rules.work(w, "FARM", "landing") / 31, "rule 7's share test still divides the work by every plant's sixths (15a)")
	var fresh := _large_farm(w)
	Rules.founding(w, "FARM", "landing")
	check_eq(int(Logbook.rows(w, {"kind": "RULE"})[-1]["why"]["capacity"]), 500 * S + TypeTable.output_milli("FARM", "LARGE"),
		"a farm with no closed month yet counts at its full output: %s" % fresh)


func test_rule_7_costs_a_company_at_the_areas_starting_salaries() -> void:
	# 15a: the share "covers what a company of that size costs to run per month"; its posts cost what they are offered,
	# the area's starting salary (9.2, the user: 2 x the rent), not the type table's 300 (Bob's trace: a family farm read
	# 1,379 a month against about 900, and founding stayed shut while the colony went hungry)
	var w := _w()
	var posts := TypeTable.posts("FARM", "FAMILY")
	var want := 0
	for t in posts:
		want += int(posts[t]) * Rules.starting_salary(w, "landing", String(t))
	var u := TypeTable.upkeep_milli("FARM", "FAMILY")
	want += int(u["material"]) * TypeTable.start_price("MATERIAL") / S + int(u["bw"]) * TypeTable.start_price("BW") / S
	check_eq(Rules.running_cost(w, "FARM", "FAMILY", "landing"), want, "a family farm: its posts at the starting salaries and its upkeep")
	check(Rules.running_cost(w, "FARM", "FAMILY", "landing") < 1000 * S, "about 900 a month at the landing (%d)" % (Rules.running_cost(w, "FARM", "FAMILY", "landing") / S))


## Rule 4's signal three months running (the user: output is lowered only after "3 months in a row" of over half unsold):
## the first two leave the level, the third may cut. Leaves the world at the month after.
func _three_months(w: WorldState, cid: String, sig: Dictionary) -> void:
	for i in 3:
		Rules.output_rule(w, cid, sig, false)
		w.month += 1


func test_output_is_lowered_only_after_over_half_unsold_three_months_in_a_row() -> void:
	# section 3, rule 4, the user, 2026-11-18: "The production output is only lowered if over 50% of offered goods is not
	# sold 3 months in a row"
	var w := _w()
	var f := _farm(w, 6, 2)
	var glut := {"offered": 100 * S, "sold": 40 * S, "unmet_above": 0, "refused": 0}   # 60% unsold
	var half := {"offered": 100 * S, "sold": 50 * S, "unmet_above": 0, "refused": 0}   # exactly 50%: does not count
	var lv := func() -> int: return Company.level_of(w, f[0], f[1])
	Company.set_level(w, f[0], f[1], 800)
	for sig in [glut, glut, half]:
		Rules.output_rule(w, f[0], sig, false)
		w.month += 1
	check_eq(lv.call(), 800, "two months over half, then one at half: never cut, and the count starts again")
	for sig in [half, half, half]:
		Rules.output_rule(w, f[0], sig, false)
		w.month += 1
	check_eq(lv.call(), 800, "exactly 50% unsold three months: not over half, no cut")
	Rules.output_rule(w, f[0], glut, false)
	w.month += 1
	Rules.output_rule(w, f[0], glut, false)
	w.month += 1
	check_eq(lv.call(), 800, "two months over half: the price falls (rule 2), the level does not")
	Rules.output_rule(w, f[0], glut, false)
	w.month += 1
	check_eq(lv.call(), 760, "the third month in a row: lowered by 5% (the user: \"A CUT IS 5%\")")
	Rules.output_rule(w, f[0], glut, false)
	w.month += 1
	check_eq(lv.call(), 722, "a fourth month in a row: lowered 5% again (the user: \"IF THERE'S IS A FOURTH MONTH LOWER AGAIN\")")
	Rules.output_rule(w, f[0], {"offered": 0, "sold": 0, "unmet_above": 0, "refused": 0}, false)
	w.month += 1
	var after := int(lv.call())
	Rules.output_rule(w, f[0], glut, false)
	w.month += 1
	check_eq(lv.call(), after, "a month with nothing offered breaks the run: one glut month after it cuts nothing")
	var b := Company.create(w, "BUILDER", "SMALL", HW, "B", {"area": "landing"})
	Company.set_level(w, b, "crew", 800)
	Rules.output_rule(w, b, glut, false)
	w.month += 1
	check_eq(Company.level_of(w, b, "crew"), 800, "a builder's crew the same: one month is no cut")


func test_rule_8_counts_a_plants_months_not_yet_lived_at_full_output() -> void:
	# Terra's trace: a farm founded in autumn was read at its winter yield, 3 to 4 FOOD a month, a tenth of a farm, and
	# kept founding open (36 farms at month 12, 63 at month 18, then a glut); Wilma: over twelve months, each month the
	# plant has not yet lived counts at its full output
	var w := _w()
	var f := _large_farm(w)
	var full := TypeTable.output_milli("FARM", "LARGE")
	for m in 3:
		w.month = m
		Company.book(w, f, "made:FOOD", 4 * S)   # three winter months at 4 a month
		Company.close_month(w, f)
	Rules.founding(w, "FARM", "landing")
	var cap := int(Logbook.rows(w, {"kind": "RULE"})[-1]["why"]["capacity"])
	check_eq(cap, (3 * 4 * S + 9 * full) / 12, "three winter months as they were, nine months not yet lived at full output: %d, not 4" % (cap / S))
	check(cap > full / 2, "not a tenth of a farm")


func test_rule_3_raises_output_when_it_sells_out_by_five_percent_never_more() -> void:
	# rule 3, the user: "if you sell out all your producing produce MORE"; at most 5% of the level a month (section 3,
	# "25?! 5!!!"; Otto measured a rise below one post's share of up to 12.5% of the level)
	var w := _w()
	var f := _farm(w, 6, 2)
	var lv := func() -> int: return Company.level_of(w, f[0], f[1])
	Company.set_level(w, f[0], f[1], 600)
	Rules.output_rule(w, f[0], {"offered": 50 * S, "sold": 50 * S, "unmet_above": 0, "refused": 0}, false)
	check_eq(lv.call(), 630, "sold out with no order left over: still sold out, up 5%")
	Rules.output_rule(w, f[0], {"offered": 50 * S, "sold": 49 * S, "unmet_above": 0, "refused": 0}, false)
	check_eq(lv.call(), 630, "one unit left unsold: not sold out, no rise")
	Rules.output_rule(w, f[0], {"offered": 50 * S, "sold": 50 * S, "unmet_above": 0, "refused": 0}, true)
	check_eq(lv.call(), 630, "sold out while holding stock back: no rise (12.3, 18)")
	for start in [1, 10, 19, 60, 125, 400, 999]:
		Company.set_level(w, f[0], f[1], start)
		Rules.output_rule(w, f[0], {"offered": 10 * S, "sold": 10 * S, "unmet_above": 100 * S, "refused": 0}, false)
		var rise: int = int(lv.call()) - int(start)
		check(rise >= 1 and (rise <= start * 50 / 1000 or rise == 1), "from %d: rose %d, 5%% of the level at most (or the one per mille step)" % [start, rise])
	Company.set_level(w, f[0], f[1], 0)
	Rules.output_rule(w, f[0], {"offered": 0, "sold": 0, "unmet_above": 10 * S, "refused": 0}, false)
	check_eq(lv.call(), 1, "nothing to offer and orders came: sold out, climbs from 0")



## A family farm with `bal` credits in its account and a month that earned `earned` (all sales, nothing paid out).
func _buffer_farm(w: WorldState, bal: int, earned: int) -> String:
	var f := _farm(w, 0, 0)
	var fam := Households.make_founder(w, Households.seed_test(w, "landing", "I2", "G", 10), "", true)
	Company.family_set(w, f[0], f[1], fam, {"G": 1})
	if bal > 0:
		w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.acct(f[0]), bal, "TEST", 0)
	Company.book(w, f[0], "rev", earned)
	return String(f[0])


func test_the_farm_keeps_half_until_six_months_of_running_cost_are_built_up_then_ten_percent() -> void:
	# 15e, the user, 2026-11-18, verbatim: "the farm needs a buffer say 50% until it had 6 months worth built up then 10%"
	var w := _w()
	var line := 6 * Rules.running_cost(w, "FARM", "SMALL", "landing")
	var low := _buffer_farm(w, line - 1, 1000 * S)
	var wn := Rules.winnings(w, low)
	check_eq(int(wn["buffer_line"]), line, "the line is six months of the farm's running cost")
	check_eq([int(wn["keep_pm"]), int(wn["amount"])], [500, 500 * S], "one credit short of six months: it keeps 50%")
	var at := _buffer_farm(w, line, 1000 * S)
	wn = Rules.winnings(w, at)
	check_eq([int(wn["keep_pm"]), int(wn["amount"])], [100, 900 * S], "six months built up: it keeps 10%")
	var above := _buffer_farm(w, 2 * line, 1000 * S)
	check_eq(int(Rules.winnings(w, above)["amount"]), 900 * S, "and stays at 10% above it")


func test_the_buffer_never_pays_out_more_than_the_account_holds() -> void:
	var w := _w()
	var poor := _buffer_farm(w, 100 * S, 1000 * S)   # earned 1000 on the books, but only 100 in the account
	check_eq(int(Rules.winnings(w, poor)["amount"]), 100 * S, "half would be 500; the account holds 100")
